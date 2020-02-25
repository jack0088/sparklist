-- 2019 (c) kontakt@herrsch.de


-- NOTE helpful links:
-- https://www.lua.org/pil/22.1.html
-- https://stackoverflow.com/questions/43067106/back-and-forth-utc-dates-in-lua
-- http://lua-users.org/wiki/OsLibraryTutorial
-- http://www.cplusplus.com/reference/ctime/strftime


-- returns (string) abbreviation of your local timezone
-- returns (number) timeoffset of your timezone in seconds
-- Example: a call in Germany would produce: CET, 3600
local function timezone()
    local time_local = os.time()
    local time_utc = os.time(os.date("!*t"))
    local zone = os.date("%Z", time_local)
    local shift = os.difftime(time_local, time_utc)
    return zone, shift
end


-- returns (number) count of seconds since 1. January 1970 in UTC/GMT timezone
-- combined with a negative or positive @offset (number) in seconds, for a past or future timestamp
-- Example to get a timestamp of current time in a day: timestamp(86400), that is eqal to timestamp() + 86400
local function timestamp(offset)
    return os.time(os.date("!*t", os.time() + (offset or 0)))
end


-- returns (string) date
-- Example current *local* date: date(timezone())
-- Example current UTC date: date "UTC"
-- Example current GMT date: date()
-- Example current time's tomorrow GMT date: date(timestamp(86400)) which equals to date(timestamp() + 86400)
-- Example GMT date of timestamp at 5PM in 7 days from now (useful for Set-Cookie Expires Date):
--    local death = os.date("!*t") -- date table in UTC timezone!
--    death.hour = 17 -- adjust time
--    death.min = 0
--    death.sec = 0
--    death = os.time(death) + 60 * 60 * 24 * 7 -- convert date table into seconds and add 7 days
--    print(date(death))
local function date(time_zone, time_shift)
    local timestamp_utc = timestamp()
    if type(time_zone) == "number" and not time_shift then timestamp_utc = time_zone; time_zone = nil end
    return os.date("%a, %d %b %Y %H:%M:%S "..(time_zone or "GMT"), timestamp_utc + (time_shift or 0))
end


return {
    timezone = timezone,
    timestamp = timestamp,
    date = date
}
