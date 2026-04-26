-- scripts/PhoneSave.lua
-- All save and load logic for FS25_RoleplayPhone.
-- Covers: save directory, invoices, per-player data (contacts/messages/calls).

-- ─── Save directory ───────────────────────────────────────────────────────────

function RoleplayPhone:getSaveDir()
    if not g_currentMission or not g_currentMission.missionInfo then return nil end
    local dir = g_currentMission.missionInfo.savegameDirectory
    if not dir then return nil end
    local rpDir = dir .. "/FS25_RoleplayPhone"
    createFolder(rpDir)
    return rpDir
end

-- ─── Invoices ─────────────────────────────────────────────────────────────────

function RoleplayPhone:saveInvoices()
    if not g_currentMission or not g_currentMission.missionInfo then return end
    local dir = self:getSaveDir()
    if not dir then return end
    local xmlFile = createXMLFile("roleplayInvoicesXML", dir .. "/roleplayInvoices.xml", "roleplayInvoices")
    if xmlFile == 0 then return end
    InvoiceSave:saveToXML(xmlFile, "roleplayInvoices")
    saveXMLFile(xmlFile)
    delete(xmlFile)
    print("[PhoneSave] Invoices saved")
end

-- ─── Per-player data ──────────────────────────────────────────────────────────

