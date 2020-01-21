-- 2020 (c) kontakt@herrsch.de


local class = require "class"
local hotload = require "hotswap"
local Database = hotload "database"
local LocalStorage = class()


function LocalStorage:new(namespace)
    self.db = Database "db/local_storage.db"
    self.namespace = namespace
end


function LocalStorage:get_namespace() -- getter for LocalStorage.table
    return self.__tablename
end


function LocalStorage:set_namespace(new) -- setter for LocalStorage.table
    assert(type(new) == "string", "missing common identifier string")
    assert(not new:find("[^%a%d%-_]+"), "common identifier string '"..name.."' must only contain [a-zA-Z0-9%-_] characters")
    if self.namespace ~= nil and self.namespace ~= new then
        if self.db:count(self.namespace) == 0 then
            -- before switching to new db table delete the current one if it remains empty
            self:destroy()
        end
    end
    self.__tablename = new
    self:create()
end


function LocalStorage:create()
    if type(self.namespace) == "string" then
        self.db:run(
            [[create table if not exists '%s' (
                id integer primary key autoincrement,
                key text unique not null,
                value text not null
            )]],
            self.namespace
        )
    end
end


function LocalStorage:destory()
    if type(self.namespace) == "string" then
        self.db:run("drop table if exists '%s'", self.namespace)
    end
end


function LocalStorage:exists(key, value)
    if key and value then
        local records = self.db:run("select id from '%s' where key = '%s' and value = '%s'", self.namespace, tostring(key), tostring(value))
        return #records > 0 and record[1].id or false
    elseif value then
        local records = self.db:run("select key from '%s' where value = '%s'", self.namespace, tostring(value))
        return #records > 0 and records[1].key or false
    elseif key then
        local records = self.db:run("select value from '%s' where key = '%s'", self.namespace, tostring(key))
        return #records > 0 and records[1].value or false
    end
    return self.db:countTable(self.namespace) > 0
end


function LocalStorage:set(key, value) -- upsert (update + insert)
    if self:exists(key) then
        self.db:run("update '%s' set value = '%s' where key = '%s'", self.namespace, tostring(value), tostring(key))
    else
        self.db:run("insert into '%s' (key, value) values ('%s', '%s')", self.namespace, tostring(key), tostring(value))
    end
end


function LocalStorage:get(key)
    if type(key) == "string" then
        local value = self:exists(key)
        return value == false and nil or value
    end
    local records = self.db:run("select key, value from '%s'", self.namespace)
    if #records > 0 then -- unpack rows
        local entries = {}
        for id, row in ipairs(records) do
            entries[row.key] = row.value
        end
        return entries
    end
end


return LocalStorage
