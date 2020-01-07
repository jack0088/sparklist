-- 2019 (c) kontakt@herrsch.de

-- client response generator
-- a response runs after every request from client to server

-- local utf8len = require "utf8".len
local runstring = loadstring or load -- Lua > 5.1
local mimeguess = require "mimetype".guess
local class = require "class"
local Response = class()


Response.PATTERN_HEADER = "%s: %s\r\n" -- field, value
Response.PATTERN_HEADER_RESPONSE = "HTTP/1.1 %s %s\r\n%s\r\n" -- status, message, headers
Response.PATTERN_CONTENT_RESPONSE = "%s\r\n" -- [length,] content [, trailer_headers]
Response.PATTERN_RESPONSE = Response.PATTERN_HEADER_RESPONSE..Response.PATTERN_CONTENT_RESPONSE
Response.STATUS_TEXT = {
    [100] = "Continue",
    [101] = "Switching Protocols",
    [200] = "OK",
    [201] = "Created",
    [202] = "Accepted",
    [203] = "Non-Authoritative Information",
    [204] = "No Content",
    [205] = "Reset Content",
    [206] = "Partial Content",
    [300] = "Multiple Choices",
    [301] = "Moved Permanently",
    [302] = "Found",
    [303] = "See Other",
    [304] = "Not Modified",
    [305] = "Use Proxy",
    [307] = "Temporary Redirect",
    [400] = "Bad Request",
    [401] = "Unauthorized",
    [402] = "Payment Required",
    [403] = "Forbidden",
    [404] = "Not Found",
    [405] = "Method Not Allowed",
    [406] = "Not Acceptable",
    [407] = "Proxy Authentication Required",
    [408] = "Request Time-out",
    [409] = "Conflict",
    [410] = "Gone",
    [411] = "Length Required",
    [412] = "Precondition Failed",
    [413] = "Request Entity Too Large",
    [414] = "Request-URI Too Large",
    [415] = "Unsupported Media Type",
    [416] = "Requested range not satisfiable",
    [417] = "Expectation Failed",
    [500] = "Internal Server Error",
    [501] = "Not Implemented",
    [502] = "Bad Gateway",
    [503] = "Service Unavailable",
    [504] = "Gateway Time-out",
    [505] = "HTTP Version not supported"
}


Response.UTC = function(offset, zone) -- Coordinated Universal Time
    -- @offset number in hours
    -- @zone string, e.g.:
    -- "GTM" = Greenwich Mean Time (offset = 0)
    -- "CET" = Central European (Standard) Time (offset = +1)
    offset = type(offset) == "number" and offset * 60 * 60 or 0
    zone = offset ~= 0 and zone or "GTM"
    return os.date("!%a, %d %b %Y %H:%M:%S "..zone, os.time() + offset)
end


Response.GTM = function() return Response.UTC(0, "GTM") end -- Europe
Response.CET = function() return Response.UTC(1, "CET") end -- Germany, among others


Response.serializeURLEncoded = function(parameters)
    local query = ""
    for k, v in pairs(parameters) do query = query..k.."="..v.."&" end
    return query:sub(1, -2)
end


Response.serializeHeaders = function(headers)
    local query = ""
    for identifier, values in pairs(headers) do
        for _, content in ipairs(values) do
            query = query..string.format(Response.PATTERN_HEADER, identifier, content)
        end
    end
    return query
end


Response.file = function(url)
    local handle = io.open(url, "rb")
    if handle then
        local content = handle:read("*a")
        handle:close()
        return content, mimeguess(url), 200 -- binary content, mime type, status code
    end
    return nil, nil, 404
end


function Response:new(receiver, request)
    self.receiver = receiver -- client socket object
    self.request = request
    self.header = {}
    self.headers_send = false
    self.message_send = false
end


function Response:addHeader(identifier, content)
    if identifier == "Set-Cookie" then -- add security recomendations for cookies https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie
        local function unpack_attributes(cookie)
            local attributes = {}
            for k, v in string.gmatch(cookie, "([^=; ]+)=([^=;]+)") do
                k = k:lower():gsub("%p", "")
                if not string.find("expires maxage domain path secure httponly samesite", k) then attributes.name, attributes.value = k, v
                else attributes[k] = v end
            end
            return attributes
        end

        local function verify_attributes(cookie)
            assert(cookie.name, cookie.value, "cookie header is missing attributes")
            cookie.name = cookie.name:gsub("%p*", "") -- trim punctuation
            cookie.httponly = cookie.httponly == false and false or true -- nil defaults to true
            cookie.samesite = cookie.samesite or "Lax"
            return cookie
        end

        local function pack_attributes(cookie)
            local value = string.format("%s=%s", cookie.name, cookie.value)
            if cookie.expires then value = value.."; Expires="..cookie.expires end
            if cookie.maxage then value = value.."; Max-Age="..cookie.maxage end
            if cookie.domain then value = value.."; Domain="..cookie.domain end
            if cookie.path then value = value.."; Path="..cookie.path end
            if cookie.secure then value = value.."; Secure" end
            if cookie.httponly then value = value.."; HttpOnly" end
            if cookie.samesite then value = value.."; SameSite="..cookie.samesite end
            return value
        end

        content = pack_attributes(verify_attributes(unpack_attributes(content)))
    end
    if not self.header[identifier] then self.header[identifier] = {} end
    table.insert(self.header[identifier], content)
