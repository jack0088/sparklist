local hotload = require "hotload"
local class = hotload "class"
local Client = class()


function Client:connect(socket)
    assert(not self.socket, "client already bound")
    self.socket = socket
    self.ip, self.port = self.socket:getpeername()
    print(string.format("xors connected to client at %s:%s", self.ip, self.port))
    return self
end


function Client:disconnect()
    if self.socket then
        print(string.format("xors disconnected from client %s", self.ip))
        self.socket:close()
        self.socket = nil
        self.ip = nil
        self.port = nil
        self.request_received = true -- unfinished requests/responses will be dropped
        self.response_sent = true
        return self
    end
end


function Client:get_response_sent()
    return self.response_complete == true
        or (self.response ~= nil
        and self.response.header.sent == true
        and self.response.message.sent == true)
end


function Client:set_response_sent(flag)
    self.response_complete = flag
end


function Client:get_request_received()
    -- NOTE when .response_sent equals true then .request_received is considered true as well
    -- because client Request.message may be ignored by a controller (that is the route handler defined in dispatcher)
    return self.request_complete == true
        or (
            self.request ~= nil
            and self.request.header.received == true
            and self.request.message.received == true
        )
        or (
            self.request ~= nil
            and self.request.header.received == true
            and self.response ~= nil
            and self.response.header.sent == true
        )
        or (
            self.request ~= nil
            and self.request.header.received == true
            and self.response_sent == true
        )
end


function Client:set_request_received(flag)
    self.request_complete = flag
end


return Client
