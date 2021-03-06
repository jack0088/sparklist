-- 2019 (c) kontakt@herrsch.de


local _print = print
local path = "log/"

local function writefile(filepath, message)
    local f = io.open(filepath, "a")
    if not f then return end
    f:write(message)
    f:close()
end

function print(...)
    local dump = os.date("%H:%M:%S")
    for _, argument in ipairs{...} do
        dump = dump..tostring(argument):gsub("([^\r\n]+)", "    %1")
    end
    writefile(path..os.date("%Y-%m-%d")..".txt", dump.."\n", "a")
    _print(dump)
end

return print
