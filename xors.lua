-- 2019 (c) kontakt@herrsch.de

-- xors (pronounced horse) is a HTTP server written in vanilla Lua
-- its original inspiration came from Pegasus https://github.com/EvandroLG/pegasus.lua but became a complete rewrite

-- xors should run fine on any machine supporting fallowing dependencies:
---> Lua >= 5.1
---> luasocket
---> openssl (or luasec which bundles it)

local socket = require "socket"
local Hook = require "hook"
local class = require "class"
local Xors = class()


function Xors:new(settings)
    settings = settings or {}
    self.host = settings.host or "*"
    self.port = settings.port or "8080"
    self.info = {}
    self.timeout = settings.timeout or 1
    self.backlog = settings.backlog or 100 -- max queue of waiting clients
    self.plugins = settings.plugins or {}
end


function Xors:hotswap()
    return {
        host = self.host,
        port = self.port,
        info = self.info,
        timeout = self.timeout,
        backlog = self.backlog,
        joint = self.joint
    }
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
    self.joint = socket.tcp()
    self.joint:settimeout(self.timeout, "t")
    self.joint:bind(self.host, self.port)
    self.joint:listen(self.backlog)
    --self.ip, self.port = self.joint:getsockname()
    self.info.name, self.ip, self.port = self:whois()
    print(string.format(
        "%s xors is listening to clients at %s:%s alias %s:%s",
        os.date("%d.%m.%Y %H:%M:%S"),
        self.ip,
        self.port,
        self.info.name,
        self.port
    ))
    local processor = Hook(self)
    while true do processor:run() end -- main loop
    if self.joint then self.joint:close() end
    print(string.format(
        "%s xors shut down",
        os.date("%d.%m.%Y %H:%M:%S")
    ))
end


return Xors
