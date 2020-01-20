-- 2019 (c) kontakt@herrsch.de

-- client request parser
-- runs on every request coming from client to server

local class = require "class"
local hotload = require "hotswap"
local Header = hotload "header"
local Message = hotload "message"
local Request = class()


function Request:new(transmitter)
    self.transmitter = transmitter -- client socket object
    self.header = Header()
    self.message = Message()
    self:receiveHeader()
end


function Request:receiveHeader()
    self.header:receive(self.transmitter)
end


function Request:receiveMessage(stream_sink)
    local length = tonumber(self.header:get "Content-Length" or 0)
    local chunked = tostring(self.header:get("Transfer-Encoding")):match("chunked") == "chunked"
    self.message:receive(self.transmitter, length, stream_sink, chunked)
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
    self:receiveMessage(stream_sink)
end
--]]


return Request
