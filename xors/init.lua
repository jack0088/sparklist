-- 2019 (c) kontakt@herrsch.de


-- xors (pronounced horse) is a HTTP server written in vanilla Lua
-- its original inspiration came from Pegasus https://github.com/EvandroLG/pegasus.lua but became a complete rewrite

-- xors should run fine on any machine supporting fallowing dependencies
---> Lua >= 5.1
---> luasocket
---> luasec
---> sqlite3 + luasql

local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local socket = require "socket"
local hotload = require "hotload"
local class = hotload "class"
local Client = hotload "client"
local Xors = class()


function Xors:new(options)
    if type(options) ~= "table" then options = {} end
    self.host = options.host or "*"
    self.port = options.port or "8080"
    self.timeout = options.timeout or 1
    self.backlog = options.backlog or 100 -- max queue size of waiting clients
    self.plugins = options.plugins or {}
    self.settings = hotload "kvstorage"("settings")
end


function Xors:whois() -- works even without internet
    local connection, server, client, port = socket.udp()
    connection:setpeername("74.125.115.104", self.port or 80) -- connect client to host (google placeholder, host ip and port are non-relevant here)
    server = connection:getsockname()
    client, port = connection:getpeername()
    connection:close()
    return socket.dns.gethostname(), server, port
end


function Xors:run()
    self.clients = {}
    self.socket = socket.tcp()
    self.socket:settimeout(self.timeout, "t")
    self.socket:bind(self.host, self.port)
    self.socket:listen(self.backlog)
    --self.ip = self.socket:getsockname()
    self.name, self.ip = self:whois()
    self:hook("onStartup", self)
    print(string.format(
        "xors is listening to clients at %s:%s alias %s:%s",
        self.ip,
        self.port,
        self.name,
        self.port
    ))

    while true do -- main application loop
        self:hook("onEnterFrame", self)
        local remote = self.socket:accept()
        if remote ~= nil then
            table.insert(self.clients, Client():connect(remote))
        end
        for client_id = getn(self.clients), 1, -1 do
            local client = self.clients[client_id]
            if not client.request or not client.response then
                self:hook("onConnect", self, client)
            end
            self:hook("onProcess", self, client)
            if client.request_received and client.response_sent then
                self:hook("onDisconnect", self, client)
                client:disconnect()
                table.remove(self.clients, client_id)
            end
        end
    end
    
    -- TODO we never reach this statement because of pkill that breaks the main loop from above and terminates the running process. Need to find a way around this to peacefully close the server socket over here!
    self:hook("onShutdown", self)
    if self.socket then self.socket:close() end
    print(string.format("xors shut down"))
end


function Xors:hook(delegate, ...)
    for _, plugin in ipairs(self.plugins) do
        if type(plugin[delegate]) == "function" then
            plugin[delegate](plugin, ...)
        end
    end
end


function Xors:insertPlugin(reference)
    local existing_plugin = false
    for _, plugin in ipairs(self.plugins) do
        if plugin == reference then
            existing_plugin = true
            break
        end
    end
    if not existing_plugin then
        table.insert(self.plugins, reference)
    end
    return true
end


function Xors:removePlugin(reference)
    if type(reference) == "number" then
        table.remove(self.plugins, reference)
        return true
    end
    for id = getn(self.plugins), 1, -1 do
        if self.plugins[id] == reference then
            table.remove(self.plugins, id)
            return true
        end
    end
    return false
end


return Xors
