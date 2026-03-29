function RoleplayPhone:drawContacts()
    local s  = self.PHONE
    local px = s.x
    local py = s.y
    local pw = s.w
    local ph = s.h

    -- Phone background (padded to fill frame bezel edges)
    self:drawPhoneBackground(0.06, 0.07, 0.10, 0.97)

    local contentY = py + ph - 0.012

    -- Header bar
    local headerH = 0.042
    local headerY = contentY - headerH
    self:drawRect(px, headerY, pw, headerH, 0.10, 0.13, 0.20, 1.0)

    -- Back button
    self:drawButton("btn_back", px + 0.006, headerY + 0.008, 0.045 * self.arScale, 0.026,
        g_i18n:getText("ui_btn_back"), 0.18, 0.20, 0.28, 0.010)

    -- Title
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw / 2, headerY + headerH * 0.28, 0.013, g_i18n:getText("screen_title_contacts"))

    -- Add button (top-right)
    self:drawButton("btn_add_contact", px + pw - 0.068 * self.arScale, headerY + 0.008, 0.062 * self.arScale, 0.026,
        g_i18n:getText("contacts_btn_add"), 0.10, 0.38, 0.18, 0.012)

    -- ── Contact list ──────────────────────────────────────────────────────────
    local listY    = headerY - 0.008
    local rowH     = 0.056
    local rowGap   = 0.003
    local contacts = ContactManager.contacts

    if #contacts == 0 then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextColor(0.50, 0.52, 0.60, 0.8)
        renderText(px + pw / 2, py + ph / 2, 0.013,
            g_i18n:getText("contacts_empty_state"))
        return
    end

    for i, c in ipairs(contacts) do
        local rowY = listY - (i - 1) * (rowH + rowGap)
        if rowY - rowH < py then break end   -- clip below screen

        -- Alternating row shade
        local shade = (i % 2 == 0) and 0.115 or 0.095
        self:drawRect(px, rowY - rowH, pw, rowH, shade, shade + 0.015, shade + 0.030, 1.0)

        -- Avatar square (first initial)
        local avSize = 0.034
        local avX    = px + 0.012
        local avY    = rowY - rowH + (rowH - avSize) / 2
        self:drawRect(avX, avY, avSize, avSize, 0.15, 0.32, 0.60, 1.0)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(1, 1, 1, 1)
        renderText(avX + avSize / 2, avY + avSize * 0.20, 0.018,
            string.upper(string.sub(c.name or "?", 1, 1)))

        -- Name
        local textX = avX + avSize + 0.012
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(true)
        setTextColor(0.90, 0.92, 1.0, 1.0)
        renderText(textX, rowY - rowH + rowH * 0.52, 0.013, c.name or g_i18n:getText("phone_unknown_contact"))

        -- Farm name (sub-line)
        setTextBold(false)
        setTextColor(0.52, 0.62, 0.78, 0.9)
        renderText(textX, rowY - rowH + rowH * 0.18, 0.011,
            (c.farmName ~= "" and c.farmName) or g_i18n:getText("contacts_no_farm"))

        -- Phone (right side, green tint)
        if c.phone and c.phone ~= "" then
            setTextAlignment(RenderText.ALIGN_RIGHT)
            setTextColor(0.38, 0.72, 0.38, 0.9)
            renderText(px + pw - 0.014, rowY - rowH + rowH * 0.38, 0.011, c.phone)
        end

        -- Chevron hint
        setTextAlignment(RenderText.ALIGN_RIGHT)
        setTextColor(0.40, 0.42, 0.55, 0.6)
        renderText(px + pw - 0.008, rowY - rowH + rowH * 0.38, 0.013, ">")

        -- Unread message badge (green dot + count)
        local unread = self.unreadMessages[i] or 0
        if unread > 0 then
            local dotR  = 0.012
            local dotX  = px + pw - 0.038
            local dotY  = rowY - rowH + (rowH / 2) - dotR
            -- Green filled circle (drawn as small square for now)
            self:drawRect(dotX, dotY, dotR * 2, dotR * 2, 0.15, 0.75, 0.30, 1.0)
            -- Count number inside
            setTextAlignment(RenderText.ALIGN_CENTER)
            setTextBold(true)
            setTextColor(1, 1, 1, 1)
            local countStr = unread > 9 and "9+" or tostring(unread)
            renderText(dotX + dotR, dotY + dotR * 0.25, 0.010, countStr)
        end

        -- Hitbox for the whole row
        self:addHitbox("contact_row", px, rowY - rowH, pw, rowH, { index = i })
    end
end


