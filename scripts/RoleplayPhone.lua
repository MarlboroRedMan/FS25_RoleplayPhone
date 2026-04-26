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
RoleplayPhone.offlinePlayerData   = {}   -- [uniqueId] = {filename,contacts,messages,callHistory} cached at startup
RoleplayPhone.cachedRegistry      = nil  -- full registry loaded at startup, merged on every save

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
    name        = "",
    phone       = "",
    role        = "",
    notes       = "",
    activeField = nil,
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

-- ─── Message handling → MessageManager.lua ────────────────────────────────────
-- receiveMessage, migrateThreadToContact, sendMessage, sendContactCard

-- ─── Save helpers ─────────────────────────────────────────────────────────────
-- getSaveDir, saveInvoices, savePlayerData, loadPlayerData → PhoneSave.lua

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
            local entry        = RoleplayPhone:getOrCreateRegistryEntry(hostUniqueId, hostPhone, hostNickname)
            local filename     = RoleplayPhone:buildPlayerFilename(hostNickname, entry.fileId)
            RoleplayPhone:savePlayerData(filename,
                ContactManager.contacts,
                RoleplayPhone.messages,
                RoleplayPhone.callHistory)
            -- Save each connected client's data file
            for userId, info in pairs(RoleplayPhone.onlineUsers) do
                if userId ~= RoleplayPhone:getMyUserId() and info.uniqueId and info.uniqueId ~= "" then
                    local clientEntry    = RoleplayPhone:getOrCreateRegistryEntry(info.uniqueId, info.phone, info.name)
                    local clientFilename = RoleplayPhone:buildPlayerFilename(info.name, clientEntry.fileId)
                    local clientKey      = info.uniqueId
                    local clientContacts = ContactManager.userContacts[clientKey] or {}
                    local clientMessages = RoleplayPhone.playerMessages and RoleplayPhone.playerMessages[clientKey] or {}
                    local clientCalls    = RoleplayPhone.playerCalls    and RoleplayPhone.playerCalls[clientKey]    or {}
                    RoleplayPhone:savePlayerData(clientFilename, clientContacts, clientMessages, clientCalls)
                    -- Update cache so offline save reflects latest data
                    RoleplayPhone.offlinePlayerData[clientKey] = nil
                end
            end
            -- Re-save known offline players so tempsavegame gets their files too
            for uniqueId, cached in pairs(RoleplayPhone.offlinePlayerData) do
                RoleplayPhone:savePlayerData(cached.filename, cached.contacts, cached.messages, cached.callHistory)
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
            local clientEntry    = RoleplayPhone:getOrCreateRegistryEntry(info.uniqueId, info.phone, info.name)
            local clientFilename = RoleplayPhone:buildPlayerFilename(info.name, clientEntry.fileId)
            local clientKey      = info.uniqueId
            local clientContacts = ContactManager.userContacts[clientKey] or {}
            local clientMessages = RoleplayPhone.playerMessages and RoleplayPhone.playerMessages[clientKey] or {}
            local clientCalls    = RoleplayPhone.playerCalls    and RoleplayPhone.playerCalls[clientKey]    or {}
            RoleplayPhone:savePlayerData(clientFilename, clientContacts, clientMessages, clientCalls)
            -- Snapshot into offlinePlayerData so the next save re-writes their file to tempsavegame.
            -- Without this, a solo-session save after disconnect will not include their file.
            RoleplayPhone.offlinePlayerData[clientKey] = {
                filename    = clientFilename,
                contacts    = clientContacts,
                messages    = clientMessages,
                callHistory = clientCalls,
            }
            print(string.format("[RoleplayPhone] Saved + cached offline data on disconnect: %s", info.name or tostring(userId)))
        end
        print(string.format("[RoleplayPhone] Removed stale onlineUser: %s", tostring(userId)))
        RoleplayPhone.onlineUsers[userId] = nil
    end
end)