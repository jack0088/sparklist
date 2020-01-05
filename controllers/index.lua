local view = require "views"

return function(request, response)
    return response:submit(view("landing"), "text/html")
end
