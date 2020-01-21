-- 2019 (c) kontakt@herrsch.de

local date = {}


function date.UTC(offset, zone) -- Coordinated Universal Time
    -- @offset number in hours
    -- @zone string, e.g.:
    -- "GTM" = Greenwich Mean Time (offset = 0)
    -- "CET" = Central European (Standard) Time (offset = +1)
    offset = type(offset) == "number" and offset * 60 * 60 or 0
    zone = offset ~= 0 and zone or "GTM"
    return os.date("!%a, %d %b %Y %H:%M:%S "..zone, os.time() + offset)
end


function date.GTM() -- Europe
    return date.UTC(0, "GTM")
end


function date.CET() -- Germany, among others
    return date.UTC(1, "CET")
end

return date
