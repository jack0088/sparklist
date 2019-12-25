-- namespace unix plumbing utilities to access (file)system tools at low-level
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
    if platform and platform:lower():find("maco?s?") then platform = "darwin" end
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
    if filesystem.exists(path) then
        return trim(shell.file("--mime-type", "-b", path))
    end
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
    -- TODO? include folders as well but append / to signal that its a folder?
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
-- returns (string) birthtime of file as epoch/unix date timestamp
function filesystem.createdat(path)
    if filesystem.os("darwin") then -- MacOS
        return trim(shell.stat("-f", "%B", path))
    elseif filesystem.os("linux") then -- Linux
        -- NOTE most Linux filesystems do not support this property and return 0 or -
        -- see https://unix.stackexchange.com/questions/91197/how-to-find-creation-date-of-file
        return trim(shell.stat("-c", "%W", path))
    end
end


-- @path (string) relative- or absolute path to the file or (sub-)folder
-- returns (string) epoch/ unix date timestamp
function filesystem.modifiedat(path)
    -- NOTE a machine should first of all have the right timezone set in preferences, for Linux see https://askubuntu.com/questions/3375/how-to-change-time-zone-settings-from-the-command-line
    -- Linux does always store modification time as UTC and converts these timestamps aleways back into the local timezone of your machine. However, if a device stores time as CET then Linux would assume that timestamp to be UTC and therefor (mistakenly) convert it back into the machines local timezone, see discussion https://unix.stackexchange.com/questions/440765/linux-showing-incorrect-file-modified-time-for-camera-video
    -- In any case, you get different results for MacOS vs Linux!
    return trim(shell.date("-r", path, "+%s"))
end


-- @path (string) relative- or absolute path to the file
-- returns (string) SHA1 checksum of file contents
function filesystem.checksum(path)
    if filesystem.isfile(path) then
        if filesystem.os("darwin") then -- MacOS
            return trim(shell.cmd("shasum", "-a", 1, path, "|", "awk", "'{print $1}'"))
        elseif filesystem.os("linux") then -- Linux
            return trim(shell.cmd("sha1sum", path, "|", "awk", "'{print $1}'"))
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
-- skips non-existing file as well
-- returns (boolean) true on success
function filesystem.deletefile(path)
    if filesystem.isfolder(path) then return false end
    return select(2, shell.rm("-f", path))
end


-- @path (string) relative- or absolute path to the file
-- returns (string) raw content of a file; or nil on failure
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


-- @path (string) relative- or absolute path to the file
-- returns (boolean) true on success, false on fail
function filesystem.writefile(path, data)
    local file_pointer
    if type(path) == "string" then
        if filesystem.isfolder(path) then return false end
        if not filesystem.exists(path) then filesystem.makefile(path) end
        file_pointer = io.open(path, "wb")
    else
        file_pointer = path -- path is already a file handle
    end
    if not file_pointer then return false end
    -- TODO? check permissions before write?
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
        return shell.stat("-c", "'%a'", path)
    end
    return nil
end


-- @path (string) relative- or absolute path to a file or folder
-- returns directory path, filename, file extension and mime-type guessed by the file extension
-- NOTE .filetype is the operating system mime-type of the resource (file or folder),
-- while .mimetype is a web-compilant mime-type of the file judged by its file extension
function filesystem.fileinfo(path)
    local t = {}
    t.url = path
    t.mimetype, t.path, t.name, t.extension = mime.guess(t.url)
    t.filetype = filesystem.filetype(t.url)
    t.exists = filesystem.exists(t.url)
    t.isfile = filesystem.isfile(t.url)
    t.isfolder = filesystem.isfolder(t.url)
    t.created = filesystem.createdat(t.url)
    t.modified = filesystem.modifiedat(t.url)
    t.checksum = filesystem.checksum(t.url)
    t.permissions = filesystem.permissions(t.url)
    return t
end


