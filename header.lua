-- 2019 (c) kontakt@herrsch.de

-- HTTP/1.1

local hotload = require "hotload"
local class = hotload "class"
local Header = class()

Header.HTTP_STATUS_MESSAGE = {
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


-- handles application/x-www-form-urlencoded
-- returns raw url by converting percentage-encoded strings back into acii
Header.decodeUrlEncoded = function(percent_encoded)
    local function character(hex)
        return string.char(tonumber(hex, 16))
    end
    return percent_encoded:gsub("%+", "%%20"):gsub("%%(%x%x)", character) -- [+|%20] for space
end


-- handles application/x-www-form-urlencoded
-- returns percent encoded url, opposite of .decodeUrlEncoded()
Header.encodeUrlEncoded = function(raw_url)
    local function hex(character)
        return string.format("%%%02X", string.byte(character))
    end
    return raw_url:gsub("\n", "\r\n"):gsub("[^%w%%%-%.~_ ]", hex):gsub(" ", "+")
end


-- breaks an url query into single attribues and values
Header.explodePath = function(query)
    local attributes_list = {}
    for name, value in query:gmatch("([^=]*)=([^&]*)&?") do
        attributes_list[name] = Header.decodeUrlEncoded(value)
    end
    return attributes_list
end


-- opposite of .explodePath()
Header.implodePath = function(attributes_list)
    local query = ""
    for name, value in pairs(attributes_list) do
        query = query..name.."="..value.."&"
    end
    return query:sub(1, -2)
end


-- converts unsafe path urls into safe once by fixing their malformations
Header.normalizePath = function(path)
    local url = string.gsub(path, "\\", "/")
    url = string.gsub(url, "^/*", "/")
    url = string.gsub(url, "(/%.%.?)$", "%1/")
    url = string.gsub(url, "/%./", "/")
    url = string.gsub(url, "/+", "/")
    while true do
        local first, last = string.find(url, "/[^/]+/%.%./")
        if not first then break end
        url = string.sub(url, 1, first)..string.sub(url, last + 1)
    end
    while true do
        local n
        url, n = string.gsub(url, "^/%.%.?/", "/")
        if n == 0 then break end
    end
    while true do
        local n
        url, n = string.gsub(url, "/%.%.?$", "/")
        if n == 0 then break end
    end
    return url
end


function Header:new()
    self.registry = {}
    self.received = false
    self.sent = false
end


function Header:set(header_name, header_value)
    assert(not self.sent, "headers already sent")
    assert(type(header_name) == "string", "invalid header field type")
    assert(type(header_value) == "string" or type(header_value) == "number" or type(header_value) == "nil", "invalid header value type")
    
    -- HTTP header fields are case-insensitive!
    -- Field values may or may not be case-sensitive!
    header_name = header_name:lower()

    if header_name == "set-cookie" and type(header_value) == "string" then -- we optionally append some security settings to cookies
        local function unpack_attributes(cookie)
            local attributes = {}
            for k, v in string.gmatch(cookie, "([^=; ]+)=([^=;]+)") do
                if not string.find("expires maxage domain path secure httponly samesite", k:lower():gsub("%p", "")) then
                    attributes.name, attributes.value = k, v
                else
                    attributes[k] = v
                end
            end
            return attributes
        end

        local function verify_attributes(cookie)
            -- add security recomendations for cookies, see https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie and https://tools.ietf.org/html/rfc6265#page-7
            assert(cookie.name, cookie.value, "cookie header is missing attributes")
            cookie.name = cookie.name:gsub("[^a-zA-Z%-_]*", "") -- trim control characters, separator character, spaces and tabs
            cookie["HttpOnly"] = cookie["HttpOnly"] == false and false or true -- forbid JS to access cookies? nil defaults to true
            -- cookie["Secure"] = cookie["Secure"] == false and false or true -- use TLS/HTTPS only? nil defaults to true
            -- cookie["SameSite"] = cookie["SameSite"] or "None" -- Browsers default behaviour is "Lax"
            cookie["SameSite"] = cookie["SameSite"] or "Lax"
            return cookie
        end

        local function pack_attributes(cookie)
            local query = string.format("%s=%s", cookie.name, cookie.value)
            if cookie["Expires"]  then query = query.."; Expires="..cookie["Expires"] end
            if cookie["Max-Age"]  then query = query.."; Max-Age="..cookie["Max-Age"] end
            if cookie["Domain"]   then query = query.."; Domain="..cookie["Domain"] end
            if cookie["Path"]     then query = query.."; Path="..cookie["Path"] end
            if cookie["Secure"]   then query = query.."; Secure" end
            if cookie["HttpOnly"] then query = query.."; HttpOnly" end
            if cookie["SameSite"] then query = query.."; SameSite="..cookie["SameSite"] end
            return query
        end

        header_value = pack_attributes(verify_attributes(unpack_attributes(header_value)))
    end

    if type(self[header_name]) == "string" then
        self[header_name] = {self[header_name]}
    end
    if type(self[header_name]) == "table" and type(header_value) == "string" then
        table.insert(self[header_name], header_value)
    else
        self[header_name] = header_value
    end
    self.registry[header_name] = self[header_name]
end


function Header:get(header_name, parse_pattern, ...)
    assert(type(header_name) == "string", "header field must be a string value")
    header_name = header_name:lower()
    local header_value = self.registry[header_name]

    if type(header_value) == "string" then
        if type(parse_pattern) == "string" then
            return header_value:match(parse_pattern or ".+")
        end
        if type(parse_pattern) == "function" then
            return parse_pattern(header_value, ...)
        end
    end
    return header_value
end


function Header:parse(header_query)
    if type(header_query) == "string" then
        for header_name, header_value in header_query:gmatch("([%w%p]+): ([%w%p ]+)") do
            self:set(header_name, header_value)
        end
    end
end


function Header:serialize(http_status_code)
    assert(http_status_code, "http header is missing status code")
    local header_query = ""
    for header_name, header_value in pairs(self.registry) do
        header_query = header_query..string.format("%s: %s\r\n", header_name, header_value)
    end
    return string.format(
        "HTTP/1.1 %s %s\r\n%s\r\n",
        http_status_code,
        self.HTTP_STATUS_MESSAGE[http_status_code],
        header_query
    )
end


function Header:receive(transmitter)
    assert(not self.received, "http header already received")
    assert(transmitter, "http transmitter socket missing")

    local firstline, status, partial = transmitter:receive()
    if firstline == nil or status == "timeout" or partial == "" or status == "closed" then
        return nil
    end
    local method, path, protocol = string.match(firstline, "(.-)%s(%S+)%s(HTTP/%d%.%d)$")
    if not method then
        return nil
    end
    local resource, urlquery = ""
    if #path > 0 then
        resource, urlquery = string.match(path, "^([^#?]+)[#|?]?(.*)")
    end
    local headerquery, header = ""
    repeat
        header = transmitter:receive() or ""
        headerquery = headerquery..(#header > 0 and header.."\r\n" or "")
    until #header <= 0

    -- Some browsers send multiple requests to the same url because they try to obtain the .favicon; Safari even trigger request while auto-completing you input. Just don't wonder when you read these in the log file...
    print(string.format(
        "%s\n%s",
        firstline,
        headerquery:match("(.+)[\r\n]+$")
    ))

    self.protocol = protocol
    self.method = method:upper()
    self.url = path -- raw
    self.path = self.normalizePath(resource)
    self.query = self.explodePath(urlquery)
    -- self.fragment = nil -- browser only feature (e.g. #url-fragment-part)

    self:parse(headerquery)
    self.received = true
    return self
end


function Header:send(receiver, status)
    assert(not self.sent, "http header already sent")
    assert(receiver, "http receiver socket missing")
    assert(type(status) == "number" or type(status) == "string", "response status code missing")
    assert(self:get "date", "date header missing")
    assert(self:get "content-type", "http content type undefined")
    assert(self:get "transfer-encoding" or self:get "content-length", "http content length and/or encoding undefined")
    receiver:send(self:serialize(status))
    self.sent = true
    return self
end


return Header
