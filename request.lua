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
        -- TODO extract single cookies with Request.PATTERN_COOKIE_STRING (and that string must be edited, because cookie options are separated by , but would not be in this case ;)
    end
    return headers
end


Request.parseURLEncoded = function(query)
    local parameters = {}
    for name, value in string.gmatch(query, Request.PATTERN_QUERY_STRING) do parameters[name] = value end
    return parameters
end


function Request:new(transmitter)
    self.transmitter = transmitter -- client socket object
    self.complete = false
end


function Request:receiveHeaders()
    local firstline, status, partial = self.transmitter:receive()
    if firstline == nil or status == "timeout" or partial == "" or status == "closed" then
        return false
    end

    local method, path, protocol = string.match(firstline, self.PATTERN_REQUEST)
    if not method then
        return false
    end

    local resource, urlquery = ""
    if #path > 0 then
        resource, urlquery = string.match(path, self.PATTERN_PARAMETER_STRING)
        resource = self.normalize(resource)
    end

    local headerquery, header = ""
    repeat
        header = self.transmitter:receive() or ""
        headerquery = headerquery..header.."\r\n"
    until #header <= 0

    self.protocol = protocol
    self.method = method:upper()
    self.header = self.parseHeaders(headerquery)
    self.url = resource or path
    self.query = path -- raw url
    self.parameter = self.parseURLEncoded(urlquery)
end


function Request:receiveMessage()
    local length = 0
    if type(self.content) ~= "string" then self.content = "" end
    if self.header["Transfer-Encoding"] == "chunked" then
        -- see https://gist.github.com/CMCDragonkai/6bfade6431e9ffb7fe88
        repeat
            length = tonumber(self.transmitter:receive(), 16) -- hexadecimal value
            self.content = self.content..self.transmitter:receive(length)
            coroutine.yield(self)
        until length <= 0 -- 0\r\n
    else
        length = tonumber(self.header["Content-Length"] or 0)
        self.content = self.transmitter:receive(length)
    end
    self.complete = true
end


function Request:onConnect() -- xors hook
    self:receiveHeaders()
    self.run = coroutine.create(self.receiveMessage)
    coroutine.resume(self.run, self)
end


function Request:onEnterFrame() -- xors hook
    if self.run ~= nil and coroutine.status(self.run) ~= "dead" then
        coroutine.resume(self.run, self)
    end
end


function Request:hotswap() -- hook for restoring state when hot-swappingw this file
    return {
        transmitter = self.transmitter,
        protocol = self.protocol,
        method = self.method,
        header = self.header,
        url = self.url,
        query = self.query,
        parameter = self.parameter,
        content = self.content,
        run = self.run -- coroutine resume function
    }
end


return Request
