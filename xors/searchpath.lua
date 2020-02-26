-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local locations = {}
local previous_record


local function clamp(num, min, max)
    return num < min and min or num > max and max or num
end


local function record(path, pos)
    local count = getn(locations)
    local min = 1
    local max = count + 1

    if type(tonumber(pos)) == "nil" then
        for index, location in ipairs(locations) do
            if location == pos then
                pos = index
                break
            end
        end
    end
    
    pos = clamp(tonumber(pos) or max, min, max)

    if not path then
        if pos <= count then
            table.remove(locations, pos)
        end
        return
    end

    for index, location in ipairs(locations) do
        if location == path then
            if index == pos then
                return
            end
            if pos > index then
                pos = clamp(pos - 1, min, max)
            end
            table.remove(locations, index)
            break
        end
    end

    table.insert(locations, pos, path)
    package.path = table.concat(locations, ";")
end


for path in package.path:gmatch("[^;]+") do -- unpack existing
    -- table.insert(locations, path)
    record(path)
end


record("./?.lua", 1)
record("./?/init.lua", 2) -- Lua <= 5.1
return record
