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

local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local unpack = unpack or table.unpack -- Lua > 5.1
local hotload = require "hotload"
local class = hotload "class"
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
-- if no handler function was found through that file path then a proxy @route_handler is created that responds directly with the file path (or view 400 if that leads to nowhere)

function Router:register(route_method, route_regex, route_handler)
    table.insert(self.map, {
        route = route_method:upper()..route_regex,
        controller = route_handler
    })
end


function Router:onDispatch(server, client)
    local request = client.request
    local response = client.response
    local route = request.header.method:upper()..request.header.url
    for _, entry in ipairs(self.map) do
        -- for more inspiration or improvements see http://nikic.github.io/2014/02/18/Fast-request-routing-using-regular-expressions.html
        local captures = {route:match("^"..entry.route.."$")}
        if getn(captures) > 0 then
            if type(request.route_controller) ~= "thread" then
                request.route_controller = coroutine.create(entry.controller)
            end
            if coroutine.status(request.route_controller) ~= "dead" then
                -- NOTE in most scenarios `return <value>` or `coroutine.yield(<value>)` must NOT return nil from inside that route handler function as a <value> of nil will always fall through to the next matching route (if any) because the response is void!
                if captures[1] == entry.route then
                    table.remove(captures, 1)
                end
                local status, message = assert(coroutine.resume(
                    request.route_controller,
                    client,
                    unpack(captures)
                ))
                print(string.format("client dispatched to route '%s'", entry.route))
                if status and message ~= nil then break end
                request.route_controller = nil -- free for next mathing route handler!
                print(string.format("route handler of '%s' is void and falls-through to the next mathing route...", entry.route))
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
        local controller = hotload(file_name:gsub("/", "."))
        return function(...)
            -- NOTE the wrapping function is needed for coroutine.create inside .onDispatch above
            -- couroutine needs a function parameter but controller is a hot-swappable object of type table
            return controller(...)
        end
    end
    return function(client)
        return client.response:submit(handler)
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
