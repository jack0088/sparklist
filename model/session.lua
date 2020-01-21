-- 2020 (c) kontakt@herrsch.de


local hotload = require "hotload"
local class = hotload "class"
local hash = hotload "randomseed"
local Storage = hotload "model.local_storage"
local Session = class(Storage)
Session.get_uuid = Storage.get_namespace
Session.set_uuid = Storage.set_namespace


function Session:new(request, response, cookie, lifetime)
    local session_uuid = hash(32)
    for key, value in request.header:get("cookie", string.gmatch, "([^=; ]+)=([^=;]+)") or function() end do
        if key == self.cookie_name then
            session_uuid = value
            break
        end
    end
    self.db = Database "db/client_session.db"
    self.uuid = session_uuid
    self.cookie_name = cookie or "xors-session-id"
    self.cookie_lifetime = lifetime or 604800 -- 7 days (in seconds)
    response.header:set("set-cookie", self.cookie_name.."="..self.uuid.."; Max-Age="..self.cookie_lifetime) -- update or create new
end


return Session
