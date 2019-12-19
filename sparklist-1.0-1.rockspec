package = "sparklist"
version = "1.0-1"
source = {
    url = "git+https://supacowa@bitbucket.org/supacowa/sparklist.git"
}
description = {
    homepage = "https://herrsch.de",
    license = "Closed Source. Unauthorized copying of this file, via any medium is strictly prohibited! 2019 (c) kontakt@herrsch.de"
}
dependencies = {
    "lua == 5.1.5",
    "luasocket",
    "sqlite3",
    "luasql-sqlite3"
}
build = {
    type = "builtin",
    modules = {
        hotswap = "hotswap.lua",
        mimetype = "mimetype.lua",
        server = "server.lua",
        utilities = "utilities.lua"
    }
}
