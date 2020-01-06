-- 2019 (c) kontakt@herrsch.de

-- simple router with paths based on regex expressions
-- NOTE Any route should return true on successful handling of request and false on failing!
-- NOTE Any route that returns nil (void) will fall-through to next possible match!

local api = require "router"()

api:get("/chunked%-message", "controller/chunked_messages.lua")

api:get("/auth", "controller/auth.lua")
api:get("/auth%?id=(.+)", "controller/auth.lua")
api:get("/uploads/([%w%p]+)%.(%a%a%a+)", "controller/assets.lua")
api:get("/?", "controller/index.lua")
api:any(".*", "controller/404.lua")

return api
