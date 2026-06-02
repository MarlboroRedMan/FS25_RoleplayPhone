-- scripts/ContactManager.lua
-- Manages the player contact list (name, farm, phone, notes, playerUserId)
-- Save/load mirrors InvoiceSave XML pattern

ContactManager = {}
ContactManager.contacts       = {}   -- ordered array of contact tables (current player)
ContactManager.userContacts   = {}   -- [uniqueId] = contacts array (host-side, all players)
ContactManager._uidCounter    = 0

-- ─── UID generation ───────────────────────────────────────────────────────────
-- Short stable ID: 6 hex chars of time + 4 hex chars of per-session counter.
-- Generated client-side and sent to host so both sides share the same uid.
-- Collision probability is negligible for the contact list sizes expected.
function ContactManager:generateUid()
    ContactManager._uidCounter = ContactManager._uidCounter + 1
    return string.format("%06x%04x",
        math.floor(getTimeSec()) % 0xFFFFFF,
        ContactManager._uidCounter % 0xFFFF)
end

-- ─── CRUD ─────────────────────────────────────────────────────────────────────

function ContactManager:addContact(data)
    table.insert(self.contacts, {
        uid          = data.uid or self:generateUid(),
        name         = data.name         or "",
        farmName     = data.farmName     or "",
        phone        = data.phone        or "",
        role         = data.role         or "",
        notes        = data.notes        or "",
        playerUserId = data.playerUserId or 0,
    })
end

-- Index-based accessors kept for local UI use (no network involvement).
function ContactManager:removeContact(index)
    table.remove(self.contacts, index)
end

function ContactManager:getContact(index)
    return self.contacts[index]
end

-- UID-based accessors used for all network operations.
function ContactManager:getContactByUid(uid)
    for _, c in ipairs(self.contacts) do
        if c.uid == uid then return c end
    end
    return nil
end

function ContactManager:getContactIndexByUid(uid)
    for i, c in ipairs(self.contacts) do
        if c.uid == uid then return i end
    end
    return nil
end

function ContactManager:removeContactByUid(uid)
    for i, c in ipairs(self.contacts) do
        if c.uid == uid then
            table.remove(self.contacts, i)
            return true
        end
    end
    return false
end

function ContactManager:count()
    return #self.contacts
end
