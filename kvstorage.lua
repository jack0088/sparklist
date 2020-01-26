-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local hotload = require "hotload"
local class = hotload "class"
local Database = hotload "database"
local Storage = class()


function Storage:new(table_name, database_file)
    self.db = Database(database_file or "db/xors.db")
    self.verbose = false
    self.table = table_name
end


function Storage:get_verbose()
    return self.db.verbose
end


function Storage:set_verbose(flag)
    self.db.verbose = flag
end


function Storage:get_table() -- getter for Storage.table
    return self.__tablename
end


function Storage:set_table(name) -- setter for Storage.table
    assert(type(name) == "string", "missing common identifier string")
    assert(not name:find("[^%a%d%-_]+"), "common identifier string '"..name.."' must only contain [a-zA-Z0-9%-_] characters")
    if self.table ~= nil and self.table ~= name then
        if self.db:count(self.table) < 1 then
            -- before switching to new db table delete the current one if it remains empty
            self:destroy()
        end
    end
    self.__tablename = name
    self:create()
end


function Storage:create()
    self.db:ceate(self.table)
end


function Storage:destroy()
    self.db:destroy(self.table)
end


function Storage:exists(key, value)
    if key and value then
        local records = self.db:run("select id from '%s' where key = '%s' and value = '%s'", self.table, tostring(key), tostring(value))
        return getn(records) > 0 and record[1].id or false
    elseif value then
        local records = self.db:run("select key from '%s' where value = '%s'", self.table, tostring(value))
        return getn(records) > 0 and records[1].key or false
    elseif key then
        local records = self.db:run("select value from '%s' where key = '%s'", self.table, tostring(key))
        return getn(records) > 0 and records[1].value or false
    end
    return self.db:count(self.table) > 0
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
    if getn(records) > 0 then -- unpack rows
        local entries = {}
        for id, row in ipairs(records) do
            entries[row.key] = row.value
        end
        return entries
    end
end


return Storage
