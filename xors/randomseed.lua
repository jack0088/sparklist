local socket = require "socket"

local charset = {}  do -- [0-9a-zA-Z]
    for c = 48, 57  do table.insert(charset, string.char(c)) end
    for c = 65, 90  do table.insert(charset, string.char(c)) end
    for c = 97, 122 do table.insert(charset, string.char(c)) end
end


local function hash(length)
    if not length or length < 1 then return "" end
    math.randomseed(socket.gettime() * 10000)
    return hash(length - 1)..charset[math.random(1, #charset)]
end

return hash
