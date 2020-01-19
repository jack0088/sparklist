-- 2020 (c) kontakt@herrsch.de

-- client sessions are an extension to cookies
-- sessions are stored in a sqlite3 database
-- and referenced by an uuid token
-- that uuid, in turn, is stored in a client cookie


local hash = require "hash"
local class = require "class"
local hotload = require "hotswap"
local Storage = hotload "local_storage"
local Session = class(Storage)

Session.get_uuid = Storage.get_uuid
Session.set_uuid = Storage.set_uuid
Session.COOKIE_NAME = "xors-session-identifier"
Session.COOKIE_LIFETIME = 604800 -- 7 days (in seconds)


function Session:new(request, response, cookie, lifetime)
    if type(cookie) == "string" then
        self.COOKIE_NAME = cookie
    end
    if type(lifetime) == "number" then
        self.COOKIE_LIFETIME = lifetime
    end
    local session_identifier = hash(32)
    for key, value in request.header:get("cookie", string.gmatch, "([^=; ]+)=([^=;]+)") or function() end do
        if key == self.COOKIE_NAME then
            session_identifier = value
            break
        end
    end
    response.header:set("set-cookie", self.COOKIE_NAME.."="..session_identifier.."; Max-Age="..self.COOKIE_LIFETIME)
    self.name = "session_"..session_identifier
end


return Session
