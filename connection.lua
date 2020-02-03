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
local Contact = {}


function Contact:onConnect(server, client)
    server:hook("beforeRequest", server, client)
    client.request = Request(client.socket)
    if client.request.header then
        server:hook("beforeResponse", server, client)
        client.response = Response(client.socket, client.request)

        local cookie_name = server.settings:get "session_cookie_name"
        local cookie_lifetime = server.settings:get "session_cookie_lifetime"
        if not cookie_name then
            cookie_name = "xors_session_id"
            server.settings:set("session_cookie_name", cookie_name)
        end
        if not cookie_lifetime then
            cookie_lifetime = 604800 -- 7 days (in seconds)
            server.settings:set("session_cookie_lifetime", cookie_lifetime)
        end
        client.request.header.session = Session(client, cookie_name, cookie_lifetime)

        local session_database = client.request.header.session.db.file
        local session_table = client.request.header.session.table
        local current_time = dt.timestamp()
        local cookie_expiry = current_time + cookie_lifetime
        if cookie_expiry > current_time then
            server:insertPlugin(session_gc) -- if not yet done
            session_gc:queue(session_database, session_table, nil, cookie_expiry)
        end
    else
        -- certainly not HTTP protocol but some kind of raw data!
        print "could not identify http request..."
        print(string.format("xors dropped client %s", client.ip))
        return client:disconnect()-- drop client
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
                if client.request.header.session
                and client.request.header.method == "GET"
                and not client.request.header:get "referer"
                then
                    -- NOTE we try only to save what the use really tries to access not the auto-redirected page paths
                    -- For example, Response.refresh would not be catched but Response.redirect will be!
                    client.request.header.session:set("previous_path", client.request.header.path)
                end
                server:hook("afterResponse", server, client)
            end
        end
    end
end

return Contact
