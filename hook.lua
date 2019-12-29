-- 2019 (c) kontakt@herrsch.de

-- Plugin hook and processor
-- it runs on every request from client to server
-- and allows you to hook-in with a plugin at different states of the app lifecycle

local socket = require "socket"
local hostname = socket.dns.tohostname
local Request = require "request"
local Response = require "response"
local class = require "class"
local Processor = class()


function Processor:new(server)
    self.server = server
    return self
end


function Processor:run() -- main loop
    self:hook("onEnterFrame")
    self:connect()
    if self.client and not self.client.keepalive then
        self.request = Request(self.client.joint)
        if self.request == false then self:disconnect() end
    end
    if self.client and not self.client.keepalive then
        self.response = Response(self.client.joint, self.request)
        if self.response == false then self:disconnect() end
    end
    if self.client and self:hook("onDispatch", self.request, self.response) == false then self:disconnect() end
    self:disconnect() -- lifecycle complete?
end


function Processor:connect()
    if not self.client or not self.client.keepalive then
        local candidate = self.server.joint:accept()
        if candidate then
            self.client = {}
            self.client.joint = candidate
            self.client.ip, self.client.port = self.client.joint:getpeername()
            self.client.info = select(2, hostname(self.client.ip))
            if self:hook("onConnect", self.client, self.server) == false then self:disconnect() end
            print(string.format(
                "%s XORS connected to client at %s:%s (browse %s:%s)",
                os.date("%d.%m.%Y %H:%M:%S"),
                self.client.ip,
                self.client.port,
                self.client.info.name,
                self.server.port
            ))
            return self
        end
    end
    return false
end


function Processor:disconnect()
    if self.client and not self.client.keepalive then
        self:hook("onDisconnect", self.client, self.server)
        self.client.joint:close()
        print(string.format(
            "%s XORS disconnected from client %s",
            os.date("%d.%m.%Y %H:%M:%S"),
            self.client.ip
        ))
        self.client = nil
        self.request = nil
        self.response = nil
    end
    return false
end


function Processor:hook(delegate, ...)
    for _, plugin in ipairs(self.server.plugins) do
        if plugin[delegate] then
            return plugin[delegate](plugin, ...)
        end
    end
end


function Processor:hotswap() -- restore state when hot-swapping this file
    return {
        server = self.server,
        client = self.client,
        request = self.request,
        response = self.response
    }
end


return Processor
