-- scripts/apps/CallsApp.lua
-- Calls app: Keypad / Recents / Contacts tabs + floating call-screen overlay.

-- ─── MAIN ENTRY ──────────────────────────────────────────────────────────────
function RoleplayPhone:drawCallsApp()
    local s  = self.PHONE
    local px = s.x
    local py = s.y
    local pw = s.w
    local ph = s.h

    self:drawPhoneBackground(0.06, 0.07, 0.10, 0.97)

    -- Header
    local headerH = 0.042
    local headerY = py + ph - 0.012 - headerH
    self:drawRect(px, headerY, pw, headerH, 0.08, 0.11, 0.18, 1.0)
    self:drawButton("btn_back", px + 0.006, headerY + 0.008, 0.045 * self.arScale, 0.026,
        g_i18n:getText("ui_btn_back"), 0.12, 0.15, 0.22, 0.010)

    -- Clear All button — only on Recents tab when history exists
    local tab = self.callsTab or "keypad"
    if tab == "recents" and #self.callHistory > 0 then
        local clrW = 0.044 * self.arScale
        local clrH = 0.026
        local clrX = px + pw - clrW - 0.006
        local clrY = headerY + (headerH - clrH) / 2
        self:drawButton("recents_clear_all", clrX, clrY, clrW, clrH,
            g_i18n:getText("recents_clear_all"), 0.40, 0.10, 0.10, 0.009)
    end

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw / 2, headerY + headerH * 0.28, 0.013,
        g_i18n:getText("screen_title_calls"))

    -- Tab bar (sits immediately below header)
    local tabBarH = 0.036
    local tabBarY = headerY - tabBarH
    self:drawCallsTabBar(px, tabBarY, pw, tabBarH)

    -- Content area (everything between tab bar bottom and phone bottom)
    local contentH = tabBarY - py
    local tab = self.callsTab or "keypad"
    if     tab == "keypad"   then self:drawCallsKeypad(px, py, pw, contentH)
    elseif tab == "recents"  then self:drawCallsRecents(px, py, pw, contentH)
    elseif tab == "contacts" then self:drawCallsContacts(px, py, pw, contentH)
    end
end

-- ─── TAB BAR ─────────────────────────────────────────────────────────────────
function RoleplayPhone:drawCallsTabBar(px, tabBarY, pw, tabBarH)
    local tab  = self.callsTab or "keypad"
    local tabs = {
        { id = "calls_tab_keypad",   label = g_i18n:getText("calls_tab_keypad")   },
        { id = "calls_tab_recents",  label = g_i18n:getText("calls_tab_recents")  },
        { id = "calls_tab_contacts", label = g_i18n:getText("calls_tab_contacts") },
    }
    local tabW = pw / #tabs
    for i, t in ipairs(tabs) do
        local tx     = px + (i - 1) * tabW
        local active = (tab == t.id:sub(11))  -- strips "calls_tab_" (10 chars)
        local br = active and 0.12 or 0.07
        local bg = active and 0.18 or 0.10
        local bb = active and 0.28 or 0.15
        self:drawRect(tx, tabBarY, tabW, tabBarH, br, bg, bb, 1.0)
        if active then
            -- Blue underline on active tab
            self:drawRect(tx, tabBarY + tabBarH - 0.003, tabW, 0.003, 0.25, 0.55, 1.0, 1.0)
        end
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(active)
        setTextColor(
            active and 1.0 or 0.58,
            active and 1.0 or 0.64,
            active and 1.0 or 0.75,
            1.0)
        renderText(tx + tabW / 2, tabBarY + tabBarH * 0.25, 0.011, t.label)
        self:addHitbox(t.id, tx, tabBarY, tabW, tabBarH)
    end
    -- Separator below tab bar
    self:drawRect(px, tabBarY - 0.002, pw, 0.002, 0.15, 0.22, 0.38, 0.8)
end

