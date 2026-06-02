-- scripts/PhoneInput.lua
-- Mouse and keyboard input handling: mouseEvent, onHitboxClicked, keyEvent, handleBackspace.
-- onHitboxClicked delegates to app-specific handlers in scripts/apps/*Input.lua.

function RoleplayPhone:mouseEvent(posX, posY, isDown, isUp, button)
    self.mouseX = posX
    self.mouseY = posY

    -- When phone is closed, let NotificationManager handle HUD icon dragging
    if self.state == self.STATE.CLOSED then
        NotificationManager:mouseEvent(posX, posY, isDown, isUp, button)
        return
    end

    -- Forward to NotificationManager from HOME — cursor is visible so icon can be dragged
    if self.state == self.STATE.HOME then
        local handled = NotificationManager:mouseEvent(posX, posY, isDown, isUp, button)
        if handled then return end
    end

    -- Scroll wheel on message thread
    if self.state == self.STATE.MESSAGE_THREAD and isDown then
        local msgs = self.selectedContact and (self.messages[self.selectedContact] or {}) or {}
        if button == Input.MOUSE_BUTTON_WHEEL_UP then
            self.messageScrollOffset = math.min(#msgs - 1, (self.messageScrollOffset or 0) + 1)
            return
        end
        if button == Input.MOUSE_BUTTON_WHEEL_DOWN then
            self.messageScrollOffset = math.max(0, (self.messageScrollOffset or 0) - 1)
            return
        end
    end

    -- Scroll wheel on create invoice form
    if self.state == self.STATE.INVOICE_CREATE and isDown then
        local scrollStep = 0.058
        local maxScroll  = scrollStep * 3
        if button == Input.MOUSE_BUTTON_WHEEL_UP then
            self.form.scrollOffset = math.max(0, self.form.scrollOffset - scrollStep)
            return
        end
        if button == Input.MOUSE_BUTTON_WHEEL_DOWN then
            self.form.scrollOffset = math.min(maxScroll, self.form.scrollOffset + scrollStep)
            return
        end
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
        self.homePage = hb.data.page; return
    end
    if hb.id == "page_prev" then self.homePage = math.max(1, self.homePage - 1); return end
    if hb.id == "page_next" then self.homePage = math.min(self.homePageCount, self.homePage + 1); return end

    -- Dock app clicks
    if hb.id:sub(1,5) == "dock_" and hb.data and hb.data.appId then
        local appId = hb.data.appId
        if appId == "invoices" then
            local myFarmId = self:getMyFarmId()
            for _, inv in pairs(InvoiceManager.invoices) do
                if inv.toFarmId == myFarmId and inv.status == "PENDING" then
                    self.seenInvoiceIds[inv.id] = true
                end
            end
            self.state = self.STATE.INVOICES_LIST; return
        end
        if appId == "contacts" then self.state = self.STATE.CONTACTS;      return end
        if appId == "messages" then self.state = self.STATE.MESSAGES;      return end
        if appId == "calls"    then self.state = self.STATE.CALLS; self:clearMissedCallBadge(); return end
        if appId == "settings" then self.state = self.STATE.SETTINGS;      return end
        return
    end

    -- Grid app clicks (page 2+)
    if hb.id:sub(1,9) == "grid_app_" and hb.data and hb.data.appId then
        local appId = hb.data.appId
        if appId == "weather" then self.state = self.STATE.WEATHER; return end
        -- market: TODO
        return
    end

    -- App-specific input handlers
    if self:handleCallsInput(hb)    then return end
    if self:handleContactsInput(hb) then return end
    if self:handleMessagesInput(hb) then return end
    if self:handleInvoicesInput(hb) then return end

    -- Back button
    if hb.id == "btn_back" then
        if self.state == self.STATE.CALLS then
            self:clearMissedCallBadge()
            self.dialerFromMessages = false
            self:goHome(); return
        end
        if self.state == self.STATE.MESSAGE_THREAD then
            self.messageCompose.active = false
            self.messageCompose.text   = ""
            self.state = self.STATE.MESSAGES; return
        end
        if self.state == self.STATE.MESSAGES       then self:goHome(); return end
        if self.state == self.STATE.CONTACT_DETAIL then self.state = self.STATE.CONTACTS; return end
        if self.state == self.STATE.INVOICE_CREATE  then self.state = self.STATE.INVOICES_LIST; return end
        if self.state == self.STATE.INVOICE_DETAIL  then self.state = self.STATE.INVOICES_LIST; return end
        self:goHome(); return
    end

    -- Invoice inbox/outbox tabs
    if hb.id == "tab_inbox"  then self.currentTab = self.TAB.INBOX;  return end
    if hb.id == "tab_outbox" then self.currentTab = self.TAB.OUTBOX; return end

    -- Settings tabs
    if hb.id == "settings_tab_general"   then self.settingsTab = "general";   return end
    if hb.id == "settings_tab_ringtones" then self.settingsTab = "ringtones"; return end
    if hb.id == "settings_tab_wallpaper" then self.settingsTab = "wallpaper"; return end

    -- Wallpaper preview / apply
    if hb.id == "wallp_prev" then
        local cur = self.previewWallpaper or self.settings.wallpaperIndex
        self.previewWallpaper = ((cur - 2) % #self.WALLPAPERS) + 1; return
    end
    if hb.id == "wallp_next" then
        local cur = self.previewWallpaper or self.settings.wallpaperIndex
        self.previewWallpaper = (cur % #self.WALLPAPERS) + 1; return
    end
    if hb.id == "wallp_apply" then
        if self.previewWallpaper then
            self.settings.wallpaperIndex = self.previewWallpaper
            self:saveSettings()
        end; return
    end

    -- Settings toggles
    if hb.id == "setting_timeformat_12"  then self.settings.timeFormat = "12"; self:saveSettings(); return end
    if hb.id == "setting_timeformat_24"  then self.settings.timeFormat = "24"; self:saveSettings(); return end
    if hb.id == "setting_temp_F"         then self.settings.tempUnit = "F";    self:saveSettings(); return end
    if hb.id == "setting_temp_C"         then self.settings.tempUnit = "C";    self:saveSettings(); return end
    if hb.id == "setting_battery_toggle" then
        self.settings.batteryVisible = not self.settings.batteryVisible
        self:saveSettings(); return
    end
    if hb.id == "setting_voicemode_toggle" and g_server ~= nil then
        self.rpVoiceModeConfig = not (self.rpVoiceModeConfig or false)
        self:saveServerConfig()
        local state = self.rpVoiceModeConfig
            and g_i18n:getText("settings_on")
            or  g_i18n:getText("settings_off")
        NotificationManager:push("info",
            string.format(g_i18n:getText("settings_rp_voice_saved_fmt"), state))
        return
    end

    -- Ringtone arrows + preview
    if hb.id == "ringtone_prev" then
        local n = #self.RINGTONES
        local cur = self.previewRingtone or self.settings.ringtoneIndex
        self.previewRingtone = ((cur - 2) % n) + 1; return
    end
    if hb.id == "ringtone_next" then
        local n = #self.RINGTONES
        local cur = self.previewRingtone or self.settings.ringtoneIndex
        self.previewRingtone = (cur % n) + 1; return
    end
    if hb.id == "ringtone_apply" then
        if self.previewRingtone then
            self.settings.ringtoneIndex = self.previewRingtone
            self.ringSample = self.ringtoneSamples[self.previewRingtone]
            self:saveSettings()
        end; return
    end
    if hb.id == "ringtone_preview" then
        -- Stop any currently-playing preview before starting a new one
        for _, sample in ipairs(self.ringtoneSamples or {}) do
            if sample and sample ~= 0 then stopSample(sample, 0, 0) end
        end
        local cur = self.previewRingtone or self.settings.ringtoneIndex
        local s = self.ringtoneSamples[cur]
        if s and s ~= 0 then playSample(s, 1, 1.0, 1.0, 0, 0) end
        return
    end
end

function RoleplayPhone:keyEvent(unicode, sym, modifier, isDown)
    if not isDown then return false end

    -- Self-cleanup: exit TEXT_INPUT context if no text field is currently active.
    -- Handles the case where a field was deactivated without calling deactivateTextInputContext.
    if self._textInputContextActive then
        local hasActiveField =
            (self.form.activeField ~= nil      and self.state == self.STATE.INVOICE_CREATE) or
            (self.contactForm.activeField ~= nil and self.state == self.STATE.CONTACT_CREATE) or
            (self.messageCompose.active          and self.state == self.STATE.MESSAGE_THREAD)
        if not hasActiveField then
            self:deactivateTextInputContext()
        end
    end

    -- FS25 constants are lowercase (Input.KEY_backspace, not KEY_BackSpace)
    local isBackspace = (unicode == 8)
        or (Input.KEY_backspace ~= nil and sym == Input.KEY_backspace)
    local isLeft   = sym == Input.KEY_left
    local isRight  = sym == Input.KEY_right
    local isHome   = sym == Input.KEY_home
    local isEnd    = sym == Input.KEY_end
    local isFwdDel = sym == Input.KEY_delete
    local isCtrl   = bit32.band(modifier, Input.MOD_LCTRL) > 0
    local isCtrlV  = isCtrl and sym == Input.KEY_v
    local isCtrlA  = isCtrl and sym == Input.KEY_a
    local isCtrlC  = isCtrl and sym == Input.KEY_c

    -- Ensure cursor state is initialized for the given field value.
    local function ensureCursor(val)
        if not self.textCursor then self:activateFieldCursor(val) end
    end

    -- Delete the char before cursor (no selection). Returns new string.
    -- Confirmed utf8Substr(str, start0, -1) = from start to end (FS25 TextInputElement pattern).
    local function backspaceAt(val)
        local p   = self.textCursor.pos
        local len = utf8Strlen(val)
        if p <= 1 then return val end
        local before = (p - 1 > 1) and utf8Substr(val, 0, p - 2) or ""
        local after  = (p - 1 < len) and utf8Substr(val, p - 1, -1) or ""
        self.textCursor.pos = p - 1
        self._cursorBlinkOrigin = getTimeSec()
        return before .. after
    end

    -- Delete the char at cursor position (forward delete, no selection). Returns new string.
    local function forwardDeleteAt(val)
        local p   = self.textCursor.pos
        local len = utf8Strlen(val)
        if p > len then return val end
        local before = (p > 1) and utf8Substr(val, 0, p - 1) or ""
        local after  = (p < len) and utf8Substr(val, p, -1) or ""
        self._cursorBlinkOrigin = getTimeSec()
        return before .. after
    end

    -- ── Keypad digit entry (Calls dialer) ────────────────────────────────────
    if self.state == self.STATE.CALLS and (self.callsTab or "keypad") == "keypad" then
        if isBackspace then
            local n = self.keypadNumber or ""
            if #n > 0 then self.keypadNumber = n:sub(1, #n - 1) end
            return true
        end
        if unicode and unicode >= 48 and unicode <= 57 then
            if #(self.keypadNumber or "") < self:getMaxKeypadDigits() then
                self.keypadNumber = (self.keypadNumber or "") .. string.char(unicode)
            end
            return true
        end
        return false
    end

    -- ── Invoice create text fields ───────────────────────────────────────────
    if self.form.activeField and self.state == self.STATE.INVOICE_CREATE then
        local field  = self.form.activeField
        local val    = self.form[field] or ""
        local maxLen = (field == "amount") and 10 or 200

        ensureCursor(val)

        if sym == Input.KEY_tab or sym == Input.KEY_return then
            local order = {"amount", "dueDate", "notes"}
            for i, f in ipairs(order) do
                if f == field then
                    self.form.activeField = order[i + 1] or nil
                    if self.form.activeField then
                        self:activateFieldCursor(self.form[self.form.activeField] or "")
                    end
                    break
                end
            end
            return true
        end
        if isCtrlA then
            local len = utf8Strlen(val)
            self.textCursor = {pos = len + 1, selStart = 1, selEnd = len + 1}
            return true
        end
        if isLeft  then self:tcMoveCursor(val, -1, isCtrl); return true end
        if isRight then self:tcMoveCursor(val,  1, isCtrl); return true end
        if isHome  then
            self.textCursor.pos = 1; self.textCursor.selStart = nil
            self.textCursor.selEnd = nil; self._cursorBlinkOrigin = getTimeSec()
            return true
        end
        if isEnd then
            self.textCursor.pos = utf8Strlen(val) + 1; self.textCursor.selStart = nil
            self.textCursor.selEnd = nil; self._cursorBlinkOrigin = getTimeSec()
            return true
        end
        if isBackspace then
            local s = self:getSelectionRange()
            self.form[field] = s and self:tcDeleteSelection(val) or backspaceAt(val)
            return true
        end
        if isFwdDel then
            local s = self:getSelectionRange()
            self.form[field] = s and self:tcDeleteSelection(val) or forwardDeleteAt(val)
            return true
        end
        if isCtrlC then
            local s, e = self:getSelectionRange()
            RoleplayPhone._clipboard = s and utf8Substr(val, s-1, e-s) or val
            return true
        end
        if isCtrlV and field ~= "amount" then
            self.form[field] = self:tcInsert(val, RoleplayPhone._clipboard, maxLen)
            return true
        end
        if unicode and unicode > 31 and (unicode < 127 or getCanRenderUnicode(unicode)) then
            self.form[field] = self:tcInsert(val, unicodeToUtf8(unicode), maxLen)
            return true
        end
        return false
    end

    -- ── Contact create/edit text fields ──────────────────────────────────────
    if self.contactForm.activeField and self.state == self.STATE.CONTACT_CREATE then
        local field = self.contactForm.activeField
        local val   = self.contactForm[field] or ""

        ensureCursor(val)

        if sym == Input.KEY_tab or sym == Input.KEY_return then
            local order = {"name", "phone", "role", "notes"}
            for i, f in ipairs(order) do
                if f == field then
                    self.contactForm.activeField = order[i + 1] or nil
                    if self.contactForm.activeField then
                        self:activateFieldCursor(self.contactForm[self.contactForm.activeField] or "")
                    end
                    break
                end
            end
            return true
        end

        if field == "phone" then
            -- Digits only, auto-formatted — no mid-string cursor (display changes on every digit)
            local digits    = val:gsub("[^%d]", "")
            local maxDigits = self:getMaxKeypadDigits()
            if isBackspace then
                if #digits > 0 then
                    digits = digits:sub(1, #digits - 1)
                    self.contactForm.phone = self:formatKeypadDisplay(digits)
                    self:activateFieldCursor(self.contactForm.phone)
                end
            elseif unicode and unicode >= 48 and unicode <= 57 then
                if #digits < maxDigits then
                    digits = digits .. string.char(unicode)
                    self.contactForm.phone = self:formatKeypadDisplay(digits)
                    self:activateFieldCursor(self.contactForm.phone)
                end
            end
            return true
        end

        if isCtrlA then
            local len = utf8Strlen(val)
            self.textCursor = {pos = len + 1, selStart = 1, selEnd = len + 1}
            return true
        end
        if isLeft  then self:tcMoveCursor(val, -1, isCtrl); return true end
        if isRight then self:tcMoveCursor(val,  1, isCtrl); return true end
        if isHome  then
            self.textCursor.pos = 1; self.textCursor.selStart = nil
            self.textCursor.selEnd = nil; self._cursorBlinkOrigin = getTimeSec()
            return true
        end
        if isEnd then
            self.textCursor.pos = utf8Strlen(val) + 1; self.textCursor.selStart = nil
            self.textCursor.selEnd = nil; self._cursorBlinkOrigin = getTimeSec()
            return true
        end
        if isBackspace then
            local s = self:getSelectionRange()
            self.contactForm[field] = s and self:tcDeleteSelection(val) or backspaceAt(val)
            return true
        end
        if isFwdDel then
            local s = self:getSelectionRange()
            self.contactForm[field] = s and self:tcDeleteSelection(val) or forwardDeleteAt(val)
            return true
        end
        if isCtrlC then
            local s, e = self:getSelectionRange()
            RoleplayPhone._clipboard = s and utf8Substr(val, s-1, e-s) or val
            return true
        end
        if isCtrlV then
            self.contactForm[field] = self:tcInsert(val, RoleplayPhone._clipboard, 60)
            return true
        end
        if unicode and unicode > 31 and (unicode < 127 or getCanRenderUnicode(unicode)) then
            self.contactForm[field] = self:tcInsert(val, unicodeToUtf8(unicode), 60)
            return true
        end
        return false
    end

    -- ── Message compose ──────────────────────────────────────────────────────
    if self.messageCompose.active and self.state == self.STATE.MESSAGE_THREAD then
        local val = self.messageCompose.text or ""

        ensureCursor(val)

        if sym == Input.KEY_return then
            self:sendMessage()
            self:activateFieldCursor("")  -- sendMessage clears text; reset cursor to pos 1
            return true
        end
        if isCtrlA then
            local len = utf8Strlen(val)
            self.textCursor = {pos = len + 1, selStart = 1, selEnd = len + 1}
            return true
        end
        if isLeft  then self:tcMoveCursor(val, -1, isCtrl); return true end
        if isRight then self:tcMoveCursor(val,  1, isCtrl); return true end
        if isHome  then
            self.textCursor.pos = 1; self.textCursor.selStart = nil
            self.textCursor.selEnd = nil; self._cursorBlinkOrigin = getTimeSec()
            return true
        end
        if isEnd then
            self.textCursor.pos = utf8Strlen(val) + 1; self.textCursor.selStart = nil
            self.textCursor.selEnd = nil; self._cursorBlinkOrigin = getTimeSec()
            return true
        end
        if isBackspace then
            local s = self:getSelectionRange()
            self.messageCompose.text = s and self:tcDeleteSelection(val) or backspaceAt(val)
            return true
        end
        if isFwdDel then
            local s = self:getSelectionRange()
            self.messageCompose.text = s and self:tcDeleteSelection(val) or forwardDeleteAt(val)
            return true
        end
        if isCtrlC then
            local s, e = self:getSelectionRange()
            RoleplayPhone._clipboard = s and utf8Substr(val, s-1, e-s) or val
            return true
        end
        if isCtrlV then
            self.messageCompose.text = self:tcInsert(val, RoleplayPhone._clipboard, 300)
            return true
        end
        if unicode and unicode > 31 and (unicode < 127 or getCanRenderUnicode(unicode)) then
            self.messageCompose.text = self:tcInsert(val, unicodeToUtf8(unicode), 300)
            return true
        end
    end

    return false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TEXT CURSOR HELPERS
-- Used by keyEvent and drawField. textCursor is shared state on RoleplayPhone.
-- cursorPos is 1-based: 1 = before first char, len+1 = after last char.
-- ═══════════════════════════════════════════════════════════════════════════════

-- Call when activating a text field. Resets cursor to end of current value.
function RoleplayPhone:activateFieldCursor(val)
    local len = utf8Strlen(val or "")
    self.textCursor = { pos = len + 1, selStart = nil, selEnd = nil }
    self._cursorBlinkOrigin = getTimeSec()
    -- Enter TEXT_INPUT context when a field becomes active.
    -- This tells the engine to stop intercepting Ctrl+V at the C++ level
    -- so it reaches our addModEventListener:keyEvent. Stacks on RI_PHONE_UI.
    if not self._textInputContextActive then
        g_inputBinding:setContext("TEXT_INPUT", true, false)
        self._textInputContextActive = true
        print("[RoleplayPhone] TEXT_INPUT context activated")
    end
end

-- Exits TEXT_INPUT context when no text field is active.
function RoleplayPhone:deactivateTextInputContext()
    if self._textInputContextActive then
        g_inputBinding:revertContext(true)
        self._textInputContextActive = false
        print("[RoleplayPhone] TEXT_INPUT context deactivated")
    end
end

-- Places cursor at the character position closest to clickX in a single-line field.
-- fieldTextStartX = hb.x + textPad (textPad is 0.004 in drawField).
-- textSize = 0.012 (drawField constant). For long trimmed fields placement is approximate.
function RoleplayPhone:placeCursorAtX(val, fieldTextStartX, textSize, clickX)
    local offset = math.max(0, clickX - fieldTextStartX)
    local len    = utf8Strlen(val or "")
    for i = 1, len do
        local w = getTextWidth(textSize, utf8Substr(val, 0, i))
        if w >= offset then
            local prevW = i > 1 and getTextWidth(textSize, utf8Substr(val, 0, i - 1)) or 0
            local pos   = ((offset - prevW) < (w - offset)) and i or (i + 1)
            self.textCursor         = { pos = pos, selStart = nil, selEnd = nil }
            self._cursorBlinkOrigin = getTimeSec()
            return
        end
    end
    -- Click past end of text → cursor at end
    self.textCursor         = { pos = len + 1, selStart = nil, selEnd = nil }
    self._cursorBlinkOrigin = getTimeSec()
end

-- Returns true when the cursor rect should be drawn (blink on/off).
function RoleplayPhone:isCursorBlinkVisible()
    local elapsed = getTimeSec() - (self._cursorBlinkOrigin or 0)
    return (elapsed % 0.8) < 0.4
end

-- Returns ordered selection range (sMin, sMax) or (nil, nil) if no selection.
function RoleplayPhone:getSelectionRange()
    local c = self.textCursor
    if c and c.selStart and c.selEnd and c.selStart ~= c.selEnd then
        return math.min(c.selStart, c.selEnd), math.max(c.selStart, c.selEnd)
    end
    return nil, nil
end

-- Deletes the active selection from val. Returns (newVal, true) or (val, false).
function RoleplayPhone:tcDeleteSelection(val)
    local s, e = self:getSelectionRange()
    if not s then return val, false end
    local before = s > 1 and utf8Substr(val, 0, s-1) or ""
    local after  = e <= utf8Strlen(val) and utf8Substr(val, e-1) or ""
    self.textCursor = { pos = s, selStart = nil, selEnd = nil }
    return before .. after, true
end

-- Inserts str at cursor position (or replaces selection). Respects maxLen char limit.
function RoleplayPhone:tcInsert(val, str, maxLen)
    local newVal, _ = self:tcDeleteSelection(val)
    local pos    = self.textCursor.pos
    local len    = utf8Strlen(newVal)
    local strLen = utf8Strlen(str)
    if maxLen then
        local remaining = maxLen - len
        if remaining <= 0 then return newVal end
        if strLen > remaining then str = utf8Substr(str, 0, remaining); strLen = utf8Strlen(str) end
    end
    local before = pos > 1 and utf8Substr(newVal, 0, pos-1) or ""
    local after  = pos <= len and utf8Substr(newVal, pos-1) or ""
    self.textCursor.pos      = pos + strLen
    self.textCursor.selStart = nil
    self.textCursor.selEnd   = nil
    self._cursorBlinkOrigin  = getTimeSec()
    return before .. str .. after
end

-- Moves cursor left (dir=-1) or right (dir=1). isCtrl = word jump.
-- Clears selection on movement (shift-selection not yet implemented).
function RoleplayPhone:tcMoveCursor(val, dir, isCtrl)
    local c   = self.textCursor
    local len = utf8Strlen(val or "")
    local newPos

    if dir < 0 then  -- left
        if isCtrl then
            local pos = c.pos
            while pos > 1 and utf8Substr(val, pos-2, 1) == " " do pos = pos - 1 end
            while pos > 1 and utf8Substr(val, pos-2, 1) ~= " " do pos = pos - 1 end
            newPos = pos
        else
            newPos = math.max(1, c.pos - 1)
        end
    else  -- right
        if isCtrl then
            local pos = c.pos
            while pos <= len and utf8Substr(val, pos-1, 1) ~= " " do pos = pos + 1 end
            while pos <= len and utf8Substr(val, pos-1, 1) == " " do pos = pos + 1 end
            newPos = pos
        else
            newPos = math.min(len + 1, c.pos + 1)
        end
    end

    c.selStart = nil
    c.selEnd   = nil
    c.pos      = newPos
    self._cursorBlinkOrigin = getTimeSec()
end
