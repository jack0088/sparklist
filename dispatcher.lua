-- 2019 (c) kontakt@herrsch.de

-- simple router with paths based on regex expressions
-- NOTE Any route should return true on successful handling of request and false on failing!
-- NOTE Any route that returns nil (void) will fall-through to next possible match!

local hotload = require "hotswap"
local api = hotload "router"()

api:get("/chunked%-message", "controller/chunked_messages.lua")
api:get("/refresh", function(request, response)
    response:refresh("/", 5, "view/error.lua", "text/html", request.path, request.method)
end)

api:get("/auth", "controller/auth.lua")
api:get("/auth%?id=(.+)", "controller/auth.lua")
api:get("/uploads/([%w%p]+)%.(%a%a%a+)", "controller/assets.lua")
api:get("/?", "controller/index.lua")
api:any(".*", "controller/error.lua")

return api
