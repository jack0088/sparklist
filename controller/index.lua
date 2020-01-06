return function(request, response)
    return response:submit("view/index.lua", "text/html")
end
