return function(template, ...)
    local status, view = pcall(dofile, template:gsub("%.", "/")..".lua") -- pcalls are not cheap I heared somewhere
    if status and type(view) == "function" then return view(...) end
    return ""
end