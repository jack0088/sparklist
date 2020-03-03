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
    self.connection = assert(sql:connect(self.file, self.timeout or 1))
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


-- returns true or false and a list of all available records (= tables or columns)
-- @table_name (optional string) db table name of table to check for existance in this database; if nil then returns all available tables in this db
-- @column_name (optional string) db column name in this @table_name to check for existance
function Database:has(table_name, column_name)
    if type(table_name) == "string" then
        if type(column_name) == "string" then
            local columns = self.run("select name from pragma_table_info('%s')", tostring(table_name))
            return getn(columns) > 0 and columns[1].name == tostring(column_name) or false, columns
        end
        local tables = self:run("select name from sqlite_master where type = 'table' and name = '%s'", tostring(table_name))
        return getn(tables) > 0 and tables[1].name == tostring(table_name) or false, tables
    end
    local tables = self:run "select name from sqlite_master where type = 'table' and name not like 'sqlite_%'"
    return false, tables
end


-- returns the number of counted records in table @name
-- Database.count(@table_name) == 0 means it is empty
function Database:count(table_name)
    local exists = self:has(table_name)
    if type(exists) == "table" or not exists then return 0 end
    local records = self:run("select count(id) as count from '%s'", table_name)
    return records[1].count
end


-- rename table: Database:rename(table_name, new_table_name)
-- rename column: Database:rename(table_name, column_name, new_column_name)
function Database:rename(table_name, ...)
    assert(type(table_name) == "string" and #table_name > 0, "missing database table reference")
    local arguments = {...}
    if type(arguments[2]) == "string" then
        local column_name = arguments[1]
        local new_column_name = arguments[2]
        assert(type(column_name) == "string" and #column_name > 0, "missing database column reference")
        assert(type(new_column_name) == "string" and #new_column_name > 0, "missing new database column name")
        assert(not new_column_name:find("[^%a%d%-_]+"), "new column name string '"..new_column_name.."' must only contain [a-zA-Z0-9%-_] characters")
        if column_name ~= new_column_name and self:has(table_name) == true then
            self:run("alter table '%s' rename column '%s' to '%s'", table_name, column_name, new_column_name)
        end
    else
        local new_table_name = arguments[1]
        assert(type(new_table_name) == "string" and #new_table_name > 0, "missing new database table name")
        assert(not new_table_name:find("[^%a%d%-_]+"), "new table name string '"..new_table_name.."' must only contain [a-zA-Z0-9%-_] characters")
        if table_name ~= new_table_name and self:has(table_name) == true then
            self:run("alter table '%s' rename to '%s'", table_name, new_table_name)
        end
    end
end


-- destoys existing database table named @table_name
function Database:destroy(table_name)
    if type(table_name) == "string" then
        self:run("drop table if exists '%s'", table_name)
    end
end


return Database
