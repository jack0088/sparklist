
-- TODO plugin (session cleaner / expiry tracker)
-- init a database for tracking expired databases or their tables or their entries

-- watch db/client_session.db for new tables that dont yet have expiry date assigned and record them to the scheduler
-- onEnterFrame you check current os.time() and last-time-the-plugin-ran and expiry dates of
-- when some table in some database becomes absolete, then remove it and its tracking facilities

-- TODO open expiry_registry database add this database and table and cookie_lifetime to further tracking
-- local exipry = Expiry():set(self.db.file, self.table, self.cookie_lifetime)
