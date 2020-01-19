-- 2019 (c) kontakt@herrsch.de

-- client response generator
-- a response runs after every request from client to server

local runstring = loadstring or load -- Lua > 5.1
local mimeguess = require "utilities".filemime
local class = require "class"
local hotload = require "hotswap"
local Header = hotload "header"
local Response = class()


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


Response.encodeUrlEncoded = function(raw_url) -- handles application/x-www-form-urlencoded, returns percent encoded url, opposite of Request.decodeUrlEncoded
    local function hex(character)
        return string.format("%%%02X", string.byte(character))
    end
    return raw_url:gsub("\n", "\r\n"):gsub("[^%w%%%-%.~_ ]", hex):gsub(" ", "+")
end


Response.implodePath = function(attributes_list) -- opposite of Request.explodePath
    local query = ""
    for name, value in pairs(attributes_list) do
        query = query..name.."="..value.."&"
    end
    return query:sub(1, -2)
end


Response.file = function(url)
    local handle = io.open(url, "rb")
    if handle then
        local content = handle:read("*a")
        handle:close()
        return content, mimeguess(url), 200 -- (binary) content, mime-type, status code
    end
    return nil, nil, 404
end


function Response:new(receiver, request)
    self.receiver = receiver -- client socket object
    self.request = request
    self.header = Header()
    self.header_sent = false
    self.message_sent = false
end


function Response:sendHeader(status)
    if not self.header_sent then
        assert(type(status) == "number" or type(status) == "string", "response status code missing")
        assert(self.header:get "Date", "date header missing")
        assert(self.header:get "Content-Type", "http content type undefined")
        assert(self.header:get "Transfer-Encoding" or self.header:get "Content-Length", "http content length undefined")
        self.receiver:send(self.header:serialize(status))
        self.header_sent = true
    end
    return true
end


function Response:sendMessage(stream)
    if not self.message_sent then
        assert(self.receiver, "http receiver missing")
        assert(self.header_sent, "send http header first")
        stream = stream or ""
        local threaded = type(coroutine.running()) == "thread"
        local chunked = tostring(self.header:get("Transfer-Encoding")):match("chunked") == "chunked"
        local length = #stream
        if threaded then
            self.message = stream
        else
            self.message = (self.message or "")..stream
        end
        if chunked and length > 0 then
            self.receiver:send(string.format(
                "%s\r\n%s\r\n",
                string.format("%X", length), -- hexadecimal value
                stream
            ))
        elseif chunked then
            self.receiver:send("0\r\n\r\n")
            self.message_sent = true
        else
            self.receiver:send(string.format("%s\r\n", stream))
            self.message_sent = true
        end
    end
    return true
end


function Response:submit(content, mime, status, ...)
    if (self.header_sent or self.message_sent) and content == nil and mime == nil and status == nil then
        return self:sendMessage() -- finish up ongoing response
    end
    assert(not self.header_sent, "incomplete header sent too early")
    if type(content) == "string" and #content > 0 then
        local file_extension = content:match("%.%w%w[%w%p]*$")
        if file_extension then
            local file_content, file_mime, response_status = self.file(content:gsub("^[%./]+", ""))
            if file_extension == ".lua" and type(file_content) == "string" and (mime or ""):match("^text/html.*") ~= nil then
                -- response with *.lua file and explicit @mime of "text/html" means we want a view template
                local view_loader = assert(runstring(file_content))()
                local html_content = assert(view_loader(...))
                content = html_content
            else
                -- resond with file contents
                -- NOTE @mime must match its actual file encoding, e.g. *.txt file saved in charset=utf-8 must be passed with "text/plain; charset=utf-8"
                content = file_content
                mime = mime or file_mime
                status = status or response_status
            end
        end
    end
    if not content then
        status = status or 404
        mime = mime or "text/html"
        content = assert(dofile("view/error.lua"))(
            self.request.path,
            self.request.method,
            status,
            self.header.HTTP_STATUS_MESSAGE[status]
        )
    end
    self.header:set("Date", self.GTM()) -- update/assign
    self.header:set("Content-Type", mime or "text/plain")
    self.header:set("Content-Length", #content)
    self:sendHeader(status or 200)
    return self:sendMessage(content)
end


function Response:refresh(url, timeout, content, mime, ...)
    self.header:set("Refresh", tostring(timeout or 0).."; URL="..(url or self.request.path))
    if content then
        return self:submit(content, mime, nil, ...)
    end
end


function Response:redirect(url)
    self.header:set("Location", url) -- with browser back-button support
    return self:submit(nil, nil, 307) -- instant, automatic request forward with unchanged request method and body
end


function Response:attach(location, name) -- attach file and force client/browser to download it from given location [with custom name]
    local filename, extension = location:match("(.+)(%.%w%w[%w%p]*)$")
    self.header:add("Content-Disposition", string.format("attachment; filename=%s", name or filename))
    return self:submit(location)
end


return Response
