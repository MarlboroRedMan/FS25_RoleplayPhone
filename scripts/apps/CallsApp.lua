function RoleplayPhone:drawCallScreen()
    local call = self.call

    -- Popup dimensions — left side, between minimap and keybinding list
    local pw  = 0.165 * self.arScale
    local ph  = 0.140
    local px  = 0.01            -- left edge with small margin
    local py  = 0.38            -- vertically between minimap (bottom) and keybindings (top)
    local cx  = px + pw / 2

    -- Background card
    self:drawRect(px - 0.004, py - 0.004, pw + 0.008, ph + 0.008, 0.08, 0.12, 0.22, 0.85)
    self:drawRect(px, py, pw, ph, 0.04, 0.07, 0.14, 0.97)
    -- Top accent line
    self:drawRect(px, py + ph - 0.003, pw, 0.003, 0.25, 0.50, 1.0, 0.9)

    -- Status label
    local statusStr = "Calling..."
    if self.state == self.STATE.CALL_INCOMING then statusStr = "Incoming Call"
    elseif self.state == self.STATE.CALL_ACTIVE then statusStr = "On Call" end
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(false)
    setTextColor(0.55, 0.70, 1.0, 0.9)
    renderText(cx, py + ph - 0.022, 0.012, statusStr)

    -- Contact name
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(cx, py + ph * 0.62, 0.018, call.contactName or "Unknown")

    -- Timer / ringing dots
    setTextBold(false)
    if self.state == self.STATE.CALL_ACTIVE and call.startTime and call.startTime > 0 then
        local now     = (g_currentMission and g_currentMission.time) or call.startTime
        local elapsed = math.max(0, math.floor((now - call.startTime) / 1000))
        local mins    = math.floor(elapsed / 60)
        local secs    = elapsed % 60
        setTextColor(0.70, 0.95, 0.70, 1.0)
        renderText(cx, py + ph * 0.44, 0.014, string.format("%d:%02d", mins, secs))
    elseif self.state == self.STATE.CALL_OUTGOING then
        local dots = string.rep(".", (math.floor(getTimeSec() * 2) % 4))
        setTextColor(0.60, 0.70, 0.85, 0.8)
        renderText(cx, py + ph * 0.44, 0.012, "Ringing" .. dots)
    end

    -- Decorative buttons (visual only — F8 does the actual action)
    local gap  = 0.008
    local btnW = (pw - gap * 3) / 2  -- two buttons fit exactly inside pw with margins
    local btnH = 0.032
    local btnY = py + 0.018
    if self.state == self.STATE.CALL_INCOMING then
        local bx1 = px + gap
        local bx2 = px + gap*2 + btnW
        self:drawRect(bx1, btnY, btnW, btnH, 0.08, 0.45, 0.18, 0.85)
        setTextBold(false)
        setTextColor(1, 1, 1, 0.9)
        renderText(bx1 + btnW/2, btnY + 0.008, 0.010, "Answer")
        self:drawRect(bx2, btnY, btnW, btnH, 0.50, 0.10, 0.10, 0.85)
        renderText(bx2 + btnW/2, btnY + 0.008, 0.010, "Decline")
    else
        self:drawRect(cx - btnW/2, btnY, btnW, btnH, 0.50, 0.10, 0.10, 0.85)
        setTextBold(false)
        setTextColor(1, 1, 1, 0.9)
        renderText(cx, btnY + 0.008, 0.010, "End Call")
    end

    -- Key hint — shows just the bound key name
    setTextBold(false)
    setTextColor(0.50, 0.60, 0.75, 0.70)
    renderText(cx, py + 0.004, 0.009, "Press " .. self:getCallActionKeyName() .. " to answer / hang up")
end

