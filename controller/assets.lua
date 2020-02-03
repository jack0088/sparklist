return function(client, filename, extension) -- requests to files
    local allowed_extensions = {
        "jpg",
        "jpeg",
        "png",
        "tiff",
        "bmp",
        "gif",
        "svg",
        "eps",
        "pdf",
        "txt"
    }
    if table.concat(allowed_extensions, " "):find(extension) then -- whitelist look-up
        return client.response:submit(client.request.header.url)
        -- return client.response:attach(client.request.header.url) -- force browser to download file
    end
    return client.response:submit(nil, nil, 403)
end
