-- 2020 (c) kontakt@herrsch.de

-- thin high-level wrapper around luasql-sqlite3
-- luasql-sqlite3 itself is a wrapper around LuaSQL
-- LuaSQL documentation at https://keplerproject.github.io/luasql/manual.html


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


function Database:run(sql_statement, request_sink)
    self:connect()
    local cursor = assert(self.connection:execute(sql_statement)) -- single transaction (auto-commit mode)
    local dataset, row
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
    until not row
    cursor:close()
    self:disconnect()
    return dataset
end


return Database
