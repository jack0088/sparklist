local class = require "class"
local Client = class()


function Client:connect(socket)
    assert(not self.socket, "client already bound")
    self.socket = socket
    self.ip, self.port = self.socket:getpeername()
    print(string.format(
        "%s xors connected to client at %s:%s",
        os.date("%d.%m.%Y %H:%M:%S"),
        self.ip,
        self.port
    ))
    return self
end


function Client:disconnect()
    assert(self.socket, "missing client socket")
    self.request_received = true -- unfinished requests/responses will be dropped
    self.response_sent = true
    self.socket:close()
    print(string.format(
        "%s xors disconnected from client %s",
        os.date("%d.%m.%Y %H:%M:%S"),
        self.ip
    ))
    return self
end


function Client:get_request_received()
    return self.request_complete == true
        or (self.request ~= nil
        and self.request.header_received == true
        and self.request.message_received == true)
end


function Client:set_request_received(flag)
    self.request_complete = flag
end


function Client:get_response_sent()
    return self.response_complete == true
        or (self.response ~= nil
        and self.response.header_sent == true
        and self.response.message_sent == true)
end


function Client:set_response_sent(flag)
    self.response_complete = flag
end


return Client
