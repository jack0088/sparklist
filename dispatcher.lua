-- 2019 (c) kontakt@herrsch.de

-- simple router with paths based on regex expressions
-- NOTE Any route should return true on successful handling of request and false on failing!
-- NOTE Any route that returns nil (void) will fall-through to next possible match!

local api = require "router"()

api:get("/?", "controllers.index")
api:get("/chunked%-message", "controllers.chunked_messages")
api:get("/uploads/([%w%p]+)%.(%a%a%a+)", "controllers.assets")
api:any("/hello%?id=(.+)", "controllers.login")
api:any(".*", "controllers.404")

return api
