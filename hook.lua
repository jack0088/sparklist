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
    self.clients = {}
end


function Processor:run() -- main loop
    self:hook("onEnterFrame")
    
    local candidate = self.server.joint:accept()

    for i = #self.clients, 1, -1 do
        if candidate == self.clients[i].joint then
            candidate = i -- cache id of existing client
        end

        if self.clients[i].request.complete then
            self:hook("onDispatch", self.clients[i].request, self.clients[i].response)
            self:hook("onDisconnect", self.clients[i], self.server)
            
            -- for j = #self.server.plugins, 1, -1 do -- remove temporary request & response plugins
            --     if self.server.plugins[j] == self.clients[i].request
            --     or self.server.plugins[j] == self.clients[i].response
            --     then
            --         table.remove(self.server.plugins, j)
            --     end
            -- end

            self.clients[i].joint:close()

            print(string.format(
                "%s xors disconnected from client %s",
                os.date("%d.%m.%Y %H:%M:%S"),
                self.clients[i].ip
            ))

            table.remove(self.clients, i)
        end
    end

    if candidate ~= nil and type(candidate) ~= "number" then -- record new client
        local client = {}
        client.joint = candidate
        client.ip, client.port = client.joint:getpeername()
        client.info = select(2, hostname(client.ip))
        client.request = Request(client.joint)
        client.response = Response(client.joint, client.request)
        table.insert(self.clients, client)

        -- register request & response objects temporary as plugins so they can use xors hooks
        -- table.insert(self.server.plugins, client.request)
        -- table.insert(self.server.plugins, client.response)

        self:hook("onConnect", client, self.server)

        print(string.format(
            "%s xors connected to client at %s:%s (browse %s:%s)",
            os.date("%d.%m.%Y %H:%M:%S"),
            client.ip,
            client.port,
            client.info.name,
            self.server.port
        ))
    end
end


function Processor:hook(delegate, ...)
    for _, plugin in ipairs(self.server.plugins) do
        if type(plugin[delegate]) == "function" then
            plugin[delegate](plugin, ...)
        end
    end
end


function Processor:hotswap() -- restore state when hot-swapping this file
    return {
        server = self.server, -- TODO does this prevent plugins from being hot-swapped? I think so..
        clients = self.clients
    }
end


return Processor
