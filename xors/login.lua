-- 2020 (c) kontakt@herrsch.de


local hotload = require "hotload"
local class = hotload "class"
local Identity = hotload "identity"
local Session = hotload "session"


-- TODO move this code maybe into identity.lua or something to have all login|swoop related code in one module
-- possibly make this module then a plugin?


return function(client, token) -- route handler
    if type(token) == "string" then
        local user = Identity(Session(token))
        if not user.continued then
            user:destroy(user.uuid) -- NOTE potentially dangerous operation because destroyed session could have been in use!
        end
        if user.authenticated then
            client.session:set("user_authentication_token", token)
            return client.response:redirect(client.session:get "previous_path_request")
        end
    end
    return client.response:submit("view/unauthorized.lua", "text/html", 200, client.request.url)
end
