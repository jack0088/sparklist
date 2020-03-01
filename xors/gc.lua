-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local hotload = require "hotload"
local utilities = require "utilities"
local dt = hotload "datetime"
local class = hotload "class"
local Database = hotload "database"
local KVStorage = hotload "kvstorage"
local GarbageCollector = class(Database)


function GarbageCollector:new(name)
    Database.new(self, "db/gc.db")
    self.table = name or "global"
end


function GarbageCollector:create(table)
    if type(table) == "string" then
        self:run(
            [[create table if not exists '%s' (
                id integer primary key autoincrement,
                dbname text not null,
                tblname text,
                tblrow integer check(tblname is not null),
                expiryts integer not null
            )]],
            table
        )
    end
end


function GarbageCollector:get_table()
    return self.__tablename
end


function GarbageCollector:set_table(name)
    assert(type(name) == "string" and #name > 0, "garbage collector name missing")
    assert(not name:find("[^%a%d%-_]+"), "garbage collector name '"..name.."' must only contain [a-zA-Z0-9%-_] characters")
    -- NOTE if you want to allow pre-defined garbage collectors only, then guard like this as well:
    -- assert(self:has(name), "no registration found for garbage collector named '"..name:match("(.+)_queue$").."' in '"..self.file.."'")
    self.__tablename = name.."_queue"
    self:create(self.table)
    self.settings = KVStorage(name.."_settings", nil, nil, self.file) -- settings of a garbage collector
end


function GarbageCollector:queue(database, table, row, expiry)
    local matching_jobs = self:run(
        "select id from '%s' where dbname = '%s' and tblname %s and tblrow %s",
        self.table,
        database,
        table and string.format("= '%s'", table) or "is null",
        row and "= "..row or "is null"
    )
    if getn(matching_jobs) > 0 then
        assert(getn(matching_jobs) == 1, "garbage collector queue contains duplicated jobs")
        self:run(
            "update '%s' set expiryts = %s where id = %s",
            self.table,
            expiry,
            matching_jobs[1].id
        )
    else
        self:run(
            "insert into '%s' (dbname, tblname, tblrow, expiryts) values ('%s', '%s', %s, %s)",
            self.table,
            database,
            table or "null",
            row or "null",
            expiry
        )
    end
end


function GarbageCollector:discard(job_or_database, table, row)
    local where
    if type(job_or_database) == "number" or (type(id) == "string" and tonumber(id) ~= nil) then
        where = "id = %s"
    else
        where = "dbname = '%s'"
        if type(table) == "string" and #table > 0 then where = where.." and tblname = '%s'" end
        if type(row) == "number" or (type(row) == "string" and tonumber(row) ~= nil) then where = where.." and tblrow = %s" end
    end
    self:run("delete from '%s' where %s", self.table, where:format(job_or_database, table or "null", row or "null"))
end


function GarbageCollector:delete(database, table, row)
    if type(database) == "string" and #database > 0 then
        local poi = Database(database)
        -- poi.verbose = true
        if (type(row) == "number" or (type(row) == "string" and tonumber(row) ~= nil)) then
            if poi:has(table) then
                poi:run("delete from '%s' where id = %s", table, row)
            end
        elseif type(table) == "string" and #table > 0 then
            poi:run("drop table if exists '%s'", table)
        else
            utilities.deletefile(database)
        end
    end
end


function GarbageCollector:collect()
    self.settings:set("previous_cycle", 0) -- force trigger/run next cycle!
    self:onEnterFrame()
end


function GarbageCollector:onEnterFrame()
    local current_time = dt.timestamp()
    local autorun_delay = tonumber(self.settings:get "autorun_delay" or 0)
    local previous_cycle = tonumber(self.settings:get "previous_cycle" or 0)

    if not autorun_delay or autorun_delay <= 0 then
        self.settings:set("autorun_delay", 86400) -- 1 day (in seconds)
    end
    
    if current_time >= previous_cycle + autorun_delay then
        for _, job in ipairs(self:run("select * from '%s' where expiryts <= %s", self.table, previous_cycle)) do
            self:delete(job.dbname, job.tblname, job.tblrow)
            self:discard(job.id)
        end
        self.settings:set("previous_cycle", current_time)
    end
end


return GarbageCollector
