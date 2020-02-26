-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local locations = {}
local append_pos


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
    
    pos = tonumber(pos) or append_pos or max
    pos = clamp(pos, min, max)

    if not path then
        if pos <= count then
            table.remove(locations, pos)
        end
        return
    end

    for index, location in ipairs(locations) do
        if location == path then
            if index == pos then
                append_pos = pos + 1
                return
            end
            table.remove(locations, index)
            count = count - 1
            max = max - 1
            pos = clamp(pos, min, max)
            break
        end
    end

    table.insert(locations, pos, path)
    append_pos = pos + 1
    package.path = table.concat(locations, ";")
end


for path in package.path:gmatch("[^;]+") do -- unpack existing
    -- table.insert(locations, path)
    record(path)
end


record("./?.lua", 1)
record("./?/init.lua") -- Lua <= 5.1
return record