-- ─── KEYPAD TAB ──────────────────────────────────────────────────────────────
function RoleplayPhone:drawCallsKeypad(px, py, pw, contentH)
    local num = self.keypadNumber or ""
    local displayNum = self:formatKeypadDisplay(num)

    -- Layout constants
    local gap       = 0.008
    local callBtnH  = 0.040
    local btnH      = 0.038
    local rows      = 4
    local cols      = 3
    local rowGap    = 0.005
    local gridH     = rows * btnH + (rows - 1) * rowGap
    local dispH     = 0.048
    local totalH    = dispH + gap + gridH + gap + callBtnH

    -- Vertically center the whole keypad block in the content area
    local startY    = py + math.max(gap, (contentH - totalH) / 2)
    local callBtnY  = startY
    local gridStartY = callBtnY + callBtnH + gap
    local dispY     = gridStartY + gridH + gap

    -- ── Number display ─────────────────────────────────────────────────────
    local margin = 0.010
    self:drawRect(px + margin, dispY, pw - margin * 2, dispH, 0.05, 0.07, 0.12, 1.0)
    if num ~= "" then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(1, 1, 1, 1)
        renderText(px + pw / 2, dispY + dispH * 0.25, 0.017, displayNum)

        -- Delete (backspace) button right of display
        local delW = 0.038 * self.arScale
        local delH = 0.028
        local delX = px + pw - margin - delW
        local delY = dispY + (dispH - delH) / 2
        self:drawRect(delX, delY, delW, delH, 0.38, 0.10, 0.10, 0.85)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextColor(1, 0.55, 0.55, 1)
        renderText(delX + delW / 2, delY + delH * 0.18, 0.010, "DEL")
        self:addHitbox("keypad_del", delX, delY, delW, delH)
    else
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextColor(0.35, 0.40, 0.52, 0.75)
        renderText(px + pw / 2, dispY + dispH * 0.25, 0.012,
            g_i18n:getText("keypad_hint"))
    end

    -- ── Digit grid ─────────────────────────────────────────────────────────
    local digits = { "1","2","3", "4","5","6", "7","8","9", "*","0","#" }
    local btnW   = (pw - (cols + 1) * gap) / cols

    for i, d in ipairs(digits) do
        local rowIdx = math.ceil(i / cols) - 1   -- 0-indexed from top
        local colIdx = (i - 1) % cols
        local bx     = px + gap + colIdx * (btnW + gap)
        local by     = gridStartY + (rows - 1 - rowIdx) * (btnH + rowGap)

        self:drawRect(bx, by, btnW, btnH, 0.11, 0.16, 0.26, 1.0)

        -- Hover highlight
        local mx, my = self.mouseX or 0, self.mouseY or 0
        if self:hitTest(mx, my, bx, by, btnW, btnH) then
            self:drawRect(bx, by, btnW, btnH, 0.18, 0.26, 0.42, 0.60)
        end

        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(0.88, 0.93, 1.0, 1.0)
        renderText(bx + btnW / 2, by + btnH * 0.22, 0.016, d)

        local id
        if     d == "*" then id = "keypad_star"
        elseif d == "#" then id = "keypad_hash"
        else                 id = "keypad_" .. d
        end
        self:addHitbox(id, bx, by, btnW, btnH)
    end

    -- ── Call button ─────────────────────────────────────────────────────────
    local active   = num ~= ""
    local callBtnW = pw * 0.55
    local callBtnX = px + (pw - callBtnW) / 2
    local cr = active and 0.08 or 0.06
    local cg = active and 0.42 or 0.25
    local cb = active and 0.16 or 0.14
    local ca = active and 1.0  or 0.60
    self:drawRect(callBtnX, callBtnY, callBtnW, callBtnH, cr, cg, cb, ca)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, active and 1.0 or 0.45)
    renderText(callBtnX + callBtnW / 2, callBtnY + callBtnH * 0.23, 0.013,
        g_i18n:getText("calls_btn_call"))
    if active then
        self:addHitbox("keypad_call", callBtnX, callBtnY, callBtnW, callBtnH)
    end
end

