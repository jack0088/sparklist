-- 2019 (c) kontakt@herrsch.de

-- NOTE every day a new log file is created and filled with messages from the command line console

local log = dofile "utilities.lua".writefile
local _print = print

function print(...)
    local dump = ""
    for _, argument in ipairs{...} do dump = dump.."    "..tostring(argument) end
    log("logs/"..os.date("%Y-%m-%d")..".txt", dump.."\n", "a")
    _print(...)
end
