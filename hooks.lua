-- 2020 (c) kontakt@herrsch.de

local hotload = require "hotload"
return {
    hotload, -- run observer via :onEnterFrame event
    hotload "connection",
    hotload "websocket",
    hotload "endpoints"
}
