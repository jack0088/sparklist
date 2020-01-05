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


Request.parseURLEncoded = function(query)
    local parameters = {}
    for name, value in string.gmatch(query, Request.PATTERN_QUERY_STRING) do parameters[name] = value end
    return parameters
end


-- TODO add helper functions for further extracting header values like cookie that consits of multiple parameters separated by semicolon (other headers do this as well like Content-Disposition from POST method)


Request.parseHeaders = function(query)
    local headers = {}
    for identifier, content in string.gmatch(query, Request.PATTERN_HEADER) do
        if not headers[identifier] then headers[identifier] = {} end
        table.insert(headers[identifier], content)
    end
    return headers
end


function Request:new(transmitter)
    self.transmitter = transmitter -- client socket object
    self.headers_received = false
    self.message_received = false
    self:receiveHeaders()
end


function Request:receiveHeaders()
    if not self.headers_received then
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
        self.headers_received = true
    end
    return true
end


function Request:receiveMessage(stream_sink)
    if not self.message_received then
        self.message = ""
        self:receiveHeaders()
        local threaded = type(coroutine.running()) == "thread"
        local chunked = self.header["Transfer-Encoding"] ~= nil
        local length = tonumber(self.header["Content-Length"] or 0)
        repeat
            if chunked then length = tonumber(self.transmitter:receive(), 16) end -- hexadecimal value
            if length > 0 then
                local stream = self.transmitter:receive(length)
                if not threaded then self.message = self.message..stream else self.message = stream end
                if not chunked then length = 0 end -- signal to break the loop
                if type(stream_sink) == "function" then stream_sink(stream) end
            end
        until length <= 0 -- 0\r\n
        if threaded then self.message = "" end
        self.message_received = true
    end
    return true
end


function Request:receiveFile()
    local stream_sink
    if self.method == "POST" and self.header["Content-Disposition"] then
        stream_sink = function(stream)
            -- TODO we need to parse POST data
            -- then, implement receiving file attachments as described in
            -- https://stackoverflow.com/questions/8659808/how-does-http-file-upload-work#answer-28193031
            -- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Disposition
        end
    end
    self:receiveMessage(stream_sink)
    return true
end


function Request:hotswap()
    return {
        transmitter = self.transmitter,
        protocol = self.protocol,
        method = self.method,
        header = self.header,
        url = self.url,
        query = self.query,
        parameter = self.parameter,
        message = self.message,
        headers_received = self.headers_received,
        message_received = self.message_received,
        route_controller = self.route_controller -- generated by the router
    }
end


return Request
