-- 2020 (c) kontakt@herrsch.de

-- client sessions are an extension to cookies
-- sessions are stored in a sqlite3 database
-- and referenced by an uuid token
-- that uuid, in turn, is stored in a client cookie


local hotload = require "hotswap"
local users = hotload "database"("db/user.db")
local class = require "class"
local Session = class()


function Session:new(id)
    self.id = assert(id, "missing session-id")
end


function Session:set(field, value)
end


function Session:get(field)
    -- TODO model out the database and its relations
    -- then write the logic for sessions
    return users:run(string.format("select * from session where (token = %s and name = %s)", self.id, field))
end


return Session
