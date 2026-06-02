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

    local nmW = 0.052 * self.arScale
    self:drawButton("btn_new_message", px + pw - nmW - 0.006, headerY + 0.008, nmW, 0.026,
        g_i18n:getText("ui_btn_new_msg"), 0.10, 0.32, 0.55, 0.010)

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw / 2, headerY + headerH * 0.28, 0.013, g_i18n:getText("screen_title_messages"))

    -- Build thread list only when dirty (new message received/loaded) or cache is empty
    if self._threadsDirty or not self._sortedThreads then
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
                        name  = self:getContactNameByPhone(info.phone) or info.phone or info.name,
                        phone = info.phone or "",
                    },
                    lastMsg = msgs and msgs[#msgs] or nil,
                    unread  = unread,
                })
            end
        end
        -- Sort threads: most recently active first (newest lastMsg gameDay/gameTime)
        table.sort(threads, function(a, b)
            local aDay  = a.lastMsg and (a.lastMsg.gameDay  or 0) or 0
            local aTime = a.lastMsg and (a.lastMsg.gameTime or 0) or 0
            local bDay  = b.lastMsg and (b.lastMsg.gameDay  or 0) or 0
            local bTime = b.lastMsg and (b.lastMsg.gameTime or 0) or 0
            if aDay ~= bDay then return aDay > bDay end
            return aTime > bTime
        end)
        self._sortedThreads = threads
        self._threadsDirty  = false
    end
    local threads = self._sortedThreads

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

        -- Contact name (bold if unread)
        local textX = px + 0.012
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
            local preview = (thread.lastMsg.msgType == "contact_card") and g_i18n:getText("msg_contact_card_preview") or (thread.lastMsg.text or "")
            if #preview > 28 then preview = preview:sub(1, 25) .. "..." end
            setTextColor(thread.unread > 0 and 0.60 or 0.45,
                         thread.unread > 0 and 0.80 or 0.50,
                         thread.unread > 0 and 0.95 or 0.65, 0.90)
            renderText(textX, rowY - rowH + rowH * 0.22, 0.010, preview)
        end

        -- Delete thread button (far right)
        local delW = 0.016 * self.arScale
        local delH = 0.026
        local delX = px + pw - delW - 0.006
        local delY = rowY - rowH + (rowH - delH) / 2
        self:drawRect(delX, delY, delW, delH, 0.38, 0.08, 0.08, 0.80)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(1, 0.50, 0.50, 1)
        renderText(delX + delW / 2, delY + delH * 0.18, 0.009, "X")
        self:addHitbox("msg_delete_thread", delX, delY, delW, delH, { index = thread.index })

        -- Unread badge OR chevron (right of content, left of delete button)
        local badgeEdge = delX - 0.006
        if thread.unread > 0 then
            local bsz = 0.018
            local bx  = badgeEdge - bsz
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
            renderText(badgeEdge, rowY - rowH + rowH * 0.38, 0.013, ">")
        end

        self:addHitbox("msg_thread_row", px, rowY - rowH, delX - px - 0.004, rowH, { index = thread.index })
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
        -- Use saved contact name if available, then phone, then raw nickname
        headerName = self:getContactNameByPhone(info.phone)
                  or (info.phone and info.phone ~= "" and info.phone)
                  or info.name
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

    -- Sort + alreadySentCard cache — recomputes only when contact or message count changes
    local _msgs     = self.messages[self.selectedContact] or {}
    local _cacheKey = tostring(self.selectedContact) .. ":" .. tostring(#_msgs)
    if self._msgCacheKey ~= _cacheKey then
        if #_msgs > 1 then
            table.sort(_msgs, function(a, b)
                if a.gameDay ~= b.gameDay then return a.gameDay < b.gameDay end
                return (a.gameTime or 0) < (b.gameTime or 0)
            end)
        end
        local _found = false
        for _, _m in ipairs(_msgs) do
            if _m.sent and (_m.msgType or "text") == "contact_card" then _found = true; break end
        end
        self._msgAlreadySentCard = _found
        self._msgDataCache       = nil
        self._msgCacheKey        = _cacheKey
    end

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
    local composeH  = 0.112
    local composeY  = py + 0.006
    local sendBtnW  = 0.060 * self.arScale
    local sendBtnH  = 0.030
    local cardBtnH  = 0.026
    local btnGap    = 0.005
    local totalBtnH = sendBtnH + cardBtnH + btnGap
    local btnTopY   = composeY + (composeH - totalBtnH) / 2
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

    -- Character counter (bottom-right of compose field, visible when active or has text)
    local charCount = utf8Strlen(compose.text)
    if charCount > 0 or active then
        local cr, cg, cb, ca
        if charCount >= 295 then
            cr, cg, cb, ca = 0.95, 0.30, 0.25, 1.00   -- red: almost full
        elseif charCount >= 250 then
            cr, cg, cb, ca = 0.90, 0.70, 0.15, 0.85   -- orange: getting close
        else
            cr, cg, cb, ca = 0.80, 0.85, 0.95, 0.90   -- dim: plenty of room
        end
        setTextAlignment(RenderText.ALIGN_RIGHT)
        setTextBold(false)
        setTextColor(cr, cg, cb, ca)
        renderText(fieldX + fieldW - 0.004, fieldY + 0.006, 0.008,
            charCount .. "/300")
    end

    -- Share Card button (above Send) — hide if already sent card in this thread
    local btnX  = fieldX + fieldW + 0.006
    local cbY   = btnTopY + sendBtnH + btnGap
    local alreadySentCard = self._msgAlreadySentCard or false
    if not alreadySentCard then
        self:drawButton("btn_share_card", btnX, cbY, sendBtnW - 0.004, cardBtnH,
            g_i18n:getText("msg_share_card"), 0.18, 0.28, 0.45, 0.009)
    end

    -- Send button (bottom of right column)
    local canSend = compose.text ~= ""
    local sbR = canSend and 0.10 or 0.15
    local sbG = canSend and 0.42 or 0.18
    local sbB = canSend and 0.22 or 0.20
    self:drawButton("btn_send_message", btnX, btnTopY, sendBtnW - 0.004, sendBtnH,
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

        -- Pre-calculate lines + height once; reuse cached table until messages change
        if not self._msgDataCache then
            local cardFixedH = topPad + dateLineH + dateGap + 2 * lineH + 0.030 + botPad
            local built = {}
            for i = 1, #msgs do
                if (msgs[i].msgType or "text") == "contact_card" then
                    built[i] = { lines = {}, h = cardFixedH, isCard = true }
                else
                    local lines = self:wrapText(msgs[i].text, textSize, maxTextW)
                    local bh    = topPad + dateLineH + dateGap + #lines * lineH + botPad
                    built[i]    = { lines = lines, h = bh }
                end
            end
            self._msgDataCache = built
        end
        local msgData = self._msgDataCache

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
            local textX  = bx + 0.009

            -- Date stamp (shared by both bubble types)
            local dateStr = self:formatGameDate(msg.gameDay or 0)
            if (msg.gameTime or 0) > 0 then
                dateStr = dateStr .. "  " .. self:formatGameTime(msg.gameTime)
            end

            if md.isCard then
                -- ── Contact card bubble ───────────────────────────────────────
                local br = isSent and 0.08 or 0.10
                local bg = isSent and 0.28 or 0.18
                local bb = isSent and 0.45 or 0.42
                self:drawRect(bx, curY, bubbleW, bh, br, bg, bb, 1.0)
                -- Accent line on left edge
                self:drawRect(bx, curY, 0.003, bh, 0.40, 0.65, 1.0, 1.0)

                -- Date
                local dateY = curY + botPad + 2 * lineH + 0.030 + dateGap
                setTextAlignment(RenderText.ALIGN_LEFT)
                setTextBold(false)
                setTextColor(0.55, 0.65, 0.75, 0.7)
                renderText(textX, dateY, dateSize, dateStr)

                -- Card content: name, phone
                local nameY  = curY + botPad + 1 * lineH + 0.030
                local phoneY = curY + botPad + 0 * lineH + 0.030

                setTextAlignment(RenderText.ALIGN_LEFT)
                setTextBold(true)
                setTextColor(1, 1, 1, 1)
                renderText(textX, nameY, textSize, msg.cardName or "")
                setTextBold(false)
                setTextColor(0.75, 0.88, 1.0, 0.9)
                renderText(textX, phoneY, textSize, msg.cardPhone or "")

                -- Save / Saved button (only on received cards)
                if not isSent then
                    local alreadySaved = RoleplayPhone:getContactByPhone(msg.cardPhone or "") ~= nil
                    local saveBtnW = 0.040 * self.arScale
                    local saveBtnH = 0.022
                    local saveBtnX = bx + bubbleW - saveBtnW - 0.006
                    local saveBtnY = curY + botPad
                    if not alreadySaved then
                        self:drawButton("btn_save_contact_card", saveBtnX, saveBtnY, saveBtnW, saveBtnH,
                            g_i18n:getText("msg_card_save"), 0.10, 0.42, 0.22, 0.009,
                            { cardName=msg.cardName, cardPhone=msg.cardPhone, cardFarm=msg.cardFarm })
                    end
                end
            else
                -- ── Normal text bubble ────────────────────────────────────────
                local br = isSent and 0.10 or 0.14
                local bg = isSent and 0.40 or 0.18
                local bb = isSent and 0.20 or 0.42
                self:drawRect(bx, curY, bubbleW, bh, br, bg, bb, 1.0)

                local dateY = curY + botPad + #md.lines * lineH + dateGap
                setTextAlignment(RenderText.ALIGN_LEFT)
                setTextBold(false)
                setTextColor(0.55, 0.65, 0.75, 0.7)
                renderText(textX, dateY, dateSize, dateStr)

                setTextColor(1, 1, 1, 0.95)
                for li, line in ipairs(md.lines) do
                    local lineY = curY + botPad + (#md.lines - li) * lineH
                    renderText(textX, lineY, textSize, line)
                end
            end

            curY = curY + bh + bubbleGap
        end
    end
end
