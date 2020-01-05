local function controller(handler)
    if not handler:match("^controllers.+") then handler = "controllers."..handler end
    local status, delegate = pcall(dofile, handler:gsub("%.", "/")..".lua")
    if status and type(delegate) == "function" then return delegate end
    return controller "404"
end
return controller
