-- 2020 (c) kontakt@herrsch.de

-- client sessions are an extension to cookies
-- sessions are stored in a sqlite3 database
-- and referenced by an namespace token
-- that namespace, in turn, is stored in a client cookie


local class = require "class"
local hotload = require "hotswap"
local Database = hotload "database"
local Storage = class()


function Storage:new(common_identifier)
    self.db = Database "db/local_storage.db"
    self.table = common_identifier
end


function Storage:get_table() -- getter for Storage.table
    return self.__tablename
end


function Storage:set_table(identifier) -- setter for Storage.table
    assert(type(identifier) == "string", "missing common identifier string")
    assert(not identifier:find("[^%a%d%-_]+"), "common identifier string '"..identifier.."' must only contain [a-zA-Z0-9%-_] characters")
    if self.table ~= nil
    and self.table ~= identifier
    and self.db:countTable(self.table) == 0
    then -- switched Storage.name
        self.db:destroy(self.table)
    end
    self.__tablename = tostring(identifier)
    self.db:create(self.table)
end


-- if table has key then return its stored value
-- if table has value then return the key its stored under
-- if both, key and value, exist then return the id of that record in table
-- if key and value are both passed as nil then return the count of records in that table
function Storage:exists(key, value)
    if key and value then
        local records = self.db:run("select id from '%s' where key = '%s' and value = '%s'", self.table, tostring(key), tostring(value))
        return #records > 0 and record[1].id or false
    elseif value then
        local records = self.db:run("select key from '%s' where value = '%s'", self.table, tostring(value))
        return #records > 0 and records[1].key or false
    elseif key then
        local records = self.db:run("select value from '%s' where key = '%s'", self.table, tostring(key))
        return #records > 0 and records[1].value or false
    end
    return self.db:countTable(self.table) > 0
end


function Storage:set(key, value) -- upsert (update + insert)
    if self:exists(key) then
        self.db:run("update '%s' set value = '%s' where key = '%s'", self.table, tostring(value), tostring(key))
    else
        self.db:run("insert into '%s' (key, value) values ('%s', '%s')", self.table, tostring(key), tostring(value))
    end
end


function Storage:get(key)
    if type(key) == "string" then
        local value = self:exists(key)
        return value == false and nil or value
    end
    local records = self.db:run("select key, value from '%s'", self.table)
    if #records > 0 then -- unpack rows
        local entries = {}
        for id, row in ipairs(records) do
            entries[row.key] = row.value
        end
        return entries
    end
end


return Storage
