-- namespace plumbing tools to access filesystem at low-level
local mime = require "mimetype"
local filesystem = {shell = shell}


-- @str (string) the string to trim
-- returns (string) with removed whitespaces, tabs and line-break characters from beginning- and ending of the string
-- NOTE also useful to omit additional return values (only keep the first returned value)
local function trim(str)
    if type(str) ~= "string" then str = tostring(str or "") end
    local mask = "[ \t\r\n]*"
    local output = str:gsub("^"..mask, ""):gsub(mask.."$", "")
    return output
end


-- @val (any) the value to wrap in qoutes
-- returns (string) value converted to string and wrapped into quotation marks
local function quote(val)
    return "\""..tostring(val or "").."\""
end


-- @fragments (table) list of values
-- returns (string) concatenated string of all items similar to table.concat
local function toquery(fragments)
    local query = ""
    for _, frag in ipairs(fragments) do
        local f = tostring(frag)
        if (f == "" or f:match("%s+")) and not f:match("^[\"\']+.+[\"\']$") then f = quote(f) end -- but ignore already escaped frags
        if not query:match("=$") then f = " "..f end
        query = query..f
    end
    return trim(query)
end


-- @... (any) first argument should be the utility name fallowed by its list of parameters
-- returns (string or nil, boolean) return value of utility call or nil, and its status
local function cmd(...)
    local tmpfile = "/tmp/shlua"
    local exitcode = "; echo $? >>"..tmpfile
    local command = os.execute(toquery{...}.." >>"..tmpfile..exitcode)
    local console = io.open(tmpfile, "r")
    local report, status = console:read("*a"):match("(.*)(%d+)[\r\n]*$") -- response, exitcode
    report = trim(report)
    status = tonumber(status) == 0
    console:close()
    os.remove(tmpfile)
    return report ~= "" and report or nil, status
end


-- add api like shell[utility](arguments) or shell.utility(arguments)
local shell = setmetatable({cmd = cmd}, {__index = function(_, utility)
    return function(...)
        return cmd(utility, ...)
    end
end})


-- @platform (string) operating system to check against; returns (boolean) true on match
-- platform regex could be: linux*, windows* darwin*, cygwin*, mingw* (everything else might count as unknown)
-- returns (string) operating system identifier or (boolean) on match with @platform
-- NOTE love.system.getOS() is another way of retreving this, if the love2d framework is used in this context
function filesystem.os(platform)
    if platform:lower():find("maco?s?") then platform = "darwin" end
    local plat = shell.uname("-s")
    if type(platform) == "string" then return type(plat:lower():match("^"..platform:lower())) ~= "nil" end
    return plat
end


-- @path (string) relative- or absolute path to a file or folder
-- returns (boolean)
function filesystem.exists(path)
    return select(2, shell.test("-e", path))
end


-- @path (string) relative- or absolute path to a file or folder
-- returns (string) mime-type of the resource (file or folder)
-- NOTE for more predictable web-compilant results use the mime.lua module!
function filesystem.filetype(path)
    if filesystem.exists(path) then return trim(shell.file("--mime-type", "-b", path)) end
    return nil
end


-- @path (string) relative- or absolute path to a file
-- returns (boolean)
function filesystem.isfile(path)
    return filesystem.exists(path) and select(2, shell.test("-f", path))
end


-- @path (string) relative- or absolute path to a folder
-- returns (boolean)
function filesystem.isfolder(path)
    return filesystem.exists(path) and select(2, shell.test("-d", path))
end


-- returns (string) of the current location you are at
function filesystem.currentfolder()
    return trim(shell.echo("$(pwd)"))
end


