-- scripts/ContactEvents.lua
-- Network events for contacts: RI_ContactEvent, RI_ContactSyncEvent.

-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: Contact — client sends add/update/delete to host for persistence
-- ─────────────────────────────────────────────────────────────────────────────

if RI_ContactEvent == nil then
    RI_ContactEvent    = {}
    RI_ContactEvent_mt = Class(RI_ContactEvent, Event)
    InitEventClass(RI_ContactEvent, "RI_ContactEvent")
end

function RI_ContactEvent.emptyNew()
    return Event.new(RI_ContactEvent_mt)
end

function RI_ContactEvent.new(action, playerUserId, contactUid, contactData)
    local self = RI_ContactEvent.emptyNew()
    self.action       = action
    self.playerUserId = playerUserId
    self.contactUid   = contactUid   -- stable uid string, not a fragile array index
    self.contactData  = contactData
    return self
end

function RI_ContactEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.action       or "")
    streamWriteInt32(streamId,  self.playerUserId or 0)
    streamWriteString(streamId, self.contactUid   or "")
    local d = self.contactData or {}
    streamWriteString(streamId, d.uid          or "")
    streamWriteString(streamId, d.name         or "")
    streamWriteString(streamId, d.farmName     or "")
    streamWriteString(streamId, d.phone        or "")
    streamWriteString(streamId, d.role         or "")
    streamWriteString(streamId, d.notes        or "")
    streamWriteInt32(streamId,  d.playerUserId or 0)
end

function RI_ContactEvent:readStream(streamId, connection)
    self.action       = streamReadString(streamId)
    self.playerUserId = streamReadInt32(streamId)
    self.contactUid   = streamReadString(streamId)
    self.contactData  = {
        uid          = streamReadString(streamId),
        name         = streamReadString(streamId),
        farmName     = streamReadString(streamId),
        phone        = streamReadString(streamId),
        role         = streamReadString(streamId),
        notes        = streamReadString(streamId),
        playerUserId = streamReadInt32(streamId),
    }
    self:run(connection)
end

function RI_ContactEvent:run(connection)
    if g_server == nil then return end

    local userId     = self.playerUserId
    local info       = RoleplayPhone.onlineUsers[userId]
    local uniqueId   = info and info.uniqueId or ""
    local storageKey = uniqueId ~= "" and uniqueId or tostring(userId)
    if not ContactManager.userContacts[storageKey] then
        ContactManager.userContacts[storageKey] = {}
    end
    local list = ContactManager.userContacts[storageKey]

    if self.action == "add" then
        table.insert(list, {
            uid          = self.contactData.uid ~= "" and self.contactData.uid or ContactManager:generateUid(),
            name         = self.contactData.name         or "",
            farmName     = self.contactData.farmName     or "",
            phone        = self.contactData.phone        or "",
            role         = self.contactData.role         or "",
            notes        = self.contactData.notes        or "",
            playerUserId = self.contactData.playerUserId or 0,
        })
        print(string.format("[ContactEvents] Contact added for userId %d: %s",
            userId, self.contactData.name or "?"))
    elseif self.action == "update" then
        -- Find by stable uid — immune to index drift from concurrent operations
        for _, c in ipairs(list) do
            if c.uid == self.contactUid then
                c.name  = self.contactData.name  ~= "" and self.contactData.name  or c.name
                c.phone = self.contactData.phone ~= "" and self.contactData.phone or c.phone
                c.role  = self.contactData.role  ~= "" and self.contactData.role  or c.role
                c.notes = self.contactData.notes ~= "" and self.contactData.notes or c.notes
                print(string.format("[ContactEvents] Contact uid=%s updated for userId %d", self.contactUid, userId))
                break
            end
        end
    elseif self.action == "delete" then
        -- Find by stable uid — index-based delete was the MP race condition
        for i, c in ipairs(list) do
            if c.uid == self.contactUid then
                table.remove(list, i)
                print(string.format("[ContactEvents] Contact uid=%s deleted for userId %d", self.contactUid, userId))
                break
            end
        end
    end

    if uniqueId ~= "" then
        local entry    = RoleplayPhone:getOrCreateRegistryEntry(uniqueId, info and info.phone or "", info and info.name or "")
        local filename = RoleplayPhone:buildPlayerFilename(info and info.name or "unknown", entry.fileId)
        local msgs     = RoleplayPhone.playerMessages and RoleplayPhone.playerMessages[uniqueId] or {}
        local calls    = RoleplayPhone.playerCalls    and RoleplayPhone.playerCalls[uniqueId]    or {}
        RoleplayPhone:savePlayerData(filename, list, msgs, calls)
    end
end


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: ContactSync — host sends full contact list to a connecting client
-- ─────────────────────────────────────────────────────────────────────────────

if RI_ContactSyncEvent == nil then
    RI_ContactSyncEvent    = {}
    RI_ContactSyncEvent_mt = Class(RI_ContactSyncEvent, Event)
    InitEventClass(RI_ContactSyncEvent, "RI_ContactSyncEvent")
end

function RI_ContactSyncEvent.emptyNew()
    return Event.new(RI_ContactSyncEvent_mt)
end

function RI_ContactSyncEvent.new(contacts)
    local self = RI_ContactSyncEvent.emptyNew()
    self.contacts = contacts or {}
    return self
end

function RI_ContactSyncEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, #self.contacts)
    for _, c in ipairs(self.contacts) do
        streamWriteString(streamId, c.uid          or "")
        streamWriteString(streamId, c.name         or "")
        streamWriteString(streamId, c.farmName     or "")
        streamWriteString(streamId, c.phone        or "")
        streamWriteString(streamId, c.role         or "")
        streamWriteString(streamId, c.notes        or "")
        streamWriteInt32(streamId,  c.playerUserId or 0)
    end
end

function RI_ContactSyncEvent:readStream(streamId, connection)
    local count = streamReadInt32(streamId)
    self.contacts = {}
    for i = 1, count do
        local uid = streamReadString(streamId)
        if uid == "" then uid = ContactManager:generateUid() end
        table.insert(self.contacts, {
            uid          = uid,
            name         = streamReadString(streamId),
            farmName     = streamReadString(streamId),
            phone        = streamReadString(streamId),
            role         = streamReadString(streamId),
            notes        = streamReadString(streamId),
            playerUserId = streamReadInt32(streamId),
        })
    end
    self:run(connection)
end

function RI_ContactSyncEvent:run(connection)
    if g_server ~= nil then return end
    ContactManager.contacts = self.contacts
    print(string.format("[ContactEvents] ContactSync: loaded %d contacts from host",
        #self.contacts))
end
