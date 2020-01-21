-- 2019 (c) kontakt@herrsch.de

-- HTTP/1.1
-- NOTE could also be used for any kind of regular messages as an alternative to socket:receive() or socket:send()


local hotload = require "hotswap"
local class = hotload "class"
local Message = class()


function Message:new()
    self.received = false
    self.sent = false
end


-- @transmitter (required tcp socket)
-- @length ([optional] string or number) see LuaSocket documentation; can be optional if @chunked is set to true
-- @stream_sink (optinal function)
-- @chunked (optional boolean) determines how to read the buffer length
-- This function can run inside a coroutine or via its plain function call
-- When called inside coroutine (determined automatically by threaded variable), you may use coroutine.yield() inside the @stream_sink function
-- If @stream_sink is given than read stream from buffer is piped through that function for post-processing
-- When called with a @length, then that many bytes will be read from the buffer, however if @chunked is set to true then that @length is ignored
function Message:receive(transmitter, length, stream_sink, chunked)
    if not self.received then
        self.content = ""
        local threaded = type(coroutine.running()) == "thread"
        repeat
            if chunked then length = tonumber(transmitter:receive(), 16) end -- hexadecimal value
            if length > 0 then
                local stream = transmitter:receive(length)
                if not threaded then self.content = self.content..stream else self.content = stream end
                if not chunked then length = 0 end -- signal to break the loop!
                if type(stream_sink) == "function" then stream_sink(stream) end
            end
        until length <= 0 -- 0\r\n\r\n
        if threaded then self.content = "" end
        self.received = true
    end
end


-- @receiver (required tcp socket)
-- @stream (optional string) non-empty string to respond with; or pass nil to complete the response
-- @chunked (optional boolean) determines how to write to the buffer
-- This function may run inside a blocking loop, that may run inside a coroutine.
-- When running inside a coroutine you may use coroutine.yield() there to send chunked messages
-- When @stream is given, than that string is send, otherwise this function finishes the ongoing response
-- When @chunked is set to false then the stream is written out in one go and response is considered finished,
-- otherwise the response is kept open and chunkes of stream can be written to the buffer
-- (one final :send(receiver) will then finish off the response)
function Message:send(receiver, stream, chunked)
    if not self.sent then
        stream = stream or ""
        local length = #stream
        local threaded = type(coroutine.running()) == "thread"
        if threaded then self.content = stream else self.content = (self.content or "")..stream end
        if chunked and length > 0 then
            receiver:send(string.format(
                "%s\r\n%s\r\n",
                string.format("%X", length), -- hexadecimal value
                stream
            ))
        -- length <= 0 (for all remaining cases) so finish the response
        elseif chunked then
            receiver:send("0\r\n\r\n")
            self.sent = true
        elseif not chunked then
            receiver:send(string.format("%s\r\n", stream))
            self.sent = true
        else
            self.sent = true
        end
    end
end


return Message