-- @path (string) relative- or absolute path to the (sub-)folder
-- @filter (string) filename to check against; or regex expression mask, see https://www.cyberciti.biz/faq/grep-regular-expressions
-- returns (boolen or table) nil if @path leads to a file instead of a folder;
-- true on a match with @filter + an array of files that match the @filter criteria;
-- otherwise an array of files inside that folder
function filesystem.infolder(path, filter)
    if not filesystem.isfolder(path) then return nil end
    local content, status = shell.cmd("ls", path, "|", "grep", filter or "")
    local list = {}
    for resource in content:gmatch("[^\r\n]*") do
        if resource ~= "" then table.insert(list, resource) end
    end
    if filter then return content ~= "", list end
    return list
end


-- @path (string) relative- or absolute path to the file or (sub-)folder
-- returns (string) epoch/ unix date timestamp
function filesystem.createdat(path)
    return trim(shell.stat("-f", "%B", path)) -- TODO needs testing on Linux and Windows
end


-- @path (string) relative- or absolute path to the file or (sub-)folder
-- returns (string) epoch/ unix date timestamp
function filesystem.modifiedat(path)
    return trim(shell.date("-r", path, "+%s")) -- TODO needs testing on Linux and Windows
end


-- @path (string) relative- or absolute path to the file
-- returns (string) SHA1 checksum of file contents
function filesystem.checksum(path)
    if filesystem.isfile(path) then
        if filesystem.os("darwin") then -- MacOS
            return shell.cmd("shasum", "-a", 1, path, "|", "awk", "'{print $1}'")
        elseif filesystem.os("linux") then -- Linux
            return shell.cmd("sha1sum", path, "|", "awk", "'{print $1}'")
        elseif filesystem.os("windows") then -- Windows
            return shell.cmd("CertUtil", "-hashfile", path, "SHA1") -- TODO needs testing
        end
    end
    return nil
end


-- @path (string) relative- or absolute path to the new, empty file
-- does not override existing file but updates its timestamp
-- returns (boolean) true on success
function filesystem.makefile(path)
    if filesystem.isfolder(path) then return false end
    return select(2, shell.touch(path))
end


-- @path (string) relative- or absolute path to the file
-- returns (table) that contains information about the file, e.g. path, directory, filename, file extension, raw content, etc
function filesystem.readfile(path)
    local file_pointer
    if type(path) == "string" then
        if not filesystem.isfile(path) then return nil end
        file_pointer = io.open(path, "rb")
    else
        file_pointer = path -- path is already a file handle
    end
    if not file_pointer then return nil end
    local content = file_pointer:read("*a")
    file_pointer:close()
    return content
end


function filesystem.writefile(path, data)
    -- TODO? check permissions before write?
    local file_pointer
    if type(path) == "string" then
        if filesystem.isfolder(path) then return false end
        if not filesystem.exists(path) then filesystem.makefile(path) end
        file_pointer = io.open(path, "wb")
    else
        file_pointer = path -- path is already a file handle
    end
    if not file_pointer then return false end
    file_pointer:write(data)
    file_pointer:close()
    return true
end


-- @path (string) relative- or absolute path to the new (sub-)folder
-- folder name must not contain special characters, except: spaces, plus- & minus signs and underscores
-- does nothing to existing (sub-)folder or its contents
-- returns (boolean) true on success
function filesystem.makefolder(path)
    if filesystem.isfile(path) then return false end
    return select(2, shell.mkdir("-p", path))
end


-- @path (string) relative- or absolute path to the file
-- skips non-existing file as well
-- returns (boolean) true on success
function filesystem.deletefile(path)
    if filesystem.isfolder(path) then return false end
    return select(2, shell.rm("-f", path))
end


-- @path (string) relative- or absolute path to the (sub-)folder
-- deletes recursevly any sub-folder and its contents
-- skips non-existing folder
-- returns (boolean) true on success
function filesystem.deletefolder(path)
    if filesystem.isfile(path) then return false end
    return select(2, shell.rm("-rf", path))
end


-- @path (string) relative- or absolute path to the file or (sub-)folder you want to copy
-- @location (string) is the new place of the copied resource, NOTE that this string can also contain a new name for the copied resource!
-- includes nested files and folders
-- returns (boolean) true on success
function filesystem.copy(path, location)
    if not filesystem.exists(path) then return false end
    return select(2, shell.cp("-a", path, location))
