-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(obj) return #obj end -- Lua > 5.1 idom
local hotload = require "hotload"
local dt = hotload "datetime"
local class = hotload "class"
local Database = hotload "database"
local Storage = hotload "local_storage"
local GarbageCollector = class()


function GarbageCollector:new(name)
    local gc_name = (type(name) == "string" and #name > 0) and name.."_garbage" or "global_garbage"
    self.db = Database "db/local_storage.db"
    self.name = gc_name.."_queue"
    self.settings = Storage(gc_name.."_settings")
    self.db:run(
        [[create table if not exists '%s' (
            id integer primary key autoincrement,
            dbname text not null,
            tbname text,
            row_id integer check(tbname is not null),
            expiry_timestamp integer not null
        )]],
        self.name
    )
end


function GarbageCollector:queue(database, table, row, date)
    local matching_jobs = self.db:run(
        "select id from '%s' where dbname = '%s' and tbname %s and row_id %s",
        self.name,
        database,
        table and string.format("= '%s'", table) or "is null",
        row and "= "..row or "is null"
    )
    if getn(matching_jobs) > 0 then
        assert(getn(matching_jobs) == 1, "garbage collector queue contains duplicated jobs")
        self.db:run(
            "update '%s' set expiry_timestamp = %s where id = %s",
            self.name,
            date,
            matching_jobs[1].id
        )
    else
        self.db:run(
            "insert into '%s' (dbname, tbname, row_id, expiry_timestamp) values ('%s', '%s', %s, %s)",
            self.name,
            database,
            table or "null",
            row or "null",
            date
        )
    end
end


function GarbageCollector:discard(job_or_database, table, row)
    local where
    if type(job_or_database) == "number" or (type(id) == "string" and tonumber(id) ~= nil) then
        where = "id = %s"
    else
        where = "dbname = '%s'"
        if type(table) == "string" and #table > 0 then where = where.." and tbname = '%s'" end
        if type(row) == "number" or (type(row) == "string" and tonumber(row) ~= nil) then where = where.." and row_id = %s" end
    end
    self.db:run("delete from '%s' where %s", self.name, where:format(job_or_database, table or "null", row or "null"))
end


function GarbageCollector:delete(database, table, row)
    local absolete_object = Database(database)
    --TODO!!!!
end


function GarbageCollector:run()
    local current_timestamp = dt.timestamp()
    local previous_cycle = self.settings:get "previous_cycle" or current_timestamp
    local garbage_queue = self.db:run("select * from '%s' where expiry_timestamp <= %s", self.name, previous_cycle)
    for _, entry in ipairs(garbage_queue) do
        self:delete(entry.database, entry.table, entry.row)
        self:discard(entry.id)
    end
    self.settings:set("previous_cycle", current_timestamp)
end


function GarbageCollector:onEnterFrame()
    self:run()
end


return GarbageCollector
