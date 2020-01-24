-- 2019 (c) kontakt@herrsch.de

-- client request parser
-- runs on every request coming from client to server

local hotload = require "hotload"
local class = hotload "class"
local Header = hotload "header"
local Message = hotload "message"
local Request = class()


function Request:new(transmitter)
    self.transmitter = transmitter -- client socket object
    self.header = Header():receiveHeader()
    self.message = Message()
end


function Request:receiveHeader()
    return self.header:receive(self.transmitter)
end


function Request:receiveMessage(stream_sink)
    local length = tonumber(self.header:get "Content-Length" or 0)
    local chunked = tostring(self.header:get("Transfer-Encoding")):match("chunked") == "chunked"
    return self.message:receive(self.transmitter, length, stream_sink, chunked)
end


--[[
function Request:receiveFile(stream_sink)
    local stream_sink
    if self.method == "POST" and self.header:get "Content-Disposition" then
        stream_sink = function(stream)
            -- TODO we need to parse POST data
            -- then, implement receiving file attachments as described in
            -- https://stackoverflow.com/questions/8659808/how-does-http-file-upload-work#answer-28193031
            -- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Disposition
        end
    end
    return self:receiveMessage(stream_sink)
end
--]]


return Request
