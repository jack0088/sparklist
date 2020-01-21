-- 2019 (c) kontakt@herrsch.de

-- NOTE every day a new log file is created and filled with messages from the command line console

local write = dofile "utilities.lua".writefile
local path = "log/"
local _print = print

function print(...)
    local time = os.date("%H:%M:%S")
    local dump = time
    for _, argument in ipairs{...} do dump = dump.."    "..tostring(argument) end
    write(path..os.date("%Y-%m-%d")..".txt", dump:sub(1, -4).."\n", "a")
    _print(time, ...)
end

return print
