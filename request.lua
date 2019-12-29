-- 2019 (c) kontakt@herrsch.de

-- client request parser
-- runs on every request coming from client to server

local class = require "class"
local Request = class()


Request.PATTERN_METHOD = "^(.-)%s"
Request.PATTERN_PATH = "(%S+)%s*"
Request.PATTERN_PROTOCOL = "(HTTP%/%d%.%d)"
Request.PATTERN_REQUEST = (Request.PATTERN_METHOD..Request.PATTERN_PATH..Request.PATTERN_PROTOCOL)
Request.PATTERN_HEADER = "([%w-]+): ([%w %p]+=?)"
Request.PATTERN_QUERY_STRING = "([^=]*)=([^&]*)&?"
Request.PATTERN_COOKIE_STRING = "([^=]*)=([^;]*);? ?"
Request.PATTERN_PARAMETER_STRING = "^([^#?]+)[#|?]?(.*)"


Request.normalize = function(path)
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


Request.parseHeaders = function(query)
    local headers = {}
    for identifier, content in string.gmatch(query, Request.PATTERN_HEADER) do
        if not headers[identifier] then headers[identifier] = {} end
        table.insert(headers[identifier], content)
        -- TODO extract single cookies with Request.PATTERN_COOKIE_STRING (and that string must be edited, because cookie options are separated dby , in this case not ;)
    end
    return headers
end


Request.parseURLEncoded = function(query)
    local parameters = {}
    for name, value in string.gmatch(query, Request.PATTERN_QUERY_STRING) do parameters[name] = value end
    return parameters
end


function Request:new(receiver)
    local firstline, status, partial = receiver:receive()
    if firstline == nil or status == "timeout" or partial == "" or status == "closed" then
        return false
    end

    local method, path, protocol = string.match(firstline, Request.PATTERN_REQUEST)
    if not method then
        return false
    end

    local resource, urlquery = ""
    if #path > 0 then
        resource, urlquery = string.match(path, Request.PATTERN_PARAMETER_STRING)
        resource = Request.normalize(resource)
    end

    local headerquery, header = ""
    repeat
        header = receiver:receive() or ""
        headerquery = headerquery..header.."\r\n"
    until #header <= 0

    self.receiver = receiver
    self.protocol = protocol
    self.method = method:upper()
    self.header = Request.parseHeaders(headerquery)
    self.url = resource or path
    self.query = path -- raw url
    self.parameter = Request.parseURLEncoded(urlquery)

    -- TODO? support Transfer-Encoding: chunked with self.keepalive = true (also see response.lua and https://gist.github.com/CMCDragonkai/6bfade6431e9ffb7fe88)
    local length = tonumber(self.header["Content-Length"] or 0)
    if length > 0 then self.content = self.receiver:receive(length) end

    return self
end


function Request:hotswap() -- hook for restoring state when hot-swappingw this file
    return {
        receiver = self.receiver,
        protocol = self.protocol,
        method = self.method,
        header = self.header,
        url = self.url,
        query = self.query,
        parameter = self.parameter,
        content = self.content
    }
end


return Request
