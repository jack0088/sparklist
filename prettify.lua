-- 2019 (c) kontakt@herrsch.de

local function prettify(t, o)
    o = o or ""
    if type(t) == "table" then
        local s = "{"
        for k, v in pairs(t) do
            if type(k) ~= "number" then k = '"'..k..'"' end
            s = s.."\n    "..o.."["..k.."] = "..prettify(v, o.."    ")..","
        end
        return s:sub(1, -2).."\n"..o.."}"
    else
        return type(t) == "string" and '"'..tostring(t)..'"' or tostring(t)
    end
end

return prettify
