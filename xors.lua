-- 2019 (c) kontakt@herrsch.de

-- xors (pronounced horse) is a HTTP server written in vanilla Lua
-- its original inspiration came from Pegasus https://github.com/EvandroLG/pegasus.lua but became a complete rewrite

-- xors should run fine on any machine supporting fallowing dependencies:
---> Lua >= 5.1
---> luasocket
---> openssl (or luasec or lua-http, which both bundle it)

local class = require "class"
local socket = require "socket"
local Request = require "request"
local Response = require "response"
local Xors = class()


function Xors:new(settings)
    if type(settings) ~= "table" then settings = {} end
    self.host = settings.host or "*"
    self.port = settings.port or "8080"
    self.timeout = settings.timeout or 1
    self.backlog = settings.backlog or 100 -- max queue size of waiting clients
    self.plugins = settings.plugins or {}
end


function Xors:run()
    self.queue = {}
    self.clients = {}
    self.socket = socket.tcp()
    self.socket:settimeout(self.timeout, "t")
    self.socket:bind(self.host, self.port)
    self.socket:listen(self.backlog)
    --self.ip = self.socket:getsockname()
    self.name, self.ip = self:whois()

    print(string.format(
        "%s xors is listening to clients at %s:%s alias %s:%s",
        os.date("%d.%m.%Y %H:%M:%S"),
        self.ip,
        self.port,
        self.name,
        self.port
    ))

    while true do -- main application loop
        local transmitters, receivers = socket.select(self.queue, self.queue, self.timeout) -- list of ready-to-read/write client sockets
        local candidate = self.socket:accept()
        
        for _, client in ipairs(self.queue) do
            if candidate == client then -- already known client
                candidate = nil
                break
            end
        end

        if candidate then -- yet unknown client
            local ip, port = candidate:getpeername()
            table.insert(self.queue, candidate)
            self.clients[candidate] = {
                socket = candidate,
                ip = ip,
                port = port
            }
            print(string.format(
                "%s xors attempts to connect to client at %s:%s",
                os.date("%d.%m.%Y %H:%M:%S"),
                ip,
                port
            ))
        end

        print(#transmitters, #receivers)
        
        for _, remote in ipairs(transmitters) do
            local client = self.clients[remote]
            self:hook("onEnterFrame", client, self)
            if not client.request or not client.response then
                client.request = Request(client.socket)
                client.response = Response(client.socket, client.request)
                print(string.format(
                    "%s xors connected to client %s",
                    os.date("%d.%m.%Y %H:%M:%S"),
                    client.ip
                ))
                self:insertPlugin(client.request)
                self:insertPlugin(client.response)
                self:hook("onConnect", client, self)
            end
        end

        for _, remote in ipairs(receivers) do
            local client = self.clients[remote]
            self:hook("onEnterFrame", client, self)
            if client.request.complete then
                self:hook("onDispatch", client.request, client.response)
            end
            if client.response.complete then
                self:hook("onDisconnect", client, self)
                print(string.format(
                    "%s xors disconnected from client %s",
                    os.date("%d.%m.%Y %H:%M:%S"),
                    client.ip
                ))
                client.socket:close()
                self:removePlugin(client.request)
                self:removePlugin(client.response)
                self.client[remote] = nil
                for id, ptr in ipairs(self.queue) do
                    if ptr == remote then
                        table.remove(self.queue, id)
                        break
                    end
                end
            end
        end
    end
    
    if self.socket then self.socket:close() end

    print(string.format(
        "%s xors shut down",
        os.date("%d.%m.%Y %H:%M:%S")
    ))
end


function Xors:hook(delegate, ...)
    for _, plugin in ipairs(self.plugins) do
        if type(plugin[delegate]) == "function" then
            plugin[delegate](plugin, ...)
        end
    end
end


function Xors:insertPlugin(reference)
    table.insert(self.plugins, reference)
    return true
end


function Xors:removePlugin(reference)
    if type(reference) == "number" then
        table.remove(self.plugins, reference)
        return true
    end
    for id = #self.plugins, 1, -1 do
        if self.plugins[id] == reference then
            table.remove(self.plugins, id)
            return true
        end
    end
    return false
end


function Xors:whois() -- works even without internet
    local connection, server, client, port = socket.udp()
    connection:setpeername("74.125.115.104", self.port or 80) -- connect client to host (google placeholder, host ip and port are non-relevant here)
    server = connection:getsockname()
    client, port = connection:getpeername()
    connection:close()
    return socket.dns.gethostname(), server, port
end


function Xors:hotswap()
    return {
        -- TODO
    }
end


return Xors
