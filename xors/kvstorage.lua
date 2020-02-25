-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local hotload = require "xors.hotload"
local class = hotload "xors.class"
local Database = hotload "xors.database"
local Storage = class()


function Storage:new(table_name, database_file)
    self.db = Database(database_file or "db/xors.db")
    self.verbose = false
    self.table = table_name
    self.column1 = "key" -- column name for key
    self.column2 = "value" -- column name for value
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


function Storage:get_column1()
    return self.__columnname1 or "key"
end


function Storage:set_column1(name)
    if self.__columnname1 ~= nil and self.__columnname1 ~= name then
        self.db:rename(self.table, self.__columnname1, name)
    end
    self.__columnname1 = name
end


function Storage:get_column2()
    return self.__columnname2 or "value"
end


function Storage:set_column2(name)
    if self.__columnname2 ~= nil and self.__columnname2 ~= name then
        self.db:rename(self.table, self.__columnname2, name)
    end
    self.__columnname2 = name
end


function Storage:create()
    if type(self.table) == "string" then
        self.db:run(
            [[create table if not exists '%s' (
                id integer primary key autoincrement,
                %s text unique not null,
                %s text not null
            )]],
            self.table,
            self.column1,
            self.column2
        )
    end
end


function Storage:destroy()
    self.db:destroy(self.table)
end


function Storage:exists(key, value)
    if key and value then
        local records = self.db:run(
            "select id from '%s' where %s = '%s' and %s = '%s'",
            self.table, self.column1, tostring(key), self.column2, tostring(value)
        )
        return getn(records) > 0 and record[1].id or false
    elseif value then
        local records = self.db:run(
            "select %s from '%s' where %s = '%s'",
            self.column1, self.table, self.column2, tostring(value)
        )
        return getn(records) > 0 and records[1][self.column1] or false
    elseif key then
        local records = self.db:run(
            "select %s from '%s' where %s = '%s'",
            self.column2, self.table, self.column1, tostring(key)
        )
        return getn(records) > 0 and records[1][self.column2] or false
    end
    return self.db:count(self.table) > 0
end


function Storage:set(key, value)
    if type(key) ~= nil then
        if type(value) ~= nil then -- upsert (update + insert)
            if self:exists(key) then
                self.db:run(
                    "update '%s' set %s = '%s' where %s = '%s'",
                    self.table, self.column2, tostring(value), self.column1, tostring(key)
                )
            else
                self.db:run(
                    "insert into '%s' (%s, %s) values ('%s', '%s')",
                    self.table, self.column1, self.column2, tostring(key), tostring(value)
                )
            end
        elseif self:exists(key) then
            self.db:run(
                "delete from '%s' where %s = '%s'",
                self.table, self.column1, tostring(key)
            )
        end
    end
end


function Storage:get(key)
    if type(key) == "string" then
        local value = self:exists(key)
        return value == false and nil or value
    end
    local records = self.db:run(
        "select %s, %s from '%s'",
        self.column1, self.column2, self.table
    )
    if getn(records) > 0 then -- unpack rows
        local entries = {}
        for id, row in ipairs(records) do
            local k = row[self.column1]
            local v = row[self.column2]
            entries[k] = v
        end
        return entries
    end
end


return Storage
