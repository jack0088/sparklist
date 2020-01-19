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
    self.name = common_identifier
end


function Storage:get_name()
    return self.__db_table_name
end


function Storage:set_name(identifier)
    assert(type(identifier) == "string", "missing common identifier string")
    assert(not identifier:find("[^%a%d%-_]+"), "common identifier string '"..identifier.."' must only contain [a-zA-Z0-9%-_] characters")
    if self.name ~= nil and self.name ~= identifier and self:empty() then -- switched Storage.name
        self:destroy()
    end
    if identifier ~= nil then
        self.__db_table_name = tostring(identifier)
        self:create()
    end
end


function Storage:create()
    -- IMPORTANT NOTE .create() is a potential memory leak! Be careful with this!
    -- HTTP Session objects for example might never use the reserved storage space
    -- but create a new one for every new client (because of different session-identifier)
    -- thus, be sure to always .destroy() when the storage remains .empty()
    if self.name ~= nil then
        ram:run(
            [[create table if not exists '%s' (
                id integer primary key autoincrement,
                key text unique not null,
                value text not null
            )]],
            self.name
        )
    end
end


function Storage:destroy()
    if self.name ~= nil then
        ram:run("drop table if exists '%s'", self.name)
    end
end


function Storage:empty()
    if not ram:hasTable(self.name) then return true end
    local records = ram:run("select count(id) as count from '%s' limit 1", self.name)
    return records[1].count < 1
end


function Storage:exists(key, value)
    if key and value then
        local records = ram:run("select id from '%s' where key = '%s' and value = '%s'", self.name, tostring(key), tostring(value))
        return #records > 0 and record[1].id or false
    elseif value then
        local records = ram:run("select key from '%s' where value = '%s'", self.name, tostring(value))
        return #records > 0 and records[1].key or false
    elseif key then
        local records = ram:run("select value from '%s' where key = '%s'", self.name, tostring(key))
        return #records > 0 and records[1].value or false
    end
    return not self:empty()
end


function Storage:set(key, value) -- upsert (update + insert)
    if self:exists(key) then
        ram:run("update '%s' set value = '%s' where key = '%s'", self.name, tostring(value), tostring(key))
    else
        ram:run("insert into '%s' (key, value) values ('%s', '%s')", self.name, tostring(key), tostring(value))
    end
end


function Storage:get(key)
    if type(key) == "string" then
        local value = self:exists(key)
        return value == false and nil or value
    end
    local records = ram:run("select key, value from '%s'", self.name)
    if #records > 0 then -- unpack rows
        local entries = {}
        for id, row in ipairs(records) do
            entries[row.key] = row.value
        end
        return entries
    end
end


return Storage
