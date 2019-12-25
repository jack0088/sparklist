--[[

PLUGIN HOOK PROCESSOR

This runs on every request from client to server
and allows you to hook-in with a plugin into its lifecycle at different states.

2019 (c) kontakt@herrsch.de

--]]


local tohostname = require "socket".dns.tohostname
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
        self.client = {}
        self.client.joint = self.server.joint:accept()
        self.client.joint:settimeout(self.server.timeout, "b")
        self.client.ip, self.client.port = self.client.joint:getpeername()
        self.client.info = select(2, tohostname(self.client.ip))
        if self:hook("onConnect", self.client, self.server) == false then self:disconnect() end
        print(string.format("XORS connected to client at %s:%s (browse %s:%s)", self.client.ip, self.client.port, self.client.info.name, self.server.port))
        return self
    end
end


function Processor:disconnect()
    if self.client and not self.client.keepalive then
        self:hook("onDisconnect", self.client, self.server)
        self.client.joint:close()
        print(string.format("XORS disconnected from client %s", self.client.ip))
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


return Processor
