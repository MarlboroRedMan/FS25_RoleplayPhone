-- scripts/RoleplayPhone.lua
-- RP Phone UI — core: state, init, lifecycle, draw dispatcher, Mission00 hooks.
-- Drawing helpers, input handlers, call logic, and home screen live in
-- PhoneUI/PhoneInput/PhoneCallLogic/HomeApp/PhoneHelpers/PhoneWeather.

local modDirectory = g_currentModDirectory

RoleplayPhone = {}

-- ─── State constants ──────────────────────────────────────────────────────────
RoleplayPhone.STATE = {
    CLOSED         = 0,
    HOME           = 1,
    INVOICES_LIST  = 2,
    INVOICE_DETAIL = 3,
    INVOICE_CREATE = 4,
    CONTACTS       = 5,
    CALLS          = 6,
    CONTACT_DETAIL = 7,
    CONTACT_CREATE = 8,
    CALL_OUTGOING  = 9,
    CALL_INCOMING  = 10,
    CALL_ACTIVE    = 11,
    SETTINGS       = 12,
    MESSAGE_THREAD = 13,
    WEATHER        = 14,
    MESSAGES       = 15,
}

-- ─── Tab constants ────────────────────────────────────────────────────────────
RoleplayPhone.TAB = { INBOX = 1, OUTBOX = 2 }

-- ─── Runtime state ────────────────────────────────────────────────────────────
RoleplayPhone.state               = RoleplayPhone.STATE.CLOSED
RoleplayPhone.isOpen              = false
RoleplayPhone.phoneContextEventId = nil
RoleplayPhone.flashlightBlockerId = nil
RoleplayPhone.currentTab          = RoleplayPhone.TAB.INBOX
RoleplayPhone.settingsTab         = "general"

-- ─── Ringtone definitions ─────────────────────────────────────────────────────
RoleplayPhone.RINGTONES = {
    { name = "Classic",   file = "ringtone.ogg"         },
    { name = "Farm",      file = "ringtone_farm.ogg"    },
    { name = "Tractor",   file = "ringtone_tractor.ogg" },
    { name = "Old Phone", file = "ringtone_oldphone.ogg"},
}

RoleplayPhone.previewWallpaper          = nil
RoleplayPhone.mouseX                    = 0
RoleplayPhone.mouseY                    = 0
RoleplayPhone.whiteOverlay              = nil
RoleplayPhone.wallpaper                 = nil
RoleplayPhone.iconInvoices              = nil
RoleplayPhone.iconContacts              = nil
RoleplayPhone.iconMessages              = nil
RoleplayPhone.iconCalls                 = nil
RoleplayPhone.iconSettings              = nil
RoleplayPhone.callActionEventId         = nil
RoleplayPhone.incomingCallActionEventId = nil
RoleplayPhone.seenInvoiceIds            = {}
RoleplayPhone.callHistory               = {}
RoleplayPhone.callsTab                  = "keypad"
RoleplayPhone.keypadNumber              = ""
RoleplayPhone.hitboxes                  = {}
RoleplayPhone.onlineUsers               = {}

-- ─── Aspect ratio correction ──────────────────────────────────────────────────
RoleplayPhone.arScale  = 1.0
RoleplayPhone.actualAR = 16 / 9

-- ─── Home screen page system ──────────────────────────────────────────────────
RoleplayPhone.homePage      = 1
RoleplayPhone.homePageCount = 2

-- ─── App grid definition (page 2+) ───────────────────────────────────────────
RoleplayPhone.GRID_APPS = {
    { id="weather", label="Weather", page=2, color={0.15, 0.45, 0.75}, icon="iconWeather" },
    { id="market",  label="Market",  page=2, color={0.20, 0.60, 0.30}, icon="iconMarket"  },
}

-- ─── Dock apps ────────────────────────────────────────────────────────────────
RoleplayPhone.DOCK_APPS = {
    { id="invoices", label="Invoices", color={0.25, 0.25, 0.30} },
    { id="contacts", label="Contacts", color={0.10, 0.50, 0.30} },
    { id="messages", label="Messages", color={0.10, 0.35, 0.55}, icon="iconMessages" },
    { id="calls",    label="Calls",    color={0.10, 0.30, 0.65} },
    { id="settings", label="Settings", color={0.35, 0.25, 0.45} },
}

-- ─── Player settings ──────────────────────────────────────────────────────────
RoleplayPhone.settings = {
    timeFormat     = "12",
    tempUnit       = "F",
    wallpaperIndex = 1,
    batteryVisible = true,
    ringtoneIndex  = 1,
}

-- ─── Battery widget ───────────────────────────────────────────────────────────
RoleplayPhone.battery = {
    level      = 100.0,
    drainRate  = 0.04,
    callRate   = 0.08,
    chargeRate = 0.20,
}

