-- 2020 (c) kontakt@herrsch.de

-- thin high-level wrapper around luasql-sqlite3
-- luasql-sqlite3 itself is a wrapper around LuaSQL
-- LuaSQL documentation at https://keplerproject.github.io/luasql/manual.html


local unpack = unpack or table.unpack -- Lua > 5.1
local sql = require "luasql.sqlite3".sqlite3()
local class = require "class"
local Database = class()


function Database:new(filepath)
    self.timeout = 1
    self.file = filepath
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
    local sql_statement = sql_query:gsub("%s+", " ")
    local variables = {...}
    local request_sink = variables[#variables]

    if type(request_sink) == "function" then
        table.remove(variables, #variables)
    else
        request_sink = nil
    end

    if #variables > 0 then
        sql_statement = string.format(sql_statement, unpack(variables))
    end

    print(string.format(
        "%s execute SQL transaction with query \"%s\"",
        os.date("%d.%m.%Y %H:%M:%S"),
        sql_statement
    ))

    local cursor = assert(self.connection:execute(sql_statement)) -- single transaction (auto-commit mode)
    local dataset, row
    if type(cursor) == "userdata" then
        repeat
            row = cursor:fetch({}, "a")
            if row then
                if type(request_sink) == "function" then
                    -- NOTE @request_sink works similar to Requst:receiveMessage(stream_sink)
                    -- and is advised to be used together with coroutine.yield for large requests to the database
                    request_sink(row)
                else
                    if not dataset then dataset = {} end
                    table.insert(dataset, row)
                end
            end
        until not row or not cursor
        cursor:close()
    end
    self:disconnect()
    return dataset
end


return Database
