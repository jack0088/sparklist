local Request = hotload "request"
local Response = hotload "response"
local Contact = {}


function Contact:onConnect(server, client)
    server:hook("beforeRequest", server, client)
    client.request = Request(client.socket)
    if client.request.header_received then
        server:hook("beforeResponse", server, client)
        client.response = Response(client.socket, client.request)
        return -- ok
    end
    client.request = nil
    -- NOTE could not parse HTTP header of client request
    -- seem the client request can not be handled by this plugin
    -- leave it alone, another plugin may handle the request instead...
end


function Contact:onProcess(server, client)
    if client.request and client.response then
        if client.request.header_received
        and (not client.request.message_received
        or not client.response.header_sent
        or not client.response.message_sent)
        then
            -- emit xors hook event to trigger listening plugin callbacks
            server:hook("onDispatch", server, client)
        end
        if client.request.header_received and client.request.message_received then
            server:hook("afterRequest", server, client)
        end
        if client.response.header_sent and client.response.message_sent then
            server:hook("afterResponse", server, client)
        end
    end
end

return Contact