-- ─── Wallpaper colour palettes ────────────────────────────────────────────────
RoleplayPhone.WALLPAPERS = {
    { name="Countryside",   texture="wallpaper",              r=0.08, g=0.12, b=0.06 },
    { name="Barn & Silos",  texture="wallpaperBarnSilos",     r=0.08, g=0.10, b=0.14 },
    { name="Red Barn",      texture="wallpaperBigRedBarn",    r=0.14, g=0.06, b=0.06 },
    { name="Winter Barn",   texture="wallpaperWinterRedBarn", r=0.10, g=0.12, b=0.16 },
    { name="Hay Bales",     texture="wallpaperHayBales",      r=0.06, g=0.14, b=0.06 },
    { name="Midnight",      texture=false, r=0.07, g=0.07, b=0.14 },
    { name="Forest",        texture=false, r=0.04, g=0.14, b=0.07 },
    { name="Slate",         texture=false, r=0.10, g=0.10, b=0.10 },
    { name="Ember",         texture=false, r=0.16, g=0.07, b=0.04 },
    { name="Dusk",          texture=false, r=0.14, g=0.05, b=0.18 },
    { name="Ocean",         texture=false, r=0.04, g=0.12, b=0.20 },
    { name="Rose Gold",     texture=false, r=0.20, g=0.10, b=0.12 },
}

-- ─── Invoice create form state ────────────────────────────────────────────────
RoleplayPhone.form = {
    toFarmIndex        = 1,
    categoryGroupIndex = 1,
    categoryTypeIndex  = 1,
    amount      = "",
    notes       = "",
    dueDate     = "",
    activeField = nil,
}

RoleplayPhone.selectedContact = nil

-- ─── Message storage & compose ────────────────────────────────────────────────
RoleplayPhone.messages            = {}
RoleplayPhone.messageDisplayNames = {}   -- [key] = {name, phone} for senders not in contacts
RoleplayPhone.messageCompose      = { text = "", active = false }
RoleplayPhone.unreadMessages      = {}
RoleplayPhone.playerMessages      = {}   -- [uniqueId] = messages table for connected clients (server only)
RoleplayPhone.playerCalls         = {}   -- [uniqueId] = callHistory table for connected clients (server only)

-- ─── Call state ───────────────────────────────────────────────────────────────
RoleplayPhone.call = {
    contactName = "",
    contactNum  = "",
    toUserId    = 0,
    fromUserId  = 0,
    startTime   = 0,
    ringSample  = nil,
    prevState   = 7,
}

-- ─── Contact create form state ────────────────────────────────────────────────
RoleplayPhone.contactForm = {
    name         = "",
    farmName     = "",
    phone        = "",
    notes        = "",
    playerUserId = 0,
    activeField  = nil,
}

-- ─── Layout constants ─────────────────────────────────────────────────────────
RoleplayPhone.PHONE = { x = 0.390, y = 0.10, w = 0.220, h = 0.55 }
RoleplayPhone.BIG   = { x = 0.390, y = 0.10, w = 0.220, h = 0.55 }

RoleplayPhone.FRAME_SCREEN = {
    L = 38,  R = 474,
    B = 100, T = 914,
    imgW = 512, imgH = 1024,
}