-- ─── CONTACT DETAIL screen ────────────────────────────────────────────────────
-- ─── CONTACT DETAIL screen (small phone screen) ──────────────────────────────
function RoleplayPhone:drawContactDetail()
    if not self.selectedContact then
        self.state = self.STATE.CONTACTS
        return
    end
    local c = ContactManager:getContact(self.selectedContact)
    if not c then
        self.state = self.STATE.CONTACTS
        return
    end

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
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw / 2, headerY + headerH * 0.28, 0.013, g_i18n:getText("screen_title_contact_detail"))

    -- Avatar
    local avSz = pw * 0.25
    local avH  = avSz * self.actualAR
    local avX  = px + pw/2 - avSz/2
    local avY  = headerY - avH - 0.018
    self:drawRect(avX, avY, avSz, avH, 0.15, 0.32, 0.60, 1.0)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(avX + avSz/2, avY + avH * 0.25, 0.028,
        string.upper(string.sub(c.name or "?", 1, 1)))

    -- Name
    setTextBold(true)
    setTextColor(0.92, 0.95, 1.0, 1.0)
    renderText(px + pw/2, avY - 0.018, 0.014, c.name or g_i18n:getText("phone_unknown_contact"))

    -- Info rows
    local infoY = avY - 0.040
    local infoX = px + 0.012
    local rowH  = 0.030
    local gap   = 0.006

    local function infoRow(label, value)
        if not value or value == "" then return end
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(false)
        setTextColor(0.50, 0.62, 0.78, 0.85)
        renderText(infoX, infoY, 0.009, label)
        setTextColor(0.92, 0.95, 1.0, 1.0)
        renderText(infoX, infoY - 0.014, 0.011, value)
        infoY = infoY - rowH - gap
    end

    infoRow(g_i18n:getText("contacts_label_phone"), c.phone)
    infoRow(g_i18n:getText("contacts_label_notes"), c.notes)

    -- Message and Delete buttons
    local btnW = pw - 0.020
    local btnH = 0.032
    local btnX = px + 0.010

    self:drawButton("btn_call",           btnX, py + 0.092, btnW, btnH,
        g_i18n:getText("contacts_btn_call"),    0.10, 0.48, 0.22, 0.011)
    self:drawButton("btn_message_contact", btnX, py + 0.052, btnW, btnH,
        g_i18n:getText("contacts_btn_message"), 0.10, 0.35, 0.55, 0.011)
    self:drawButton("btn_delete_contact",  btnX, py + 0.012, btnW, btnH,
        g_i18n:getText("contacts_btn_delete"),  0.50, 0.10, 0.10, 0.010)
end

