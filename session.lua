-- 2020 (c) kontakt@herrsch.de

local hotload = require "hotswap"
local users = hotload "database"("db/user.doc")
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