-- ─── RECENTS TAB ─────────────────────────────────────────────────────────────
function RoleplayPhone:drawCallsRecents(px, py, pw, contentH)
    local history = self.callHistory
    if #history == 0 then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextColor(0.45, 0.50, 0.60, 0.8)
        renderText(px + pw / 2, py + contentH / 2, 0.011,
            g_i18n:getText("calls_empty"))
        return
    end

    local rowH   = 0.050
    local rowGap = 0.003
    local listY  = py + contentH - 0.006

    for i, entry in ipairs(history) do
        local rowY = listY - (i - 1) * (rowH + rowGap)
        if rowY - rowH < py then break end

        local shade = (i % 2 == 0) and 0.100 or 0.085
        self:drawRect(px, rowY - rowH, pw, rowH, shade, shade + 0.010, shade + 0.025, 1.0)

        local isMissed = entry.direction == "missed" or entry.direction == "missed_seen"
        local dirColor, dirSymbol
        if entry.direction == "incoming" then
            dirColor = {0.20, 0.80, 0.40}; dirSymbol = "<<"
        elseif isMissed then
            dirColor = {0.90, 0.25, 0.25}; dirSymbol = "<<"
        else
            dirColor = {0.40, 0.65, 1.00}; dirSymbol = ">>"
        end

        -- Direction arrow
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(true)
        setTextColor(dirColor[1], dirColor[2], dirColor[3], 1.0)
        renderText(px + 0.008, rowY - rowH + rowH * 0.52, 0.013, dirSymbol)

        -- Contact name (use saved contact name if phone matches, else stored name)
        setTextBold(true)
        setTextColor(0.92, 0.95, 1.0, 1.0)
        local displayName = self:getContactNameByPhone(entry.phone) or entry.name
        renderText(px + 0.028, rowY - rowH + rowH * 0.52, 0.012,
            displayName or g_i18n:getText("phone_unknown_contact"))

        -- Direction label
        setTextBold(false)
        setTextColor(dirColor[1], dirColor[2], dirColor[3], 0.75)
        local label = isMissed and g_i18n:getText("calls_dir_missed")
            or entry.direction == "incoming" and g_i18n:getText("calls_dir_incoming")
            or g_i18n:getText("calls_dir_outgoing")
        renderText(px + 0.028, rowY - rowH + rowH * 0.18, 0.009, label)

        -- Date/time (right-aligned, left of callback button if present)
        local cbW     = 0.040 * self.arScale
        local dateStr = self:formatGameDate(entry.gameDay or 0)
        if (entry.gameTime or 0) > 0 then
            dateStr = dateStr .. "  " .. self:formatGameTime(entry.gameTime)
        end
        local dateEdgeX = (entry.phone and entry.phone ~= "")
            and (px + pw - 0.008 - cbW - 0.008)
            or  (px + pw - 0.010)
        setTextAlignment(RenderText.ALIGN_RIGHT)
        setTextBold(false)
        setTextColor(0.42, 0.48, 0.60, 0.70)
        renderText(dateEdgeX, rowY - rowH + rowH * 0.18, 0.009, dateStr)

        -- Call-back button — only shown when phone number is known
        if entry.phone and entry.phone ~= "" then
            local cbW = 0.040 * self.arScale
            local cbH = 0.028
            local cbX = px + pw - 0.008 - cbW
            local cbY = rowY - rowH + (rowH - cbH) / 2
            self:drawRect(cbX, cbY, cbW, cbH, 0.07, 0.36, 0.13, 0.90)
            setTextAlignment(RenderText.ALIGN_CENTER)
            setTextBold(false)
            setTextColor(0.70, 1.0, 0.70, 1.0)
            renderText(cbX + cbW / 2, cbY + cbH * 0.18, 0.009,
                g_i18n:getText("calls_btn_call"))
            self:addHitbox("recents_callback", cbX, cbY, cbW, cbH,
                { phone = entry.phone, name = entry.name })
        end
    end
end