end


-- @path (string) relative- or absolute path to the file or (sub-)folder you want to move to another location
-- @location (string) is the new place of the moved rosource, NOTE that this string can also contain a new name for the copied resource!
-- includes nested files and folders
-- returns (boolean) true on success
function filesystem.move(path, location)
    if not filesystem.exists(path) then return false end
    return select(2, shell.mv(path, location))
end


-- @path (string) relative- or absolute path to folder or file
-- @rights (string or number) permission level, see http://permissions-calculator.org
-- fs.permissions(path) returns (string) an encoded 4 octal digit representing the permission level
-- fs.permissions(path, right) recursevly sets permission level and returns (boolean) true for successful assignment
function filesystem.permissions(path, right)
    local fmt = "%03d"
    if type(path) ~= "string" or not filesystem.exists(path) then return nil end
    if type(right) == "number" then
        -- NOTE seems you can not go below chmod 411 on MacOS
        -- as the operating system resets it automatically to the next higher permission level
        -- because the User (who created the file) at least holds a read access
        -- thus trying to set rights to e.g. 044 would result in 644
        -- which means User group automatically gets full rights (7 bits instead of 0)
        return select(2, shell.chmod("-R", string.format(fmt, right), path))
    end
    if filesystem.os("darwin") then -- MacOS
        return string.format(fmt, shell.cmd("stat", "-r", path, "|", "awk", "'{print $3}'", "|", "tail", "-c", "4"))
    elseif filesystem.os("linux") then -- Linux
        return shell.stat("-c", "'%a'", path) -- TODO needs testing
    elseif filesystem.os("windows") then -- Windows
        -- TODO
    end
    return nil
end


-- @path (string) relative- or absolute path to a file or folder
-- returns directory path, filename, file extension and mime-type guessed by the file extension
-- NOTE .filetype is the operating system mime-type of the resource (file or folder),
-- while .mimetype is a web-compilant mime-type of the file judged by its file extension
function filesystem.fileinfo(path)
    local meta = {}
    meta.url = path
    meta.mimetype, meta.path, meta.name, meta.extension = mime.guess(meta.url)
    meta.filetype = filesystem.filetype(meta.url)
    meta.exists = filesystem.exists(meta.url)
    meta.isfile = filesystem.isfile(meta.url)
    meta.isfolder = filesystem.isfolder(meta.url)
    meta.created = filesystem.createdat(meta.url)
    meta.modified = filesystem.modifiedat(meta.url)
    meta.checksum = filesystem.checksum(meta.url)
    meta.permissions = filesystem.permissions(meta.url)
    return meta
end


-- returns (string) current content of the system clipboard
function filesystem.readclipboard()
    if filesystem.os("darwin") then -- MacOS
        -- TODO? can we pass around other types like files? do we need to encode/decode these string queries somehow?
        return shell.pbpaste() --trim(sh.echo("`pbpaste`"))
    elseif filesystem.os("linux") then -- Linux
        -- TODO use xclip util
    end
    return nil
end


-- @data (string) the content to insert into the clipboard
-- returns (boolean) true on success
function filesystem.writeclipboard(query)
    if filesystem.os("darwin") then -- MacOS
        return shell.cmd("echo", query, "|", "pbcopy")
    elseif filesystem.os("linux") then -- Linux
        -- TODO use xclip
    end
    return false
end


function filesystem.sysinfo()
    -- TODO implement system load information
    -- possibly with shell.cmd("top", "-F", "-R", "-o", "cpu") from http://osxdaily.com/2009/10/06/monitoring-cpu-usage-on-your-mac-a-better-top-command
    -- or something like ps -A -o %cpu | awk '{s+=$1} END {print s "%"}' taken from https://stackoverflow.com/questions/30855440/how-to-get-cpu-utilization-in-in-terminal-mac should also work
    return {
        os = filesystem.os(),
        workload = "...%"
    }
end


return filesystem
