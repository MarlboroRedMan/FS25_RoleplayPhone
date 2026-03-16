-- scripts/ContactManager.lua
-- Manages the player contact list (name, farm, phone, notes)
-- Save/load mirrors InvoiceSave XML pattern

ContactManager = {}
ContactManager.contacts       = {}   -- ordered array of contact tables (current player)
ContactManager.farmContacts   = {}   -- [farmId] = contacts array (host-side, all farms)
ContactManager.nextPhoneNumber = 5550100  -- auto-increments, saved to XML

-- ─── Phone number generator ───────────────────────────────────────────────────
function ContactManager:generatePhoneNumber()
    local n   = self.nextPhoneNumber
    self.nextPhoneNumber = n + 1
    -- Format as 555-XXXX  (keeping 555 prefix for obvious RP feel)
    local suffix = n % 10000
    return string.format("555-%04d", suffix)
end


-- ─── CRUD ─────────────────────────────────────────────────────────────────────

function ContactManager:addContact(data)
    local phone = data.phone or ""
    if phone == "" then
        phone = self:generatePhoneNumber()
    end
    table.insert(self.contacts, {
        name     = data.name     or "",
        farmName = data.farmName or "",
        phone    = phone,
        notes    = data.notes    or "",
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
    setXMLInt(xmlFile, key .. "#nextPhoneNumber", self.nextPhoneNumber or 5550100)

    -- Legacy: save self.contacts under the flat contact() keys (host's own farm)
    for i, c in ipairs(self.contacts) do
        local cKey = string.format("%s.contact(%d)", key, i - 1)
        setXMLString(xmlFile, cKey .. "#name",     c.name     or "")
        setXMLString(xmlFile, cKey .. "#farmName", c.farmName or "")
        setXMLString(xmlFile, cKey .. "#phone",    c.phone    or "")
        setXMLString(xmlFile, cKey .. "#notes",    c.notes    or "")
    end

    -- Per-farm contacts: all client farms stored under farms(N)
    local farmList = {}
    for farmId, contacts in pairs(self.farmContacts) do
        table.insert(farmList, { farmId = farmId, contacts = contacts })
    end
    table.sort(farmList, function(a, b) return a.farmId < b.farmId end)

    setXMLInt(xmlFile, key .. "#farmCount", #farmList)
    for fi, entry in ipairs(farmList) do
        local farmKey = string.format("%s.farms(%d)", key, fi - 1)
        setXMLInt(xmlFile, farmKey .. "#farmId", entry.farmId)
        for i, c in ipairs(entry.contacts) do
            local cKey = string.format("%s.contact(%d)", farmKey, i - 1)
            setXMLString(xmlFile, cKey .. "#name",     c.name     or "")
            setXMLString(xmlFile, cKey .. "#farmName", c.farmName or "")
            setXMLString(xmlFile, cKey .. "#phone",    c.phone    or "")
            setXMLString(xmlFile, cKey .. "#notes",    c.notes    or "")
        end
    end
end


-- ─── XML LOAD ─────────────────────────────────────────────────────────────────

function ContactManager:loadFromXML(xmlFile, key)
    self.contacts = {}
    self.farmContacts = {}
    self.nextPhoneNumber = getXMLInt(xmlFile, key .. "#nextPhoneNumber") or 5550100

    -- Legacy: load own contacts from flat contact() keys
    local i = 0
    while true do
        local cKey = string.format("%s.contact(%d)", key, i)
        local name = getXMLString(xmlFile, cKey .. "#name")
        if name == nil then break end
        table.insert(self.contacts, {
            name     = name,
            farmName = getXMLString(xmlFile, cKey .. "#farmName") or "",
            phone    = getXMLString(xmlFile, cKey .. "#phone")    or "",
            notes    = getXMLString(xmlFile, cKey .. "#notes")    or "",
        })
        i = i + 1
    end

    -- Per-farm contacts
    local farmCount = getXMLInt(xmlFile, key .. "#farmCount") or 0
    for fi = 0, farmCount - 1 do
        local farmKey = string.format("%s.farms(%d)", key, fi)
        local farmId  = getXMLInt(xmlFile, farmKey .. "#farmId")
        if farmId then
            local contacts = {}
            local j = 0
            while true do
                local cKey = string.format("%s.contact(%d)", farmKey, j)
                local name = getXMLString(xmlFile, cKey .. "#name")
                if name == nil then break end
                table.insert(contacts, {
                    name     = name,
                    farmName = getXMLString(xmlFile, cKey .. "#farmName") or "",
                    phone    = getXMLString(xmlFile, cKey .. "#phone")    or "",
                    notes    = getXMLString(xmlFile, cKey .. "#notes")    or "",
                })
                j = j + 1
            end
            self.farmContacts[farmId] = contacts
        end
    end

    print(string.format("[ContactManager] Loaded %d own contacts, %d client farms",
        #self.contacts, farmCount))
end
