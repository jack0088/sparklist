-- 2019 (c) kontakt@herrsch.de
--[[

The NAIVE REGEX ROUTER is a xors Plugin

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


EXAMPLE (respond with html layout shorthand; taken care by preload() function, see below)

    Router:any(".*", "views.404") -- response is always status 200

--]]

local unpack = unpack or table.unpack -- Lua > 5.1
local view = require "views"
local class = require "class"
local Router = class()


function Router:new()
    self.map = {}
end


function Router:register(route_method, route_regex, route_handler)
    table.insert(self.map, {
        route = route_method:upper()..route_regex,
        handler = route_handler --coroutine.wrap(route_handler)
    })
end


function Router:onDispatch(request, response)
    -- for more inspiration or improvements see http://nikic.github.io/2014/02/18/Fast-request-routing-using-regular-expressions.html
    for _, entry in ipairs(self.map) do
        if #{string.match(request.method:upper()..request.query, "^"..entry.route.."$")} > 0 then
            -- NOTE in most scenarios `return <value>` or `coroutine.yield(<value>)` must NOT return nil from inside a route handler function as a <value> of nil will always fall through to the next matching route (if any) because the response is void!
            local message = entry.handler(request, response)
            if message ~= nil then break end
        end
    end
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
