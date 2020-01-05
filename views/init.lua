local function view(template, ...)
    if not template:match("^views.+") then template = "views."..template end
    local status, delegate = pcall(dofile, template:gsub("%.", "/")..".lua")
    if status and type(delegate) == "function" then return delegate(...) end
    return view "404"
end
return view
