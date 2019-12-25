--[[

The NAIVE REGEX ROUTER is a XORS Plugin

- Match concrete literal route strings or match routes by regex expressions.
- On any request the router will try to map a given route (inluding the http method)
  to a user defined handler function. The finder will process your definitions top to bottom,
  in the order you defined them.
- Define your routes in decending order of importance, meaning,
  specific ones come first and more generic ones last.
- Any route should return true on successful handling and false on failing.
  Any route that returns nil (void) will fall-through to next possible match.
- To use a wildcard, wrap the expression into parentheses, e.g. (%w+)
  They are passed as parameters to your handler function (right after request and response)
  and you can name them however you like, as shown below.

2019 (c) kontakt@herrsch.de


EXAMPLE (define routes with custom handlers)

    local view = require "views"
    local Router = require("router")()

    Router:get(".+%/([%w%p]+)%.(%a%a%a+)$", function(request, response, filename, extension) -- requests to files!
        response:submit("."..request.url) -- prefix with current (root) directory
    end)

    Router:get("/(%w+)/(.+)", function(request, response, forum, topic) -- another random route
        response:submit(string.format("ur at '%s' forum, checking out topic '%s'", forum, topic))
    end)

    Router:any(".*", function(request, response, path)  -- general security filter!
        --response:submit(nil, nil, 404) -- default error response
        response:submit("no response on "..path, nil, 404)
    end)


EXAMPLE (respond with html layout after custom handling the route)

    Router:any(".*", function(request, response, path)
        --do whatever here
        response:submit(view("views.404", request.url), "text/html", 404)
    end)


EXAMPLE (respond with html layout shorthand)

    Router:any(".*", "views.404") -- response is always status 200

--]]

local unpack = unpack or table.unpack -- Lua > 5.1
local class = require "class"
local view = require "views"
local Router = class()


function Router:new()
    self.map = {}
    return self
end


function Router:onDispatch(request, response) -- Plugin hook method
    for _, entry in ipairs(self.map) do
        local parameters = {string.match(request.method:upper()..request.query, "^"..entry.route.."$")}
        if #parameters > 0 then
            local result = entry.handler(request, response, unpack(parameters))
            if result ~= nil then return result end -- nil falls through to the next route check because such match/response is void
        end
    end
    return false
end


function Router:register(route_method, route_regex, route_handler)
    table.insert(self.map, {route = route_method:upper()..route_regex, handler = route_handler})
end


local function preload(template)
    if type(template) == "function" then
        return template
    end
    return function(request, response, ...)
        response:submit(view(template, ...), "text/html", 200)
    end
end


for _, method in ipairs{"GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "CONNECT", "OPTIONS"} do
    Router[method:lower()] = function(dispatcher, route, handler)
        dispatcher:register(method:upper(), route, preload(handler))
    end
end


Router.any = function(dispatcher, route, handler)
    dispatcher:register("[A-Z]+", route, preload(handler))
end


return Router
