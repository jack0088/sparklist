local hotswap = require "hotswap"
require "_tests.lol.foo"

for k, v in pairs(package.loaded) do
    print(k)
end

while true do hotswap() lol() end

