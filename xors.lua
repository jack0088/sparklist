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
        self:hook("onEnterFrame", self)

        local remote = self.socket:accept()
        if remote ~= nil then
            local client = {}
            client.socket = remote
            client.ip, client.port = client.socket:getpeername()
            client.request = Request(client.socket)
            client.response = Response(client.socket, client.request)
            table.insert(self.clients, client)
            print(string.format(
                "%s xors connected to client at %s:%s",
                os.date("%d.%m.%Y %H:%M:%S"),
                client.ip,
                client.port
            ))
            self:hook("onConnect", client, self)
        end

        for client_id = #self.clients, 1, -1 do
            local client = self.clients[client_id]
            if client.request.headers_received
            and (not client.request.message_received
            or not client.response.headers_send
            or not client.response.message_send)
            then
                self:hook("onDispatch", client.request, client.response, client, self)
            end
            if client.request.headers_received
            and client.request.message_received
            and client.response.headers_send
            and client.response.message_send
            then
                self:hook("onDisconnect", client, self)
                print(string.format(
                    "%s xors disconnected from client %s",
                    os.date("%d.%m.%Y %H:%M:%S"),
                    client.ip
                ))
                client.socket:close()
                table.remove(self.clients, client_id)
            end
        end
    end
    
    -- TODO we never reach this statement because of pkill that breaks the main loop from above and terminates the running process. Need to find a way around this to peacefully close the server socket over here!
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
        socket = self.socket,
        host = self.host,
        port = self.port,
        ip = self.ip,
        name = self.name,
        timeput = self.timeout,
        backlog = self.backlog,
        clients = self.clients,
        plugins = self.plugins
    }
end


return Xors
