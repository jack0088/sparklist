-- 2019 (c) kontakt@herrsch.de

-- client request parser
-- runs on every request coming from client to server

local class = require "class"
local Header = require "header"
local Request = class()


Request.decodeUrlEncoded = function(percent_encoded) -- application/x-www-form-urlencoded
    local function character(hex)
        return string.char(tonumber(hex, 16))
    end
    return percent_encoded:gsub("%+", "%%20"):gsub("%%(%x%x)", character) -- [+|%20] for space
end


Request.explodePath = function(query)
    local list = {}
    for name, value in string.gmatch(query, "([^=]*)=([^&]*)&?") do
        list[name] = Request.decodeUrlEncoded(value)
    end
    return list
end


Request.normalizePath = function(path)
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


function Request:new(transmitter)
    self.transmitter = transmitter -- client socket object
    self.headers_received = false
    self.message_received = false
    self:receiveHeader()
end


function Request:receiveHeader()
    if not self.headers_received then
        local firstline, status, partial = self.transmitter:receive()
        if firstline == nil or status == "timeout" or partial == "" or status == "closed" then
            return false
        end
        local method, path, protocol = string.match(firstline, "(.-)%s(%S+)%s(HTTP/%d%.%d)$")
        if not method then
            return false
        end
        local resource, urlquery = ""
        if #path > 0 then
            resource, urlquery = string.match(path, "^([^#?]+)[#|?]?(.*)")
        end
        local headerquery, header = ""
        repeat
            header = self.transmitter:receive() or ""
            headerquery = headerquery..(#header > 0 and header.."\r\n" or "")
        until #header <= 0

        -- Some browsers send multiple requests to the same url because they try to obtain the .favicon; Safari even trigger request while auto-completing you input. Just don't wonder when you read these in the log file...
        print(string.format(
            "%s %s\n%s",
            os.date("%d.%m.%Y %H:%M:%S"),
            firstline,
            headerquery:gsub("([^\r\n]+)", "    %1"):match("(.+)[\r\n]+$")
        ))

        self.protocol = protocol
        self.method = method:upper()
        self.url = path -- raw
        self.path = self.normalizePath(resource)
        self.query = self.explodePath(urlquery)
        -- self.fragment = nil -- browser only feature
        self.header = Header(headerquery)
        self.headers_received = true
    end
    return true
end


function Request:receiveMessage(stream_sink)
    if not self.message_received then
        self:receiveHeader()
        self.message = ""
        local threaded = type(coroutine.running()) == "thread"
        local chunked = self.header:get "Transfer-Encoding" ~= nil
        local length = tonumber(self.header:get "Content-Length" or 0)
        repeat
            if chunked then length = tonumber(self.transmitter:receive(), 16) end -- hexadecimal value
            if length > 0 then
                local stream = self.transmitter:receive(length)
                if not threaded then self.message = self.message..stream else self.message = stream end
                if not chunked then length = 0 end -- signal to break the loop
                if type(stream_sink) == "function" then stream_sink(stream) end
            end
        until length <= 0 -- 0\r\n\r\n
        if threaded then self.message = "" end
        self.message_received = true
    end
    return true
end


function Request:receiveFile()
    local stream_sink
    if self.method == "POST" and self.header:get "Content-Disposition" then
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


return Request
