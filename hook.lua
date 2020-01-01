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
    self.client = {}
end


function Processor:run() -- main loop
    self:hook("onEnterFrame")
    
    local candidate = self.server.joint:accept()

    for id = #self.client, 1, -1 do
        if candidate == self.client[id].joint then
            candidate = id -- cache id of existing client
        end
        if self.client[id].request.complete then
            self:hook("onDispatch", self.client[id].request, self.client[id].response)
            self:hook("onDisconnect", self.client[id], self.server)
            
            for id = #self.server.plugins, 1, -1 do -- remove temporary request & response plugins
                if self.server.plugins[id] == self.client[id].request
                or self.server.plugins[id] == self.client[id].response
                then
                    table.remove(self.server.plugins, id)
                end
            end

            self.client[id].joint:close()

            print(string.format(
                "%s xors disconnected from client %s",
                os.date("%d.%m.%Y %H:%M:%S"),
                self.client[id].ip
            ))

            table.remove(self.clients, id)
        end
    end

    if type(candidate) ~= "number" then -- record new client
        local client = {}
        client.joint = candidate
        client.ip, client.port = client.joint:getpeername()
        client.info = select(2, hostname(client.ip))
        client.request = Request(client.joint)
        client.reponse = Response(client.joint, client.request)
        table.insert(self.client, client)

        -- register request & response objects temporary as plugins so they can use xors hooks
        table.insert(self.server.plugins, client.request)
        table.insert(self.server.plugins, client.response)

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
        client = self.client
    }
end


return Processor
