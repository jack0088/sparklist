-- 2019 (c) kontakt@herrsch.de

local super = {
    parent = function(something) return (getmetatable(something) or {}).__index end;
    derivant = function(anything, something) return anything:parent() == something end
}
super.__index = super

local function replica(something, ...)
    local meta = getmetatable(something)
    local copy = meta and replica(meta.__index) or {}
    if something ~= super then for k, v in pairs(something) do copy[k] = v end end
    return copy.new and (copy:new(...) or copy) or copy
end

local function thing(something)
    if not something or not getmetatable(something) then something = setmetatable(something or {}, super) end
    return setmetatable({}, {__index = something, __call = replica})
end

return thing
