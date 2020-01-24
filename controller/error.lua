return function(request, response)
    -- ignore request and respond with error 400
    return response:submit()
end