-- ─── CONTACTS LIST screen ─────────────────────────────────────────────────────
function RoleplayPhone:drawCallsList()
    local s  = self.PHONE
    local px = s.x
    local py = s.y
    local pw = s.w
    local ph = s.h

    -- Phone background (padded to fill frame bezel edges)
    self:drawPhoneBackground(0.06, 0.07, 0.10, 0.97)

    -- Header
    local headerH = 0.042
    local headerY = py + ph - 0.012 - headerH
    self:drawRect(px, headerY, pw, headerH, 0.08, 0.11, 0.18, 1.0)
    self:drawButton("btn_back", px + 0.006, headerY + 0.008, 0.045 * self.arScale, 0.026,
        "< Back", 0.12, 0.15, 0.22, 0.010)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw / 2, headerY + headerH * 0.28, 0.013, "Recent Calls")

    -- List
    local history = self.callHistory
    if #history == 0 then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextColor(0.45, 0.50, 0.60, 0.8)
        renderText(px + pw / 2, py + ph / 2, 0.011, "No recent calls.")
        return
    end

    local rowH   = 0.048
    local rowGap = 0.003
    local listY  = headerY - 0.008

    for i, entry in ipairs(history) do
        local rowY = listY - (i - 1) * (rowH + rowGap)
        if rowY - rowH < py then break end

        local shade = (i % 2 == 0) and 0.10 or 0.085
        self:drawRect(px, rowY - rowH, pw, rowH, shade, shade + 0.01, shade + 0.025, 1.0)

        -- Direction icon color and symbol
        local dirColor = {1, 1, 1}
        local dirSymbol = "→"
        if entry.direction == "incoming" then
            dirColor = {0.20, 0.80, 0.40}
            dirSymbol = "↙"
        elseif entry.direction == "missed" then
            dirColor = {0.90, 0.25, 0.25}
            dirSymbol = "↙"
        elseif entry.direction == "outgoing" then
            dirColor = {0.40, 0.65, 1.0}
            dirSymbol = "↗"
        end

        -- Direction arrow
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(true)
        setTextColor(dirColor[1], dirColor[2], dirColor[3], 1.0)
        renderText(px + 0.008, rowY - rowH + rowH * 0.28, 0.014, dirSymbol)

        -- Contact name
        setTextBold(true)
        setTextColor(0.92, 0.95, 1.0, 1.0)
        renderText(px + 0.026, rowY - rowH + rowH * 0.28, 0.012, entry.name or "Unknown")

        -- Direction label
        setTextBold(false)
        setTextColor(dirColor[1], dirColor[2], dirColor[3], 0.75)
        local label = entry.direction == "missed" and "Missed" 
            or entry.direction == "incoming" and "Incoming"
            or "Outgoing"
        renderText(px + 0.026, rowY - rowH + rowH * 0.62, 0.009, label)
    end
end


-- ─── Mission00 hooks ─────────────────────────────────────────────────────────
Mission00.update = Utils.appendedFunction(Mission00.update, function(mission, dt)
    RoleplayPhone:updateBattery(dt / 1000)
    RoleplayPhone:updateCallTimeout(dt)
    RoleplayPhone:updateCallKeyPoll()
end)

Mission00.draw = Utils.appendedFunction(Mission00.draw, function(mission)
    if not RoleplayPhone.inputRegistered then return end
    RoleplayPhone:draw()
end)


Mission00.mouseEvent = Utils.appendedFunction(Mission00.mouseEvent,
    function(mission, posX, posY, isDown, isUp, button)
        RoleplayPhone:mouseEvent(posX, posY, isDown, isUp, button)
    end)

local _phoneKeyListener = {}
function _phoneKeyListener:keyEvent(unicode, sym, modifier, isDown)
    RoleplayPhone:keyEvent(unicode, sym, modifier, isDown)
end

-- FS25 calls these on every registered mod event listener during game save/load.
-- Without them the engine fails the entire save with Error 7.
function _phoneKeyListener:saveToXMLFile(xmlFilename, key, usedModNames)
    RoleplayPhone:saveInvoices()
end

function _phoneKeyListener:loadFromXMLFile(xmlFilename, key)
    -- Loading is handled in Mission00.loadMap hook via RoleplayPhone:loadSavedData()
end

addModEventListener(_phoneKeyListener)

Mission00.loadMap = Utils.appendedFunction(Mission00.loadMap, function(mission, name)
    RoleplayPhone:init()
    RoleplayPhone:loadSavedData()
end)

-- Register the phone keybinding after gameplay fully starts.
-- The correct hook is MessageType.CURRENT_MISSION_LOADED via g_messageCenter --
-- that is the exact same event the built-in Player class uses to register its
-- own input actions (see Player:initialise). It fires AFTER "Entered Gameplay"
-- on both host and MP clients, so registration always lands at the right time.
RoleplayPhone.inputRegistered = false

g_messageCenter:subscribe(MessageType.CURRENT_MISSION_LOADED, function()
    if RoleplayPhone.inputRegistered then return end
    print("[RoleplayPhone] CURRENT_MISSION_LOADED fired, registering keybind")
    RoleplayPhone:registerKeybind()

    -- Login notification: fires after "Entered Gameplay" so farmId is reliable
    local myFarmId = RoleplayPhone:getMyFarmId()
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

    -- Client-pull contact sync: ask host for our saved contacts
    -- Host replies with RI_ContactSyncEvent containing this farm's contacts
    if g_server == nil and myFarmId and myFarmId > 0 then
        g_client:getServerConnection():sendEvent(
            RI_ContactEvent.new("request", myFarmId, 0, {}))
        print(string.format("[RoleplayPhone] Requested contact sync for farm %d", myFarmId))
    end
end, RoleplayPhone)

