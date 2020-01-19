-- 2020 (c) kontakt@herrsch.de

-- xors has only three hooks (onEnterFrame, onConnect, onDisconnect)
-- this plugin emits additional, custom xors hook-events to trigger listening plugin-callbacks
-- it also enriches existing Client object with Request and Response objects

local hotload = require "hotswap"
local Request = hotload "request"
local Response = hotload "response"
local Session = hotload "session"
local Contact = {}


function Contact:onConnect(server, client)
    server:hook("beforeRequest", server, client)
    client.request = Request(client.socket)
    if client.request.header_received then
        server:hook("beforeResponse", server, client)
        client.response = Response(client.socket, client.request)
        print(">>>>>>>>", Session)
        client.request.header.session = Session(client.request, client.response, "sparklist-session")
        return -- ok
    end
    client.request = nil
    -- NOTE could not parse HTTP header of client request
    -- seem the client request can not be handled by this plugin
    -- leave it alone, another plugin may handle the request instead...
end


function Contact:onDisconnect(server, client)
    client.request.header.session:destroy()
end


function Contact:onProcess(server, client)
    if client.request and client.response then
        if client.request.header_received
        and (not client.request.message_received
        or not client.response.header_sent
        or not client.response.message_sent)
        then
            server:hook("onDispatch", server, client)
        end
        if client.request_received then
            server:hook("afterRequest", server, client)
        end
        if client.response_sent then
            server:hook("afterResponse", server, client)
        end
    end
end

return Contact
