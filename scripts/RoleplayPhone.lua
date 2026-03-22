-- scripts/RoleplayPhone.lua
-- RP Phone UI - Draw-based, no XML GUI required
-- Pattern: Mission00 appended functions

-- Capture mod directory immediately at script load time
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
}

-- ─── Tab constants ────────────────────────────────────────────────────────────
RoleplayPhone.TAB = {
    INBOX  = 1,
    OUTBOX = 2,
}

-- ─── Runtime state ────────────────────────────────────────────────────────────
RoleplayPhone.state          = RoleplayPhone.STATE.CLOSED
RoleplayPhone.isOpen         = false   -- true while phone UI is visible (context pushed)
RoleplayPhone.phoneContextEventId = nil  -- eventId of close action registered in RI_PHONE_UI context
RoleplayPhone.currentTab     = RoleplayPhone.TAB.INBOX
RoleplayPhone.mouseX         = 0
RoleplayPhone.mouseY         = 0
RoleplayPhone.whiteOverlay   = nil
RoleplayPhone.wallpaper      = nil  -- home screen wallpaper texture
RoleplayPhone.iconInvoices   = nil
RoleplayPhone.iconContacts   = nil
RoleplayPhone.iconCalls      = nil
RoleplayPhone.iconSettings              = nil
RoleplayPhone.callActionEventId         = nil
RoleplayPhone.incomingCallActionEventId = nil
RoleplayPhone.backspaceEventId          = nil
RoleplayPhone.callHistory               = {}  -- current session only, cleared on game restart
RoleplayPhone.hitboxes       = {}   -- rebuilt every draw frame

-- ─── Aspect ratio correction ──────────────────────────────────────────────────
-- FS25 normalised coords: 0-1 on both axes. On ultrawide, same x-range covers
-- far more physical pixels, stretching everything horizontally.
-- arScale corrects widths:  correctedW = baseW * arScale
-- actualAR corrects shapes: squareH   = sideW * actualAR
RoleplayPhone.arScale  = 1.0      -- (16/9) / actual — set in init()
RoleplayPhone.actualAR = 16 / 9   -- screenW / screenH — set in init()

-- ─── Home screen page system ──────────────────────────────────────────────────
RoleplayPhone.homePage       = 1    -- current page (1 = home with clock/weather)
RoleplayPhone.homePageCount  = 2    -- total pages (grows as we add apps)

-- ─── App grid definition (page 2+) ───────────────────────────────────────────
-- Each entry: { id, label, color {r,g,b}, icon (optional overlay ref) }
RoleplayPhone.GRID_APPS = {
    -- Page 2
    { id="weather",  label="Weather",  page=2, color={0.15, 0.45, 0.75}, icon="iconWeather" },
    { id="market",   label="Market",   page=2, color={0.20, 0.60, 0.30}, icon="iconMarket"  },
}

-- ─── Dock apps (always visible, bottom) ──────────────────────────────────────
-- These are the 3 core apps pinned to the dock on every page
RoleplayPhone.DOCK_APPS = {
    { id="invoices", label="Invoices", color={0.25, 0.25, 0.30} },
    { id="contacts", label="Contacts", color={0.10, 0.50, 0.30} },
    { id="calls",    label="Calls",    color={0.10, 0.30, 0.65} },
    { id="settings", label="Settings", color={0.35, 0.25, 0.45} },
}

-- ─── Player settings (cosmetic, per-player, saved to modSettings XML) ─────────
RoleplayPhone.settings = {
    timeFormat     = "12",   -- "12" or "24"
    tempUnit       = "F",    -- "F" or "C"
    wallpaperIndex = 1,      -- 1-6 colour swatch
    batteryVisible = true,   -- show battery widget in status bar
}

-- ─── Battery widget (cosmetic, purely visual) ─────────────────────────────────
RoleplayPhone.battery = {
    level      = 100.0,   -- 0-100
    drainRate  = 0.04,    -- % per second while open (~40 min to drain)
    callRate   = 0.08,    -- % per second during active call (~20 min to drain)
    chargeRate = 0.20,    -- % per second while closed (~8 min to full)
}

-- ─── Wallpaper colour palettes ────────────────────────────────────────────────
-- Index 1 = Countryside (uses wallpaper.dds texture if present)
-- Index 2+ = solid colour swatches
RoleplayPhone.WALLPAPERS = {
    { name="Countryside", texture=true,  r=0.08, g=0.12, b=0.06 },  -- 1 fallback tint if no .dds
    { name="Midnight",    texture=false, r=0.07, g=0.07, b=0.14 },  -- 2
    { name="Forest",      texture=false, r=0.04, g=0.14, b=0.07 },  -- 3
    { name="Slate",       texture=false, r=0.10, g=0.10, b=0.10 },  -- 4
    { name="Ember",       texture=false, r=0.16, g=0.07, b=0.04 },  -- 5
    { name="Dusk",        texture=false, r=0.14, g=0.05, b=0.18 },  -- 6
    { name="Ocean",       texture=false, r=0.04, g=0.12, b=0.20 },  -- 7
}

-- Create invoice form state
RoleplayPhone.form = {
    toFarmIndex   = 1,      -- index into available farms list
    categoryIndex = 1,      -- index into InvoiceManager.categories
    amount        = "",
    description   = "",
    notes         = "",
    dueDate       = "",
    activeField   = nil,    -- "amount" | "description" | "notes" | "dueDate"
}

RoleplayPhone.selectedContact = nil   -- index into ContactManager.contacts

-- ─── Message storage & compose ────────────────────────────────────────────────
-- messages[contactIndex] = { { fromFarmId, senderName, text, gameDay, sent }, ... }
RoleplayPhone.messages       = {}
RoleplayPhone.messageCompose = { text = "", active = false }
RoleplayPhone.unreadMessages = {}  -- unreadMessages[contactIndex] = count

-- ─── Call state ───────────────────────────────────────────────────────────────
RoleplayPhone.call = {
    contactName  = "",    -- display name of the other party
    contactNum   = "",    -- their phone number
    toFarmId     = 0,     -- farmId of the other party
    fromFarmId   = 0,     -- farmId of caller (for incoming)
    startTime    = 0,     -- g_currentMission.time when call connected
    ringSample   = nil,   -- sound handle
    prevState    = 7,     -- STATE to return to after call (default CONTACT_DETAIL)
}

RoleplayPhone.contactForm = {
    name        = "",
    farmName    = "",
    phone       = "",
    notes       = "",
    activeField = nil,  -- "name" | "farmName" | "phone" | "notes"
}


-- ─── Layout: small phone (HOME screen) ───────────────────────────────────────
RoleplayPhone.PHONE = {
    x = 0.390, y = 0.10,
    w = 0.220, h = 0.55,
}

-- ─── Layout: big screen (INVOICES, CONTACTS, PING) ───────────────────────────
RoleplayPhone.BIG = {
    x = 0.390, y = 0.10,
    w = 0.220, h = 0.55,
}

-- ─── Phone frame texture — screen hole pixel coords within 900×900 image ─────
-- The transparent screen area in Test_Phone_Pic.dds is approximately here.
-- Tune these 4 numbers until the frame bezel lines up with the screen edges.
--   L = pixels from LEFT  edge of image to LEFT  side of screen hole
--   R = pixels from LEFT  edge of image to RIGHT side of screen hole
--   B = pixels from BOTTOM edge of image to BOTTOM of screen hole
--   T = pixels from BOTTOM edge of image to TOP    of screen hole
RoleplayPhone.FRAME_SCREEN = {
    L = 38,  R = 474,
    B = 100, T = 914,
    imgW = 512, imgH = 1024,
}

