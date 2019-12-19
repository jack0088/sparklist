package = "sparklist"
version = "1.0-1"
source = {
    url = "git+https://supacowa@bitbucket.org/supacowa/sparklist.git"
}
description = {
    homepage = "https://herrsch.de",
    license = "***private***"
}
dependencies = {
    "lua >= 5.1"
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
