local class = require "class"
local Header = class()

Header.HTTP_STATUS_MESSAGE = {
    [100] = "Continue",
    [101] = "Switching Protocols",
    [200] = "OK",
    [201] = "Created",
    [202] = "Accepted",
    [203] = "Non-Authoritative Information",
    [204] = "No Content",
    [205] = "Reset Content",
    [206] = "Partial Content",
    [300] = "Multiple Choices",
    [301] = "Moved Permanently",
    [302] = "Found",
    [303] = "See Other",
    [304] = "Not Modified",
    [305] = "Use Proxy",
    [307] = "Temporary Redirect",
    [400] = "Bad Request",
    [401] = "Unauthorized",
    [402] = "Payment Required",
    [403] = "Forbidden",
    [404] = "Not Found",
    [405] = "Method Not Allowed",
    [406] = "Not Acceptable",
    [407] = "Proxy Authentication Required",
    [408] = "Request Time-out",
    [409] = "Conflict",
    [410] = "Gone",
    [411] = "Length Required",
    [412] = "Precondition Failed",
    [413] = "Request Entity Too Large",
    [414] = "Request-URI Too Large",
    [415] = "Unsupported Media Type",
    [416] = "Requested range not satisfiable",
    [417] = "Expectation Failed",
    [500] = "Internal Server Error",
    [501] = "Not Implemented",
    [502] = "Bad Gateway",
    [503] = "Service Unavailable",
    [504] = "Gateway Time-out",
    [505] = "HTTP Version not supported"
}


function Header:new(query)
    self.registry = {}
    self:parse(query)
end


function Header:set(header_name, header_value)
    assert(type(header_name) == "string", "invalid type of header field name")
    assert(type(header_value) == "string" or type(header_value) == "nil", "invalid type of header value")
    
    if header_name == "Set-Cookie" and type(header_value) == "string" then -- we optionally append some security settings to cookies
        local function unpack_attributes(cookie)
            local attributes = {}
            for k, v in string.gmatch(cookie, "([^=; ]+)=([^=;]+)") do
                if not string.find("expires maxage domain path secure httponly samesite", k:lower():gsub("%p", "")) then
                    attributes.name, attributes.value = k, v
                else
                    attributes[k] = v
                end
            end
            return attributes
        end

        local function verify_attributes(cookie)
            -- add security recomendations for cookies, see https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie and https://tools.ietf.org/html/rfc6265#page-7
            assert(cookie.name, cookie.value, "cookie header is missing attributes")
            cookie.name = cookie.name:gsub("[^a-zA-Z%-_]*", "") -- trim control characters, separator character, spaces and tabs
            cookie.httponly = cookie.httponly == false and false or true -- nil defaults to true
            cookie.samesite = cookie.samesite or "Lax"
            return cookie
        end

        local function pack_attributes(cookie)
            local query = string.format("%s=%s", cookie.name, cookie.value)
            if cookie.expires then query = query.."; Expires="..cookie.expires end
            if cookie.maxage then query = query.."; Max-Age="..cookie.maxage end
            if cookie.domain then query = query.."; Domain="..cookie.domain end
            if cookie.path then query = query.."; Path="..cookie.path end
            if cookie.secure then query = query.."; Secure" end
            if cookie.httponly then query = query.."; HttpOnly" end
            if cookie.samesite then query = query.."; SameSite="..cookie.samesite end
            return query
        end

        header_value = pack_attributes(verify_attributes(unpack_attributes(header_value)))
    end

    if type(self[header_name]) == "string" then
        self[header_name] = {self[header_name]}
    end
    if type(self[header_name]) == "table" and type(header_value) == "string" then
        table.insert(self[header_name], header_value)
    else
        self[header_name] = header_value
    end
    self.registry[header_name] = self[header_name]
end


function Header:get(header_name, parse_pattern)
    if type(parse_pattern) == "string" then
        return self.registry[header_name]:match(parse_pattern or ".+")
    end
    if type(parse_pattern) == "function" then
        return parse_pattern(self.registry[header_name])
    end
    return self.registry[header_name]
end


function Header:parse(header_query)
    if type(header_query) == "string" then
        for header_name, header_value in query:gmatch("([%w%p]+): ([%w%p ]+)") do
            self:set(header_name, header_value)
        end
    end
end


function Header:serialize(http_status_code)
    assert(http_status_code, "http header is missing status code")
    local header_query = ""
    for header_name, header_value in pairs(self.registry) do
        header_query = header_query..string.format("%s: %s\r\n", header_name, header_value)
    end
    return string.format(
        "HTTP/1.1 %s %s\r\n%s\r\n",
        http_status_code,
        self.HTTP_STATUS_MESSAGE[http_status_code],
        header_query
    )
end


return Header
