-- 2020 (c) kontakt@herrsch.de

-- client sessions are an extension to cookies
-- sessions are stored in a sqlite3 database
-- and referenced by an namespace token
-- that namespace, in turn, is stored in a client cookie


local class = require "class"
local hotload = require "hotswap"
local ram = hotload "database"("db/local_storage.db")
local Storage = class()


function Storage:new(common_identifier)
    self.uuid = common_identifier
end


function Storage:get_uuid()
    return self.__db_table_name
end


function Storage:set_uuid(common_identifier)
    assert(type(common_identifier) == "string", "missing common identifier string")
    assert(not common_identifier:find("[^%a%-_]+"), "common identifier string must only contain [a-zA-Z%-_] characters")
    if common_identifier ~= self.uuid and self:empty() then
        self:destroy()
    end
    self.__db_table_name = common_identifier
    self:create()
end


function Storage:create()
    -- IMPORTANT NOTE .create() is a potential memory leak! Be careful with this!
    -- HTTP Session objects for example might never use the reserved storage space
    -- but create one for every new client
    -- so always .destroy() when the storage remains .empty()
    ram:run(
        [[create table if not exists '%s' (
            id integer primary key autoincrement,
            key text unique not null,
            value text not null
        )]],
        self.uuid
    )
end


function Storage:destroy()
    ram:run("drop table '%s'", self.uuid)
end


function Storage:empty()
    local entries = ram:run("select id from '%s' limit 1", self.uuid)
    return #entries > 0 and true or false
end


function Storage:exists(key, value)
    if key and value then
        local records = ram:run("select id from '%s' where (key = '%s' and value = '%s')", self.uuid, tostring(key), tostring(value))
        return #records > 0 and record[1].id or false
    elseif value then
        local records = ram:run("select key from '%s' where value = '%s'", self.uuid, tostring(value))
        return #records > 0 and record[1].key or false
    elseif key then
        local records = ram:run("select value from '%s' where key = '%s'", self.uuid, tostring(key))
        return #records > 0 and record[1].value or false
    end
    return self:empty()
end


function Storage:set(key, value) -- upsert (update + insert)
    if self:exists(key) then
        ram:run("update '%s' set value = '%s' where key = '%s'", self.uuid, tostring(value), tostring(key))
    else
        ram:run("insert into '%s' (key, value) values ('%s', '%s')", self.uuid, tostring(key), tostring(value))
    end
end


function Storage:get(key)
    if type(key) == "string" then
        local value = self:exists(key)
        return value == false and nil or value
    end
    local records = ram:run("select key, value from '%s'", self.uuid)
    if #records > 0 then -- unpack rows
        local entries = {}
        for id, row in ipairs(records) do
            entries[row.key] = row.value
        end
        return entries
    end
end


return Storage