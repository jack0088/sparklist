-- 2019 (c) kontakt@herrsch.de

-- simple router with paths based on regex expressions
-- NOTE Any route should return true on successful handling of request and false on failing!
-- NOTE Any route that returns nil (void) will fall-through to next possible match!

local api = require "router"()

api:get("/chunked%-message", "controllers.chunked_messages")
api:get("/auth%?id=(.+)", "controllers.auth")
api:get("/auth", "controllers.auth")
api:get("/uploads/([%w%p]+)%.(%a%a%a+)", "controllers.assets")
api:get("/?", "controllers.index")
api:any(".*", "views.404")

return api