end


function Response:sendHeaders()
    if not self.headers_send then
        self.receiver:send(string.format(
            self.PATTERN_HEADER_RESPONSE,
            status or 200,
            self.STATUS_TEXT[status or 200],
            self.serializeHeaders(self.header)
        ))
        self.headers_send = true
    end
    return true
end


function Response:sendMessage(stream)
    if not self.message_send then
        self:sendHeaders()
        local threaded = type(coroutine.running()) == "thread"
        local chunked = self.header["Transfer-Encoding"] ~= nil
        local length = #(stream or "")
        if self.message == nil then self.message = "" end
        if length < 1 then -- message_send
            if threaded then self.message = "" end
            return self:submit()
        end
        if not threaded then self.message = self.message..stream else self.message = stream end
        if not chunked then
            return self:submit(string.format(self.PATTERN_CONTENT_RESPONSE, stream))
        else
            self.receiver:send(string.format(
                "%s\r\n"..self.PATTERN_CONTENT_RESPONSE,
                string.format("%X", length), -- hexadecimal value
                stream
            ))
        end
    end
    return true
end


function Response:submit(content, mime, status, ...) -- NOTE mime-types must match their actual file mime-types, e.g. a *.txt file saved in utf-8 charset should be passed with "text/plain; charset=utf-8"
    if not self.receiver then
        return false
    end

    -- close up ongoing response
    if self.headers_send then
        if self.message_send then return true end
        local threaded = type(coroutine.running()) == "thread"
        local chunked = self.header["Transfer-Encoding"] ~= nil
        if not content and chunked then content = "0\r\n\r\n" end
        if threaded then self.message = "" end
        self.receiver:send(content or "")
        self.message_send = true
        return true
    end

    -- repond with file or view
    if type(content) == "string" and #content > 0 then
        local file_extension = content:match(".+(%.%w%w%w+)$")
        if file_extension then
            local file_content, file_mime, response_status = self.file(content:gsub("^[%./]+", ""))
            if file_extension == ".lua"
            and type(file_content) == "string"
            and (mime or ""):match("^text/html.*") ~= nil
            then
                -- respond with a non-empty .lua file
                -- with explicit mime of 'text/html' means we want a view template
                -- fire runstring() should produce an HTML string, or error out
                local view_loader = assert(runstring(file_content))()
                local html_content = assert(view_loader(...))
                content = html_content
            else
                content = file_content
                mime = mime or file_mime
                status = status or response_status
            end
        end
    end

    -- respond with 404
    if not content then
        status = status or 404
        mime = mime or "text/html"
        content = assert(dofile("view/404.lua"))(
            self.request.query,
            self.request.method,
            status,
            self.STATUS_TEXT[status]
        )
    end

    self:addHeader("Date", Response.GTM())
    self:addHeader("Content-Length", #content)
    self:addHeader("Content-Type", mime or "text/plain")
    self:addHeader("X-Content-Type-Options", "nosniff")
    self.receiver:send(string.format(
        self.PATTERN_RESPONSE,
        status or 200,
        self.STATUS_TEXT[status or 200],
        self.serializeHeaders(self.header),
        content
    ))

    self.headers_send = true
    self.message_send = true
    return true
end


function Response:redirect(url)
    self:addHeader("Location", url)
    return self:submit(nil, nil, 307) -- automatic request forward with unchanged request method and body
end


function Response:attach(location, name) -- attach file and force client browser to download it from given location [with custom name]
    local filename, extension = location:match("([^%p]+)%.(%a%a%a+)$")
    self:addHeader("Content-Disposition", string.format("attachment; filename=%s", name or filename))
    return self:submit(location)
end


function Response:hotswap()
    return {
        receiver = self.receiver,
        request = self.request,
        header = self.header,
        headers_send = self.headers_send,
        message_send = self.message_send
    }
end


return Response
