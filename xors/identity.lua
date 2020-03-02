-- 2020 (c) kontakt@herrsch.de


-- Swoop, a paswordless single-sign-on service, see https://swoopnow.com/documentation

-- NOTE Swoop depends on a secure TLS connection
-- it uses DKIM and SPF to verify the identity of the sender
-- it also depends on SNI (server name indication), which is not supported by every SSL library!!!
-- a plain socket.http.request() will fail and will always responds with a status code 301
-- considering the above, possible dependencies are openssl (or luasec or lua-http, which both bundle openssl) - luasec is the most recomended!!!

-- NOTE on troubles installing luasec, see https://github.com/luarocks/luarocks/issues/579
-- some linux distribustion need to run `sudo apt-get install libssl-dev`, to get all the header files and all the installation directories of openssl


local https = require "ssl.https"
local hotload = require "hotload"
local class = hotload "class"
local User = hotload "user"
local Identity = class(User)


function Identity:new(session)
    User.new(self, session.uuid)
    self.session = session
end


function Identity:get_session()
    return self.__session
end


function Identity:set_session(delegate)
    self.__session = delegate
    self.set_authenticated()
end


function Identity:get_authenticated()
    return self.__authenticated == true
end


function Identity:set_authenticated() -- ignore flag because we evaluate and set this flag in realtime
    local token = self.session:get "user_authentication_token"
    if token then
        local email, status = https.request("https://app.swoopnow.com/api/inbound_emails/"..token) -- TODO add timeout
        if status == 200
        and User.validEmail(email)
        and select(2, User.exists(self, email)) == self.session.uuid
        then
            self.__authenticated = true
        end
    end
    self.__authenticated = nil
end


function Identity:validLogin()
    return self.authenticated == true
end


return Identity