-- returns (string) current content of the system clipboard
function filesystem.readclipboard()
    if filesystem.os("darwin") then -- MacOS
        -- NOTE we could pass around specific formats
        -- and by encode/decode these queries we could copy/paste application specific data
        -- just like Adobe can transfer Photos from InDesign to Photoshop and back (or even settings)
        return shell.pbpaste() --trim(sh.echo("`pbpaste`"))
    elseif filesystem.os("linux") then-- TODO? Linux support via xclip
        -- NOTE this makes no sense on a machine without a display, like is a webserver
        -- see https://unix.stackexchange.com/questions/211817/copy-the-contents-of-a-file-into-the-clipboard-without-displaying-its-contents
    end
    return nil
end


-- @data (string) the content to insert into the clipboard
-- returns (boolean) true on success
function filesystem.writeclipboard(query)
    if filesystem.os("darwin") then -- MacOS
        return select(2, shell.cmd("echo", query, "|", "pbcopy"))
    end
    -- see NOTE above about Linux support
    return false
end


-- @hyperthreading (optional boolean) to check against maximal resources instead of physically available once
-- returns (number) of cores this machine has (optionally counting the maximal utilization potential (@hyperthreading = true))
function filesystem.cores(hyperthreading)
    if filesystem.os("darwin") then -- MacOS
        local pntr = hyperthreading and "hw.logicalcpu" or "hw.physicalcpu"
        return trim(shell.sysctl(pntr, "|", "awk", "'{print $2}'"))
    elseif filesystem.os("linux") then -- Linux
        return trim(shell.nproc())
    end
end


-- returns (number) representing cpu workload in % percent
-- NOTE the workload could be grater than 100% if to much workload or not enough cores to handle it
function filesystem.cpu()
    if filesystem.os("darwin") or filesystem.os("linux") then -- MacOS or Linux
        -- NOTE @avgcpu can be grater than 100% if machine has multiple cores, e.g. up to 600% at 6 cores
        -- it could also be larger than that, because of @hyperthreading (physical vs logical number of cores)
        local avgcpu = trim(shell.ps("-A", "-o", "%cpu", "|", "awk", "'{s+=$1} END {print s}'")):gsub(",", ".") --%
        local ncores = filesystem.cores()
        local used = avgcpu * 100 / (ncores * 100) --%
        local free = 100 - used --%
        return used, free
    end
end


-- returns (number) available ram space in kB
function filesystem.ram()
    if filesystem.os("darwin") then -- MacOS
        return trim(shell.sysctl("hw.memsize"))
    elseif filesystem.os("linux") then -- Linux
        return trim(shell.cat("/proc/meminfo", "|", "grep", "-i", "MemTotal", "|", "awk", "'{print $2}'"))
    end
end


function filesystem.mem()
    if filesystem.os("darwin") or filesystem.os("linux") then -- MacOS or Linux
        local avgmem = trim(shell.ps("-A", "-o", "%mem", "|", "awk", "'{s+=$1} END {print s}'")):gsub(",", ".") --%
        local rsize = filesystem.ram() --kB
        local rfree = avgmem * rsize / 100 --kB
        local rused = rsize - rfree --kB
        local used = 100 - rused * 100 / rsize --%
        local free = 100 - used --%
        return used, free
    end
end


-- returns (table) various information about the machine
function filesystem.sysinfo()
    local t = {cpu = {}, mem = {}}
    t.os = filesystem.os()
    t.cores = filesystem.cores()
    t.cpu.used, t.cpu.free = filesystem.cpu() -- in percent
    t.ram = filesystem.ram() -- in kilobytes
    t.mem.used, t.mem.free = filesystem.mem() -- in percent
    return t
end


-- TODO rewrite so that filesystem.os is only checked once
-- e.g. middleman function can then map filesystem.cpu to filesystem.darwin.cpu or filesystem.linix.cpu


return filesystem
