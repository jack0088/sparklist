-- 2020 (c) kontakt@herrsch.de

-- thin high-level wrapper around luasql-sqlite3
-- luasql-sqlite3 itself is a wrapper around LuaSQL
-- LuaSQL documentation at https://keplerproject.github.io/luasql/manual.html


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local unpack = unpack or table.unpack -- Lua > 5.1
local sql = require "luasql.sqlite3".sqlite3()
local hotload = require "hotload"
local class = hotload "class"
local Database = class()


function Database:new(filepath)
    self.timeout = 1
    self.file = filepath
    self.verbose = false
end


function Database:connect()
    self:disconnect()
    assert(type(self.file) == "string", "missing database file path")
    self.connection = sql:connect(self.file, self.timeout or 1)
end


function Database:disconnect()
    if self.connection then
        self.connection:close()
        self.connection = nil
    end
end


-- possible parameters are (in order)
-- @sql_query (required string) the sql statement you want to execute on the database
-- @... (optional any) when @sql_query uses a string with placeholders inside, e.g. %s like in string.format, then @... can be any type or amount of optional parameters that will be forwarded to string.format("", ...) to fill out the placeholders
-- @request_sink (optional function) handler that can process each row of the returned database records; it works pretty much the same as Requst:receiveMessage(stream_sink); the idea is to allow Database.run to be executed in a threaded manner
function Database:run(sql_query, ...)
    self:connect()
    local sql_statement = sql_query:gsub("[\r\n%s]+", " ") -- trim whitespaces and newlines
    local variables = {...}
    local request_sink = variables[getn(variables)]

    if type(request_sink) == "function" then
        table.remove(variables, getn(variables))
    else
        request_sink = nil
    end

    if getn(variables) > 0 then
        sql_statement = string.format(sql_statement, unpack(variables))
    end

    if self.verbose then
        print(string.format("executed SQL transaction in database '%s' with query:\n%s", self.file, sql_statement))
    end

    local cursor = assert(self.connection:execute(sql_statement)) -- single transaction (auto-commit mode)
    local dataset, row = {}
    if type(cursor) == "userdata" then
        repeat
            row = cursor:fetch({}, "a")
            if row then
                if type(request_sink) == "function" then
                    -- NOTE @request_sink works similar to Requst:receiveMessage(stream_sink)
                    -- and is advised to be used together with coroutine.yield for large requests to the database
                    request_sink(row)
                else
                    table.insert(dataset, row)
                end
            end
        until not row or not cursor
        cursor:close()
    end
    self:disconnect()
    return dataset
end


-- check if table @name exists and return true or false
-- if @table_name is nil then returns all existing tables in that database
function Database:has(table_name)
    if type(table_name) == "string" then
        local matches = self:run("select name from sqlite_master where type = 'table' and name = '%s'", tostring(table_name))
        return getn(matches) > 0 and matches[1].name == tostring(table_name) or false
    end
    return self:run "select name from sqlite_master where type = 'table' and name not like 'sqlite_%'"
end


-- returns the number of counted records in table @name
-- Database.count(@table_name) == 0 means it is empty
function Database:count(table_name)
    local exists = self:has(table_name)
    if type(exists) == "table" or not exists then return 0 end
    local records = self:run("select count(id) as count from '%s'", table_name)
    return records[1].count
end


-- creates a database table named @table_name if not yet existing
function Database:create(table_name)
    if type(table_name) == "string" then
        self:run(
            [[create table if not exists '%s' (
                id integer primary key autoincrement,
                key text unique not null,
                value text not null
            )]],
            table_name
        )
    end
end


-- destoys existing database table named @table_name
function Database:destroy(table_name)
    if type(table_name) == "string" then
        self:run("drop table if exists '%s'", table_name)
    end
end


return Database
