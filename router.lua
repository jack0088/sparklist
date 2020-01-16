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

    local view = require "view"
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
        response:submit(view("view.404", request.url), "text/html", 404)
    end)


EXAMPLE (respond with html layout shorthand; taken care by preload() function, see below)

    Router:any(".*", "view.404") -- response is always status 200

--]]

local unpack = unpack or table.unpack -- Lua > 5.1
local aquire = require "hotswap"
local class = require "class"
local Router = class()


function Router:new()
    self.map = {}
end


-- @route_method is the HTTP method (GET, POST,...)
-- @route_regex is the regex based url to check the request against
-- @route_handler can actually be a function or a string!
-- in case of function it IS the route handler function for the request/response
-- in case of string it is supposed to be a file name
-- (path separated by / and with .extension OR separated by . in require paths)
-- if that file could be found and returns a function then its supposed to be the @route_handler
-- if no handler function was found through that file path then a proxy @route_handler is created that responds directly with the file path (or view 404 if that leads to nowhere)

function Router:register(route_method, route_regex, route_handler)
    table.insert(self.map, {
        route = route_method:upper()..route_regex,
        controller = route_handler
    })
end


function Router:onDispatch(request, response)
    -- for more inspiration or improvements see http://nikic.github.io/2014/02/18/Fast-request-routing-using-regular-expressions.html
    for _, entry in ipairs(self.map) do
        local captures = {string.match(request.method:upper()..request.path, "^"..entry.route.."$")}
        if #captures > 0 then
            print(string.format(
                "%s client dispatched to route '%s'",
                os.date("%d.%m.%Y %H:%M:%S"),
                entry.route
            ))
            if type(request.route_controller) ~= "thread" then
                request.route_controller = coroutine.create(entry.controller)
            end
            if coroutine.status(request.route_controller) ~= "dead" then
                -- NOTE in most scenarios `return <value>` or `coroutine.yield(<value>)` must NOT return nil from inside a route handler function as a <value> of nil will always fall through to the next matching route (if any) because the response is void!
                if captures[1] == entry.route then
                    table.remove(captures, 1)
                end
                local status, message = assert(coroutine.resume(
                    request.route_controller,
                    request,
                    response,
                    unpack(captures)
                ))
                if status and message ~= nil then break end
            end
        end
    end
end


local function preload(handler)
    assert(type(handler) == "function" or type(handler) == "string")
    if type(handler) == "function" then
        return handler
    end
    local file_name, file_extension = handler:match("(.+)(%.%w%w[%w%p]*)$")
    if not file_extension or file_extension == ".lua" then
        local controller = aquire(file_name:gsub("/", "."))
        return function(...)
            -- NOTE this wrapping function is needed for coroutine.create
            -- couroutine needs a function parameter but controller is a hot-swappable object of type table
            return controller(...)
        end
    end
    return function(request, response)
        return response:submit(handler)
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
