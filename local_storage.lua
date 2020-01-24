-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local hotload = require "hotload"
local class = hotload "class"
local Database = hotload "database"
local LocalStorage = class()


function LocalStorage:new(name)
    self.db = Database "db/local_storage.db"
    self.verbose = false
    self.table = name
end


function LocalStorage:get_verbose()
    return self.db.verbose
end


function LocalStorage:set_verbose(flag)
    self.db.verbose = flag
end


function LocalStorage:get_table() -- getter for LocalStorage.table
    return self.__tablename
end


function LocalStorage:set_table(name) -- setter for LocalStorage.table
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


function LocalStorage:create()
    if type(self.table) == "string" then
        self.db:run(
            [[create table if not exists '%s' (
                id integer primary key autoincrement,
                key text unique not null,
                value text not null
            )]],
            self.table
        )
    end
end


function LocalStorage:destory()
    if type(self.table) == "string" then
        self.db:run("drop table if exists '%s'", self.table)
    end
end


function LocalStorage:exists(key, value)
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


function LocalStorage:set(key, value) -- upsert (update + insert)
    if self:exists(key) then
        self.db:run("update '%s' set value = '%s' where key = '%s'", self.table, tostring(value), tostring(key))
    else
        self.db:run("insert into '%s' (key, value) values ('%s', '%s')", self.table, tostring(key), tostring(value))
    end
end


function LocalStorage:get(key)
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


return LocalStorage
