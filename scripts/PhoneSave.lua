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

-- ─── Server config ────────────────────────────────────────────────────────────
-- Reads rpVoiceMode from server_config.xml in the savegame folder.
-- Only called on the host — clients receive rpVoiceMode via RI_ServerConfigEvent.
-- To change rpVoiceMode, shut down the game, edit server_config.xml, then restart.

function RoleplayPhone:loadServerConfig()
    if g_server == nil then return end
    local dir = self:getSaveDir()
    if not dir then
        print("[PhoneSave] loadServerConfig: saveDir unavailable — rpVoiceMode=false")
        self.settings.rpVoiceMode = false
        self.rpVoiceModeConfig    = false
        return
    end
    local path = dir .. "/server_config.xml"
    if not fileExists(path) then
        -- First run: auto-generate with true (default for roleplay servers)
        print("[PhoneSave] No server_config.xml — generating defaults (rpVoiceMode=true)")
        self.settings.rpVoiceMode    = true
        self.rpVoiceModeConfig       = true
        self.settings.carrierEnabled  = false
        self.settings.carrierName     = "FarmNet"
        self.settings.carrierPhone    = "000-CARRIER"
        self.settings.carrierWelcome  = "Welcome to the server!"
        self.settings.carrierDefault  = "Sorry, I didn't understand that."
        self.settings.carrierKeywords = {}
        self:saveServerConfig()
        return
    end
    local xmlFile = loadXMLFile("RP_ServerConfig", path)
    if not xmlFile or xmlFile == 0 then
        print("[PhoneSave] Failed to open server_config.xml — rpVoiceMode=false")
        self.settings.rpVoiceMode = false
        self.rpVoiceModeConfig    = false
        return
    end
    local vm    = getXMLBool(xmlFile, "serverConfig#rpVoiceMode")
    local value = (vm == true)
    self.settings.rpVoiceMode = value
    self.rpVoiceModeConfig    = value
    -- Carrier Bot settings
    self.settings.carrierEnabled  = getXMLBool(xmlFile,   "serverConfig#carrierEnabled")  or false
    self.settings.carrierName     = getXMLString(xmlFile, "serverConfig#carrierName")     or "FarmNet"
    self.settings.carrierPhone    = getXMLString(xmlFile, "serverConfig#carrierPhone")    or "000-CARRIER"
    self.settings.carrierWelcome  = getXMLString(xmlFile, "serverConfig#carrierWelcome")  or "Welcome to the server!"
    self.settings.carrierDefault  = getXMLString(xmlFile, "serverConfig#carrierDefault")  or "Sorry, I didn't understand that."
    self.settings.carrierKeywords = {}
    local ki = 0
    while true do
        local kpath = string.format("serverConfig.keyword(%d)", ki)
        local k = getXMLString(xmlFile, kpath .. "#k"); if k == nil then break end
        table.insert(self.settings.carrierKeywords, { k = k:upper(), r = getXMLString(xmlFile, kpath .. "#r") or "" })
        ki = ki + 1
    end
    delete(xmlFile)
    print(string.format("[PhoneSave] Server config loaded: rpVoiceMode=%s", tostring(value)))
end

function RoleplayPhone:saveServerConfig()
    if g_server == nil then return end
    local dir = self:getSaveDir()
    if not dir then return end
    local path    = dir .. "/server_config.xml"
    local xmlFile = createXMLFile("RP_ServerConfig", path, "serverConfig")
    if not xmlFile or xmlFile == 0 then
        print("[PhoneSave] Failed to create server_config.xml")
        return
    end
    local settings = self.settings
    setXMLBool(xmlFile, "serverConfig#rpVoiceMode", self.rpVoiceModeConfig or false)
    -- Carrier Bot settings
    setXMLBool(xmlFile,   "serverConfig#carrierEnabled",  settings.carrierEnabled  or false)
    setXMLString(xmlFile, "serverConfig#carrierName",     settings.carrierName     or "FarmNet")
    setXMLString(xmlFile, "serverConfig#carrierPhone",    settings.carrierPhone    or "000-CARRIER")
    setXMLString(xmlFile, "serverConfig#carrierWelcome",  settings.carrierWelcome  or "")
    setXMLString(xmlFile, "serverConfig#carrierDefault",  settings.carrierDefault  or "")
    for i, kw in ipairs(settings.carrierKeywords or {}) do
        local kpath = string.format("serverConfig.keyword(%d)", i - 1)
        setXMLString(xmlFile, kpath .. "#k", kw.k or "")
        setXMLString(xmlFile, kpath .. "#r", kw.r or "")
    end
    saveXMLFile(xmlFile)
    delete(xmlFile)
    print(string.format("[PhoneSave] Server config saved: rpVoiceMode=%s", tostring(self.rpVoiceModeConfig)))
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
        setXMLString(xmlFile, cKey .. "#uid",   c.uid   or "")
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
                setXMLString(xmlFile, mKey .. "#text",         msg.text         or "")
                setXMLBool(xmlFile,   mKey .. "#sent",         msg.sent         or false)
                setXMLInt(xmlFile,    mKey .. "#gameDay",      msg.gameDay      or 0)
                setXMLInt(xmlFile,    mKey .. "#gameTime",     msg.gameTime     or 0)
                setXMLInt(xmlFile,    mKey .. "#fromUserId",   msg.fromUserId   or 0)
                setXMLString(xmlFile, mKey .. "#fromUniqueId", msg.fromUniqueId or "")
                setXMLString(xmlFile, mKey .. "#senderName",   msg.senderName   or "")
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
        print("[PhoneSave] ERROR: could not open XML for reading: " .. filename)
        return nil
    end

    -- Contacts
    local contacts = {}
    local cIdx = 0
    while true do
        local cKey = string.format("roleplayData.contacts.contact(%d)", cIdx)
        local name = getXMLString(xmlFile, cKey .. "#name")
        if name == nil then break end
        local uid = getXMLString(xmlFile, cKey .. "#uid") or ""
        if uid == "" then uid = ContactManager:generateUid() end  -- backfill for pre-uid saves
        table.insert(contacts, {
            uid   = uid,
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
                text         = text,
                sent         = getXMLBool(xmlFile,   mKey .. "#sent")         or false,
                gameDay      = getXMLInt(xmlFile,    mKey .. "#gameDay")      or 0,
                gameTime     = getXMLInt(xmlFile,    mKey .. "#gameTime")     or 0,
                fromUserId   = getXMLInt(xmlFile,    mKey .. "#fromUserId")   or 0,
                fromUniqueId = getXMLString(xmlFile, mKey .. "#fromUniqueId") or "",
                senderName   = getXMLString(xmlFile, mKey .. "#senderName")   or "",
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
        self._threadsDirty      = true
        local hostUniqueId = self:getMyUniqueId()
        local hostUserId   = self:getMyUserId()
        local key = hostUniqueId ~= "" and hostUniqueId or tostring(hostUserId)
        ContactManager.userContacts[key] = contacts
    end

    return { contacts = contacts, messages = messages, callHistory = callHistory }
end
