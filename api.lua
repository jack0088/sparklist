-- 2019 (c) kontakt@herrsch.de

-- simple router with paths based on regex expressions
-- NOTE Any route should return true on successful handling of request and false on failing!
-- NOTE Any route that returns nil (void) will fall-through to next possible match!


-- NOTE
-- SwoopJS (a paswordless single-sign-on service) uses https for login verification requests (plain socket.http.request() fail and always responds with status code 301)
-- since I decided to keep this whole server simple, I use plain http everywhere and the plan is to protect it behind a reverse SSL proxy (e.g. cloudflare)
-- however, to overcome the Swoop requirement, we need to install Lua-OpenSSL from one of the fallowing sources:
-- https://github.com/zhaozg/lua-openssl
-- https://github.com/brunoos/luasec (I used it on my local development machine and it includes OpenSSL)
-- If you have trouble installing luasec, see https://github.com/luarocks/luarocks/issues/579
local https = require "ssl.https"
local view = require "views"
local api = require "router"()
-- TODO later add rest_api.lua for backend routes (like for preloading content or live streaming over (web)sockets)


api:get("/?", function(request, response)
    return response:submit(view("views.landing"), "text/html")
end)


api:get("/assets/([%w%p]+)%.(%a%a%a+)", function(request, response, filename, extension) -- requests to files
    if string.find("jpg jpg png tiff bmp gif svg eps pdf", extension) then -- whitelist look-up
        -- return response:submit(request.url)
        return response:attach(request.url)
    end
    return response:submit(nil, nil, 403)
end)


api:any("/hello%?id=(.+)", function(request, response, token) -- swoop login
    -- e.g. https://app.swoopnow.com/api/inbound_emails/d98fc8d31ceb2bf9208dae120530e2bf
    local identity, status = https.request("https://app.swoopnow.com/api/inbound_emails/"..token)
    if status == 200 and identity then
        response:addHeader("Set-Cookie", "swoopid="..token)
    end
    return response:submit(view("views.hellologin", identity), "text/html")
end)


api:any(".*", function(request, response) -- general security fallback-filter
    return response:submit()
end)


return api
