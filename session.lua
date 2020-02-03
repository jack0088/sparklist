-- 2020 (c) kontakt@herrsch.de


local hotload = require "hotload"
local dt = hotload "datetime"
local hash = hotload "randomseed"
local class = hotload "class"
local Storage = hotload "kvstorage"
local Session = class(Storage)
Session.get_table = Storage.get_table
Session.set_table = Storage.set_table


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

    Storage.new(self, session_uuid, "db/session.db")
    
    if not client.request.header.path:match("%.%w%w[%w%p]*$") then
        -- update or create new cookie BUT ONLY IF it is not a resource file like favicon.ico
        client.response.header:set("set-cookie", cookie.."="..self.table.."; Expires="..death_date)
    end
end


return Session
