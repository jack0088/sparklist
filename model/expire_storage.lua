local expirations = Storage "expirations"

function Session:create()
    if type(self.table) == "string" then
        Storage.create(self)
        expirations:set(os.time() + self.cookie_lifetime, )
        -- TODO use Storage module to drive another (xors) table
        -- that will be used to hold expiration dates
        -- for other tables that have limited lifetime
    end
end
