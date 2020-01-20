return function(request, response)
    -- ignore request and respond with error 404
    return response:submit()
end