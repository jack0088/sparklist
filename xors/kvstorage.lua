-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local hotload = require "hotload"
local class = hotload "class"
local Database = hotload "database"
local Storage = class(Database)


function Storage:new(table, column1, column2, database)
    Database.new(self, database or "db/xors.db")
    self.table = table
    self.column1 = column1
    self.column2 = column2
end


function Storage:create(table)
    if type(table) == "string" and #table > 0 then
        self:run(
            [[create table if not exists '%s' (
                id integer primary key autoincrement,
                %s text unique not null,
                %s text not null
            )]],
            table,
            "key",
            "value"
        )
    end
end


function Storage:get_table()
    return self.__tablename
end


function Storage:set_table(name)
    assert(type(name) == "string", "missing common identifier string")
    assert(not name:find("[^%a%d%-_]+"), "common identifier string '"..name.."' must only contain [a-zA-Z0-9%-_] characters")
    if self.table ~= nil and self.table ~= name then
        if self:count(self.table) < 1 then
            -- before switching to new db table delete the current one if it remains empty
            self:destroy()
        end
    end
    self.__tablename = name
    self:create(self.table)
end


function Storage:get_column1()
    return self.__columnname1 or "key"
end


function Storage:set_column1(name)
    if type(name) == "string" and #name > 0 then
        if self.column1 ~= name and self.__columnname1 ~= name then
            self:rename(self.table, self.column1, name)
        end
        self.__columnname1 = name
    end
end


function Storage:get_column2()
    return self.__columnname2 or "value"
end


function Storage:set_column2(name)
    if type(name) == "string" and #name > 0 then
        if self.column2 ~= name and self.__columnname2 ~= name then
            self:rename(self.table, self.column2, name)
        end
        self.__columnname2 = name
    end
end


function Storage:exists(key, value)
    if key and value then
        local records = self:run(
            "select id from '%s' where %s = '%s' and %s = '%s'",
            self.table, self.column1, tostring(key), self.column2, tostring(value)
        )
        return getn(records) > 0 and record[1].id or false
    elseif value then
        local records = self:run(
            "select %s from '%s' where %s = '%s'",
            self.column1, self.table, self.column2, tostring(value)
        )
        return getn(records) > 0 and records[1][self.column1] or false
    elseif key then
        local records = self:run(
            "select %s from '%s' where %s = '%s'",
            self.column2, self.table, self.column1, tostring(key)
        )
        return getn(records) > 0 and records[1][self.column2] or false
    end
    return self:count(self.table) > 0
end


function Storage:get(key)
    if type(key) == "string" then
        local value = self:exists(key)
        return value == false and nil or value
    end
    local records = self:run(
        "select %s, %s from '%s'",
        self.column1, self.column2, self.table
    )
    if getn(records) > 0 then -- unpack rows
        local entries = {}
        for _, row in ipairs(records) do
            local k = row[self.column1]
            local v = row[self.column2]
            entries[k] = v
        end
        return entries
    end
end


function Storage:getUUID(key, value)
    local records
    if key and value then
        records = self:run(
            "select id from '%s' where %s = '%s' and %s = '%s'",
            self.table, self.column1, tostring(key), self.column2, tostring(value)
        )
    elseif value then
        records = self:run(
            "select id from '%s' %s",
            self.table, self.column2, tostring(value)
        )
    elseif key then
        records = self:run(
            "select id from '%s' %s",
            self.table, self.column1, tostring(key)
        )
    end
    if type(records) == "table" and getn(records) > 0 then
        local entries = {}
        for _, row in ipairs(records) do
            table.insert(entries, tonumber(row.id))
        end
        return getn(entries) == 1 and entries[1] or entries
    end
end


function Storage:set(key, value)
    if type(key) ~= nil then
        if type(value) ~= nil then -- upsert (update + insert)
            if self:exists(key) then
                self:run(
                    "update '%s' set %s = '%s' where %s = '%s'",
                    self.table, self.column2, tostring(value), self.column1, tostring(key)
                )
            else
                self:run(
                    "insert into '%s' (%s, %s) values ('%s', '%s')",
                    self.table, self.column1, self.column2, tostring(key), tostring(value)
                )
            end
        elseif self:exists(key) then
            self:run(
                "delete from '%s' where %s = '%s'",
                self.table, self.column1, tostring(key)
            )
        end
    end
end


return Storage