-- Saves contacts, messages, and call history for one player into their own XML file.
function RoleplayPhone:savePlayerData(filename, contacts, messages, callHistory)
    local dir = self:getSaveDir()
    if not dir then return end
    local path       = dir .. "/" .. filename .. ".xml"
    local handleName = "roleplayPlayerXML_" .. tostring(math.floor(getTime() * 1000))
    local xmlFile    = createXMLFile(handleName, path, "roleplayData")
    if not xmlFile or xmlFile == 0 then
        print("[PhoneSave] ERROR: could not create " .. path)
        return
    end

    -- Contacts
    local cIdx = 0
    for _, c in ipairs(contacts or {}) do
        local cKey = string.format("roleplayData.contacts.contact(%d)", cIdx)
        setXMLString(xmlFile, cKey .. "#name",  c.name  or "")
        setXMLString(xmlFile, cKey .. "#phone", c.phone or "")
        setXMLString(xmlFile, cKey .. "#role",  c.role  or "")
        setXMLString(xmlFile, cKey .. "#notes", c.notes or "")
        cIdx = cIdx + 1
    end

    -- Messages (capped at 50 per thread)
    local MESSAGE_CAP = 50
    local tIdx = 0
    for key, msgs in pairs(messages or {}) do
        if #msgs > 0 then
            local tKey = string.format("roleplayData.messages.thread(%d)", tIdx)
            setXMLString(xmlFile, tKey .. "#key", tostring(key))
            local startIdx = math.max(1, #msgs - MESSAGE_CAP + 1)
            local mIdx = 0
            for i = startIdx, #msgs do
                local msg  = msgs[i]
                local mKey = string.format("%s.msg(%d)", tKey, mIdx)
                setXMLString(xmlFile, mKey .. "#text",       msg.text       or "")
                setXMLBool(xmlFile,   mKey .. "#sent",       msg.sent       or false)
                setXMLInt(xmlFile,    mKey .. "#gameDay",    msg.gameDay    or 0)
                setXMLInt(xmlFile,    mKey .. "#gameTime",   msg.gameTime   or 0)
                setXMLInt(xmlFile,    mKey .. "#fromUserId", msg.fromUserId or 0)
                setXMLString(xmlFile, mKey .. "#senderName", msg.senderName or "")
                setXMLString(xmlFile, mKey .. "#msgType",    msg.msgType    or "text")
                setXMLString(xmlFile, mKey .. "#cardName",   msg.cardName   or "")
                setXMLString(xmlFile, mKey .. "#cardPhone",  msg.cardPhone  or "")
                setXMLString(xmlFile, mKey .. "#cardFarm",   msg.cardFarm   or "")
                mIdx = mIdx + 1
            end
            tIdx = tIdx + 1
        end
    end

    -- Call history (capped at 25 entries)
    local CALL_CAP = 25
    local entries  = callHistory or {}
    local startIdx = math.max(1, #entries - CALL_CAP + 1)
    local eIdx = 0
    for i = startIdx, #entries do
        local e    = entries[i]
        local eKey = string.format("roleplayData.calls.entry(%d)", eIdx)
        setXMLString(xmlFile, eKey .. "#name",      e.name      or "")
        setXMLString(xmlFile, eKey .. "#phone",     e.phone     or "")
        setXMLString(xmlFile, eKey .. "#direction", e.direction or "")
        setXMLInt(xmlFile,    eKey .. "#gameDay",   e.gameDay   or 0)
        setXMLInt(xmlFile,    eKey .. "#gameTime",  e.gameTime  or 0)
        setXMLInt(xmlFile,    eKey .. "#count",     e.count     or 1)
        eIdx = eIdx + 1
    end

    saveXMLFile(xmlFile)
    delete(xmlFile)
    print(string.format("[PhoneSave] Saved player data: %s (%d contacts, %d threads, %d calls)",
        filename, cIdx, tIdx, eIdx))
end

-- Loads a player's data file.
-- isHost=true  → populates runtime tables (ContactManager.contacts, messages, callHistory) directly.
-- isHost=false → returns { contacts, messages, callHistory } for server-side storage / client push.
function RoleplayPhone:loadPlayerData(filename, isHost)
    local dir = self:getSaveDir()
    if not dir then return nil end
    local path       = dir .. "/" .. filename .. ".xml"
    if not fileExists(path) then
        print("[PhoneSave] No player data found: " .. filename)
        return nil
    end
    local handleName = "roleplayPlayerXML_" .. tostring(math.floor(getTime() * 1000))
    local xmlFile    = loadXMLFile(handleName, path)
    if not xmlFile or xmlFile == 0 then
        print("[PhoneSave] No player data found: " .. filename)
        return nil
    end

    -- Contacts
    local contacts = {}
    local cIdx = 0
    while true do
        local cKey = string.format("roleplayData.contacts.contact(%d)", cIdx)
        local name = getXMLString(xmlFile, cKey .. "#name")
        if name == nil then break end
        table.insert(contacts, {
            name  = name,
            phone = getXMLString(xmlFile, cKey .. "#phone") or "",
            role  = getXMLString(xmlFile, cKey .. "#role")  or "",
            notes = getXMLString(xmlFile, cKey .. "#notes") or "",
        })
        cIdx = cIdx + 1
    end

    -- Messages
    local messages = {}
    local tIdx = 0
    while true do
        local tKey = string.format("roleplayData.messages.thread(%d)", tIdx)
        local key  = getXMLString(xmlFile, tKey .. "#key")
        if key == nil then break end
        local parsedKey = tonumber(key) or key
        messages[parsedKey] = {}
        local mIdx = 0
        while true do
            local mKey = string.format("%s.msg(%d)", tKey, mIdx)
            local text = getXMLString(xmlFile, mKey .. "#text")
            if text == nil then break end
            table.insert(messages[parsedKey], {
                text       = text,
                sent       = getXMLBool(xmlFile,   mKey .. "#sent")       or false,
                gameDay    = getXMLInt(xmlFile,    mKey .. "#gameDay")    or 0,
                gameTime   = getXMLInt(xmlFile,    mKey .. "#gameTime")   or 0,
                fromUserId = getXMLInt(xmlFile,    mKey .. "#fromUserId") or 0,
                senderName = getXMLString(xmlFile, mKey .. "#senderName") or "",
                msgType    = getXMLString(xmlFile, mKey .. "#msgType")    or "text",
                cardName   = getXMLString(xmlFile, mKey .. "#cardName")   or "",
                cardPhone  = getXMLString(xmlFile, mKey .. "#cardPhone")  or "",
                cardFarm   = getXMLString(xmlFile, mKey .. "#cardFarm")   or "",
            })
            mIdx = mIdx + 1
        end
        tIdx = tIdx + 1
    end

    -- Call history
    local callHistory = {}
    local eIdx = 0
    while true do
        local eKey = string.format("roleplayData.calls.entry(%d)", eIdx)
        local name = getXMLString(xmlFile, eKey .. "#name")
        if name == nil then break end
        table.insert(callHistory, {
            name      = name,
            phone     = getXMLString(xmlFile, eKey .. "#phone")     or "",
            direction = getXMLString(xmlFile, eKey .. "#direction") or "",
            gameDay   = getXMLInt(xmlFile,    eKey .. "#gameDay")   or 0,
            gameTime  = getXMLInt(xmlFile,    eKey .. "#gameTime")  or 0,
            count     = getXMLInt(xmlFile,    eKey .. "#count")     or 1,
        })
        eIdx = eIdx + 1
    end

    delete(xmlFile)
    print(string.format("[PhoneSave] Loaded player data: %s (%d contacts, %d threads, %d calls)",
        filename, #contacts, tIdx, #callHistory))

    if isHost then
        ContactManager.contacts = contacts
        self.messages           = messages
        self.callHistory        = callHistory
        local hostUniqueId = self:getMyUniqueId()
        local hostUserId   = self:getMyUserId()
        local key = hostUniqueId ~= "" and hostUniqueId or tostring(hostUserId)
        ContactManager.userContacts[key] = contacts
    end

    return { contacts = contacts, messages = messages, callHistory = callHistory }
end