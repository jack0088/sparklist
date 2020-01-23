-- 2020 (c) kontakt@herrsch.de


local hotload = require "hotload"
local dt = hotload "datetime"
local hash = hotload "randomseed"
local class = hotload "class"
local Database = hotload "database"
local Storage = hotload "local_storage"
local Session = class(Storage)
Session.get_table = Storage.get_table
Session.set_table = Storage.set_table


function Session:new(client, cookie, lifetime)
    assert(client.request and client.response, "client request/response object missing")
    
    self.cookie_name = cookie or "xors-session-id"
    local session_uuid = hash(32)
    for key, value in client.request.header:get("cookie", string.gmatch, "([^=; ]+)=([^=;]+)") or function() end do
        if key == self.cookie_name then
            session_uuid = value
            break
        end
    end

    self.db = Database "db/client_session.db"
    self.table = session_uuid
    self.cookie_lifetime = lifetime or 604800 -- 7 days (in seconds)
    local death_date = dt.date(dt.timestamp() + self.cookie_lifetime)
    client.response.header:set("set-cookie", self.cookie_name.."="..self.table.."; Expires="..death_date) -- update or create new
end


return Session
