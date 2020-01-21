-- 2019 (c) kontakt@herrsch.de

local date = {}


-- TODO needs more work to output any timezone as date string or timestamp
-- also functions to convert back and forth between timestamps and date strings


function date.timestamp()
    return os.time()
end


function date.UTC(offset, timezone) -- Coordinated Universal Time
    -- @offset number in hours
    -- @timezone string, e.g.:
    -- "GTM" = Greenwich Mean Time (offset = 0)
    -- "CET" = Central European (Standard) Time (offset = +1)
    offset = type(offset) == "number" and offset * 60 * 60 or 0
    timezone = offset ~= 0 and timezone or "GTM"
    return os.date("!%a, %d %b %Y %H:%M:%S "..timezone, date.timestamp() + offset)
end


function date.GTM() -- Europe
    return date.UTC(0, "GTM")
end


function date.CET() -- Germany, among others
    return date.UTC(1, "CET")
end


return date
