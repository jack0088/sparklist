-- 2019 (c) kontakt@herrsch.de

-- SwoopJS is a paswordless single-sign-on service
-- see docs for more information https://swoopnow.com/documentation

-- NOTE the service depends on a tls connection when working with their API
-- NOTE swoop uses DKIM and SPF to verify the identity of the sender it also depends on SNI (server name indication) which is not supported by every ssl-library!
-- plain socket.http.request() will fail and always responds with a status code 301

-- NOTE on some linux distribustion you need to run `sudo apt-get install libssl-dev`
-- to get the header files as well as all default install directories

-- possible dependencies are openssl (or luasec or lua-http, which both bundle openssl); luasec is recomended
-- NOTE when having trouble installing luasec, see https://github.com/luarocks/luarocks/issues/579

-- I decided to keep it simple and use plain HTTP everywhere
-- for security reasons however I'll should hide the xors server behind a reverse SSL proxy like cloudflare


local https = require "ssl.https"

return function(client, token)
    -- client uses swoops fontend plugin that opens a form and sends a login request
    -- swoopjs receives that login request and generates a resonse containing a user identification token
    -- that swoopjs response is forwarded onto an url specified in their admin panel
    -- once swoopjs has requested this route with the token we need to check the credentials
    -- the server (xors) requests the swoopjs API with the token https://app.swoopnow.com/api/inbound_emails/d98fc8d31ceb2bf9208dae120530e2bf
    -- if the user is- or has been logged-in successfully then out respose is a plain/text containing the email of the user and a status code of 200, otherwise status code of 404 and no message

    -- dependencies ---> luasec

    --[[
    print "auth route fired..."

    local cookie = client.request.header:get "cookie: swoopid" -- TODO!!!!
    local identity = token or cookie
    print(identity, token, cookie)

    if identity then
        local email, status = https.request("https://app.swoopnow.com/api/inbound_emails/"..identity) -- TODO add timeout of 1s
        print(string.format("swoopjs responded with token=%s, state=%s, email=%s", identity, status, email))
        if status == 200 and type(email) == "string" and #email > 0 then
            client.response:addHeader("set-cookie", "swoopid="..identity) -- create new or update existing
            return client.response:submit("view/profile.lua", "text/html", 200, email, request.header.url)
        end
    end
    return client.response:submit("no swoopid token found in either cookie or url")
    --]]
end
