-- 2020 (c) kontakt@herrsch.de

-- client sessions are an extension to cookies
-- sessions are stored in a sqlite3 database
-- and referenced by an uuid token
-- that uuid, in turn, is stored in a client cookie


local hash = require "hash"
local hotload = require "hotswap"
local users = hotload "database"("db/user.db")
local class = require "class"
local Session = class()
Session.COOKIE_NAME = "xors-session-uuid"


function Session:new(uuid)
    users:run [[create table if not exists session (
        id integer primary key autoincrement,
        uuid text not null,
        key text not null,
        value text not null
    )]]
    self.uuid = uuid or hash(32)
end


function Session:empty()
    local entries = users:run("select uuid from session where uuid = '%s' limit 1", self.uuid)
    return (entries and #entries > 0) and true or false
end


function Session:set(key, value)
    assert(self.uuid, "missing session uuid")
    local records = users:run("select * from session where (uuid = '%s' and key = '%s')", self.uuid, tostring(key))
    if records and #records > 0 then
        users:run("update session set value = '%s' where (uuid = '%s' and key = '%s')", tostring(value), self.uuid, tostring(key))
    else
        users:run("insert into session (uuid, key, value) values ('%s', '%s', '%s')", self.uuid, tostring(key), tostring(value))
    end
    return self.uuid
end


function Session:get(key)
    assert(self.uuid, "missing session uuid")
    if type(key) == "string" then
        local record = users:run("select value from session where (uuid = '%s' and key = '%s')", self.uuid, key)
        return record[1].value
    end
    local records = users:run("select key, value from session where uuid = '%s'", self.uuid)
    if records and #records > 0 then
        local entries = {}
        for id, row in ipairs(records) do
            entries[row.key] = row.value
        end
        return entries
    end
end


return Session
