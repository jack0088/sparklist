-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local hotload = require "hotload"
local utilities = require "utilities"
local dt = hotload "datetime"
local class = hotload "class"
local Database = hotload "database"
local LocalStorage = hotload "local_storage"
local GarbageCollector = class()


function GarbageCollector:new(name)
    local gc_name = (type(name) == "string" and #name > 0) and name.."_garbage" or "global_garbage"
    self.db = Database "db/local_storage.db"
    self.name = gc_name.."_queue"
    self.settings = LocalStorage(gc_name.."_settings")
    self.verbose = false
    self.db:run(
        [[create table if not exists '%s' (
            id integer primary key autoincrement,
            dbname text not null,
            tblname text,
            tblrow integer check(tblname is not null),
            expiryts integer not null
        )]],
        self.name
    )
end


function GarbageCollector:get_verbose()
    return self.settings.db.verbose and self.db.verbose
end


function GarbageCollector:set_verbose(flag)
    self.settings.db.verbose = flag
    self.db.verbose = flag
end


function GarbageCollector:queue(database, table, row, expiry)
    local matching_jobs = self.db:run(
        "select id from '%s' where dbname = '%s' and tblname %s and tblrow %s",
        self.name,
        database,
        table and string.format("= '%s'", table) or "is null",
        row and "= "..row or "is null"
    )
    if getn(matching_jobs) > 0 then
        assert(getn(matching_jobs) == 1, "garbage collector queue contains duplicated jobs")
        self.db:run(
            "update '%s' set expiryts = %s where id = %s",
            self.name,
            expiry,
            matching_jobs[1].id
        )
    else
        self.db:run(
            "insert into '%s' (dbname, tblname, tblrow, expiryts) values ('%s', '%s', %s, %s)",
            self.name,
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
    self.db:run("delete from '%s' where %s", self.name, where:format(job_or_database, table or "null", row or "null"))
end


function GarbageCollector:delete(database, table, row)
    if type(database) == "string" and #database > 0 then
        local poi = Database(database)
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
    self:run()
end


function GarbageCollector:run()
    local current_timestamp = dt.timestamp()
    local previous_cycle = self.settings:get "previous_cycle" or current_timestamp
    local garbage_queue = self.db:run("select * from '%s' where expiryts <= %s", self.name, previous_cycle)
    for _, job in ipairs(garbage_queue) do
        self:delete(job.dbname, job.tblname, job.tblrow)
        self:discard(job.id)
    end
    self.settings:set("previous_cycle", current_timestamp)
end


return GarbageCollector