-- ─── Init ─────────────────────────────────────────────────────────────────────
function RoleplayPhone:init()
    local tex = modDirectory .. "textures/"
    self.whiteOverlay           = createImageOverlay(tex .. "white.dds")
    self.wallpaper              = createImageOverlay(tex .. "wallpaper.dds")
    self.wallpaperBarnSilos     = createImageOverlay(tex .. "wallpaper_barnsilos.dds")
    self.wallpaperBigRedBarn    = createImageOverlay(tex .. "wallpaper_bigredbarn.dds")
    self.wallpaperWinterRedBarn = createImageOverlay(tex .. "wallpaper_winterredbarn.dds")
    self.wallpaperHayBales      = createImageOverlay(tex .. "wallpaper_haybales.dds")
    self.iconInvoices = createImageOverlay(tex .. "icon_invoices.dds")
    self.iconContacts = createImageOverlay(tex .. "icon_contacts.dds")
    self.iconMessages = createImageOverlay(tex .. "icon_message.dds")
    self.iconCalls    = createImageOverlay(tex .. "recent_call.dds")
    self.iconSettings = createImageOverlay(tex .. "icon_settings.dds")
    self.iconWeather  = createImageOverlay(tex .. "weather.dds")
    self.weatherIcons = {
        Clear        = createImageOverlay(tex .. "weather_clear.dds"),
        PartlyCloudy = createImageOverlay(tex .. "weather_partlycloudy.dds"),
        Cloudy       = createImageOverlay(tex .. "weather_cloudy.dds"),
        Rain         = createImageOverlay(tex .. "weather_rain.dds"),
        HeavyRain    = createImageOverlay(tex .. "weather_heavyrain.dds"),
        Snow         = createImageOverlay(tex .. "weather_snow.dds"),
        Storm        = createImageOverlay(tex .. "weather_storm.dds"),
        Hail         = createImageOverlay(tex .. "weather_hail.dds"),
    }
    self.iconMarket = nil
    self.phoneFrame = createImageOverlay(tex .. "phone_frame.dds")
    if self.phoneFrame == nil or self.phoneFrame == 0 then
        self.phoneFrame = nil
        print("[RoleplayPhone] WARN: phone_frame.dds not found - using drawRect bezel")
    else
        print("[RoleplayPhone] Phone frame texture loaded OK")
    end
    if self.whiteOverlay == nil or self.whiteOverlay == 0 then
        print("[RoleplayPhone] ERROR: failed to load white.dds")
    else
        print("[RoleplayPhone] Initialized OK")
    end
    if self.wallpaper == nil or self.wallpaper == 0 then
        print("[RoleplayPhone] WARN: wallpaper.dds not found - using solid background")
        self.wallpaper = nil
    end

    self.ringtoneSamples = {}
    for i, rt in ipairs(self.RINGTONES) do
        local snd = createSample("RP_ringtone_" .. i)
        if snd and snd ~= 0 then
            loadSample(snd, modDirectory .. "sounds/" .. rt.file, false)
            self.ringtoneSamples[i] = snd
        end
    end
    self.ringSample = self.ringtoneSamples[self.settings.ringtoneIndex or 1]
    print("[RoleplayPhone] Ringtones loaded: " .. #self.ringtoneSamples)

    self.ringbackSample = createSample("RP_ringback")
    if self.ringbackSample and self.ringbackSample ~= 0 then
        loadSample(self.ringbackSample, modDirectory .. "sounds/ringback.ogg", false)
        print("[RoleplayPhone] Ringback loaded OK")
    else
        self.ringbackSample = nil
        print("[RoleplayPhone] WARN: ringback.ogg not found")
    end

    self.unavailableSample = createSample("RP_unavailable")
    if self.unavailableSample and self.unavailableSample ~= 0 then
        loadSample(self.unavailableSample, modDirectory .. "sounds/unavailable.ogg", false)
        print("[RoleplayPhone] Unavailable tone loaded OK")
    else
        self.unavailableSample = nil
    end

    self.notifSample = createSample("RP_notification")
    if self.notifSample and self.notifSample ~= 0 then
        loadSample(self.notifSample, modDirectory .. "sounds/notification.ogg", false)
        print("[RoleplayPhone] Notification sound loaded OK")
    else
        self.notifSample = nil
    end

    local sw = g_screenWidth  or 1920
    local sh = g_screenHeight or 1080
    self.actualAR = sw / sh
    self.arScale  = (16 / 9) / self.actualAR
    print(string.format("[RoleplayPhone] Screen %dx%d  AR=%.3f  arScale=%.3f", sw, sh, self.actualAR, self.arScale))

    local baseW = 0.220
    self.PHONE.w = baseW * self.arScale
    self.PHONE.x = 0.5 - self.PHONE.w / 2
    self.BIG.w   = baseW * self.arScale
    self.BIG.x   = 0.5 - self.BIG.w / 2

    NotificationManager:init(self.whiteOverlay, modDirectory, self.arScale)
    self:loadSettings()
end

-- ─── Load saved data ──────────────────────────────────────────────────────────
function RoleplayPhone:loadSavedData()
    if g_server == nil then return end
    if not g_currentMission or not g_currentMission.missionInfo then return end
    local dir = self:getSaveDir()
    if not dir then return end

    -- Load invoices (shared file — all players)
    local invFile = loadXMLFile("roleplayInvoicesXML", dir .. "/roleplayInvoices.xml")
    if invFile and invFile ~= 0 then
        InvoiceSave:loadFromXML(invFile, "roleplayInvoices")
        delete(invFile)
        local count = 0
        for _ in pairs(InvoiceManager.invoices) do count = count + 1 end
        print(string.format("[RoleplayPhone] Loaded %d invoices from disk", count))
    else
        print("[RoleplayPhone] No saved invoices found (new save or first run)")
    end
    -- Host player data is loaded in CURRENT_MISSION_LOADED where uniqueId is available
end

-- ─── Open / Close ─────────────────────────────────────────────────────────────
function RoleplayPhone:toggle()
    print("[RoleplayPhone] toggle() called — state=" .. tostring(self.state))
    local now = getTimeSec()
    if self.lastToggleTime and (now - self.lastToggleTime) < 0.4 then return end
    self.lastToggleTime = now

    if self.state == self.STATE.CALL_INCOMING then
        self:answerCall()
        return
    end

    if self.state == self.STATE.CLOSED then
        self.state  = self.STATE.HOME
        self.isOpen = true
        self:clearFarmCache()

        g_inputBinding:setShowMouseCursor(true)
        if g_localPlayer and g_localPlayer.inputComponent then
            g_localPlayer.inputComponent.locked = true
        end
        g_inputBinding:setContext("RI_PHONE_UI", true, false)

        -- Register actions inside RI_PHONE_UI context
        g_inputBinding:beginActionEventsModification("RI_PHONE_UI")
        -- F7: close phone
        local _, evtId = g_inputBinding:registerActionEvent(
            "RI_OPEN_PHONE", RoleplayPhone, RoleplayPhone.toggle,
            false, true, false, true)
        self.phoneContextEventId = evtId
        if evtId then
            g_inputBinding:setActionEventText(evtId, g_i18n:getText("input_RI_OPEN_PHONE"))
        end
        -- F: block flashlight from firing through phone context
        local noop = function() end
        local _, flashBlockId = g_inputBinding:registerActionEvent(
            "TOGGLE_LIGHTS_FPS", RoleplayPhone, noop,
            false, true, false, true)
        self.flashlightBlockerId = flashBlockId
        g_inputBinding:endActionEventsModification()

        if self.pendingInboxCheck then
            self.pendingInboxCheck = false
            local myFarmId = self:getMyFarmId()
            local unpaid = 0
            for _, inv in pairs(InvoiceManager.invoices) do
                if inv.toFarmId == myFarmId and inv.status == "PENDING" then unpaid = unpaid + 1 end
            end
            if unpaid > 0 then
                local msg = unpaid == 1
                    and g_i18n:getText("phone_notif_unpaid_one")
                    or  string.format(g_i18n:getText("phone_notif_unpaid_multi"), unpaid)
                NotificationManager:push("info", msg)
            end
        end

        NotificationManager:clearBadge()
        print("[RoleplayPhone] Opened")
    else
        self:close()
    end
end

function RoleplayPhone:close()
    if not self.isOpen then return end
    self.isOpen = false
    self.state  = self.STATE.CLOSED
    self.form.activeField = nil

    if self.phoneContextEventId then
        g_inputBinding:removeActionEvent(self.phoneContextEventId)
        self.phoneContextEventId = nil
    end
    if self.flashlightBlockerId then
        g_inputBinding:removeActionEvent(self.flashlightBlockerId)
        self.flashlightBlockerId = nil
    end
    if g_localPlayer and g_localPlayer.inputComponent then
        g_localPlayer.inputComponent.locked = false
    end
    g_inputBinding:revertContext(true)
    g_inputBinding:setShowMouseCursor(false)
    print("[RoleplayPhone] Closed")
end

function RoleplayPhone:goHome()
    self.state = self.STATE.HOME
    self.form.activeField = nil
end

-- ─── Message handling ─────────────────────────────────────────────────────────
function RoleplayPhone:receiveMessage(contactKey, fromUserId, senderName, text, gameDay, sent, gameTime)
    if not self.messages[contactKey] then self.messages[contactKey] = {} end
    table.insert(self.messages[contactKey], {
        fromUserId = fromUserId, senderName = senderName,
        text = text, gameDay = gameDay or 0, gameTime = gameTime or 0, sent = sent or false,
    })
    if sent then return end
    if self.isSyncing then return end  -- historical sync, no notification
    local viewing = ((self.state == self.STATE.CONTACT_DETAIL or self.state == self.STATE.MESSAGE_THREAD)
                     and self.selectedContact == contactKey)
    if not viewing then
        local displayName = senderName
        for _, c in ipairs(ContactManager.contacts) do
            if c.farmName and string.lower(c.farmName) == string.lower(senderName) then
                displayName = c.name or senderName; break
            end
        end
        self.unreadMessages[contactKey] = (self.unreadMessages[contactKey] or 0) + 1
        if self.notifSample and self.notifSample ~= 0 then
            playSample(self.notifSample, 1, 1.0, 1.0, 0, 0)
        end
        NotificationManager:push("ping",
            string.format(g_i18n:getText("phone_notif_msg_from"), displayName, text))
    end
end

function RoleplayPhone:sendMessage()
    local text = self.messageCompose.text
    if not text or text == "" then return end
    if not self.selectedContact then return end

    local toUserId
    local displayName

    -- Unknown sender (not in contacts) — key is a string like "u_2"
    if type(self.selectedContact) == "string" then
        local info = self.messageDisplayNames[self.selectedContact]
        if not info then return end
        -- userId may not be set yet if loaded from registry — resolve from onlineUsers by phone
        if not info.userId or info.userId == 0 then
            for uid, u in pairs(RoleplayPhone.onlineUsers) do
                if u.phone and u.phone == info.phone then
                    info.userId = uid
                    break
                end
            end
        end
        if not info.userId or info.userId == 0 then return end
        toUserId    = info.userId
        displayName = info.phone ~= "" and info.phone or info.name
    else
        local c = ContactManager:getContact(self.selectedContact)
        if not c then return end
        toUserId = self:resolveUserId(c)
        if toUserId == 0 then
            NotificationManager:push("rejected",
                string.format(g_i18n:getText("phone_notif_farm_not_found"), c.name or c.farmName or "?"))
            return
        end
        displayName = c.name or c.farmName
    end

    local myUserId = self:getMyUserId()
    local myName   = (g_currentMission and g_currentMission.playerNickname) or self:getFarmName(self:getMyFarmId())
    local gameDay  = (g_currentMission and g_currentMission.environment
                      and g_currentMission.environment.currentDay) or 0
    local gameTime = (g_currentMission and g_currentMission.environment
                      and g_currentMission.environment.dayTime) or 0
    self:receiveMessage(self.selectedContact, myUserId, myName, text, gameDay, true, gameTime)
    local evt = RI_MessageEvent.new(myUserId, toUserId, myName, text, gameDay, gameTime)
    if g_server ~= nil then
        -- Server: find recipient's connection and send directly (already received locally above)
        local ps   = g_currentMission and g_currentMission.playerSystem
        local rp   = ps and ps:getPlayerByUserId(toUserId)
        local conn = rp and rp.connection
        if conn then conn:sendEvent(evt) end

        -- Store host-sent message in recipient's server-side playerMessages so it syncs on reconnect
        local myUniqueId        = self:getMyUniqueId()
        local recipientInfo     = self.onlineUsers[toUserId]
        local recipientUniqueId = recipientInfo and recipientInfo.uniqueId or ""
        if recipientUniqueId ~= "" then
            if not self.playerMessages[recipientUniqueId] then
                self.playerMessages[recipientUniqueId] = {}
            end
            local key = "in_" .. (myUniqueId ~= "" and myUniqueId or tostring(self:getMyUserId()))
            if not self.playerMessages[recipientUniqueId][key] then
                self.playerMessages[recipientUniqueId][key] = {}
            end
            table.insert(self.playerMessages[recipientUniqueId][key], {
                fromUserId = myUserId,
                senderName = myName,
                text       = text,
                gameDay    = gameDay,
                gameTime   = gameTime,
                sent       = false,
            })
        end
    elseif g_client ~= nil then
        g_client:getServerConnection():sendEvent(evt)
    end
    self.messageCompose.text = ""
    print(string.format("[RoleplayPhone] Message sent to userId %d: %s", toUserId, text))
end

-- ─── Save helpers ─────────────────────────────────────────────────────────────
function RoleplayPhone:getSaveDir()
    if not g_currentMission or not g_currentMission.missionInfo then return nil end
    local dir = g_currentMission.missionInfo.savegameDirectory
    if not dir then return nil end
    local rpDir = dir .. "/FS25_RoleplayPhone"
    createFolder(rpDir)
    return rpDir
end

function RoleplayPhone:saveInvoices()
    if not g_currentMission or not g_currentMission.missionInfo then return end
    local dir = self:getSaveDir()
    if not dir then return end
    local xmlFile = createXMLFile("roleplayInvoicesXML", dir .. "/roleplayInvoices.xml", "roleplayInvoices")
    if xmlFile == 0 then return end
    InvoiceSave:saveToXML(xmlFile, "roleplayInvoices")
    saveXMLFile(xmlFile); delete(xmlFile)
    print("[RoleplayPhone] Invoices saved")
end

-- ─── Per-player data save/load ────────────────────────────────────────────────

-- Saves contacts, messages, and call history for one player into their own file.
-- isHost=true means we're saving the host's own runtime data.
-- isHost=false means we're saving data that was synced from a client.
function RoleplayPhone:savePlayerData(filename, contacts, messages, callHistory)
    local dir = self:getSaveDir()
    if not dir then return end
    local path    = dir .. "/" .. filename .. ".xml"
    local xmlFile = createXMLFile("roleplayPlayerXML", path, "roleplayData")
    if not xmlFile or xmlFile == 0 then
        print("[RoleplayPhone] ERROR: could not create " .. path)
        return
    end

    -- Contacts
    local cIdx = 0
    for _, c in ipairs(contacts or {}) do
        local cKey = string.format("roleplayData.contacts.contact(%d)", cIdx)
        setXMLString(xmlFile, cKey .. "#name",         c.name         or "")
        setXMLString(xmlFile, cKey .. "#farmName",     c.farmName     or "")
        setXMLString(xmlFile, cKey .. "#phone",        c.phone        or "")
        setXMLString(xmlFile, cKey .. "#notes",        c.notes        or "")
        setXMLInt(xmlFile,    cKey .. "#playerUserId", c.playerUserId or 0)
        cIdx = cIdx + 1
    end

    -- Messages
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
                mIdx = mIdx + 1
            end
            tIdx = tIdx + 1
        end
    end

    -- Call history
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
    print(string.format("[RoleplayPhone] Saved player data: %s (%d contacts, %d threads, %d calls)",
        filename, cIdx, tIdx, eIdx))
end

-- Loads a player's data file. If isHost=true, populates runtime tables directly.
-- Returns { contacts, messages, callHistory } for client push use.
function RoleplayPhone:loadPlayerData(filename, isHost)
    local dir = self:getSaveDir()
    if not dir then return nil end
    local path    = dir .. "/" .. filename .. ".xml"
    local xmlFile = loadXMLFile("roleplayPlayerXML", path)
    if not xmlFile or xmlFile == 0 then
        print("[RoleplayPhone] No player data found: " .. filename)
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
            name         = name,
            farmName     = getXMLString(xmlFile, cKey .. "#farmName")     or "",
            phone        = getXMLString(xmlFile, cKey .. "#phone")        or "",
            notes        = getXMLString(xmlFile, cKey .. "#notes")        or "",
            playerUserId = getXMLInt(xmlFile,    cKey .. "#playerUserId") or 0,
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
    print(string.format("[RoleplayPhone] Loaded player data: %s (%d contacts, %d threads, %d calls)",
        filename, #contacts, tIdx, #callHistory))

    -- If loading for host, populate runtime tables directly
    if isHost then
        ContactManager.contacts = contacts
        self.messages           = messages
        self.callHistory        = callHistory
        -- Bootstrap userContacts so the server can push host's contacts if asked
        local hostUniqueId = self:getMyUniqueId()
        local hostUserId   = self:getMyUserId()
        local key = hostUniqueId ~= "" and hostUniqueId or tostring(hostUserId)
        ContactManager.userContacts[key] = contacts
    end

    return { contacts = contacts, messages = messages, callHistory = callHistory }
end

-- ─── Main draw dispatcher ─────────────────────────────────────────────────────
function RoleplayPhone:draw()
    NotificationManager:draw()
    if self.state == self.STATE.CALL_OUTGOING
    or self.state == self.STATE.CALL_INCOMING
    or self.state == self.STATE.CALL_ACTIVE then
        self:drawCallScreen(); return
    end
    if self.state == self.STATE.CLOSED then return end
    self.hitboxes = {}
    if     self.state == self.STATE.HOME           then self:drawPhoneHome()
    elseif self.state == self.STATE.INVOICES_LIST  then self:drawBigScreen(); self:drawInvoicesList()
    elseif self.state == self.STATE.INVOICE_CREATE then self:drawBigScreen(); self:drawCreateInvoice()
    elseif self.state == self.STATE.INVOICE_DETAIL then self:drawBigScreen(); self:drawInvoiceDetail()
    elseif self.state == self.STATE.CONTACTS       then self:drawContacts()
    elseif self.state == self.STATE.CONTACT_DETAIL then self:drawContactDetail()
    elseif self.state == self.STATE.MESSAGE_THREAD then self:drawMessageThread()
    elseif self.state == self.STATE.MESSAGES       then self:drawMessages()
    elseif self.state == self.STATE.CONTACT_CREATE then self:drawContactCreate()
    elseif self.state == self.STATE.CALLS          then self:drawCallsApp()
    elseif self.state == self.STATE.SETTINGS       then self:drawSettings()
    elseif self.state == self.STATE.WEATHER        then self:drawBigScreen(); self:drawWeatherApp()
    end
    self:drawPhoneFrame()
end

-- ─── Keybind registration ─────────────────────────────────────────────────────
function RoleplayPhone:registerKeybind()
    if self.inputRegistered then return end

    g_inputBinding:beginActionEventsModification("PLAYER")
    local _, eventId = g_inputBinding:registerActionEvent(
        "RI_OPEN_PHONE", RoleplayPhone, RoleplayPhone.toggle,
        false, true, false, true)
    self.actionEventId = eventId
    if eventId then
        g_inputBinding:setActionEventText(eventId, g_i18n:getText("input_RI_OPEN_PHONE"))
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_NORMAL or 0)
        print("[RoleplayPhone] RI_OPEN_PHONE registered OK: " .. tostring(eventId))
    else
        print("[RoleplayPhone] WARNING: RI_OPEN_PHONE registration failed")
    end
    g_inputBinding:endActionEventsModification()

    for _, context in ipairs({"PLAYER", "VEHICLE"}) do
        g_inputBinding:beginActionEventsModification(context)
        local _, callEventId = g_inputBinding:registerActionEvent(
            "RI_CALL_ACTION", RoleplayPhone, RoleplayPhone.callAction,
            false, true, false, true)
        if context == "PLAYER" then
            self.callActionEventId = callEventId
            if callEventId then
                g_inputBinding:setActionEventText(callEventId, g_i18n:getText("input_RI_CALL_ACTION"))
                g_inputBinding:setActionEventTextPriority(callEventId, GS_PRIO_NORMAL or 0)
                print("[RoleplayPhone] RI_CALL_ACTION registered OK: " .. tostring(callEventId))
            else
                print("[RoleplayPhone] WARNING: RI_CALL_ACTION registration failed")
            end
        end
        g_inputBinding:endActionEventsModification()
    end

    self.inputRegistered = true
end

function RoleplayPhone:callAction()
    if self.state == self.STATE.CALL_INCOMING then
        self:answerCall()
    elseif self.state == self.STATE.CALL_OUTGOING or self.state == self.STATE.CALL_ACTIVE then
        self:endCall()
    end
end

function RoleplayPhone:updateCallKeyPoll() end

-- ─── Mission00 hooks ──────────────────────────────────────────────────────────

Mission00.keyboardEvent = Utils.appendedFunction(Mission00.keyboardEvent,
    function(mission, unicode, sym, modifier, isDown)
        if RoleplayPhone.state ~= RoleplayPhone.STATE.CLOSED then
            RoleplayPhone:keyEvent(unicode, sym, modifier, isDown)
        end
    end
)

Mission00.deleteMap = Utils.appendedFunction(Mission00.deleteMap, function(mission)
    if RoleplayPhone.isOpen then
        if RoleplayPhone.phoneContextEventId then
            g_inputBinding:removeActionEvent(RoleplayPhone.phoneContextEventId)
            RoleplayPhone.phoneContextEventId = nil
        end
        if RoleplayPhone.flashlightBlockerId then
            g_inputBinding:removeActionEvent(RoleplayPhone.flashlightBlockerId)
            RoleplayPhone.flashlightBlockerId = nil
        end
        if g_localPlayer and g_localPlayer.inputComponent then
            g_localPlayer.inputComponent.locked = false
        end
        g_inputBinding:revertContext(true)
        g_inputBinding:setShowMouseCursor(false)
        RoleplayPhone.isOpen = false
    end
    if RoleplayPhone.actionEventId then
        g_inputBinding:removeActionEvent(RoleplayPhone.actionEventId)
        RoleplayPhone.actionEventId = nil
    end
    if RoleplayPhone.callActionEventId then
        g_inputBinding:removeActionEvent(RoleplayPhone.callActionEventId)
        RoleplayPhone.callActionEventId = nil
    end
    g_messageCenter:unsubscribeAll(RoleplayPhone)
    RoleplayPhone.inputRegistered = false
    local textures = {
        "whiteOverlay","wallpaper","wallpaperBarnSilos","wallpaperBigRedBarn",
        "wallpaperWinterRedBarn","wallpaperHayBales",
        "iconInvoices","iconContacts","iconMessages","iconCalls","iconSettings","phoneFrame",
    }
    for _, k in ipairs(textures) do
        if RoleplayPhone[k] and RoleplayPhone[k] ~= 0 then delete(RoleplayPhone[k]) end
    end
    if RoleplayPhone.weatherIcons then
        for _, icon in pairs(RoleplayPhone.weatherIcons) do
            if icon and icon ~= 0 then delete(icon) end
        end
    end
end)

Mission00.saveSavegame = Utils.appendedFunction(Mission00.saveSavegame,
    function(mission)
        if g_server ~= nil then
            RoleplayPhone:saveInvoices()
            -- Save host's own player data file
            local hostUniqueId = RoleplayPhone:getMyUniqueId()
            local hostNickname = (g_currentMission and g_currentMission.playerNickname) or "host"
            local hostPhone    = RoleplayPhone:hashPhone(RoleplayPhone:getMyUserId())
            local entry        = RoleplayPhone:getOrCreateRegistryEntry(hostUniqueId, hostPhone)
            local filename     = RoleplayPhone:buildPlayerFilename(hostNickname, entry.fileId)
            RoleplayPhone:savePlayerData(filename,
                ContactManager.contacts,
                RoleplayPhone.messages,
                RoleplayPhone.callHistory)
            -- Save each connected client's data file
            for userId, info in pairs(RoleplayPhone.onlineUsers) do
                if userId ~= RoleplayPhone:getMyUserId() and info.uniqueId and info.uniqueId ~= "" then
                    local clientEntry    = RoleplayPhone:getOrCreateRegistryEntry(info.uniqueId, info.phone)
                    local clientFilename = RoleplayPhone:buildPlayerFilename(info.name, clientEntry.fileId)
                    local clientKey      = info.uniqueId
                    local clientContacts = ContactManager.userContacts[clientKey] or {}
                    -- Client messages and calls are stored server-side under their uniqueId key
                    local clientMessages = RoleplayPhone.playerMessages and RoleplayPhone.playerMessages[clientKey] or {}
                    local clientCalls    = RoleplayPhone.playerCalls    and RoleplayPhone.playerCalls[clientKey]    or {}
                    RoleplayPhone:savePlayerData(clientFilename, clientContacts, clientMessages, clientCalls)
                end
            end
        end
    end
)

Mission00.onConnectionFinishedLoading = Utils.appendedFunction(
    Mission00.onConnectionFinishedLoading,
    function(mission, connection)
        if g_server == nil then return end

        local hostUserId   = RoleplayPhone:getMyUserId()
        local hostFarmId   = RoleplayPhone:getMyFarmId()
        local hostName     = RoleplayPhone:getFarmName(hostFarmId)
        local hostPhone    = RoleplayPhone:hashPhone(hostUserId)
        local hostUniqueId = RoleplayPhone:getMyUniqueId()
        connection:sendEvent(RI_PlayerHelloEvent.new(hostUserId, hostFarmId, hostName, hostPhone, hostUniqueId))

        for userId, info in pairs(RoleplayPhone.onlineUsers) do
            if userId ~= hostUserId then
                connection:sendEvent(RI_PlayerHelloEvent.new(userId, info.farmId, info.name, info.phone, info.uniqueId or ""))
            end
        end

        local farms = RoleplayPhone:getAvailableFarms()
        if farms and #farms > 0 then
            connection:sendEvent(RI_FarmListEvent.new(farms))
            RoleplayPhone.knownFarms = farms
            print(string.format("[RoleplayPhone] Sent farm list (%d farms) to new client", #farms))
        end

        local count = 0
        for _, inv in pairs(InvoiceManager.invoices) do
            connection:sendEvent(RI_SendInvoiceEvent.new(inv, false))
            count = count + 1
        end
        if count > 0 then
            print(string.format("[RoleplayPhone] Sent %d existing invoices to new client", count))
        end

        local forecast = RoleplayPhone:getForecastFromXML()
        if forecast and next(forecast) ~= nil then
            connection:sendEvent(RI_WeatherForecastEvent.new(forecast))
            print("[RoleplayPhone] Sent weather forecast to new client")
        end

        -- Contacts, messages, and call history are pushed in RI_PlayerHelloEvent:run()
        -- once the player's identity (uniqueId) is known.
    end
)

-- ─── Stale onlineUsers cleanup ────────────────────────────────────────────────
-- Runs every 5 seconds on host only. Compares onlineUsers against active
-- connections and removes entries for players who have disconnected.
Mission00.update = Utils.appendedFunction(Mission00.update, function(mission, dt)
    if g_server == nil then return end
    RoleplayPhone._cleanupTimer = (RoleplayPhone._cleanupTimer or 0) + dt
    if RoleplayPhone._cleanupTimer < 5000 then return end
    RoleplayPhone._cleanupTimer = 0

    local ps = g_currentMission and g_currentMission.playerSystem
    if not ps then return end

    local myUserId = RoleplayPhone:getMyUserId()
    local toRemove = {}
    for userId, _ in pairs(RoleplayPhone.onlineUsers) do
        if userId ~= myUserId then
            if not ps:getPlayerByUserId(userId) then
                table.insert(toRemove, userId)
            end
        end
    end
    for _, userId in ipairs(toRemove) do
        local info = RoleplayPhone.onlineUsers[userId]
        if info and info.uniqueId and info.uniqueId ~= "" then
            local clientEntry    = RoleplayPhone:getOrCreateRegistryEntry(info.uniqueId, info.phone)
            local clientFilename = RoleplayPhone:buildPlayerFilename(info.name, clientEntry.fileId)
            local clientKey      = info.uniqueId
            local clientContacts = ContactManager.userContacts[clientKey] or {}
            local clientMessages = RoleplayPhone.playerMessages and RoleplayPhone.playerMessages[clientKey] or {}
            local clientCalls    = RoleplayPhone.playerCalls    and RoleplayPhone.playerCalls[clientKey]    or {}
            RoleplayPhone:savePlayerData(clientFilename, clientContacts, clientMessages, clientCalls)
            print(string.format("[RoleplayPhone] Saved data on disconnect: %s", info.name or tostring(userId)))
        end
        print(string.format("[RoleplayPhone] Removed stale onlineUser: %s", tostring(userId)))
        RoleplayPhone.onlineUsers[userId] = nil
    end
end)