-- ─── CONTACTS TAB ────────────────────────────────────────────────────────────
function RoleplayPhone:drawCallsContacts(px, py, pw, contentH)
    local contacts = ContactManager.contacts
    if #contacts == 0 then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextColor(0.50, 0.52, 0.60, 0.8)
        renderText(px + pw / 2, py + contentH / 2, 0.013,
            g_i18n:getText("contacts_empty_state"))
        return
    end

    local rowH   = 0.052
    local rowGap = 0.003
    local listY  = py + contentH - 0.006

    for i, c in ipairs(contacts) do
        local rowY = listY - (i - 1) * (rowH + rowGap)
        if rowY - rowH < py then break end

        local shade = (i % 2 == 0) and 0.115 or 0.095
        self:drawRect(px, rowY - rowH, pw, rowH, shade, shade + 0.015, shade + 0.030, 1.0)

        -- Avatar initial
        local avSize = 0.030
        local avX    = px + 0.010
        local avY    = rowY - rowH + (rowH - avSize) / 2
        self:drawRect(avX, avY, avSize, avSize, 0.12, 0.28, 0.58, 1.0)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(1, 1, 1, 1)
        renderText(avX + avSize / 2, avY + avSize * 0.18, 0.016,
            string.upper(string.sub(c.name or "?", 1, 1)))

        -- Name + phone sub-line
        local textX = avX + avSize + 0.010
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(true)
        setTextColor(0.90, 0.92, 1.0, 1.0)
        renderText(textX, rowY - rowH + rowH * 0.52, 0.012,
            c.name or g_i18n:getText("phone_unknown_contact"))
        setTextBold(false)
        setTextColor(0.50, 0.60, 0.76, 0.9)
        renderText(textX, rowY - rowH + rowH * 0.18, 0.010,
            (c.phone and c.phone ~= "") and c.phone
            or g_i18n:getText("contacts_no_phone"))

        -- Call button
        local canCall = c.phone and c.phone ~= ""
        local cbW = 0.044 * self.arScale
        local cbH = 0.030
        local cbX = px + pw - 0.008 - cbW
        local cbY = rowY - rowH + (rowH - cbH) / 2
        local callR = canCall and 0.08 or 0.12
        local callG = canCall and 0.38 or 0.18
        local callB = canCall and 0.14 or 0.20
        local callA = canCall and 0.90 or 0.50
        self:drawRect(cbX, cbY, cbW, cbH, callR, callG, callB, callA)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextColor(1, 1, 1, canCall and 1.0 or 0.40)
        renderText(cbX + cbW / 2, cbY + cbH * 0.18, 0.009,
            g_i18n:getText("calls_btn_call"))
        if canCall then
            self:addHitbox("calls_contact_call", cbX, cbY, cbW, cbH, { index = i })
        end
    end
end

-- ─── CALL SCREEN OVERLAY ─────────────────────────────────────────────────────
-- Floating popup shown during outgoing / incoming / active calls.
-- Rendered over the world, not inside the phone app — stays unchanged.
function RoleplayPhone:drawCallScreen()
    local call = self.call

    local pw  = 0.165 * self.arScale
    local ph  = 0.140
    local px  = 0.01
    local py  = 0.38
    local cx  = px + pw / 2

    self:drawRect(px - 0.004, py - 0.004, pw + 0.008, ph + 0.008, 0.08, 0.12, 0.22, 0.85)
    self:drawRect(px, py, pw, ph, 0.04, 0.07, 0.14, 0.97)
    self:drawRect(px, py + ph - 0.003, pw, 0.003, 0.25, 0.50, 1.0, 0.9)

    local statusStr = g_i18n:getText("call_status_calling")
    if self.state == self.STATE.CALL_INCOMING then statusStr = g_i18n:getText("call_status_incoming")
    elseif self.state == self.STATE.CALL_ACTIVE then statusStr = g_i18n:getText("call_status_active") end
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(false)
    setTextColor(0.55, 0.70, 1.0, 0.9)
    renderText(cx, py + ph - 0.022, 0.012, statusStr)

    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(cx, py + ph * 0.62, 0.018, call.contactName or g_i18n:getText("phone_unknown_contact"))

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
        renderText(cx, py + ph * 0.44, 0.012, g_i18n:getText("call_ringing") .. dots)
    end

    local gap  = 0.008
    local btnW = (pw - gap * 3) / 2
    local btnH = 0.032
    local btnY = py + 0.018
    if self.state == self.STATE.CALL_INCOMING then
        local bx1 = px + gap
        local bx2 = px + gap * 2 + btnW
        self:drawRect(bx1, btnY, btnW, btnH, 0.08, 0.45, 0.18, 0.85)
        setTextBold(false)
        setTextColor(1, 1, 1, 0.9)
        renderText(bx1 + btnW / 2, btnY + 0.008, 0.010, g_i18n:getText("call_btn_answer"))
        self:drawRect(bx2, btnY, btnW, btnH, 0.50, 0.10, 0.10, 0.85)
        renderText(bx2 + btnW / 2, btnY + 0.008, 0.010, g_i18n:getText("call_btn_decline"))
    else
        self:drawRect(cx - btnW / 2, btnY, btnW, btnH, 0.50, 0.10, 0.10, 0.85)
        setTextBold(false)
        setTextColor(1, 1, 1, 0.9)
        renderText(cx, btnY + 0.008, 0.010, g_i18n:getText("call_btn_end"))
    end

    setTextBold(false)
    setTextColor(0.50, 0.60, 0.75, 0.70)
    renderText(cx, py + 0.004, 0.009,
        string.format(g_i18n:getText("call_key_hint_fmt"), self:getCallActionKeyName()))
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
    -- saveSavegame handles all saving now — this is intentionally empty
    -- (engine requires this function to exist to avoid Error 7)
