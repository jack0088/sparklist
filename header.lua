local class = require "class"
local Header = class()


Header.URL_QUERY = "([^=]*)=([^&]*)&?"
Header.URL_PARAM = "^([^#?]+)[#|?]?(.*)"
Header.COOKIE_ATTR = "([^=]*)=([^;]*);?%s?"


function Header:new(query)
    if type(query) == "string" then
        for header_name, header_value in query:gmatch("([%w-]+): ([%w %p]+=?)") do
            if not self[header_name] then
                self[header_name] = header_value
            else
                -- NOTE duplicated header-fields may occur in requests or resposes and can be concatenated into a comma separated query resulting in a single combined header, as stated here https://stackoverflow.com/questions/39912920/how-to-interpret-multiple-accept-headers and here https://stackoverflow.com/questions/3096888/standard-for-adding-multiple-values-of-a-single-http-header-to-a-request-or-resp
                self[header_name] = self[header_name]..", "..header_value
            end
        end
    end
end


function Header:parse(header_reference, pattern_recipe)
    -- TODO
    --take header and split it into parts like cookies into a list of single cookie or multiple header-fields into list of single (duplicate) headers
    -- resulting header-values can be :split() further into attributes if any
end


function Header:split(header_value, pattern_recipe)
    -- TODO split a header_value into its single attributes like cookie into value, expires, domain, etc.
end


function Header:serialize()
    -- NOTE just a reminder: servers are allowed to respond with same header-field multiple times like Set-Cookie but clients MUST send only one concaneted header for Cookie
    local query = ""
    for header_name, header_value in pairs(self) do
        if header_name:match("^(_+).+") == nil then -- ignore "private" keys that start with underscore like __parent!
            query = query..string.format("%s: %s\r\n", header_name, header_value)
        end
    end
    return query
end


function Header:add(header_name, header_value)
    if header_name == "Set-Cookie" then -- we optionally append some security settings to cookies
        local function unpack_attributes(cookie)
            local attributes = {}
            for k, v in string.gmatch(cookie, "([^=; ]+)=([^=;]+)") do
                k = k:lower():gsub("%p", "")
                if not string.find("expires maxage domain path secure httponly samesite", k) then
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
            cookie.name = cookie.name:gsub("%p*", "") -- trim punctuation
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
    
    if not self[header_name] then
        self[header_name] = header_value
    else
        self[header_name] = self[header_name]..", "..header_value
    end
end


return Header
