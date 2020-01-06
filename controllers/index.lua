local view = require "views"

return function(request, response)
    return response:submit(view("index"), "text/html")
end
