-- scripts/ContactManager.lua
-- Manages the player contact list (name, farm, phone, notes, playerUserId)
-- Save/load mirrors InvoiceSave XML pattern

ContactManager = {}
ContactManager.contacts       = {}   -- ordered array of contact tables (current player)
ContactManager.userContacts   = {}   -- [playerUserId] = contacts array (host-side, all players)


-- ─── CRUD ─────────────────────────────────────────────────────────────────────

function ContactManager:addContact(data)
    table.insert(self.contacts, {
        name         = data.name         or "",
        farmName     = data.farmName     or "",
        phone        = data.phone        or "",
        notes        = data.notes        or "",
        playerUserId = data.playerUserId or 0,
    })
end

function ContactManager:removeContact(index)
    table.remove(self.contacts, index)
end

function ContactManager:getContact(index)
    return self.contacts[index]
end

function ContactManager:count()
    return #self.contacts
end


-- ─── XML SAVE ─────────────────────────────────────────────────────────────────

function ContactManager:saveToXML(xmlFile, key)
    -- Save own contacts (host's local list)
    for i, c in ipairs(self.contacts) do
        local cKey = string.format("%s.contact(%d)", key, i - 1)
        setXMLString(xmlFile, cKey .. "#name",         c.name         or "")
        setXMLString(xmlFile, cKey .. "#farmName",     c.farmName     or "")
        setXMLString(xmlFile, cKey .. "#phone",        c.phone        or "")
        setXMLString(xmlFile, cKey .. "#notes",        c.notes        or "")
        setXMLInt(xmlFile,    cKey .. "#playerUserId", c.playerUserId or 0)
    end

    -- Per-user contacts: keyed by uniqueId for stability across sessions
    local userList = {}
    for uniqueId, contacts in pairs(self.userContacts) do
        table.insert(userList, { uniqueId = tostring(uniqueId), contacts = contacts })
    end
    table.sort(userList, function(a, b) return a.uniqueId < b.uniqueId end)

    setXMLInt(xmlFile, key .. "#userCount", #userList)
    for ui, entry in ipairs(userList) do
        local userKey = string.format("%s.users(%d)", key, ui - 1)
        setXMLString(xmlFile, userKey .. "#uniqueId", entry.uniqueId)
        for i, c in ipairs(entry.contacts) do
            local cKey = string.format("%s.contact(%d)", userKey, i - 1)
            setXMLString(xmlFile, cKey .. "#name",         c.name         or "")
            setXMLString(xmlFile, cKey .. "#farmName",     c.farmName     or "")
            setXMLString(xmlFile, cKey .. "#phone",        c.phone        or "")
            setXMLString(xmlFile, cKey .. "#notes",        c.notes        or "")
            setXMLInt(xmlFile,    cKey .. "#playerUserId", c.playerUserId or 0)
        end
    end
end


-- ─── XML LOAD ─────────────────────────────────────────────────────────────────

function ContactManager:loadFromXML(xmlFile, key)
    self.contacts     = {}
    self.userContacts = {}

    -- Load own contacts
    local i = 0
    while true do
        local cKey = string.format("%s.contact(%d)", key, i)
        local name = getXMLString(xmlFile, cKey .. "#name")
        if name == nil then break end
        table.insert(self.contacts, {
            name         = name,
            farmName     = getXMLString(xmlFile, cKey .. "#farmName")     or "",
            phone        = getXMLString(xmlFile, cKey .. "#phone")        or "",
            notes        = getXMLString(xmlFile, cKey .. "#notes")        or "",
            playerUserId = getXMLInt(xmlFile,    cKey .. "#playerUserId") or 0,
        })
        i = i + 1
    end

    -- Load per-user contacts (keyed by uniqueId)
    local userCount = getXMLInt(xmlFile, key .. "#userCount") or 0
    for ui = 0, userCount - 1 do
        local userKey  = string.format("%s.users(%d)", key, ui)
        local uniqueId = getXMLString(xmlFile, userKey .. "#uniqueId")
        if uniqueId then
            local contacts = {}
            local j = 0
            while true do
                local cKey = string.format("%s.contact(%d)", userKey, j)
                local name = getXMLString(xmlFile, cKey .. "#name")
                if name == nil then break end
                table.insert(contacts, {
                    name         = name,
                    farmName     = getXMLString(xmlFile, cKey .. "#farmName")     or "",
                    phone        = getXMLString(xmlFile, cKey .. "#phone")        or "",
                    notes        = getXMLString(xmlFile, cKey .. "#notes")        or "",
                    playerUserId = getXMLInt(xmlFile,    cKey .. "#playerUserId") or 0,
                })
                j = j + 1
            end
            self.userContacts[uniqueId] = contacts
        end
    end

    print(string.format("[ContactManager] Loaded %d own contacts, %d client users",
        #self.contacts, userCount))
end
