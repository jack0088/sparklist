-- 2020 (c) kontakt@herrsch.de

-- xors has only three hooks (onEnterFrame, onConnect, onDisconnect)
-- this plugin emits additional, custom xors hook-events to trigger listening plugin-callbacks
-- it also enriches existing Client object with Request and Response objects

local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local hotload = require "hotload"
local dt = hotload "datetime"
local Request = hotload "request"
local Response = hotload "response"
local Session = hotload "session"
local session_gc = hotload "gc"("session")
local xors_settings = hotload "local_storage"("xors_settings")
local Contact = {}


function Contact:onConnect(server, client)
    server:hook("beforeRequest", server, client)
    server:hook("beforeResponse", server, client)
    client.request = Request(client.socket)
    client.response = Response(client.socket, client.request)

    local cookie_name = xors_settings:get "client_cookie_name"
    local cookie_lifetime = xors_settings:get "client_cookie_lifetime"
    if not cookie_name then
        cookie_name = "xors_session_id"
        xors_settings:set("client_cookie_name", cookie_name)
    end
    if not cookie_lifetime then
        cookie_lifetime = 604800 -- 7 days (in seconds)
        xors_settings:set("client_cookie_lifetime", cookie_lifetime)
    end
    client.request.header.session = Session(client, cookie_name, cookie_lifetime)
    
    local session_database = client.request.header.session.db.file
    local session_table = client.request.header.session.table
    local current_time = dt.timestamp()
    local cookie_expiry = current_time + cookie_lifetime
    if cookie_expiry > current_time then
        server:insertPlugin(session_gc) -- if not yet done
        -- server.plugins[getn(server.plugins) + 1] = session_gc
        session_gc:queue(session_database, session_table, nil, cookie_expiry)
    end
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
