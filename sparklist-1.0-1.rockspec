package = "sparklist"
version = "1.0-1"
source = {
    url = "./"
}
description = {
    homepage = "https://herrsch.de",
    license = "Closed Source. Unauthorized copies or further distribution of files in this project, via any medium, is strictly prohibited! All rights reserved. 2019 (c) kontakt@herrsch.de"
}
dependencies = {
    "lua == 5.1.5",
    "luasocket",
    "sqlite3",
    "luasql-sqlite3"
}
build = {
    type = "none",
    install = {
        lua = {
            hotswap = "hotswap.lua",
            mimetype = "mimetype.lua",
            server = "server.lua",
            utilities = "utilities.lua"
        }
    }
}