-- ─── MESSAGE THREAD screen (big screen) ──────────────────────────────────────
function RoleplayPhone:drawMessageThread()
    if not self.selectedContact then
        self.state = self.STATE.CONTACTS
        return
    end

    local c = ContactManager:getContact(self.selectedContact)
    if not c then
        self.state = self.STATE.CONTACTS
        return
    end

    local s  = self.BIG
    local px = s.x
    local py = s.y
    local pw = s.w
    local ph = s.h

    self:drawBigScreen()

    -- ── Header bar ────────────────────────────────────────────────────────────
    local headerH = 0.062
    local headerY = py + ph - 0.055 - headerH
    self:drawRect(px, headerY, pw, headerH, 0.07, 0.10, 0.16, 1.0)

    self:drawButton("btn_back", px + 0.006, headerY + 0.016, 0.055 * self.arScale, 0.030,
        g_i18n:getText("ui_btn_back"), 0.15, 0.18, 0.26, 0.011)

    -- Call button (top right of header)
    self:drawButton("btn_call", px + pw - 0.080 * self.arScale, headerY + 0.016, 0.068 * self.arScale, 0.030,
        g_i18n:getText("contacts_btn_call"), 0.10, 0.48, 0.22, 0.011)

    -- Name centered in header
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(0.92, 0.95, 1.0, 1.0)
    renderText(px + pw/2, headerY + headerH * 0.28, 0.014, c.name or g_i18n:getText("phone_unknown_contact"))
    setTextBold(false)

    -- ── Compose bar (bottom) ──────────────────────────────────────────────────
    local composeH  = 0.052
    local composeY  = py + 0.006
    local sendBtnW  = 0.060 * self.arScale
    local fieldX    = px + 0.010
    local fieldW    = pw - sendBtnW - 0.022
    local compose   = self.messageCompose

    -- Compose background
    self:drawRect(px, composeY, pw, composeH, 0.07, 0.09, 0.13, 1.0)
    self:drawRect(px, composeY + composeH - 0.002, pw, 0.002, 0.15, 0.18, 0.26, 0.6)

    -- Text input pill
    local pillH = 0.032
    local pillY = composeY + (composeH - pillH) / 2
    local active = compose.active
    local pillBg = active and 0.16 or 0.10
    self:drawRect(fieldX, pillY, fieldW, pillH, pillBg, pillBg + 0.03, pillBg + 0.08, 1.0)
    self:drawRect(fieldX, pillY + pillH - 0.002, fieldW, 0.002, 0.3, 0.4, 0.6,
        active and 0.8 or 0.3)

    local displayText = (compose.text == "" and not active) and g_i18n:getText("contacts_msg_placeholder") or compose.text
    local displayCol  = (compose.text == "" and not active) and 0.40 or 1.0
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(displayCol, displayCol, displayCol, 0.85)
    renderText(fieldX + 0.008, pillY + pillH * 0.25, 0.012,
        displayText .. (active and "|" or ""))
    self:addHitbox("msg_field", fieldX, pillY, fieldW, pillH, {})

    -- Send button
    local canSend = compose.text ~= ""
    local sbX = fieldX + fieldW + 0.006
    local sbR = canSend and 0.10 or 0.15
    local sbG = canSend and 0.42 or 0.18
    local sbB = canSend and 0.22 or 0.20
    self:drawButton("btn_send_message", sbX, pillY, sendBtnW - 0.004, pillH,
        g_i18n:getText("contacts_btn_send"), sbR, sbG, sbB, 0.010)

    -- ── Message thread (between header and compose bar) ───────────────────────
    local threadTop = headerY - 0.008
    local threadBot = composeY + composeH + 0.006
    local threadH   = threadTop - threadBot

    -- Clip region visual (subtle inner border)
    self:drawRect(px, threadBot, pw, 0.001, 0.12, 0.14, 0.20, 0.4)

    local msgs = self.messages[self.selectedContact] or {}

    if #msgs == 0 then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextColor(0.35, 0.40, 0.50, 0.8)
        renderText(px + pw/2, threadBot + threadH/2, 0.012,
            g_i18n:getText("contacts_msg_empty"))
        renderText(px + pw/2, threadBot + threadH/2 - 0.018, 0.010,
            g_i18n:getText("contacts_msg_prompt"))
    else
        -- Show most recent messages that fit, newest at bottom
        -- Calculate how many we can fit
        local bubblePad  = 0.008
        local bubbleH    = 0.038   -- height per message row (wrapping is TODO)
        local bubbleGap  = 0.006
        local maxVisible = math.floor(threadH / (bubbleH + bubbleGap))
        local startIdx   = math.max(1, #msgs - maxVisible + 1)

        local curY = threadBot + bubblePad
        for i = startIdx, #msgs do
            local msg      = msgs[i]
            local isSent   = msg.sent
            local bubbleW  = pw * 0.68
            local bx       = isSent and (px + pw - bubbleW - 0.012) or (px + 0.012)

            -- Bubble background
            local br = isSent and 0.10 or 0.14
            local bg = isSent and 0.40 or 0.18
            local bb = isSent and 0.20 or 0.42
            self:drawRect(bx, curY, bubbleW, bubbleH, br, bg, bb, 1.0)

            -- Message text
            setTextAlignment(isSent and RenderText.ALIGN_RIGHT or RenderText.ALIGN_LEFT)
            setTextBold(false)
            setTextColor(1, 1, 1, 0.95)
            local textX = isSent and (bx + bubbleW - 0.008) or (bx + 0.008)
            renderText(textX, curY + bubbleH * 0.35, 0.011, msg.text or "")

            -- Day label (small, muted)
            setTextAlignment(isSent and RenderText.ALIGN_RIGHT or RenderText.ALIGN_LEFT)
            setTextColor(0.55, 0.65, 0.75, 0.7)
            renderText(textX, curY + bubbleH * 0.68, 0.008,
                string.format(g_i18n:getText("ui_day_fmt"), msg.gameDay or 0))

            curY = curY + bubbleH + bubbleGap
        end
    end
end


-- ─── CONTACT CREATE screen ────────────────────────────────────────────────────
function RoleplayPhone:drawContactCreate()
    local s  = self.PHONE
    local px = s.x
    local py = s.y
    local pw = s.w
    local ph = s.h

    self:drawPhoneBackground(0.06, 0.07, 0.10, 0.97)

    local contentY = py + ph - 0.012

    -- Header bar
    local headerH = 0.042
    local headerY = contentY - headerH
    self:drawRect(px, headerY, pw, headerH, 0.10, 0.13, 0.20, 1.0)

    self:drawButton("btn_back", px + 0.006, headerY + 0.010, 0.055 * self.arScale, 0.030,
        g_i18n:getText("ui_btn_back"), 0.18, 0.20, 0.28, 0.011)

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw / 2, headerY + headerH * 0.30, 0.016, g_i18n:getText("screen_title_new_contact"))

    local f    = self.contactForm
    local fX   = px + 0.012
    local fW   = pw - 0.024
    local fH   = 0.044
    local fGap = 0.008
    local fY   = headerY - 0.014

    -- Name field (free text)
    fY = fY - fH
    self:drawField("cf_name", fX, fY, fW, fH, g_i18n:getText("contacts_field_name"), f.name, f.activeField == "name")

    -- ── Online player picker (replaces free-text farmName) ────────────────────
    fY = fY - fH - fGap

    -- Build sorted list of online players (excluding ourselves)
    local myUserId = self:getMyUserId()
    local onlineList = {}
    for uid, info in pairs(self.onlineUsers) do
        if uid ~= myUserId then
            table.insert(onlineList, { userId = uid, name = info.name, phone = info.phone, farmId = info.farmId })
        end
    end
    table.sort(onlineList, function(a, b) return a.name < b.name end)

    -- Label
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(0.6, 0.7, 0.8, 0.9)
    renderText(fX + 0.008, fY + fH - 0.013, 0.010, g_i18n:getText("contacts_field_player"))

    if #onlineList == 0 then
        -- Nobody online to add
        self:drawRect(fX, fY, fW, fH, 0.10, 0.14, 0.20, 1.0)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextColor(0.45, 0.50, 0.60, 0.8)
        renderText(fX + fW / 2, fY + fH * 0.28, 0.011, g_i18n:getText("contacts_no_players_online"))
    else
        -- Clamp picker index
        local maxIdx = #onlineList
        if not self.contactForm.playerPickerIdx or self.contactForm.playerPickerIdx < 1 then
            self.contactForm.playerPickerIdx = 1
        elseif self.contactForm.playerPickerIdx > maxIdx then
            self.contactForm.playerPickerIdx = maxIdx
        end

        local idx      = self.contactForm.playerPickerIdx
        local selected = onlineList[idx]
        local arrowW   = 0.026 * self.arScale
        local nameW    = fW - arrowW * 2 - 0.008

        -- Arrow left
        self:drawButton("cf_player_prev", fX, fY, arrowW, fH, "<", 0.15, 0.20, 0.35, 0.013)

        -- Player name display
        local nameX = fX + arrowW + 0.004
        self:drawRect(nameX, fY, nameW, fH, 0.12, 0.16, 0.28, 1.0)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(1, 1, 1, 1)
        renderText(nameX + nameW / 2, fY + fH * 0.42, 0.012, selected.name)
        setTextBold(false)
        setTextColor(0.45, 0.78, 0.45, 0.85)
        renderText(nameX + nameW / 2, fY + fH * 0.14, 0.009, selected.phone)

        -- Index indicator
        setTextColor(0.45, 0.50, 0.65, 0.60)
        renderText(nameX + nameW / 2, fY + fH * 0.70, 0.008,
            string.format("%d / %d", idx, maxIdx))

        -- Arrow right
        self:drawButton("cf_player_next", nameX + nameW + 0.004, fY, arrowW, fH, ">", 0.15, 0.20, 0.35, 0.013)

        -- Sync contactForm fields from selection
        f.farmName     = self:getFarmName(selected.farmId)
        f.phone        = selected.phone
        f.playerUserId = selected.userId
    end

    -- Notes field
    fY = fY - fH - fGap
    self:drawField("cf_notes", fX, fY, fW, fH, g_i18n:getText("contacts_field_notes"), f.notes, f.activeField == "notes")

    -- Validation hint
    if f.name == "" then
        fY = fY - 0.020
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextColor(0.80, 0.55, 0.20, 0.85)
        renderText(px + pw / 2, fY + 0.006, 0.010, g_i18n:getText("contacts_validation_name"))
    end

    -- Save button
    fY = fY - fH - 0.012
    local canSave = f.name and f.name ~= "" and f.playerUserId and f.playerUserId ~= 0
    local btnR = canSave and 0.10 or 0.20
    local btnG = canSave and 0.38 or 0.22
    local btnB = canSave and 0.18 or 0.22
    self:drawButton("btn_save_contact", fX, fY, fW, fH,
        g_i18n:getText("contacts_btn_save"), btnR, btnG, btnB, 0.013)
end


-- ─── resetContactForm helper ──────────────────────────────────────────────────
function RoleplayPhone:resetContactForm()
    self.contactForm = {
        name            = "",
        farmName        = "",
        phone           = "",
        notes           = "",
        playerUserId    = 0,
        playerPickerIdx = 1,
        activeField     = nil,
    }
end


-- ─── SETTINGS screen ──────────────────────────────────────────────────────────
