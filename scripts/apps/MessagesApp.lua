-- scripts/apps/MessagesApp.lua
-- Messages app: conversation list screen (drawMessages) and message thread screen (drawMessageThread).
-- drawMessageThread was moved here from ContactsApp.lua.

-- ─── MESSAGES LIST screen ─────────────────────────────────────────────────────
function RoleplayPhone:drawMessages()
    local s  = self.PHONE
    local px = s.x
    local py = s.y
    local pw = s.w
    local ph = s.h

    self:drawPhoneBackground(0.06, 0.07, 0.10, 0.97)

    local contentY = py + ph - 0.012

    -- Header
    local headerH = 0.042
    local headerY = contentY - headerH
    self:drawRect(px, headerY, pw, headerH, 0.10, 0.13, 0.20, 1.0)

    self:drawButton("btn_back", px + 0.006, headerY + 0.008, 0.045 * self.arScale, 0.026,
        g_i18n:getText("ui_btn_back"), 0.18, 0.20, 0.28, 0.010)

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw / 2, headerY + headerH * 0.28, 0.013, g_i18n:getText("screen_title_messages"))

    -- Build thread list: contacts with any messages or pending unread count
    local threads = {}
    for i, c in ipairs(ContactManager.contacts) do
        local msgs   = self.messages[i]
        local unread = self.unreadMessages[i] or 0
        if (msgs and #msgs > 0) or unread > 0 then
            table.insert(threads, {
                index   = i,
                contact = c,
                lastMsg = msgs and msgs[#msgs] or nil,
                unread  = unread,
            })
        end
    end
    -- Also show messages from senders not in contacts (fallback threads)
    for key, info in pairs(self.messageDisplayNames) do
        local msgs   = self.messages[key]
        local unread = self.unreadMessages[key] or 0
        if (msgs and #msgs > 0) or unread > 0 then
            table.insert(threads, {
                index   = key,
                contact = {
                    name  = (info.phone and info.phone ~= "") and info.phone or info.name,
                    phone = info.phone or "",
                },
                lastMsg = msgs and msgs[#msgs] or nil,
                unread  = unread,
            })
        end
    end

    if #threads == 0 then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextColor(0.50, 0.52, 0.60, 0.8)
        renderText(px + pw / 2, py + ph / 2, 0.013, g_i18n:getText("messages_empty_state"))
        return
    end

    local listY  = headerY - 0.006
    local rowH   = 0.060
    local rowGap = 0.003

    for i, thread in ipairs(threads) do
        local rowY = listY - (i - 1) * (rowH + rowGap)
        if rowY - rowH < py then break end

        local shade = (i % 2 == 0) and 0.115 or 0.095
        self:drawRect(px, rowY - rowH, pw, rowH, shade, shade + 0.015, shade + 0.030, 1.0)

        -- Blue accent strip on left for unread threads
        if thread.unread > 0 then
            self:drawRect(px, rowY - rowH, 0.004, rowH, 0.20, 0.65, 0.95, 1.0)
        end

        -- Avatar
        local avSize = 0.034
        local avX    = px + 0.012
        local avY    = rowY - rowH + (rowH - avSize) / 2
        local avR, avG, avB = thread.unread > 0 and 0.10 or 0.15,
                               thread.unread > 0 and 0.40 or 0.32,
                               thread.unread > 0 and 0.72 or 0.60
        self:drawRect(avX, avY, avSize, avSize, avR, avG, avB, 1.0)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(1, 1, 1, 1)
        local initial = string.upper(string.sub(thread.contact.name or "?", 1, 1))
        if tonumber(initial) then initial = "?" end
        renderText(avX + avSize / 2, avY + avSize * 0.20, 0.018, initial)

        -- Contact name (bold if unread)
        local textX = avX + avSize + 0.012
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(thread.unread > 0)
        setTextColor(thread.unread > 0 and 1.0 or 0.80,
                     thread.unread > 0 and 1.0 or 0.85,
                     thread.unread > 0 and 1.0 or 0.95, 1.0)
        renderText(textX, rowY - rowH + rowH * 0.58, 0.012,
            thread.contact.name or g_i18n:getText("phone_unknown_contact"))

        -- Last message preview
        setTextBold(false)
        if thread.lastMsg then
            local preview = thread.lastMsg.text or ""
            if #preview > 28 then preview = preview:sub(1, 25) .. "..." end
            setTextColor(thread.unread > 0 and 0.60 or 0.45,
                         thread.unread > 0 and 0.80 or 0.50,
                         thread.unread > 0 and 0.95 or 0.65, 0.90)
            renderText(textX, rowY - rowH + rowH * 0.22, 0.010, preview)
        end

        -- Unread badge OR chevron (right side)
        if thread.unread > 0 then
            local bsz = 0.018
            local bx  = px + pw - bsz - 0.012
            local by  = rowY - rowH + (rowH - bsz) / 2
            self:drawRect(bx, by, bsz, bsz, 0.15, 0.55, 0.90, 1.0)
            setTextAlignment(RenderText.ALIGN_CENTER)
            setTextBold(true)
            setTextColor(1, 1, 1, 1)
            renderText(bx + bsz / 2, by + bsz * 0.20, 0.010,
                thread.unread > 9 and "9+" or tostring(thread.unread))
            setTextBold(false)
        else
            setTextAlignment(RenderText.ALIGN_RIGHT)
            setTextColor(0.35, 0.38, 0.50, 0.5)
            renderText(px + pw - 0.010, rowY - rowH + rowH * 0.38, 0.013, ">")
        end

        self:addHitbox("msg_thread_row", px, rowY - rowH, pw, rowH, { index = thread.index })
    end
end

-- ─── MESSAGE THREAD screen (big screen) ──────────────────────────────────────
-- Moved from ContactsApp.lua. Back button returns to MESSAGES list.
function RoleplayPhone:drawMessageThread()
    if not self.selectedContact then
        self.state = self.STATE.MESSAGES
        return
    end

    -- Resolve display info — either a saved contact or an unknown sender
    local isUnknown = type(self.selectedContact) == "string"
    local c, headerName, isContact

    if isUnknown then
        local info = self.messageDisplayNames[self.selectedContact]
        if not info then self.state = self.STATE.MESSAGES; return end
        -- Show phone number if we have it, otherwise fall back to sender name
        headerName = (info.phone and info.phone ~= "") and info.phone or info.name
        c          = { name = headerName, phone = info.phone or "" }
        isContact  = false
    else
        c = ContactManager:getContact(self.selectedContact)
        if not c then self.state = self.STATE.MESSAGES; return end
        headerName = c.name or g_i18n:getText("phone_unknown_contact")
        isContact  = true
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

    -- Right header button: Call for known contacts, Add Contact for unknowns
    if isContact then
        self:drawButton("btn_call", px + pw - 0.080 * self.arScale, headerY + 0.016, 0.068 * self.arScale, 0.030,
            g_i18n:getText("contacts_btn_call"), 0.10, 0.48, 0.22, 0.011)
    else
        self:drawButton("btn_add_unknown_contact", px + pw - 0.050 * self.arScale, headerY + 0.016, 0.040 * self.arScale, 0.030,
            "+", 0.10, 0.35, 0.55, 0.011)
    end

    -- Name/number centered in header
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(0.92, 0.95, 1.0, 1.0)
    renderText(px + pw/2, headerY + headerH * 0.28, 0.014, headerName)
    setTextBold(false)

    -- ── Compose bar (bottom) ──────────────────────────────────────────────────
    local composeH  = 0.096
    local composeY  = py + 0.006
    local sendBtnW  = 0.060 * self.arScale
    local sendBtnH  = 0.032
    local fieldX    = px + 0.010
    local fieldW    = pw - sendBtnW - 0.022
    local fieldH    = composeH - 0.016
    local fieldY    = composeY + 0.008
    local compose   = self.messageCompose
    local active    = compose.active

    self:drawRect(px, composeY, pw, composeH, 0.07, 0.09, 0.13, 1.0)
    self:drawRect(px, composeY + composeH - 0.002, pw, 0.002, 0.15, 0.18, 0.26, 0.6)

    -- Multiline field — same as invoice notes
    self:drawField("msg_field", fieldX, fieldY, fieldW, fieldH,
        "", compose.text, active, true)

    -- Placeholder overlay when empty and inactive
    if compose.text == "" and not active then
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(false)
        setTextColor(0.40, 0.40, 0.40, 0.85)
        renderText(fieldX + 0.008, fieldY + fieldH * 0.55, 0.012,
            g_i18n:getText("contacts_msg_placeholder"))
    end

    -- Send button — vertically centered in compose bar
    local sbX = fieldX + fieldW + 0.006
    local sbY = composeY + (composeH - sendBtnH) / 2
    local canSend = compose.text ~= ""
    local sbR = canSend and 0.10 or 0.15
    local sbG = canSend and 0.42 or 0.18
    local sbB = canSend and 0.22 or 0.20
    self:drawButton("btn_send_message", sbX, sbY, sendBtnW - 0.004, sendBtnH,
        g_i18n:getText("contacts_btn_send"), sbR, sbG, sbB, 0.010)

    -- ── Message thread (between header and compose bar) ───────────────────────
    local threadTop = headerY - 0.008
    local threadBot = composeY + composeH + 0.006
    local threadH   = threadTop - threadBot

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
        local bubblePad = 0.008
        local bubbleGap = 0.006
        local bubbleW   = pw * 0.68
        local textSize  = 0.011
        local lineH     = 0.016
        local topPad    = 0.006
        local botPad    = 0.008
        local dateSize  = 0.008
        local dateLineH = 0.012
        local dateGap   = 0.005
        local maxTextW  = bubbleW - 0.018

        -- Word-wrap helper (same pattern as invoice notes)
        local function wrapText(text)
            local lines = {}
            local words = {}
            for w in (text or ""):gmatch("%S+") do table.insert(words, w) end
            if #words == 0 then return {""} end
            local cur = ""
            for _, word in ipairs(words) do
                -- split any word wider than maxTextW
                while getTextWidth(textSize, word) > maxTextW do
                    local i = 1
                    while i < #word and getTextWidth(textSize, word:sub(1, i+1)) <= maxTextW do
                        i = i + 1
                    end
                    if cur ~= "" then table.insert(lines, cur); cur = "" end
                    table.insert(lines, word:sub(1, i))
                    word = word:sub(i + 1)
                end
                if word == "" then
                elseif cur == "" then
                    cur = word
                elseif getTextWidth(textSize, cur .. " " .. word) <= maxTextW then
                    cur = cur .. " " .. word
                else
                    table.insert(lines, cur)
                    cur = word
                end
            end
            if cur ~= "" then table.insert(lines, cur) end
            return lines
        end

        -- Pre-calculate lines + height for every message
        local msgData = {}
        for i = 1, #msgs do
            local lines = wrapText(msgs[i].text)
            local bh    = topPad + dateLineH + dateGap + #lines * lineH + botPad
            msgData[i]  = { lines = lines, h = bh }
        end

        -- Apply scroll offset (0 = newest at bottom)
        local scrollOffset = self.messageScrollOffset or 0
        local endIdx       = math.max(1, #msgs - scrollOffset)

        -- Work backwards from endIdx to find which messages fit
        local available = threadH - bubblePad * 2
        local startIdx  = endIdx + 1
        local used      = 0
        for i = endIdx, 1, -1 do
            local need = msgData[i].h + (i < endIdx and bubbleGap or 0)
            if used + need > available then break end
            used     = used + need
            startIdx = i
        end

        -- Scroll indicators
        if startIdx > 1 then
            setTextAlignment(RenderText.ALIGN_CENTER)
            setTextBold(false)
            setTextColor(0.70, 0.80, 1.0, 0.75)
            renderText(px + pw / 2, threadTop - 0.014, 0.010, "^ " .. g_i18n:getText("msg_scroll_older"))
        end
        if scrollOffset > 0 then
            setTextAlignment(RenderText.ALIGN_CENTER)
            setTextBold(false)
            setTextColor(0.70, 0.80, 1.0, 0.75)
            renderText(px + pw / 2, threadBot + 0.004, 0.010, "v " .. g_i18n:getText("msg_scroll_newer"))
        end

        -- Render newest at bottom, oldest at top
        local curY = threadBot + bubblePad
        for i = endIdx, startIdx, -1 do
            local msg    = msgs[i]
            local md     = msgData[i]
            local isSent = msg.sent
            local bh     = md.h
            local bx     = isSent and (px + pw - bubbleW - 0.012) or (px + 0.012)
            local textX  = isSent and (bx + bubbleW - 0.009) or (bx + 0.009)

            local br = isSent and 0.10 or 0.14
            local bg = isSent and 0.40 or 0.18
            local bb = isSent and 0.20 or 0.42
            self:drawRect(bx, curY, bubbleW, bh, br, bg, bb, 1.0)

            -- Date stamp near top of bubble
            local dateStr = self:formatGameDate(msg.gameDay or 0)
            if (msg.gameTime or 0) > 0 then
                dateStr = dateStr .. "  " .. self:formatGameTime(msg.gameTime)
            end
            local dateY = curY + botPad + #md.lines * lineH + dateGap
            setTextAlignment(isSent and RenderText.ALIGN_RIGHT or RenderText.ALIGN_LEFT)
            setTextBold(false)
            setTextColor(0.55, 0.65, 0.75, 0.7)
            renderText(textX, dateY, dateSize, dateStr)

            -- Text lines (line 1 at top, last line nearest bottom)
            setTextColor(1, 1, 1, 0.95)
            for li, line in ipairs(md.lines) do
                local lineY = curY + botPad + (#md.lines - li) * lineH
                renderText(textX, lineY, textSize, line)
            end

            curY = curY + bh + bubbleGap
        end
    end
end
