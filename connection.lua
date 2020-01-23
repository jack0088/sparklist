-- 2020 (c) kontakt@herrsch.de

-- xors has only three hooks (onEnterFrame, onConnect, onDisconnect)
-- this plugin emits additional, custom xors hook-events to trigger listening plugin-callbacks
-- it also enriches existing Client object with Request and Response objects

local hotload = require "hotload"
local Request = hotload "request"
local Response = hotload "response"
local Session = hotload "session"
local SessionGarbageCollector = hotload "garbagecollect"("session")
local Contact = {}


function Contact:onConnect(server, client)
    server:hook("beforeRequest", server, client)
    server:hook("beforeResponse", server, client)
    client.request = Request(client.socket)
    client.response = Response(client.socket, client.request)
    client.request.header.session = Session(client, "sparklist_session")
    server:insertPlugin(SessionGarbageCollector) -- if not yet done so
end


function Contact:onProcess(server, client)
    if client.request and client.response then
        if client.request.header.received
        and (not client.request.message.received
        or not client.response.header.sent
        or not client.response.message.sent)
        then
            server:hook("onDispatch", server, client)
            if client.response.header.sent then
                server:hook("afterRequest", server, client)
            end
            if client.response.message.sent then
                server:hook("afterResponse", server, client)
            end
        end
    end
end

return Contact
