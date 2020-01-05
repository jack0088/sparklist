-- NOTE
-- SwoopJS (a paswordless single-sign-on service) uses https for login verification requests (plain socket.http.request() fail and always responds with status code 301)
-- since I decided to keep this whole server simple, I use plain http everywhere and the plan is to protect it behind a reverse SSL proxy (e.g. cloudflare)
-- however, to overcome the Swoop requirement, we need to install Lua-OpenSSL from one of the fallowing sources:
-- https://github.com/zhaozg/lua-openssl
-- https://github.com/brunoos/luasec (I used it on my local development machine and it includes OpenSSL)
-- If you have trouble installing luasec, see https://github.com/luarocks/luarocks/issues/579

local https = require "ssl.https"

return function(request, response, token) -- swoop login
    -- e.g. https://app.swoopnow.com/api/inbound_emails/d98fc8d31ceb2bf9208dae120530e2bf
    local identity, status = https.request("https://app.swoopnow.com/api/inbound_emails/"..token)
    if status == 200 and identity then
        response:addHeader("Set-Cookie", "swoopid="..token)
    end
    return response:submit(view("hellologin", identity), "text/html")
end
