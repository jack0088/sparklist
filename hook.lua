local hotload = require "hotswap"

return {
    hotload, -- run watcher via :onEnterFrame
    hotload "connection",
    hotload "dispatcher"
}
