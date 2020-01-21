-- 2020 (c) kontakt@herrsch.de


local hotload = require "hotload"
local class = hotload "class"
local hash = hotload "randomseed"
local Database = hotload "database"
local Storage = hotload "model.local_storage"


local Session = class(Storage)
Session.get_table = Storage.get_table
Session.set_table = Storage.set_table


function Session:new(request, response, cookie, lifetime)
    self.cookie_name = cookie or "xors-session-id"
    local session_uuid = hash(32)
    for key, value in request.header:get("cookie", string.gmatch, "([^=; ]+)=([^=;]+)") or function() end do
        if key == self.cookie_name then
            session_uuid = value
            break
        end
    end
    self.db = Database "db/client_session.db"
    self.table = session_uuid
    self.cookie_lifetime = lifetime or 604800 -- 7 days (in seconds)
    response.header:set("set-cookie", self.cookie_name.."="..self.table.."; Max-Age="..self.cookie_lifetime) -- update or create new
end


function Session:create()
    if type(self.table) == "string" then
        Storage.create(self)
        -- TODO use Storage module to drive another (xors) table
        -- that will be used to hold expiration dates
        -- for other tables that have limited lifetime
    end
end


return Session