-- ─── Init ─────────────────────────────────────────────────────────────────────
function RoleplayPhone:init()
    local tex = modDirectory .. "textures/"
    self.whiteOverlay = createImageOverlay(tex .. "white.dds")
    self.wallpaper    = createImageOverlay(tex .. "wallpaper.dds")
    self.iconInvoices = createImageOverlay(tex .. "icon_invoices.dds")
    self.iconContacts = createImageOverlay(tex .. "icon_contacts.dds")
    self.iconCalls    = createImageOverlay(tex .. "recent_call.dds")
    self.iconSettings = createImageOverlay(tex .. "icon_settings.dds")
    self.iconWeather  = createImageOverlay(tex .. "weather.dds")
    self.iconMarket   = nil  -- no icon yet
    self.phoneFrame   = createImageOverlay(tex .. "phone_frame.dds")
    if self.phoneFrame == nil or self.phoneFrame == 0 then
        self.phoneFrame = nil
        print("[RoleplayPhone] WARN: Test_Phone_Pic.dds not found - using drawRect bezel")
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

    -- Load ring tone (optional — won't error if missing)
    local soundFile = modDirectory .. "sounds/ringtone.ogg"
    self.ringSample = createSample("RP_ringtone")
    if self.ringSample and self.ringSample ~= 0 then
        loadSample(self.ringSample, soundFile, false)  -- false = not 3D positional
        print("[RoleplayPhone] Ringtone loaded OK")
    else
        self.ringSample = nil
        print("[RoleplayPhone] WARN: ringtone.ogg not found - calls will be silent")
    end

    -- ─── Aspect ratio detection ──────────────────────────────────────────────
    -- g_screenWidth / g_screenHeight are FS25 globals, available after engine init.
    -- Reference aspect ratio is 16:9 — all layout constants were authored for it.
    local sw = g_screenWidth  or 1920
    local sh = g_screenHeight or 1080
    self.actualAR = sw / sh                       -- e.g. 1.778 (16:9) or 3.556 (32:9)
    self.arScale  = (16 / 9) / self.actualAR      -- 1.0 on 16:9, ~0.5 on 32:9
    print(string.format("[RoleplayPhone] Screen %dx%d  AR=%.3f  arScale=%.3f",
        sw, sh, self.actualAR, self.arScale))

    -- Apply aspect correction to layout rectangles
    local baseW = 0.220   -- designed for 16:9
    self.PHONE.w = baseW * self.arScale
    self.PHONE.x = 0.5 - self.PHONE.w / 2
    self.BIG.w   = baseW * self.arScale
    self.BIG.x   = 0.5 - self.BIG.w / 2

    -- Init notification system — shares our white overlay for drawing
    NotificationManager:init(self.whiteOverlay, modDirectory, self.arScale)

    -- Load per-player cosmetic settings (time format, temp, wallpaper, battery)
    self:loadSettings()
end

function RoleplayPhone:loadSavedData()
    if g_server == nil then return end
    if not g_currentMission or not g_currentMission.missionInfo then return end
    local dir = g_currentMission.missionInfo.savegameDirectory
    if not dir then return end

    local filename = dir .. "/roleplayInvoices.xml"
    local xmlFile  = loadXMLFile("roleplayInvoicesXML", filename)
    if xmlFile and xmlFile ~= 0 then
        InvoiceSave:loadFromXML(xmlFile, "roleplayInvoices")
        delete(xmlFile)
        local count = 0
        for _ in pairs(InvoiceManager.invoices) do count = count + 1 end
        print(string.format("[RoleplayPhone] Loaded %d invoices from disk", count))
    else
        print("[RoleplayPhone] No saved invoices found (new save or first run)")
    end

    -- Sync host's own contacts into farmContacts so they're available for connect sync
    local hostFarmId = self:getMyFarmId()
    if hostFarmId and hostFarmId > 0 then
        ContactManager.farmContacts[hostFarmId] = ContactManager.contacts
        print(string.format("[RoleplayPhone] Bootstrapped farmContacts[%d] with %d contacts",
            hostFarmId, #ContactManager.contacts))
    end
end

-- ─── Open / Close ─────────────────────────────────────────────────────────────
function RoleplayPhone:toggle()
    print("[RoleplayPhone] toggle() called — state=" .. tostring(self.state))
    -- Debounce: axisType=HALF fires on both key press AND release (~100ms apart).
    -- Use getTimeSec() (real clock) not g_currentMission.time — the latter can
    -- return 0 or not advance on MP clients, causing debounce to never expire.
    local now = getTimeSec()
    if self.lastToggleTime and (now - self.lastToggleTime) < 0.4 then return end
    self.lastToggleTime = now

    if self.state == self.STATE.CLOSED then
        self.state = self.STATE.HOME
        self.isOpen = true
        self:clearFarmCache()  -- refresh farm list on each open

        -- Show cursor and freeze player input (purely client-local, MP-safe)
        -- setContext pushes an empty context so ALL game input is blocked.
        -- We then re-register only RI_OPEN_PHONE in that context so F6 can close.
        g_inputBinding:setShowMouseCursor(true)
        g_inputBinding:setContext("RI_PHONE_UI", true, false)
        local _, evId = g_inputBinding:registerActionEvent(
            "RI_OPEN_PHONE", self, self.close,
            false,  -- triggerUp:     don't fire on key release
            true,   -- triggerDown:   fire on key press
            false,  -- triggerAlways: don't fire every frame
            true    -- startActive:   enabled immediately
        )
        if evId then
            g_inputBinding:setActionEventTextVisibility(evId, false)
            self.phoneContextEventId = evId
        end

        -- Register backspace in RI_PHONE_UI context so it works while phone is open
        local _, bsId = g_inputBinding:registerActionEvent(
            "RI_BACKSPACE", self, self.handleBackspace,
            false, true, false, true)
        if bsId then
            g_inputBinding:setActionEventTextVisibility(bsId, false)
            self.backspaceEventId = bsId
            print("[RoleplayPhone] RI_BACKSPACE registered OK: " .. tostring(bsId))
        else
            print("[RoleplayPhone] WARNING: RI_BACKSPACE registration FAILED")
        end

        -- On first open after connecting, check for pending invoices and notify
        if self.pendingInboxCheck then
            self.pendingInboxCheck = false
            local myFarmId = self:getMyFarmId()
            local unpaid = 0
            for _, inv in pairs(InvoiceManager.invoices) do
                if inv.toFarmId == myFarmId and inv.status == "PENDING" then
                    unpaid = unpaid + 1
                end
            end
            if unpaid > 0 then
                local msg = unpaid == 1
                    and "You have 1 unpaid invoice."
                    or  string.format("You have %d unpaid invoices.", unpaid)
                NotificationManager:push("info", msg)
            end
        end

        -- Clear badge when phone opens
        NotificationManager:clearBadge()
        print("[RoleplayPhone] Opened")
    else
        self:close()
    end
end

function RoleplayPhone:close()
    if not self.isOpen then return end  -- prevent double-close
    self.isOpen = false
    self.state = self.STATE.CLOSED
    self.form.activeField = nil

    -- Hide cursor and restore full player input
    g_inputBinding:setShowMouseCursor(false)
    if self.phoneContextEventId then
        g_inputBinding:removeActionEvent(self.phoneContextEventId)
        self.phoneContextEventId = nil
    end
    if self.backspaceEventId then
        g_inputBinding:removeActionEvent(self.backspaceEventId)
        self.backspaceEventId = nil
    end
    g_inputBinding:revertContext(true)

    print("[RoleplayPhone] Closed")
end

function RoleplayPhone:goHome()
    self.state = self.STATE.HOME
    self.form.activeField = nil
end

-- ─── Store an incoming message in the right thread ────────────────────────────
function RoleplayPhone:receiveMessage(contactKey, fromFarmId, senderName, text, gameDay, sent)
    if not self.messages[contactKey] then
        self.messages[contactKey] = {}
    end
    table.insert(self.messages[contactKey], {
        fromFarmId  = fromFarmId,
        senderName  = senderName,
        text        = text,
        gameDay     = gameDay or 0,
        sent        = sent or false,
    })
    -- Notify if not currently viewing this thread
    if sent then return end  -- we sent it, no notification needed
    local viewing = ((self.state == self.STATE.CONTACT_DETAIL or self.state == self.STATE.MESSAGE_THREAD)
                     and self.selectedContact == contactKey)
    if not viewing then
        -- Look up contact name for friendlier notification
        local displayName = senderName
        for _, c in ipairs(ContactManager.contacts) do
            if c.farmName and string.lower(c.farmName) == string.lower(senderName) then
                displayName = c.name or senderName
                break
            end
        end
        self.unreadMessages[contactKey] = (self.unreadMessages[contactKey] or 0) + 1
        NotificationManager:push("ping",
            string.format("MSG from %s: %s", displayName, text))
    end
end

-- ─── Send a message from the current contact thread ──────────────────────────
function RoleplayPhone:sendMessage()
    local text = self.messageCompose.text
    if not text or text == "" then return end
    if not self.selectedContact then return end

    local c = ContactManager:getContact(self.selectedContact)
    if not c then return end

    -- Resolve recipient farmId
    local toFarmId = self:resolveFarmId(c.farmName)
    if toFarmId == 0 then
        NotificationManager:push("rejected",
            string.format("Can't find farm '%s' online.", c.farmName or "?"))
        return
    end

    local myFarmId = self:getMyFarmId()
    local myName   = self:getFarmName(myFarmId)
    local gameDay   = (g_currentMission and g_currentMission.environment
                       and g_currentMission.environment.currentDay) or 0

    -- Store locally as a sent message
    self:receiveMessage(self.selectedContact, myFarmId, myName, text, gameDay, true)

    -- Broadcast over network
    local evt = RI_MessageEvent.new(myFarmId, toFarmId, myName, text, gameDay)
    if g_server ~= nil then
        g_server:broadcastEvent(evt)
    elseif g_client ~= nil then
        g_client:getServerConnection():sendEvent(evt)
    end

    -- Clear compose
    self.messageCompose.text = ""
    print(string.format("[RoleplayPhone] Message sent to Farm %d (%s): %s",
        toFarmId, c.farmName, text))
end

-- ─── Farm lookup helpers (use g_farmManager directly — reliable on host AND client) ──

-- ─── CALL: initiate outgoing call from contact thread ─────────────────────────
function RoleplayPhone:startCall()
    if not self.selectedContact then return end
    local c = ContactManager:getContact(self.selectedContact)
    if not c then return end

    local toFarmId = self:resolveFarmId(c.farmName)
    if toFarmId == 0 then
        NotificationManager:push("rejected",
            string.format("Can't reach '%s' - are they online?", c.farmName or "?"))
        return
    end

    local myFarmId = self:getMyFarmId()
    local myName   = self:getFarmName(myFarmId)

    self.call.contactName = c.name or c.farmName
    self.call.contactNum  = c.phone or ""
    self.call.toFarmId    = toFarmId
    self.call.fromFarmId  = myFarmId
    self.call.startTime   = 0
    self.call.prevState   = self.STATE.CLOSED
    self.state = self.STATE.CALL_OUTGOING
    self.callRingTimer    = 0
    -- Record outgoing call
    table.insert(self.callHistory, 1, { direction="outgoing", name=self.call.contactName, gameTime=g_currentMission and g_currentMission.time or 0 })

    -- Close the phone UI context so player keeps full movement during call
    -- The call popup draws independently above the CLOSED guard in draw()
    self.isOpen = false
    g_inputBinding:setShowMouseCursor(false)
    if self.phoneContextEventId then
        g_inputBinding:removeActionEvent(self.phoneContextEventId)
        self.phoneContextEventId = nil
    end
    g_inputBinding:revertContext(true)

    local evt = RI_CallEvent.new("ring", myFarmId, toFarmId, myName, "")
    if g_server ~= nil then g_server:broadcastEvent(evt)
    elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end
    print(string.format("[RoleplayPhone] Calling Farm %d (%s)...", toFarmId, c.farmName))
end

-- ─── CALL: incoming ──────────────────────────────────────────────────────────
function RoleplayPhone:onIncomingCall(fromFarmId, callerName, callerNum)
    if self.state == self.STATE.CALL_OUTGOING
    or self.state == self.STATE.CALL_INCOMING
    or self.state == self.STATE.CALL_ACTIVE then
        local myFarmId = self:getMyFarmId()
        local evt = RI_CallEvent.new("decline", myFarmId, fromFarmId, "", "")
        if g_server ~= nil then g_server:broadcastEvent(evt)
        elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end
        return
    end
    -- Try to find caller in our contacts by farm name for a friendlier display name
    local displayName = callerName
    for _, c in ipairs(ContactManager.contacts) do
        if c.farmName and string.lower(c.farmName) == string.lower(callerName) then
            displayName = c.name or callerName
            break
        end
    end
    self.call.contactName = displayName
    self.call.contactNum  = callerNum
    self.call.fromFarmId  = fromFarmId
    self.call.toFarmId    = self:getMyFarmId()
    self.call.startTime   = 0
    self.call.prevState   = self.state
    self.state = self.STATE.CALL_INCOMING
    self.callRingTimer    = 0
    -- Record incoming call
    table.insert(self.callHistory, 1, { direction="incoming", name=self.call.contactName, gameTime=g_currentMission and g_currentMission.time or 0 })

    -- Popup draws independently, no context push needed — player keeps full movement
    -- Don't set isOpen so _restoreAfterCall won't try to revertContext
    if self.ringSample and self.ringSample ~= 0 then
        playSample(self.ringSample, 0, 1.0, 0, 0, 0)
    end
    print(string.format("[RoleplayPhone] Incoming call from %s", callerName))
end

function RoleplayPhone:onCallAnswered()
    self:stopRingtone()
    self.call.startTime = g_currentMission and g_currentMission.time or 0
    self.state = self.STATE.CALL_ACTIVE
end

function RoleplayPhone:onCallDeclined()
    self:stopRingtone()
    NotificationManager:push("rejected", "Call declined.")
    self:_restoreAfterCall()
end

function RoleplayPhone:onCallEnded()
    self:stopRingtone()
    -- If we were still ringing when the other side ended it, that's a missed call
    if self.state == self.STATE.CALL_INCOMING then
        local name = self.call.contactName or "Unknown"
        NotificationManager:push("info", string.format("Missed call from %s", name))
        -- Record missed call
        table.insert(self.callHistory, 1, { direction="missed", name=name, gameTime=g_currentMission and g_currentMission.time or 0 })
    end
    self:_restoreAfterCall()
end

-- Shared cleanup: called by endCall, onCallEnded, onCallDeclined
function RoleplayPhone:_restoreAfterCall()
    local prevState = self.call.prevState or self.STATE.HOME
    self:stopRingtone()
    self.call = { prevState = self.STATE.HOME, startTime = 0, fromFarmId = 0, toFarmId = 0, contactName = "", contactNum = "" }
    if prevState == self.STATE.CLOSED or not self.isOpen then
        -- If isOpen is already false, context was cleaned up by startCall — don't revert again
        if self.isOpen then
            g_inputBinding:setShowMouseCursor(false)
            if self.phoneContextEventId then
                g_inputBinding:removeActionEvent(self.phoneContextEventId)
                self.phoneContextEventId = nil
            end
            if self.incomingCallActionEventId then
                g_inputBinding:removeActionEvent(self.incomingCallActionEventId)
                self.incomingCallActionEventId = nil
            end
            g_inputBinding:revertContext(true)
        end
        self.state  = self.STATE.CLOSED
        self.isOpen = false
    else
        self.state = prevState
    end
end

function RoleplayPhone:answerCall()
    self:stopRingtone()
    self.call.startTime = g_currentMission and g_currentMission.time or 0
    self.state = self.STATE.CALL_ACTIVE
    local myFarmId = self:getMyFarmId()
    local evt = RI_CallEvent.new("answer", myFarmId, self.call.fromFarmId, "", "")
    if g_server ~= nil then g_server:broadcastEvent(evt)
    elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end
end

function RoleplayPhone:endCall()
    self:stopRingtone()
    local myFarmId = self:getMyFarmId()
    local remoteFarm = (self.call.fromFarmId == myFarmId)
                       and self.call.toFarmId or self.call.fromFarmId
    -- Send "decline" if still ringing, "end" if call was active
    local evtType = (self.state == self.STATE.CALL_INCOMING) and "decline" or "end"
    local evt = RI_CallEvent.new(evtType, myFarmId, remoteFarm, "", "")
    if g_server ~= nil then g_server:broadcastEvent(evt)
    elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end
    self:_restoreAfterCall()
end

function RoleplayPhone:stopRingtone()
    if self.ringSample and self.ringSample ~= 0 then
        stopSample(self.ringSample, 0, 0)
    end
end

-- Pattern from working FS25 mods: g_farmManager:getFarmByUserId(playerUserId)
-- playerUserId is always set on both host and client
function RoleplayPhone:getMyFarmId()
    -- Return cached value if it's still fresh (re-check every 5 seconds)
    local now = getTimeSec()
    if self.cachedFarmId and self.cachedFarmIdTime and (now - self.cachedFarmIdTime) < 30 then
        return self.cachedFarmId
    end

    local farmId = nil

    -- Primary: the correct FS25 pattern used in LeaseToOwn and other working mods
    if g_farmManager and g_currentMission and g_currentMission.playerUserId then
        local farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
        if farm and farm.farmId and farm.farmId > 0 then
            farmId = farm.farmId
        end
    end
    -- Fallback 1: playerFarmId (works on host, may be nil on client)
    if not farmId and g_currentMission and g_currentMission.playerFarmId
    and g_currentMission.playerFarmId > 0 then
        farmId = g_currentMission.playerFarmId
    end
    -- Fallback 2: player object farmId
    if not farmId and g_currentMission and g_currentMission.player
    and g_currentMission.player.farmId
    and g_currentMission.player.farmId > 0 then
        farmId = g_currentMission.player.farmId
    end

    if not farmId then
        farmId = 1
    end

    -- Cache the result
    self.cachedFarmId = farmId
    self.cachedFarmIdTime = now
    return farmId
end

-- ─── Save invoices directly (no longer depends on g_roleplayInvoices) ────────
function RoleplayPhone:saveInvoices()
    if not g_currentMission or not g_currentMission.missionInfo then return end
    local dir = g_currentMission.missionInfo.savegameDirectory
    if not dir then return end

    local filename = dir .. "/roleplayInvoices.xml"
    local xmlFile  = createXMLFile("roleplayInvoicesXML", filename, "roleplayInvoices")
    if xmlFile == 0 then return end

    InvoiceSave:saveToXML(xmlFile, "roleplayInvoices")
    saveXMLFile(xmlFile)
    delete(xmlFile)
    print("[RoleplayPhone] Invoices saved")
end

-- ─── Drawing helpers ──────────────────────────────────────────────────────────
function RoleplayPhone:drawRect(x, y, w, h, r, g, b, a)
    if not self.whiteOverlay or self.whiteOverlay == 0 then return end
    setOverlayColor(self.whiteOverlay, r, g, b, a or 1.0)
    renderOverlay(self.whiteOverlay, x, y, w, h)
end

function RoleplayPhone:hitTest(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

-- ─── Time formatter (respects 12/24hr player setting) ────────────────────────
function RoleplayPhone:formatTime(hrs, mins)
    if self.settings.timeFormat == "24" then
        return string.format("%02d:%02d", hrs, mins)
    else
        local suffix = hrs >= 12 and "PM" or "AM"
        local h12    = hrs % 12
        if h12 == 0 then h12 = 12 end
        return string.format("%d:%02d %s", h12, mins, suffix)
    end
end

-- ─── Battery update (call from Mission00.update) ──────────────────────────────
function RoleplayPhone:updateBattery(dt)
    local bat = self.battery
    if self.state ~= self.STATE.CLOSED then
        -- drain faster during active call
        local rate = (self.state == self.STATE.CALL_ACTIVE)
            and bat.callRate or bat.drainRate
        bat.level = math.max(0, bat.level - rate * dt)
    else
        bat.level = math.min(100, bat.level + bat.chargeRate * dt)
    end
end

-- Auto-timeout unanswered calls after 30 seconds
function RoleplayPhone:updateCallTimeout(dt)
    if self.state ~= self.STATE.CALL_OUTGOING
    and self.state ~= self.STATE.CALL_INCOMING then return end

    self.callRingTimer = (self.callRingTimer or 0) + dt
    if self.callRingTimer >= 30000 then  -- 30 seconds in ms
        self.callRingTimer = 0
        local myFarmId = self:getMyFarmId()
        -- Send end event to the other side
        local evt = RI_CallEvent.new("end", myFarmId, self.call.toFarmId or self.call.fromFarmId, "", "")
        if g_server ~= nil then g_server:broadcastEvent(evt)
        elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end
        -- Show missed call notification for incoming side
        if self.state == self.STATE.CALL_INCOMING then
            local name = self.call.contactName or "Unknown"
            NotificationManager:push("info", string.format("Missed call from %s", name))
        end
        self:_restoreAfterCall()
    end
end

function RoleplayPhone:addHitbox(id, x, y, w, h, data)
    table.insert(self.hitboxes, { id=id, x=x, y=y, w=w, h=h, data=data })
end

-- Draw a button and register its hitbox
function RoleplayPhone:drawButton(id, x, y, w, h, label, br, bg, bb, textSize)
    self:drawRect(x, y, w, h, br, bg, bb, 1.0)
    -- Top highlight
    self:drawRect(x, y + h - 0.002, w, 0.002, br+0.15, bg+0.15, bb+0.15, 0.3)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(false)
    setTextColor(1, 1, 1, 0.95)
    renderText(x + w/2, y + h*0.32, textSize or 0.013, label)
    self:addHitbox(id, x, y, w, h, {})
end

-- Draw an input field box (highlights if active)
function RoleplayPhone:drawField(id, x, y, w, h, label, value, active)
    local br = active and 0.15 or 0.10
    local bg = active and 0.32 or 0.14
    local bb = active and 0.55 or 0.20
    -- Background
    self:drawRect(x, y, w, h, br, bg, bb, 1.0)
    -- Border (brighter if active)
    local alpha = active and 0.9 or 0.4
    self:drawRect(x,       y,       w,    0.002, 0.5, 0.6, 0.8, alpha)
    self:drawRect(x,       y+h-0.002, w,  0.002, 0.5, 0.6, 0.8, alpha)
    self:drawRect(x,       y,       0.002, h,    0.5, 0.6, 0.8, alpha)
    self:drawRect(x+w-0.002, y,     0.002, h,    0.5, 0.6, 0.8, alpha)
    -- Label
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(0.6, 0.7, 0.8, 0.9)
    renderText(x + 0.008, y + h - 0.016, 0.010, label)
    -- Value (with cursor if active)
    local display = value
    if active then display = value .. "|" end
    setTextColor(1, 1, 1, 1)
    renderText(x + 0.008, y + 0.008, 0.013, display)
    -- Register hitbox
    self:addHitbox(id, x, y, w, h, {})
end

-- ─── Status badge helper ──────────────────────────────────────────────────────
function RoleplayPhone:getStatusColor(status)
    if status == "PAID"     then return 0.10, 0.55, 0.20  end  -- green
    if status == "OVERDUE"  then return 0.70, 0.15, 0.15  end  -- red
    if status == "DUE"      then return 0.70, 0.45, 0.05  end  -- orange
    if status == "REJECTED" then return 0.55, 0.10, 0.10  end  -- dark red
    return 0.30, 0.30, 0.38                                     -- gray (PENDING)
end

-- ─── Get farms helper ─────────────────────────────────────────────────────────
-- ─── Resolve a farm name to a farmId ─────────────────────────────────────────
-- Checks g_farmManager (works on both host AND client in FS25),
-- then falls back to knownFarms (sent by host on connect).
function RoleplayPhone:resolveFarmId(farmName)
    if not farmName or farmName == "" then return 0 end
    local lower = string.lower(farmName)
    -- g_farmManager is the correct global — g_currentMission.farmManager is often nil
    if g_farmManager then
        for _, farm in pairs(g_farmManager:getFarms()) do
            if farm.name and string.lower(farm.name) == lower then
                return farm.farmId
            end
        end
    end
    if self.knownFarms then
        for _, farm in ipairs(self.knownFarms) do
            if farm.name and string.lower(farm.name) == lower then
                return farm.farmId
            end
        end
    end
    return 0
end

function RoleplayPhone:getAvailableFarms()
    if self._farmCache and #self._farmCache > 0 then
        return self._farmCache
    end

    local result  = {}
    local seenIds = {}

    -- Build whitelist from farms.xml — only real player farms appear here
    -- This is the ground truth; g_farmManager also contains internal/spectator farms
    local xmlWhitelist = {}
    if g_server ~= nil and g_currentMission and g_currentMission.missionInfo then
        local dir = g_currentMission.missionInfo.savegameDirectory
        if dir then
            local xmlFile = loadXMLFile("farmsXML", dir .. "/farms.xml")
            if xmlFile and xmlFile ~= 0 then
                local i = 0
                while true do
                    local key    = string.format("farms.farm(%d)", i)
                    if not hasXMLProperty(xmlFile, key) then break end
                    local farmId = getXMLInt(xmlFile, key .. "#farmId")
                    local name   = getXMLString(xmlFile, key .. "#name")
                    if farmId and farmId > 0 then
                        xmlWhitelist[farmId] = (name and name ~= "") and name
                                               or ("Farm " .. tostring(farmId))
                    end
                    i = i + 1
                end
                delete(xmlFile)
            end
        end
    end

    -- Primary: g_farmManager — but only include farms that are in farms.xml
    if g_farmManager then
        for _, farm in pairs(g_farmManager:getFarms()) do
            local fid = farm.farmId
            if fid and fid > 0 and xmlWhitelist[fid] then
                table.insert(result, {
                    farmId = fid,
                    name   = (farm.name and farm.name ~= "") and farm.name
                                or xmlWhitelist[fid]
                })
                seenIds[fid] = true
            end
        end
    end

    -- Fill in any farms.xml entries that g_farmManager didn't return (offline farms)
    for fid, name in pairs(xmlWhitelist) do
        if not seenIds[fid] then
            table.insert(result, { farmId=fid, name=name })
            seenIds[fid] = true
        end
    end

    -- Client fallback: knownFarms sent by host on connect
    if self.knownFarms then
        for _, farm in ipairs(self.knownFarms) do
            if not seenIds[farm.farmId] then
                table.insert(result, farm)
                seenIds[farm.farmId] = true
            end
        end
    end

    if #result == 0 then
        table.insert(result, { farmId=1, name="Farm 1" })
    end
    table.sort(result, function(a, b) return a.farmId < b.farmId end)
    self._farmCache = result
    return result
end

function RoleplayPhone:clearFarmCache()
    self._farmCache = nil
end

function RoleplayPhone:getFarmName(farmId)
    if not farmId then return "Unknown" end
    if g_farmManager then
        local f = g_farmManager:getFarmById(farmId)
        if f and f.name and f.name ~= "" then return f.name end
    end
    -- Fall back to knownFarms (sent by host on connect, includes offline farms)
    if self.knownFarms then
        for _, f in ipairs(self.knownFarms) do
            if f.farmId == farmId then return f.name end
        end
    end
    return "Farm " .. tostring(farmId)
end

-- ─── Main draw dispatcher ─────────────────────────────────────────────────────
function RoleplayPhone:draw()
    -- HUD icon and popups always draw, even when phone is closed
    NotificationManager:draw()

    -- Call popup draws regardless of phone open state — player keeps full movement
    if self.state == self.STATE.CALL_OUTGOING
    or self.state == self.STATE.CALL_INCOMING
    or self.state == self.STATE.CALL_ACTIVE then
        self:drawCallScreen()
        return
    end

    if self.state == self.STATE.CLOSED then return end
    self.hitboxes = {}  -- clear hitboxes each frame

    if self.state == self.STATE.HOME then
        self:drawPhoneHome()
    elseif self.state == self.STATE.INVOICES_LIST then
        self:drawBigScreen()
        self:drawInvoicesList()
    elseif self.state == self.STATE.INVOICE_CREATE then
        self:drawBigScreen()
        self:drawCreateInvoice()
    elseif self.state == self.STATE.INVOICE_DETAIL then
        self:drawBigScreen()
        self:drawInvoiceDetail()
     elseif self.state == self.STATE.CONTACTS then
        self:drawContacts()
    elseif self.state == self.STATE.CONTACT_DETAIL then
        self:drawContactDetail()
    elseif self.state == self.STATE.MESSAGE_THREAD then
        self:drawMessageThread()
    elseif self.state == self.STATE.CONTACT_CREATE then
        self:drawContactCreate()
    elseif self.state == self.STATE.CALLS then
        self:drawCallsList()
    elseif self.state == self.STATE.SETTINGS then
        self:drawSettings()
    elseif self.state == self.STATE.WEATHER then
        self:drawBigScreen()
        self:drawWeatherApp()
    end

    -- Phone frame overlay: drawn LAST on top of ALL screens
    self:drawPhoneFrame()
end

-- ─── Permission system ───────────────────────────────────────────────────────
-- Uses FS25's native farm manager permission — the same system the game uses
-- for buy/sell vehicle rights in the multiplayer overview screen.
-- Permissions are automatically farm-specific: if a player leaves their farm
-- their manager rights don't follow them — exactly like the base game.
--
-- Permission table:
--   Regular player (farm hand) : view only
--   Farm manager               : post, act (pay/accept/reject), delete own
--   Server host / master user  : full access

function RoleplayPhone:isFarmManager()
    if not g_currentMission then return false end
    -- Server host always has full access
    if g_currentMission:getIsServer() then return true end
    -- G-Portal / master user always has full access
    if g_currentMission.isMasterUser then return true end
    -- Check FS25 native farm manager permission
    -- Try both method and direct property access for compatibility
    if g_currentMission.getHasPlayerPermission then
        local ok, result = pcall(function()
            return g_currentMission:getHasPlayerPermission("farmManager")
        end)
        if ok and result then return true end
    end
    -- Fallback: check userPermissions directly if available
    if g_currentMission.userPermissions then
        local ok, result = pcall(function()
            return g_currentMission.userPermissions:hasPermission("farmManager")
        end)
        if ok and result then return true end
    end
    return false
end

function RoleplayPhone:canPost()
    return self:isFarmManager()
end

function RoleplayPhone:canAct()
    return self:isFarmManager()
end

function RoleplayPhone:canDeleteAny()
    -- host/master user only — farm managers can only delete their own
    if not g_currentMission then return false end
    return g_currentMission:getIsServer() or (g_currentMission.isMasterUser == true)
end

-- ─── Shared phone background helper ─────────────────────────────────────────
-- Draws the background slightly oversized to fill flush to frame bezel edges.
function RoleplayPhone:drawPhoneBackground(r, g, b, a)
    local s   = self.BIG
    local pad = 0.006
    self:drawRect(s.x - pad * self.arScale, s.y - pad,
                  s.w + pad * self.arScale * 2, s.h + pad * 2, r, g, b, a or 1.0)
end

-- ─── Weather forecast XML reader ─────────────────────────────────────────────
-- Reads environment.xml from the save and returns:
--   { [relDay] = { typeName="CLOUDY", minTemp=8, maxTemp=14 } }
-- Map weather variations are read once and cached for temperature lookup.
RoleplayPhone._forecastCache      = nil
RoleplayPhone._forecastCacheDay   = -1
RoleplayPhone._mapWeatherTemps    = nil  -- reset forces re-read with fixed indexing

function RoleplayPhone:_loadMapWeatherTemps()
    if self._mapWeatherTemps then return self._mapWeatherTemps end
    self._mapWeatherTemps = {}
    -- Only host can load map files
    if g_server == nil then return self._mapWeatherTemps end

    -- Try known environment.xml paths — base game maps, common mod maps
    -- mapFile is often nil so we just try all candidates
    local mapFile = g_currentMission and g_currentMission.missionInfo
                    and g_currentMission.missionInfo.mapFile

    -- Build the install-relative data path from the mod's own directory
    -- modDirectory is like "C:/path/to/mods/FS25_RoleplayPhone/"
    -- Game data is typically 3 levels up then into data/ but that varies.
    -- Use Utils.getFilename if available, otherwise try $data directly.
    local function tryLoad(tag, path)
        local f = loadXMLFile(tag, path)
        if f and f ~= 0 then return f end
        return nil
    end

    local xmlFile = nil
    local usedPath = nil

    -- Try $data prefix (works in most FS25 contexts)
    for _, rel in ipairs({"maps/mapUS/config/environment.xml",
                           "maps/mapEU/config/environment.xml",
                           "maps/mapAS/config/environment.xml"}) do
        local path = "$data/" .. rel
        local f = tryLoad("RP_MapEnv_" .. rel:gsub("[/.]","_"), path)
        if f then xmlFile = f; usedPath = path; break end
    end

    -- Fallback: try absolute path using game install dir from Utils
    if not xmlFile then
        local installDir = nil
        if Utils and Utils.getFilename then
            installDir = Utils.getFilename("$data/")
        end
        if installDir then
            for _, rel in ipairs({"maps/mapUS/config/environment.xml",
                                   "maps/mapEU/config/environment.xml"}) do
                local path = installDir .. rel
                local f = tryLoad("RP_MapEnvAbs_" .. rel:gsub("[/.]","_"), path)
                if f then xmlFile = f; usedPath = path; break end
            end
        end
    end

    if not xmlFile then
        Logging.info("[RoleplayPhone] Could not load map environment.xml — using built-in temp ranges")
        -- Built-in fallback: typical FS25 mapUS temperature ranges per season/type
        self._mapWeatherTemps = {
            SPRING = {
                SUN    = {{min=10,max=18},{min=10,max=17},{min=11,max=16},{min=10,max=15}},
                CLOUDY = {{min=9,max=14},{min=8,max=13},{min=8,max=13},{min=7,max=12}},
                RAIN   = {{min=7,max=13},{min=6,max=12},{min=6,max=11},{min=5,max=10}},
            },
            SUMMER = {
                SUN    = {{min=18,max=28},{min=17,max=27},{min=16,max=26},{min=15,max=25}},
                CLOUDY = {{min=15,max=22},{min=14,max=21},{min=13,max=20},{min=12,max=19}},
                RAIN   = {{min=13,max=20},{min=12,max=19},{min=11,max=18},{min=10,max=17}},
            },
            AUTUMN = {
                SUN    = {{min=8,max=16},{min=7,max=15},{min=6,max=14},{min=5,max=13}},
                CLOUDY = {{min=5,max=12},{min=4,max=11},{min=4,max=11},{min=3,max=10}},
                RAIN   = {{min=4,max=10},{min=3,max=9},{min=2,max=8},{min=1,max=7}},
                SNOW   = {{min=-2,max=2},{min=-3,max=1},{min=-4,max=0},{min=-5,max=-1}},
            },
            WINTER = {
                SUN    = {{min=-2,max=4},{min=-3,max=3},{min=-4,max=2},{min=-5,max=1}},
                CLOUDY = {{min=-4,max=1},{min=-5,max=0},{min=-6,max=-1},{min=-7,max=-2}},
                SNOW   = {{min=-8,max=-2},{min=-9,max=-3},{min=-10,max=-4},{min=-11,max=-5}},
            },
        }
        return self._mapWeatherTemps
    end
    Logging.info("[RoleplayPhone] Loaded map env from: " .. tostring(usedPath))

    local seasonIdx = 0
    while true do
        local sKey   = string.format("environment.weather.season(%d)", seasonIdx)
        local season = getXMLString(xmlFile, sKey .. "#name")
        if season == nil then break end
        season = season:upper()
        self._mapWeatherTemps[season] = {}

        local objIdx = 0
        while true do
            local oKey    = string.format("%s.object(%d)", sKey, objIdx)
            local typeName = getXMLString(xmlFile, oKey .. "#typeName")
            if typeName == nil then break end
            typeName = typeName:upper()
            self._mapWeatherTemps[season][typeName] = {}

            local varIdx = 0
            while true do
                local vKey   = string.format("%s.variation(%d)", oKey, varIdx)
                local minT   = getXMLFloat(xmlFile, vKey .. "#minTemperature")
                if minT == nil then break end
                local maxT   = getXMLFloat(xmlFile, vKey .. "#maxTemperature") or minT
                -- Store at 1-based index to match save XML variationIndex (which is 1-based)
                self._mapWeatherTemps[season][typeName][varIdx + 1] = { min=minT, max=maxT }
                varIdx = varIdx + 1
            end
            objIdx = objIdx + 1
        end
        seasonIdx = seasonIdx + 1
    end

    delete(xmlFile)
    Logging.info("[RoleplayPhone] Loaded map weather temps for " .. seasonIdx .. " seasons")
    return self._mapWeatherTemps
end

function RoleplayPhone:getForecastFromXML()
    local env        = g_currentMission and g_currentMission.environment
    local currentDay = env and env.currentDay or 0

    -- Check cache first — clients get forecast via network event, not by reading files
    if self._forecastCacheDay == currentDay and self._forecastCache then
        return self._forecastCache
    end

    -- Clients can't read the host's savegame directory
    if g_server == nil then return {} end
    local currentDay = env and env.currentDay or 0
    if self._forecastCacheDay ~= currentDay then
        self._forecastCache    = nil
        self._forecastCacheDay = currentDay
    end
    if self._forecastCache then return self._forecastCache end

    local dir = g_currentMission and g_currentMission.missionInfo
                and g_currentMission.missionInfo.savegameDirectory
    if not dir then return {} end

    local xmlFile = loadXMLFile("RP_WeatherXML", dir .. "/environment.xml")
    if not xmlFile or xmlFile == 0 then return {} end

    -- Load map temperature ranges (cached after first call)
    local mapTemps = self:_loadMapWeatherTemps()

    local forecast = {}
    local i = 0
    while true do
        local key      = string.format("environment.weather.forecast.instance(%d)", i)
        local typeName = getXMLString(xmlFile, key .. "#typeName")
        if typeName == nil then break end
        local startDay   = getXMLInt(xmlFile, key .. "#startDay") or 0
        local season     = getXMLString(xmlFile, key .. "#season") or "SPRING"
        local varIdx     = getXMLInt(xmlFile, key .. "#variationIndex") or 1
        local relDay     = startDay - currentDay

        if relDay >= 0 and relDay <= 6 and forecast[relDay] == nil then
            local tn = typeName:upper()
            local minT, maxT = nil, nil
            local st = season:upper()
            if mapTemps[st] and mapTemps[st][tn] and mapTemps[st][tn][varIdx] then
                minT = mapTemps[st][tn][varIdx].min
                maxT = mapTemps[st][tn][varIdx].max
            end
            forecast[relDay] = { typeName=tn, minTemp=minT, maxTemp=maxT }
        end
        i = i + 1
    end

    delete(xmlFile)
    self._forecastCache = forecast
    return forecast
end

-- ─── Big screen shell (used by invoices, contacts, calls, weather, settings) ──
function RoleplayPhone:drawBigScreen()
    local s = self.BIG
    -- Phone body border (only if frame texture not available)
    if not self.phoneFrame then
        self:drawRect(s.x-0.009, s.y-0.009, s.w+0.014, s.h+0.018, 0.01, 0.01, 0.01, 1.0)
    end

    -- Wallpaper background — slightly oversized to fill flush to frame bezel edges
    local pad = 0.006
    local bx, by = s.x - pad * self.arScale, s.y - pad
    local bw, bh = s.w + pad * self.arScale * 2, s.h + pad * 2
    local wp = self.WALLPAPERS[self.settings.wallpaperIndex] or self.WALLPAPERS[1]
    if wp.texture and self.wallpaper and self.wallpaper ~= 0 then
        setOverlayColor(self.wallpaper, 1, 1, 1, 1)
        renderOverlay(self.wallpaper, bx, by, bw, bh)
        self:drawRect(bx, by, bw, bh, 0.0, 0.0, 0.0, 0.45)
    else
        self:drawRect(bx, by, bw, bh, wp.r, wp.g, wp.b, 1.0)
    end

    -- Notch (only if frame texture not available)
    if not self.phoneFrame then
        local nw = s.w * 0.18
        self:drawRect(s.x + (s.w-nw)/2, s.y + s.h - 0.014, nw, 0.014, 0.01, 0.02, 0.03, 1.0)
    end
    -- Status bar
    self:drawStatusBar(s.x, s.y, s.w, s.h)
end

-- ─── Status bar ───────────────────────────────────────────────────────────────
function RoleplayPhone:drawStatusBar(px, py, pw, ph)
    local barY     = py + ph - 0.038
    local textSize = 0.012

    local timeStr = "00:00"
    if g_currentMission and g_currentMission.environment then
        local dt   = g_currentMission.environment.dayTime / 3600000
        local hrs  = math.floor(dt) % 24
        local mins = math.floor((dt - math.floor(dt)) * 60)
        timeStr    = self:formatTime(hrs, mins)
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
    renderText(px + 0.014 * self.arScale, barY, textSize, timeStr)

    -- Right side: 4G, signal bars, battery — tight group from right edge
    setTextAlignment(RenderText.ALIGN_RIGHT)
    renderText(px + pw - 0.042 * self.arScale, barY, textSize, "4G")
    renderText(px + pw - 0.060 * self.arScale, barY, textSize, "|||")

    -- Battery widget: sits at far right, next to signal bars
    if self.settings.batteryVisible then
        local bat     = self.battery
        local pct     = bat.level / 100
        local bw      = 0.013 * self.arScale
        local bh      = 0.007
        local bx      = px + pw - 0.037 * self.arScale
        local by      = barY + 0.003
        -- Outer shell
        self:drawRect(bx, by, bw, bh, 0.55, 0.55, 0.55, 1.0)
        -- Fill colour: green >30%, yellow >15%, red <=15%
        local fr, fg, fb
        if pct > 0.30 then
            fr, fg, fb = 0.15, 0.80, 0.20
        elseif pct > 0.15 then
            fr, fg, fb = 0.90, 0.75, 0.05
        else
            fr, fg, fb = 0.90, 0.10, 0.10
        end
        local fillW = math.max(0.001, (bw - 0.002) * pct)
        self:drawRect(bx + 0.001, by + 0.001, fillW, bh - 0.002, fr, fg, fb, 1.0)
        -- Nub on right
        self:drawRect(bx + bw, by + 0.001, 0.002 * self.arScale, bh - 0.002, 0.55, 0.55, 0.55, 1.0)
        -- LOW BATTERY flash at <=15%
        if pct <= 0.15 then
            local flash = math.floor(getTimeSec() * 2) % 2 == 0
            if flash then
                setTextAlignment(RenderText.ALIGN_RIGHT)
                setTextBold(false)
                setTextColor(0.95, 0.15, 0.15, 1.0)
                renderText(bx - 0.003 * self.arScale, barY, 0.009, "LOW")
            end
        end
    end

    -- Divider
    self:drawRect(px, barY - 0.004, pw, 0.001, 0.2, 0.22, 0.28, 0.6)
end

-- ─── HOME screen ─────────────────────────────────────────────────────────────
function RoleplayPhone:drawPhoneHome()
    local px = self.PHONE.x
    local py = self.PHONE.y
    local pw = self.PHONE.w
    local ph = self.PHONE.h
    local cx = px + pw / 2

    -- Dock dimensions (shared by all pages)
    local dockH = 0.115
    local dockY = py + 0.006

    -- Phone body: drawn by frame texture overlay (see drawPhoneFrame at end of this function).
    -- If the DDS isn't loaded, fall back to the plain drawRect bezel.
    if not self.phoneFrame then
        self:drawRect(px-0.009, py-0.009, pw+0.018, ph+0.018, 0.01, 0.01, 0.01, 1.0)
    end

    -- ── Screen background ────────────────────────────────────────────────────
    if self.homePage == 1 then
        -- Page 1: wallpaper from picker — texture (Countryside) or colour swatch
        local wp = self.WALLPAPERS[self.settings.wallpaperIndex] or self.WALLPAPERS[1]
        if wp.texture and self.wallpaper and self.wallpaper ~= 0 then
            setOverlayColor(self.wallpaper, 1, 1, 1, 1)
            renderOverlay(self.wallpaper, px, py, pw, ph)
            self:drawRect(px, py, pw, ph, 0.0, 0.0, 0.0, 0.38)
        else
            self:drawRect(px, py, pw, ph, wp.r, wp.g, wp.b, 1.0)
        end
    else
        -- Page 2+: same wallpaper as page 1
        local wp = self.WALLPAPERS[self.settings.wallpaperIndex] or self.WALLPAPERS[1]
        if wp.texture and self.wallpaper and self.wallpaper ~= 0 then
            setOverlayColor(self.wallpaper, 1, 1, 1, 1)
            renderOverlay(self.wallpaper, px, py, pw, ph)
            self:drawRect(px, py, pw, ph, 0.0, 0.0, 0.0, 0.55)
        else
            self:drawRect(px, py, pw, ph, wp.r, wp.g, wp.b, 1.0)
        end
    end

    -- Notch: only draw if frame texture isn't handling it
    if not self.phoneFrame then
        local nw = pw * 0.20
        self:drawRect(cx - nw/2, py + ph - 0.010, nw, 0.010, 0.01, 0.01, 0.01, 1.0)
    end

    -- Status bar (always)
    self:drawStatusBar(px, py, pw, ph)

    -- ── Page 1 content: clock + weather widget ───────────────────────────────
    if self.homePage == 1 then
        -- Big clock
        local timeStr = "00:00"
        if g_currentMission and g_currentMission.environment then
            local dt   = g_currentMission.environment.dayTime / 3600000
            local hrs  = math.floor(dt) % 24
            local mins = math.floor((dt - math.floor(dt)) * 60)
            timeStr    = self:formatTime(hrs, mins)
        end
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(1, 1, 1, 1)
        renderText(cx, py + ph * 0.70, 0.038, timeStr)

        -- Day and Season
        local dateStr = ""
        if g_currentMission and g_currentMission.environment then
            local env     = g_currentMission.environment
            local day     = env.currentDay or 0
            local seasons = { "Spring", "Summer", "Autumn", "Winter" }
            local season  = "Spring"
            if env.currentSeason ~= nil then
                season = seasons[(env.currentSeason % 4) + 1] or "Spring"
            end
            dateStr = string.format("Day %d  -  %s", day, season)
        end
        setTextBold(false)
        setTextColor(0.90, 0.93, 1.0, 0.92)
        renderText(cx, py + ph * 0.63, 0.013, dateStr)

        -- Weather widget
        self:drawWeatherWidget(px, py, pw, ph)

    -- ── Page 2+ content: app grid ────────────────────────────────────────────
    else
        self:drawAppGrid(px, py, pw, ph, dockY, dockH)
    end

    -- ── Dock (always visible on all pages) ───────────────────────────────────
    -- Frosted glass effect: semi-transparent dark strip
    self:drawRect(px, dockY, pw, dockH, 0.03, 0.03, 0.04, 0.88)
    self:drawRect(px, dockY + dockH, pw, 0.002, 0.12, 0.12, 0.15, 0.5)
    self:drawDockIcons(px, py, pw, ph, dockY, dockH)

    -- ── Page dots ─────────────────────────────────────────────────────────────
    local dotSize   = 0.005
    local dotGap    = 0.016
    local dotY      = dockY + dockH + 0.008
    local totalDots = self.homePageCount
    local dotStartX = cx - ((totalDots - 1) * dotGap) / 2
    for i = 1, totalDots do
        local alpha = (i == self.homePage) and 0.90 or 0.25
        self:drawRect(dotStartX + (i-1)*dotGap - dotSize/2, dotY, dotSize, dotSize, 1, 1, 1, alpha)
        -- Dot hitboxes for page switching
        self:addHitbox("page_dot_" .. i, dotStartX + (i-1)*dotGap - 0.012, dotY - 0.006, 0.024, 0.018, { page=i })
    end

    -- ── Page swipe arrows (subtle, only when more than 1 page) ───────────────
    if self.homePageCount > 1 then
        if self.homePage > 1 then
            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextBold(false)
            setTextColor(1, 1, 1, 0.75)
            renderText(px + 0.004, dotY - 0.001, 0.014, "<")
            self:addHitbox("page_prev", px, dotY - 0.015, 0.025, 0.030, {})
        end
        if self.homePage < self.homePageCount then
            setTextAlignment(RenderText.ALIGN_RIGHT)
            setTextColor(1, 1, 1, 0.75)
            renderText(px + pw - 0.004, dotY - 0.001, 0.014, ">")
            self:addHitbox("page_next", px + pw - 0.025, dotY - 0.015, 0.025, 0.030, {})
        end
    end

    -- Both hints on same line — click outside left, swipe right
    setTextBold(false)
    if self.homePageCount > 1 then
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextColor(0.85, 0.87, 0.90, 0.75)
        renderText(px + 0.006, dockY + dockH - 0.008, 0.008, "Click outside to close")
        setTextAlignment(RenderText.ALIGN_RIGHT)
        setTextColor(0.65, 0.70, 0.80, 0.70)
        renderText(px + pw - 0.006, dockY + dockH - 0.008, 0.008, "< > switch pages")
    else
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextColor(0.85, 0.87, 0.90, 0.75)
        renderText(cx, dockY + dockH - 0.008, 0.008, "Click outside to close")
    end

    -- Frame texture used to be drawn here, now drawn in main draw() for all screens
end

-- ─── Phone frame texture overlay ─────────────────────────────────────────────
-- Renders Test_Phone_Pic.dds on top of screen content.
-- The frame is sized so its transparent screen hole exactly covers PHONE.x/y/w/h.
-- Tune FRAME_SCREEN pixel values at the top of this file to shift/resize the hole.
function RoleplayPhone:drawPhoneFrame()
    if not self.phoneFrame then return end

    local f   = self.FRAME_SCREEN
    local px  = self.PHONE.x
    local py  = self.PHONE.y
    local pw  = self.PHONE.w
    local ph  = self.PHONE.h

    -- Fraction of the image taken up by the screen hole
    local holeW = (f.R - f.L) / f.imgW   -- e.g. (596-178)/900 = 0.4644
    local holeH = (f.T - f.B) / f.imgH   -- e.g. (743-97)/900  = 0.7178
    local leftF = f.L / f.imgW            -- left margin fraction
    local botF  = f.B / f.imgH            -- bottom margin fraction

    -- Scale frame so hole == (pw, ph), then offset so hole origin == (px, py)
    local fw = pw / holeW
    local fh = ph / holeH
    local fx = px - fw * leftF
    local fy = py - fh * botF

    setOverlayColor(self.phoneFrame, 1, 1, 1, 1)
    renderOverlay(self.phoneFrame, fx, fy, fw, fh)
end

-- ─── Weather widget (page 1 center) ──────────────────────────────────────────
function RoleplayPhone:drawWeatherWidget(px, py, pw, ph)
    local cx = px + pw / 2

    -- Widget sits between date and dock, roughly in the center vertical area
    local widgetY = py + ph * 0.43

    -- Get weather data
    local tempStr    = "--°C"
    local condStr    = "Clear"
    local condColor  = { 1.0, 0.85, 0.30 }  -- default: sunny yellow

    if g_currentMission and g_currentMission.environment then
        local weather = g_currentMission.environment.weather

        if weather then
            local isRaining  = weather.getIsRaining  and weather:getIsRaining()  or false
            local isSnowing  = weather.getIsSnowing  and weather:getIsSnowing()  or false
            local isHailing  = weather.getIsHailing  and weather:getIsHailing()  or false

            if isHailing then
                condStr   = "Hail"
                condColor = { 0.60, 0.80, 0.95 }
            elseif isSnowing then
                condStr   = "Snow"
                condColor = { 0.85, 0.92, 1.00 }
            elseif isRaining then
                local intensity = weather.getRainFallScale and weather:getRainFallScale() or 1
                condStr   = intensity > 0.6 and "Heavy Rain" or "Rain"
                condColor = { 0.45, 0.65, 0.90 }
            else
                condStr   = "Clear"
                condColor = { 1.0, 0.85, 0.30 }
            end

            -- Temperature
            if weather.temperatureUpdater then
                local env  = g_currentMission.environment
                local temp = weather.temperatureUpdater:getTemperatureAtTime(env.dayTime)
                if temp then
                    if self.settings.tempUnit == "F" then
                        local f = math.floor(temp * 9 / 5 + 32 + 0.5)
                        tempStr = string.format("%d°F", f)
                    else
                        tempStr = string.format("%d°C", math.floor(temp + 0.5))
                    end
                end
            end
        end
    end

    -- Condition label (e.g. "Clear", "Rain")
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(false)
    setTextColor(condColor[1], condColor[2], condColor[3], 0.95)
    renderText(cx, widgetY + 0.020, 0.014, condStr)

    -- Temperature (big-ish, white)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(cx, widgetY, 0.022, tempStr)
    setTextBold(false)
end

-- ─── Weather App (full screen) ────────────────────────────────────────────────
function RoleplayPhone:drawAppGrid(px, py, pw, ph, dockY, dockH)
    local cx      = px + pw / 2
    local cols    = 3
    local iconSz  = 0.038 * self.arScale
    local iconGap = (pw - cols * iconSz) / (cols + 1)
    local startY  = dockY + dockH + 0.035  -- start just above dock area, working upward

    -- Collect apps for this page
    local pageApps = {}
    for _, app in ipairs(self.GRID_APPS) do
        if app.page == self.homePage then
            table.insert(pageApps, app)
        end
    end

    -- Draw in rows of `cols`
    local row = 0
    local col = 0
    local rowH = iconSz + 0.028  -- icon + label space
    -- Start from top of screen content area, below status bar
    local gridStartY = py + ph - 0.060 - rowH  -- just below status bar

    for idx, app in ipairs(pageApps) do
        col = (idx - 1) % cols
        row = math.floor((idx - 1) / cols)

        local ix = px + iconGap + col * (iconSz + iconGap)
        local iy = gridStartY - row * (rowH + 0.008)

        -- Icon background — aspect ratio corrected to look square
        local iconH = iconSz * self.actualAR
        local c = app.color
        self:drawRect(ix, iy, iconSz, iconH, c[1], c[2], c[3], 1.0)
        -- Highlight strip at top
        self:drawRect(ix, iy + iconH - 0.003, iconSz, 0.003, c[1]+0.2, c[2]+0.2, c[3]+0.2, 0.3)

        -- Icon image overlay
        local overlay = app.icon and self[app.icon] or nil
        if overlay and overlay ~= 0 then
            setOverlayColor(overlay, 1, 1, 1, 0.9)
            renderOverlay(overlay, ix + iconSz*0.15, iy + iconH*0.15, iconSz*0.70, iconH*0.70)
        end

        -- Label below
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextColor(1, 1, 1, 0.90)
        renderText(ix + iconSz/2, iy - 0.014, 0.009, app.label)

        -- Hitbox
        self:addHitbox("grid_app_" .. app.id, ix, iy - 0.016, iconSz, iconH + 0.016, { appId = app.id })
    end
end

-- ─── Dock icons (always visible) ─────────────────────────────────────────────
function RoleplayPhone:drawDockIcons(px, py, pw, ph, dockY, dockH)
    local cx     = px + pw / 2
    local nApps  = #self.DOCK_APPS
    -- Shrink icon + gap so all 4 fit inside the phone width with small margins
    local margin = 0.010
    local gap    = 0.008
    local iconSz = (pw - margin * 2 - gap * (nApps - 1)) / nApps  -- width in screen coords
    local iconH  = iconSz * self.actualAR  -- compensate for aspect ratio so boxes look square
    local totalW = nApps * iconSz + (nApps - 1) * gap
    local startX = cx - totalW / 2
    local iconY  = dockY + (dockH - iconH) / 2

    for i, app in ipairs(self.DOCK_APPS) do
        local ix = startX + (i-1) * (iconSz + gap)
        local c  = app.color

        -- Icon background (visually square)
        self:drawRect(ix, iconY, iconSz, iconH, c[1], c[2], c[3], 1.0)
        -- Highlight strip at top of icon
        self:drawRect(ix, iconY + iconH - 0.003, iconSz, 0.003, c[1]+0.2, c[2]+0.2, c[3]+0.2, 0.3)

        -- Icon image overlays for dock
        local overlay = nil
        if app.id == "invoices" then overlay = self.iconInvoices
        elseif app.id == "contacts" then overlay = self.iconContacts
        elseif app.id == "calls" then overlay = self.iconCalls
        end
        if overlay and overlay ~= 0 then
            setOverlayColor(overlay, 1, 1, 1, 0.9)
            renderOverlay(overlay, ix + iconSz*0.15, iconY + iconH*0.15, iconSz*0.70, iconH*0.70)
        end

        -- Settings icon overlay
        if app.id == "settings" then
            local sm = iconSz * 0.1
            local hm = iconH  * 0.1
            setOverlayColor(self.iconSettings, 1, 1, 1, 0.9)
            renderOverlay(self.iconSettings, ix + sm, iconY + hm, iconSz - sm*2, iconH - hm*2)
        end

        -- Label below icon (inside dock)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextColor(0.85, 0.87, 0.90, 0.85)
        renderText(ix + iconSz/2, dockY + 0.004, 0.008, app.label)

        -- Hitbox
        self:addHitbox("dock_" .. app.id, ix, dockY, iconSz, dockH, { appId = app.id })
    end
end

-- ─── INVOICES LIST screen ─────────────────────────────────────────────────────
function RoleplayPhone:mouseEvent(posX, posY, isDown, isUp, button)
    self.mouseX = posX
    self.mouseY = posY

    -- When phone is closed, let NotificationManager handle HUD icon dragging
    if self.state == self.STATE.CLOSED then
        NotificationManager:mouseEvent(posX, posY, isDown, isUp, button)
        return
    end

    -- Also forward to NotificationManager from HOME screen — cursor IS visible
    -- here, so the player can click-hold-drag the HUD icon while the phone is open.
    -- Must be before the isDown guard so isUp (drag-end / save) is forwarded too.
    if self.state == self.STATE.HOME then
        local handled = NotificationManager:mouseEvent(posX, posY, isDown, isUp, button)
        if handled then return end
    end

    if not isDown or button ~= Input.MOUSE_BUTTON_LEFT then return end

    -- Check hitboxes
    for _, hb in ipairs(self.hitboxes) do
        if self:hitTest(posX, posY, hb.x, hb.y, hb.w, hb.h) then
            self:onHitboxClicked(hb)
            return true
        end
    end

    -- Click outside phone body closes it (HOME state only)
    if self.state == self.STATE.HOME then
        local p = self.PHONE
        if not self:hitTest(posX, posY, p.x-0.006, p.y-0.006, p.w+0.012, p.h+0.012) then
            self:close()
            return true
        end
    end
end

function RoleplayPhone:onHitboxClicked(hb)
    -- Page dot navigation
    if hb.id:sub(1,9) == "page_dot_" and hb.data and hb.data.page then
        self.homePage = hb.data.page
        return
    end
    if hb.id == "page_prev" then
        self.homePage = math.max(1, self.homePage - 1)
        return
    end
    if hb.id == "page_next" then
        self.homePage = math.min(self.homePageCount, self.homePage + 1)
        return
    end

    -- Dock app clicks
    if hb.id:sub(1,5) == "dock_" and hb.data and hb.data.appId then
        local appId = hb.data.appId
        if appId == "invoices" then self.state = self.STATE.INVOICES_LIST; return end
        if appId == "contacts" then self.state = self.STATE.CONTACTS;      return end
        if appId == "calls"    then self.state = self.STATE.CALLS;          return end
        if appId == "settings" then self.state = self.STATE.SETTINGS;      return end
        return
    end

    -- Grid app clicks (page 2+)
    if hb.id:sub(1,9) == "grid_app_" and hb.data and hb.data.appId then
        local appId = hb.data.appId
        -- Weather and market apps coming soon
        if appId == "weather" then
            self.state = self.STATE.WEATHER
            return
        end
        if appId == "market" then
            -- TODO: self.state = self.STATE.MARKET
            return
        end
        return
    end

    -- Legacy: App icons (home screen) - keep for any old hitboxes
    if hb.id:sub(1,4) == "app_" and hb.data and hb.data.state then
        self.state = hb.data.state
        return
    end

    -- Message compose field (focus/unfocus)
    if hb.id == "msg_field" then
        self.messageCompose.active = true
        return
    end

    -- Send message button
    if hb.id == "btn_send_message" then
        self:sendMessage()
        return
    end

    -- Message button (from contact detail — opens message thread)
    if hb.id == "btn_message_contact" then
        self.state = self.STATE.MESSAGE_THREAD
        return
    end

    -- Call button (from contact thread)
    if hb.id == "btn_call" then
        self:startCall()
        return
    end

    -- Answer incoming call
    if hb.id == "btn_answer" then
        self:answerCall()
        return
    end

    -- End / decline call
    if hb.id == "btn_end_call" then
        self:endCall()
        return
    end

    -- Back button
    if hb.id == "btn_back" then
        if self.state == self.STATE.MESSAGE_THREAD then
            self.messageCompose.active = false
            self.messageCompose.text   = ""
            self.state = self.STATE.CONTACT_DETAIL
            return
        end
        if self.state == self.STATE.CONTACT_DETAIL then
            self.state = self.STATE.CONTACTS
            return
        end
        if self.state == self.STATE.INVOICE_CREATE then
            self.state = self.STATE.INVOICES_LIST
        elseif self.state == self.STATE.INVOICE_DETAIL then
            self.state = self.STATE.INVOICES_LIST
        else
            self:goHome()
        end
        return
    end

    -- Tabs
    if hb.id == "tab_inbox"  then self.currentTab = self.TAB.INBOX;  return end
    if hb.id == "tab_outbox" then self.currentTab = self.TAB.OUTBOX; return end

    -- Create invoice button
    if hb.id == "btn_create_invoice" then
        self:resetForm()
        self.state = self.STATE.INVOICE_CREATE
        return
    end

    -- Invoice row -> detail view
    if hb.id == "invoice_row" and hb.data and hb.data.invoice then
        self.selectedInvoice = hb.data.invoice
        self.state = self.STATE.INVOICE_DETAIL
        return
    end

    -- Farm selector arrows
    if hb.id == "farm_prev" then
        local farms = self:getAvailableFarms()
        self.form.toFarmIndex = ((self.form.toFarmIndex - 2) % #farms) + 1
        return
    end
    if hb.id == "farm_next" then
        local farms = self:getAvailableFarms()
        self.form.toFarmIndex = (self.form.toFarmIndex % #farms) + 1
        return
    end

    -- Category selector arrows
    if hb.id == "cat_prev" then
        local n = #InvoiceManager.categories
        self.form.categoryIndex = ((self.form.categoryIndex - 2) % n) + 1
        return
    end
    if hb.id == "cat_next" then
        local n = #InvoiceManager.categories
        self.form.categoryIndex = (self.form.categoryIndex % n) + 1
        return
    end

    -- Text fields - set active field
    if hb.id == "field_amount"      then self.form.activeField = "amount";      return end
    if hb.id == "field_description" then self.form.activeField = "description"; return end
    if hb.id == "field_notes"       then self.form.activeField = "notes";       return end
    if hb.id == "field_dueDate"     then self.form.activeField = "dueDate";     return end

    if hb.id == "clear_amount"      then self.form.amount      = ""; self.form.activeField = "amount";      return end
    if hb.id == "clear_dueDate"     then self.form.dueDate     = ""; self.form.activeField = "dueDate";     return end
    if hb.id == "clear_description" then self.form.description = ""; self.form.activeField = "description"; return end
    if hb.id == "clear_notes"       then self.form.notes       = ""; self.form.activeField = "notes";       return end

    -- Send invoice
    if hb.id == "btn_send_invoice" then
        self:submitInvoice()
        return
    end

    -- Mark as paid (sender)
    if hb.id == "btn_mark_paid" and self.selectedInvoice then
        self.selectedInvoice.status = "PAID"
        local invId = self.selectedInvoice.id
        if g_server ~= nil then
            g_server:broadcastEvent(
                InvoiceEvents.UpdateInvoiceEvent.new(invId, "PAID"))
        elseif g_client ~= nil then
            g_client:getServerConnection():sendEvent(
                InvoiceEvents.UpdateInvoiceEvent.new(invId, "PAID"))
        end
        RoleplayPhone:saveInvoices()
        UsedPlusCompat:onInvoiceMarkedPaid(self.selectedInvoice)
        print("[RoleplayPhone] Invoice marked as paid: #" .. tostring(invId))
        return
    end

    -- Reject invoice (recipient)
    if hb.id == "btn_reject_invoice" and self.selectedInvoice then
        local inv = self.selectedInvoice
        if inv.status == "PENDING" then
            inv.status = "REJECTED"
            if g_server ~= nil then
                g_server:broadcastEvent(
                    InvoiceEvents.UpdateInvoiceEvent.new(inv.id, "REJECTED"))
            elseif g_client ~= nil then
                g_client:getServerConnection():sendEvent(
                    InvoiceEvents.UpdateInvoiceEvent.new(inv.id, "REJECTED"))
            end
            RoleplayPhone:saveInvoices()
            UsedPlusCompat:onInvoiceRejected(inv)
            NotificationManager:push("rejected", "Invoice #" .. string.format("%04d", inv.id) .. " rejected.")
            print("[RoleplayPhone] Invoice rejected: #" .. tostring(inv.id))
        end
        return
    end

    -- Pay invoice (recipient)
    if hb.id == "btn_pay_invoice" and self.selectedInvoice then
        local inv = self.selectedInvoice
        local amount = inv.amount or 0
        local myFarmId = self:getMyFarmId()
        local farmManager = g_farmManager or (g_currentMission and g_currentMission.farmManager)
        if farmManager then
            local farm = farmManager:getFarmById(myFarmId)
            if farm and farm.money >= amount then
                -- Route through server event so money transfer happens authoritatively
                if g_server ~= nil then
                    -- Host paying: run directly
                    g_currentMission:addMoney(-amount, myFarmId, MoneyType.OTHER, true, true)
                    g_currentMission:addMoney(amount, inv.fromFarmId, MoneyType.OTHER, true, true)
                    inv.status = "PAID"
                    g_server:broadcastEvent(
                        InvoiceEvents.UpdateInvoiceEvent.new(inv.id, "PAID"))
                    RoleplayPhone:saveInvoices()
                elseif g_client ~= nil then
                    -- Client paying: ask server to do the transfer
                    inv.status = "PAID"  -- optimistic local update
                    g_client:getServerConnection():sendEvent(
                        RI_PayInvoiceEvent.new(inv.id, inv.fromFarmId, myFarmId, amount))
                end
                RoleplayPhone:saveInvoices()
                UsedPlusCompat:onInvoicePaid(inv)
                NotificationManager:push("paid",
                    string.format("Paid $%s to %s",
                        self:formatMoney(amount),
                        self:getFarmName(inv.fromFarmId)))
                print("[RoleplayPhone] Invoice paid: #" .. tostring(inv.id))
            else
                NotificationManager:push("rejected", "Insufficient funds to pay this invoice.")
            end
        end
        return
    end

    -- ── Contacts list ──────────────────────────────────────────────────────
    if hb.id == "contact_row" and hb.data and hb.data.index then
        self.selectedContact = hb.data.index
        self.unreadMessages[hb.data.index] = 0  -- clear badge on open
        self.messageCompose.text   = ""
        self.messageCompose.active = false
        self.state = self.STATE.CONTACT_DETAIL
        return
    end

    if hb.id == "btn_add_contact" then
        self:resetContactForm()
        self.state = self.STATE.CONTACT_CREATE
        return
    end

    -- ── Contact detail ─────────────────────────────────────────────────────
    if hb.id == "btn_delete_contact" then
        if self.selectedContact then
            local idx = self.selectedContact
            -- If client, notify host to persist the deletion
            if g_server == nil then
                local myFarmId = self:getMyFarmId()
                g_client:getServerConnection():sendEvent(
                    RI_ContactEvent.new("delete", myFarmId, idx, {}))
            end
            ContactManager:removeContact(idx)
            self.selectedContact = nil
            RoleplayPhone:saveInvoices()
        end
        self.state = self.STATE.CONTACTS
        return
    end

    -- ── Contact create fields (focus) ──────────────────────────────────────
    if hb.id == "cf_name"     then self.contactForm.activeField = "name";     return end
    if hb.id == "cf_farmName" then self.contactForm.activeField = "farmName"; return end
    if hb.id == "cf_phone"    then self.contactForm.activeField = "phone";    return end
    if hb.id == "cf_notes"    then self.contactForm.activeField = "notes";    return end

    -- ── Contact create: clear buttons ──────────────────────────────────────
    if hb.id == "cclear_name"     then self.contactForm.name     = ""; self.contactForm.activeField = "name";     return end
    if hb.id == "cclear_farmName" then self.contactForm.farmName = ""; self.contactForm.activeField = "farmName"; return end
    if hb.id == "cclear_phone"    then self.contactForm.phone    = ""; self.contactForm.activeField = "phone";    return end
    if hb.id == "cclear_notes"    then self.contactForm.notes    = ""; self.contactForm.activeField = "notes";    return end

    -- ── Contact create: save ───────────────────────────────────────────────
    if hb.id == "btn_save_contact" then
        local f = self.contactForm
        if f.name and f.name ~= "" then
            local data = {
                name     = f.name,
                farmName = f.farmName,
                phone    = f.phone,
                notes    = f.notes,
            }
            ContactManager:addContact(data)
            -- If client, notify host to persist the new contact
            if g_server == nil then
                local myFarmId = self:getMyFarmId()
                g_client:getServerConnection():sendEvent(
                    RI_ContactEvent.new("add", myFarmId, 0, data))
            end
            RoleplayPhone:saveInvoices()
        end
        self.contactForm.activeField = nil
        self.state = self.STATE.CONTACTS
        return
    end

    -- ── Settings screen ────────────────────────────────────────────────────
    if hb.id == "setting_timeformat_12" then
        self.settings.timeFormat = "12"
        RoleplayPhone:saveSettings()
        return
    end
    if hb.id == "setting_timeformat_24" then
        self.settings.timeFormat = "24"
        RoleplayPhone:saveSettings()
        return
    end
    if hb.id == "setting_temp_F" then
        self.settings.tempUnit = "F"
        RoleplayPhone:saveSettings()
        return
    end
    if hb.id == "setting_temp_C" then
        self.settings.tempUnit = "C"
        RoleplayPhone:saveSettings()
        return
    end
    if hb.id == "setting_battery_toggle" then
        self.settings.batteryVisible = not self.settings.batteryVisible
        RoleplayPhone:saveSettings()
        return
    end
    if hb.id:sub(1, 14) == "setting_wallp_" then
        local idx = tonumber(hb.id:sub(15))
        if idx and self.WALLPAPERS[idx] then
            self.settings.wallpaperIndex = idx
            RoleplayPhone:saveSettings()
        end
        return
    end
end

-- ─── Submit invoice form ──────────────────────────────────────────────────────
function RoleplayPhone:keyEvent(unicode, sym, modifier, isDown)
    if not isDown then return false end

    -- Helper: is this a backspace keypress?
    -- FS25 may or may not expose Input.KEY_BackSpace correctly so we check both:
    --   unicode == 8  (ASCII backspace, always reliable)
    --   sym check as fallback
    local isBackspace = (unicode == 8)
        or (Input.KEY_BackSpace ~= nil and sym == Input.KEY_BackSpace)

    -- Text input (only when a field is active)
    if self.form.activeField and self.state == self.STATE.INVOICE_CREATE then
        local field = self.form.activeField
        local val   = self.form[field] or ""

        -- Backspace
        if isBackspace then
            if #val > 0 then
                self.form[field] = val:sub(1, #val - 1)
            end
            return true
        end

        -- Printable character (unicode > 31 and < 127 = basic ASCII printable)
        if unicode and unicode > 31 and unicode < 127 then
            local maxLen = (field == "amount") and 10 or 60
            if #val < maxLen then
                self.form[field] = val .. string.char(unicode)
            end
            return true
        end

        -- Tab / Enter = advance to next field
        if sym == Input.KEY_Tab or sym == Input.KEY_Return then
            local order = { "amount", "dueDate", "description", "notes" }
            for i, f in ipairs(order) do
                if f == field then
                    self.form.activeField = order[i+1] or nil
                    break
                end
            end
            return true
        end
    end

    -- Contact create text input
    if self.contactForm.activeField and self.state == self.STATE.CONTACT_CREATE then
        local field = self.contactForm.activeField
        local val   = self.contactForm[field] or ""

        -- Backspace
        if isBackspace then
            if #val > 0 then
                self.contactForm[field] = val:sub(1, #val - 1)
            end
            return true
        end

        -- Printable character
        if unicode and unicode > 31 and unicode < 127 then
            if #val < 60 then
                self.contactForm[field] = val .. string.char(unicode)
            end
            return true
        end
    end

    -- Message compose text input (contact thread)
    if self.messageCompose.active and self.state == self.STATE.MESSAGE_THREAD then
        local val = self.messageCompose.text or ""

        if isBackspace then
            if #val > 0 then
                self.messageCompose.text = val:sub(1, #val - 1)
            end
            return true
        end

        -- Enter sends the message
        if sym == Input.KEY_Return then
            self:sendMessage()
            return true
        end

        -- Printable character
        if unicode and unicode > 31 and unicode < 127 then
            if #val < 120 then
                self.messageCompose.text = val .. string.char(unicode)
            end
            return true
        end
    end

    return false
end

-- ─── Money formatter ──────────────────────────────────────────────────────────
function RoleplayPhone:formatMoney(n)
    n = math.floor(n or 0)
    local s = tostring(n)
    local result = ""
    local count  = 0
    for i = #s, 1, -1 do
        if count > 0 and count % 3 == 0 then
            result = "," .. result
        end
        result = s:sub(i,i) .. result
        count  = count + 1
    end
    return result
end

-- ─── CALL SCREEN (compact popup — no freeze, F8 to answer/hang up) ───────────
function RoleplayPhone:registerKeybind()
    if self.inputRegistered then return end

    -- Register F7 in PLAYER context (on foot)
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

    -- Register F8 outside any context so it fires on foot AND in vehicles
    local _, callEventId = g_inputBinding:registerActionEvent(
        "RI_CALL_ACTION", RoleplayPhone, RoleplayPhone.callAction,
        false, true, false, true)
    self.callActionEventId = callEventId
    if callEventId then
        g_inputBinding:setActionEventText(callEventId, g_i18n:getText("input_RI_CALL_ACTION"))
        g_inputBinding:setActionEventTextPriority(callEventId, GS_PRIO_NORMAL or 0)
        g_inputBinding:setActionEventTextVisibility(callEventId, false)
        print("[RoleplayPhone] RI_CALL_ACTION registered OK: " .. tostring(callEventId))
    else
        print("[RoleplayPhone] WARNING: RI_CALL_ACTION registration failed")
    end

    self.inputRegistered = true
end

-- F8 handler: answer if incoming, hang up if outgoing or active
function RoleplayPhone:callAction()
    if self.state == self.STATE.CALL_INCOMING then
        self:answerCall()
    elseif self.state == self.STATE.CALL_OUTGOING
        or self.state == self.STATE.CALL_ACTIVE then
        self:endCall()
    end
end

-- Backspace handler: removes last character from whatever field is active
function RoleplayPhone:handleBackspace()
    print("[RoleplayPhone] handleBackspace called, state=" .. tostring(self.state))
    if self.state == self.STATE.INVOICE_CREATE and self.form.activeField then
        local f = self.form.activeField
        local v = self.form[f] or ""
        if #v > 0 then self.form[f] = v:sub(1, #v - 1) end

    elseif self.state == self.STATE.CONTACT_CREATE and self.contactForm.activeField then
        local f = self.contactForm.activeField
        local v = self.contactForm[f] or ""
        if #v > 0 then self.contactForm[f] = v:sub(1, #v - 1) end

    elseif self.state == self.STATE.MESSAGE_THREAD and self.messageCompose.active then
        local v = self.messageCompose.text or ""
        if #v > 0 then self.messageCompose.text = v:sub(1, #v - 1) end
    end
end

-- Poll F8 key state every frame — works in vehicles where keyboardEvent doesn't fire
function RoleplayPhone:updateCallKeyPoll()
    local isInCall = self.state == self.STATE.CALL_INCOMING
                  or self.state == self.STATE.CALL_OUTGOING
                  or self.state == self.STATE.CALL_ACTIVE
    if not isInCall then
        self._f8WasDown = false
        return
    end

    local isDown = Input.isKeyPressed ~= nil and Input.isKeyPressed(Input.KEY_f8)

    -- Edge trigger: only fire on press, not hold
    if isDown and not self._f8WasDown then
        print("[RoleplayPhone] F8 polled — triggering callAction")
        self:callAction()
    end
    self._f8WasDown = isDown
end
-- FS25 calls Mission00.keyboardEvent(unicode, sym, modifier, isDown) every frame
-- a key is pressed. We forward to RoleplayPhone:keyEvent which handles all field input.
Mission00.keyboardEvent = Utils.appendedFunction(Mission00.keyboardEvent,
    function(mission, unicode, sym, modifier, isDown)
        -- F8 for call answer/hangup — detected at mission level so it works in vehicles too
        if isDown and Input.KEY_f8 ~= nil and sym == Input.KEY_f8 then
            print("[RoleplayPhone] F8 detected in keyboardEvent, state=" .. tostring(RoleplayPhone.state))
            RoleplayPhone:callAction()
        end
        if RoleplayPhone.state ~= RoleplayPhone.STATE.CLOSED then
            RoleplayPhone:keyEvent(unicode, sym, modifier, isDown)
        end
    end
)

Mission00.deleteMap = Utils.appendedFunction(Mission00.deleteMap, function(mission)
    -- Safety net: if phone was open when map unloads, restore cursor and input context
    if RoleplayPhone.isOpen then
        g_inputBinding:setShowMouseCursor(false)
        if RoleplayPhone.phoneContextEventId then
            g_inputBinding:removeActionEvent(RoleplayPhone.phoneContextEventId)
            RoleplayPhone.phoneContextEventId = nil
        end
        g_inputBinding:revertContext(true)
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
    -- Clean up texture overlays
    if RoleplayPhone.whiteOverlay   and RoleplayPhone.whiteOverlay   ~= 0 then delete(RoleplayPhone.whiteOverlay)   end
    if RoleplayPhone.wallpaper      and RoleplayPhone.wallpaper      ~= 0 then delete(RoleplayPhone.wallpaper)      end
    if RoleplayPhone.iconInvoices   and RoleplayPhone.iconInvoices   ~= 0 then delete(RoleplayPhone.iconInvoices)   end
    if RoleplayPhone.iconContacts   and RoleplayPhone.iconContacts   ~= 0 then delete(RoleplayPhone.iconContacts)   end
    if RoleplayPhone.iconCalls      and RoleplayPhone.iconCalls      ~= 0 then delete(RoleplayPhone.iconCalls)      end
    if RoleplayPhone.iconSettings   and RoleplayPhone.iconSettings   ~= 0 then delete(RoleplayPhone.iconSettings)   end
end)

-- Hook into FS25's save system so our file is written as part of normal game save
-- This prevents the game from deleting our file on exit
Mission00.saveSavegame = Utils.appendedFunction(Mission00.saveSavegame,
    function(mission)
        if g_server ~= nil then
            RoleplayPhone:saveInvoices()
        end
    end
)

-- When a client finishes loading, host sends them the full farm list
-- and all existing invoices so they're fully in sync
Mission00.onConnectionFinishedLoading = Utils.appendedFunction(
    Mission00.onConnectionFinishedLoading,
    function(mission, connection)
        if g_server == nil then return end  -- only host does this

        -- Send full farm list
        local farms = RoleplayPhone:getAvailableFarms()
        if farms and #farms > 0 then
            connection:sendEvent(RI_FarmListEvent.new(farms))
            -- Host also stores knownFarms locally so resolveFarmId works on host too
            RoleplayPhone.knownFarms = farms
            print(string.format("[RoleplayPhone] Sent farm list (%d farms) to new client", #farms))
        end

        -- Send all existing invoices so client inbox is populated
        -- showNotification=false because farmId isn't resolved yet at connect time
        -- We send a summary notification via RI_FarmListEvent instead
        local count = 0
        for _, inv in pairs(InvoiceManager.invoices) do
            connection:sendEvent(RI_SendInvoiceEvent.new(inv, false))
            count = count + 1
        end
        if count > 0 then
            print(string.format("[RoleplayPhone] Sent %d existing invoices to new client", count))
        end
        -- Send weather forecast so client weather app shows real data
        local forecast = RoleplayPhone:getForecastFromXML()
        if forecast and next(forecast) ~= nil then
            connection:sendEvent(RI_WeatherForecastEvent.new(forecast))
            print("[RoleplayPhone] Sent weather forecast to new client")
        end

        -- Contacts use client-pull: client sends RI_ContactEvent("request") after
        -- CURRENT_MISSION_LOADED so we know their farmId. No push needed here.
    end
)
