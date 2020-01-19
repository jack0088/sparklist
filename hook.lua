local hotload = require "hotswap"

return {
    hotload, -- run watcher via :onEnterFrame
    hotload "http_connection",
    hotload "dispatcher"
}
