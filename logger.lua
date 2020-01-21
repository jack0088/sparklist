-- 2019 (c) kontakt@herrsch.de

-- NOTE every day a new log file is created and filled with messages from the command line console

local write = dofile "utilities.lua".writefile
local path = "log/"
local _print = print

function print(...)
    local dump = os.date("%H:%M:%S")
    for _, argument in ipairs{...} do
        dump = dump..tostring(argument):gsub("([^\r\n]+)", "    %1")
    end
    write(path..os.date("%Y-%m-%d")..".txt", dump.."\n", "a")
    _print(dump)
end

return print
