-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local hotload = require "hotload"
local utilities = require "utilities"
local dt = hotload "datetime"
local class = hotload "class"
local Database = hotload "database"
local Storage = hotload "kvstorage"
local GarbageCollector = class()


function GarbageCollector:new(name)
    local gc_name = (type(name) == "string" and #name > 0) and name or "global"
    self.db = Database "db/gc.db"
    self.table = gc_name.."_queue" -- the storage of the actual garbage collector
    self:create()
    self.settings = Storage(gc_name.."_settings", self.db.file) -- settings of a garbage collector
    self.verbose = false
end


function GarbageCollector:get_verbose()
    return self.settings.db.verbose and self.db.verbose
end


function GarbageCollector:set_verbose(flag)
    self.settings.db.verbose = flag
    self.db.verbose = flag
end


function GarbageCollector:get_table()
    return self.__tablename
end


function GarbageCollector:set_table(name)
    assert(type(name) == "string", "garbage collector name missing")
    assert(not name:find("[^%a%d%-_]+"), "garbage collector name '"..name.."' must only contain [a-zA-Z0-9%-_] characters")
    -- TODO? if only pre-defined garbage collectors are allowed to be accessed than we need to guard like this:
    -- assert(self.db:has(name), "no registration found for garbage collector named '"..name:match("(.+)_queue$").."' in '"..self.db.file.."'")
    self.__tablename = name
end


function GarbageCollector:create() -- register a new garbage collector
    self.db:run(
        [[create table if not exists '%s' (
            id integer primary key autoincrement,
            dbname text not null,
            tblname text,
            tblrow integer check(tblname is not null),
            expiryts integer not null
        )]],
        self.table
    )
end


function GarbageCollector:destroy() -- destroy an existing garbage collector
    self.db:run("destroy table if exists '%s'", self.table)
end


function GarbageCollector:queue(database, table, row, expiry)
    local matching_jobs = self.db:run(
        "select id from '%s' where dbname = '%s' and tblname %s and tblrow %s",
        self.table,
        database,
        table and string.format("= '%s'", table) or "is null",
        row and "= "..row or "is null"
    )
    if getn(matching_jobs) > 0 then
        assert(getn(matching_jobs) == 1, "garbage collector queue contains duplicated jobs")
        self.db:run(
            "update '%s' set expiryts = %s where id = %s",
            self.table,
            expiry,
            matching_jobs[1].id
        )
    else
        self.db:run(
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
    self.db:run("delete from '%s' where %s", self.table, where:format(job_or_database, table or "null", row or "null"))
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


function GarbageCollector:onEnterFrame()
    local current_time = dt.timestamp()
    local autorun_delay = self.settings:get "autorun_delay"
    local previous_cycle = self.settings:get "previous_cycle" or current_time

    if not autorun_delay then
        autorun_delay = 86400 -- 1 day (in seconds)
        self.settings:set("autorun_delay", autorun_delay)
    end
    
    if tonumber(previous_cycle) + tonumber(autorun_delay) <= current_time then
        self:run()
        -- NOTE the :run() call updates previous_cycle anyway...
        -- self.settings:set("previous_cycle", current_time)
    end
end


function GarbageCollector:run()
    local previous_cycle = self.settings:get "previous_cycle" or dt.timestamp()
    for _, job in ipairs(self.db:run("select * from '%s' where expiryts <= %s", self.table, previous_cycle)) do
        self:delete(job.dbname, job.tblname, job.tblrow)
        self:discard(job.id)
    end
    self.settings:set("previous_cycle", dt.timestamp())
end


return GarbageCollector
