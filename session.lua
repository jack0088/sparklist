-- 2020 (c) kontakt@herrsch.de


local hotload = require "hotload"
local dt = hotload "datetime"
local hash = hotload "randomseed"
local class = hotload "class"
local LocalStorage = hotload "local_storage"
local Session = class(LocalStorage)
Session.get_table = LocalStorage.get_table
Session.set_table = LocalStorage.set_table


function Session:new(client, cookie, lifetime)
    assert(client.request and client.response, "missing client request/response object")
    assert(cookie, "missing set-cookie name")
    assert(lifetime, "missing set-cookie max-age")
    
    local session_uuid = hash(32)
    local death_date = dt.date(dt.timestamp() + lifetime)

    for key, value in client.request.header:get("cookie", string.gmatch, "([^=; ]+)=([^=;]+)") or function() end do
        if key == cookie then
            session_uuid = value
            break
        end
    end

    LocalStorage.new(self, session_uuid, "db/client_session.db")
    
    client.response.header:set("set-cookie", cookie.."="..self.table.."; Expires="..death_date) -- update or create new
end


return Session