end

function _phoneKeyListener:loadFromXMLFile(xmlFilename, key)
    -- Loading is handled in Mission00.loadMap hook via RoleplayPhone:loadSavedData()
end

addModEventListener(_phoneKeyListener)

Mission00.loadMap = Utils.appendedFunction(Mission00.loadMap, function(mission, name)
    RoleplayPhone:init()
    RoleplayPhone:loadSavedData()
end)

-- Register keybind + announce player after gameplay fully starts.
RoleplayPhone.inputRegistered = false

g_messageCenter:subscribe(MessageType.CURRENT_MISSION_LOADED, function()
    if RoleplayPhone.inputRegistered then return end
    print("[RoleplayPhone] CURRENT_MISSION_LOADED fired, registering keybind")
    RoleplayPhone:registerKeybind()

    local myUserId   = RoleplayPhone:getMyUserId()
    local myFarmId   = RoleplayPhone:getMyFarmId()
    local myUniqueId = RoleplayPhone:getMyUniqueId()
    local myName     = (g_currentMission and g_currentMission.playerNickname)
                       or RoleplayPhone:getFarmName(myFarmId)
    local myPhone    = RoleplayPhone:hashPhone(myUserId)

    -- Load host's own player data now that uniqueId is available (local hosted sessions only)
    -- On dedicated servers all player data is pushed via sync events — no direct file load needed
    if g_server ~= nil and myUniqueId ~= "" then
        local entry    = RoleplayPhone:getOrCreateRegistryEntry(myUniqueId, myPhone)
        local filename = RoleplayPhone:buildPlayerFilename(myName, entry.fileId)
        RoleplayPhone:loadPlayerData(filename, true)
        print("[RoleplayPhone] Host data loaded: " .. filename)

        -- Repopulate messageDisplayNames for u_ keyed threads (unknown senders)
        local reg = RoleplayPhone:loadPlayerRegistry()
        for key, _ in pairs(RoleplayPhone.messages) do
            if type(key) == "string" and key:sub(1, 2) == "u_" then
                local uid = key:sub(3)
                local info = { name = "Unknown", phone = "", userId = 0 }
                for _, regEntry in ipairs(reg) do
                    if regEntry.uniqueId == uid then
                        info.phone = regEntry.phone or ""
                        info.name  = regEntry.phone or "Unknown"
                        break
                    end
                end
                -- Fallback: pull senderName from first message in thread
                if info.name == "Unknown" then
                    local msgs = RoleplayPhone.messages[key]
                    if msgs and msgs[1] then info.name = msgs[1].senderName or "Unknown" end
                end
                RoleplayPhone.messageDisplayNames[key] = info
            end
        end
    end

    -- Announce ourselves so everyone knows we're online
    local helloEvt = RI_PlayerHelloEvent.new(myUserId, myFarmId, myName, myPhone, myUniqueId)
    if g_server ~= nil then
        RoleplayPhone.onlineUsers[myUserId] = {
            farmId   = myFarmId,
            name     = myName,
            phone    = myPhone,
            uniqueId = myUniqueId,
        }
        g_server:broadcastEvent(helloEvt)
    elseif g_client ~= nil then
        g_client:getServerConnection():sendEvent(helloEvt)
    end
    print(string.format("[RoleplayPhone] Sent PlayerHello: userId=%d farmId=%d phone=%s name=%s",
        myUserId, myFarmId, myPhone, myName))

    -- Login notification for unpaid invoices
    local unpaid = 0
    for _, inv in pairs(InvoiceManager.invoices) do
        if inv.toFarmId == myFarmId and inv.status == "PENDING" then
            unpaid = unpaid + 1
        end
    end
    if unpaid > 0 then
        local msg = unpaid == 1
            and g_i18n:getText("phone_notif_unpaid_one")
            or  string.format(g_i18n:getText("phone_notif_unpaid_multi"), unpaid)
        NotificationManager:push("info", msg)
    end

    -- Contact sync is now push-based (server pushes on connect) — no client pull needed
end, RoleplayPhone)
