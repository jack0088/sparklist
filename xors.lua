--[[

The project name XORS (pronounced HORSE) is based on the mythological figure Chors https://de.wikipedia.org/wiki/Chors and derivated originally from Pegasus https://github.com/EvandroLG/pegasus.lua but became a complete rewrite and its own project.

XORS should run sucessfully on any machine supporting fallowing dependencies

Lua >= 5.1 (tested only with 5.1)
luasocket
luasec (openssl)

2019 (c) kontakt@herrsch.de

--]]


local socket = require "socket"
local Plugin = require "hook"
local class = require "class"
local Xors = class()


function Xors:new(settings)
    settings = settings or {}
    self.host = settings.host or "*"
    self.port = settings.port or "80"
    self.info = {}
    self.timeout = settings.timeout or 1
    self.backlog = settings.backlog or 100 -- max queue of waiting clients
    self.directory = settings.directory or "./"
    self.plugins = settings.plugins or {}
    return self
end


function Xors:hotswap()
    return {
        host = self.host,
        port = self.port,
        info = self.info,
        timeout = self.timeout,
        backlog = self.backlog,
        directory = self.directory,
        plugins = self.plugins,
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
    print(string.format("XORS is listening to clients at %s:%s alias %s:%s", self.ip, self.port, self.info.name, self.port))
    local processor = Plugin(self)
    while true do processor:run() end -- main loop
    self.joint:close()
    print(string.format("XORS shut down"))
end


return Xors
