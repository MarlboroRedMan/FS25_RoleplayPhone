-- scripts/PhoneUI.lua
-- Shared drawing helpers: primitives, status bar, big-screen shell, phone frame.

function RoleplayPhone:drawRect(x, y, w, h, r, g, b, a)
    if not self.whiteOverlay or self.whiteOverlay == 0 then return end
    setOverlayColor(self.whiteOverlay, r, g, b, a or 1.0)
    renderOverlay(self.whiteOverlay, x, y, w, h)
end

function RoleplayPhone:hitTest(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function RoleplayPhone:addHitbox(id, x, y, w, h, data)
    table.insert(self.hitboxes, { id=id, x=x, y=y, w=w, h=h, data=data })
end

function RoleplayPhone:formatTime(hrs, mins)
    if self.settings.timeFormat == "24" then
        return string.format("%02d:%02d", hrs, mins)
    else
        local suffix = hrs >= 12 and "PM" or "AM"
        local h12 = hrs % 12; if h12 == 0 then h12 = 12 end
        return string.format("%d:%02d %s", h12, mins, suffix)
    end
end

function RoleplayPhone:getStatusColor(status)
    if status == "PAID"     then return 0.10, 0.55, 0.20 end
    if status == "OVERDUE"  then return 0.70, 0.15, 0.15 end
    if status == "DUE"      then return 0.70, 0.45, 0.05 end
    if status == "REJECTED" then return 0.55, 0.10, 0.10 end
    return 0.30, 0.30, 0.38
end

function RoleplayPhone:drawButton(id, x, y, w, h, label, br, bg, bb, textSize, userData)
    self:drawRect(x, y, w, h, br, bg, bb, 1.0)
    self:drawRect(x, y + h - 0.002, w, 0.002, br+0.15, bg+0.15, bb+0.15, 0.3)
    setTextAlignment(RenderText.ALIGN_CENTER); setTextBold(false); setTextColor(1, 1, 1, 0.95)
    renderText(x + w/2, y + h*0.32, textSize or 0.013, label)
    self:addHitbox(id, x, y, w, h, userData or {})
end

-- Shared word-wrap helper used by drawField, drawMessageThread, drawDetailMultiline.
-- Returns a table of lines. Words wider than maxWidth are hard-split at the pixel boundary.
function RoleplayPhone:wrapText(text, textSize, maxWidth)
    local lines = {}
    local words = {}
    for word in (text or ""):gmatch("%S+") do table.insert(words, word) end
    if #words == 0 then return {""} end
    local cur = ""
    for _, word in ipairs(words) do
        while getTextWidth(textSize, word) > maxWidth do
            local i = 1
            while i < #word and getTextWidth(textSize, word:sub(1, i+1)) <= maxWidth do i = i + 1 end
            if cur ~= "" then table.insert(lines, cur); cur = "" end
            table.insert(lines, word:sub(1, i))
            word = word:sub(i + 1)
            if word == "" then break end  -- guard: empty remainder, outer loop will exit
        end
        if word == "" then
        elseif cur == "" then cur = word
        elseif getTextWidth(textSize, cur .. " " .. word) <= maxWidth then cur = cur .. " " .. word
        else table.insert(lines, cur); cur = word
        end
    end
    if cur ~= "" then table.insert(lines, cur) end
    return lines
end

function RoleplayPhone:drawField(id, x, y, w, h, label, value, active, multiline)
    -- Background
    local br = active and 0.15 or 0.10
    local bg = active and 0.32 or 0.14
    local bb = active and 0.55 or 0.20
    self:drawRect(x, y, w, h, br, bg, bb, 1.0)
    local alpha = active and 0.9 or 0.4
    self:drawRect(x,         y,         w,     0.002, 0.5, 0.6, 0.8, alpha)
    self:drawRect(x,         y+h-0.002, w,     0.002, 0.5, 0.6, 0.8, alpha)
    self:drawRect(x,         y,         0.002, h,     0.5, 0.6, 0.8, alpha)
    self:drawRect(x+w-0.002, y,         0.002, h,     0.5, 0.6, 0.8, alpha)
    -- Label (skip if empty)
    if label and label ~= "" then
        setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false); setTextColor(0.6, 0.7, 0.8, 0.9)
        renderText(x + 0.008, y + h - 0.016, 0.010, label)
    end

    local textPad  = 0.004
    local textSize = 0.012

    if multiline then
        -- ── Multiline field ────────────────────────────────────────────────────
        local lineH        = 0.016
        local labelReserve = (label ~= nil and label ~= "") and 0.024 or 0.006
        local textAreaH    = h - labelReserve
        local maxLines     = math.max(1, math.floor(textAreaH / lineH))
        local val          = value or ""

        if active then
            -- Cursor position (clamped to valid range)
            local pos = math.max(1, math.min(self.textCursor.pos, utf8Strlen(val) + 1))
            -- Wrap text BEFORE cursor to find which visual line the cursor falls on
            local beforeText  = pos > 1 and utf8Substr(val, 0, pos-1) or ""
            local linesBefore = self:wrapText(beforeText, textSize, w - textPad * 2)
            local cursorLineIdx  = #linesBefore          -- which visual line cursor is on (1-based)
            local cursorLineText = linesBefore[cursorLineIdx] or ""  -- portion of that line before cursor
            -- Wrap full text for display
            local lines = self:wrapText(val, textSize, w - textPad * 2)
            -- Scroll: default to bottom, but scroll up if cursor would be off-screen
            local startLine = math.max(1, #lines - maxLines + 1)
            if cursorLineIdx < startLine then startLine = cursorLineIdx end
            -- Draw lines + cursor rect
            local showCursor = self:isCursorBlinkVisible()
            setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false); setTextColor(1, 1, 1, 1)
            for i = startLine, math.min(#lines, startLine + maxLines - 1) do
                local lineY = y + textAreaH - (i - startLine + 1) * lineH + 0.004
                renderText(x + textPad, lineY, textSize, lines[i])
                if i == cursorLineIdx and showCursor then
                    local cX = x + textPad + getTextWidth(textSize, cursorLineText)
                    self:drawRect(cX, lineY - 0.002, 0.0012, lineH - 0.002, 0.85, 0.92, 1.0, 1.0)
                end
            end
        else
            local lines = self:wrapText(val, textSize, w - textPad * 2)
            local startLine = math.max(1, #lines - maxLines + 1)
            setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false); setTextColor(1, 1, 1, 1)
            for i = startLine, math.min(#lines, startLine + maxLines - 1) do
                local lineY = y + textAreaH - (i - startLine + 1) * lineH + 0.004
                renderText(x + textPad, lineY, textSize, lines[i])
            end
        end
    else
        -- ── Single-line field ──────────────────────────────────────────────────
        local maxW = w - textPad * 2
        local tx   = x + textPad
        local ty   = y + 0.008
        local val  = value or ""

        if active then
            local cursorW = 0.0012
            local pos = math.max(1, math.min(self.textCursor.pos, utf8Strlen(val) + 1))
            local before = pos > 1 and utf8Substr(val, 0, pos-1) or ""
            local after  = pos <= utf8Strlen(val) and utf8Substr(val, pos-1) or ""

            -- Trim before from left so cursor stays visible (at most ~70% of maxW)
            local dispBefore = before
            while getTextWidth(textSize, dispBefore) > maxW * 0.70 and utf8Strlen(dispBefore) > 0 do
                dispBefore = utf8Substr(dispBefore, 1)
            end
            local bW = getTextWidth(textSize, dispBefore)

            -- Trim after from right to fit remaining space
            local dispAfter = after
            local afterAvail = maxW - bW - cursorW
            while getTextWidth(textSize, dispAfter) > afterAvail and utf8Strlen(dispAfter) > 0 do
                dispAfter = utf8Substr(dispAfter, 0, utf8Strlen(dispAfter) - 1)
            end

            -- Selection highlight (only draw when whole value fits, to keep it simple)
            local sMin, sMax = self:getSelectionRange()
            if sMin and sMax and getTextWidth(textSize, val) <= maxW then
                local selPre = sMin > 1 and utf8Substr(val, 0, sMin-1) or ""
                local selTxt = utf8Substr(val, sMin-1, sMax-sMin)
                local selX = tx + getTextWidth(textSize, selPre)
                local selW = math.max(0.002, getTextWidth(textSize, selTxt))
                self:drawRect(selX, y + 0.002, selW, h - 0.004, 0.20, 0.40, 0.75, 0.35)
            end

            -- Draw text before cursor
            setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false); setTextColor(1, 1, 1, 1)
            if dispBefore ~= "" then renderText(tx, ty, textSize, dispBefore) end

            -- Draw cursor rect
            if self:isCursorBlinkVisible() then
                self:drawRect(tx + bW, ty - 0.002, cursorW, 0.014, 0.85, 0.92, 1.0, 1.0)
            end

            -- Draw text after cursor
            if dispAfter ~= "" then renderText(tx + bW + cursorW, ty, textSize, dispAfter) end
        else
            -- Inactive: trim right with ellipsis
            local display = val
            if getTextWidth(textSize, display) > maxW then
                while #display > 0 and getTextWidth(textSize, display .. "..") > maxW do
                    display = display:sub(1, #display - 1)
                end
                display = display .. ".."
            end
            setTextColor(1, 1, 1, 1); renderText(tx, ty, textSize, display)
        end
    end

    self:addHitbox(id, x, y, w, h, {})
end

function RoleplayPhone:drawPhoneBackground(r, g, b, a)
    local s = self.BIG; local pad = 0.006
    self:drawRect(s.x - pad*self.arScale, s.y - pad, s.w + pad*self.arScale*2, s.h + pad*2, r, g, b, a or 1.0)
end

function RoleplayPhone:drawBigScreen()
    local s = self.BIG
    if not self.phoneFrame then
        self:drawRect(s.x-0.009, s.y-0.009, s.w+0.014, s.h+0.018, 0.01, 0.01, 0.01, 1.0)
    end
    local pad = 0.006; local bx, by = s.x - pad*self.arScale, s.y - pad
    local bw, bh = s.w + pad*self.arScale*2, s.h + pad*2
    local wp = self.WALLPAPERS[self.settings.wallpaperIndex] or self.WALLPAPERS[1]
    local wpOverlay = wp.texture and self[wp.texture] or nil
    if wpOverlay and wpOverlay ~= 0 then
        setOverlayColor(wpOverlay, 1, 1, 1, 1); renderOverlay(wpOverlay, bx, by, bw, bh)
        self:drawRect(bx, by, bw, bh, 0.0, 0.0, 0.0, 0.45)
    else
        self:drawRect(bx, by, bw, bh, wp.r, wp.g, wp.b, 1.0)
    end
    if not self.phoneFrame then
        local nw = s.w * 0.18
        self:drawRect(s.x + (s.w-nw)/2, s.y + s.h - 0.014, nw, 0.014, 0.01, 0.02, 0.03, 1.0)
    end
    self:drawStatusBar(s.x, s.y, s.w, s.h)
end

function RoleplayPhone:drawStatusBar(px, py, pw, ph)
    local barY = py + ph - 0.038; local textSize = 0.012
    local timeStr = "00:00"
    if g_currentMission and g_currentMission.environment then
        local dt = g_currentMission.environment.dayTime / 3600000
        local hrs = math.floor(dt) % 24; local mins = math.floor((dt - math.floor(dt)) * 60)
        timeStr = self:formatTime(hrs, mins)
    end
    setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false); setTextColor(1, 1, 1, 1)
    renderText(px + 0.014*self.arScale, barY, textSize, timeStr)
    setTextAlignment(RenderText.ALIGN_RIGHT)
    if not self._cached4G then self._cached4G = g_i18n:getText("phone_status_4g") end
    renderText(px + pw - 0.042*self.arScale, barY, textSize, self._cached4G)
    renderText(px + pw - 0.060*self.arScale, barY, textSize, "|||")
    if self.settings.batteryVisible then
        local bat = self.battery; local pct = bat.level / 100
        local bw = 0.013*self.arScale; local bh = 0.007
        local bx = px + pw - 0.037*self.arScale; local by = barY + 0.003
        self:drawRect(bx, by, bw, bh, 0.55, 0.55, 0.55, 1.0)
        local fr, fg, fb
        if pct > 0.30 then fr,fg,fb = 0.15,0.80,0.20
        elseif pct > 0.15 then fr,fg,fb = 0.90,0.75,0.05
        else fr,fg,fb = 0.90,0.10,0.10 end
        local fillW = math.max(0.001, (bw-0.002)*pct)
        self:drawRect(bx+0.001, by+0.001, fillW, bh-0.002, fr, fg, fb, 1.0)
        self:drawRect(bx+bw, by+0.001, 0.002*self.arScale, bh-0.002, 0.55, 0.55, 0.55, 1.0)
        if pct <= 0.15 and math.floor(getTimeSec()*2)%2 == 0 then
            setTextAlignment(RenderText.ALIGN_RIGHT); setTextBold(false); setTextColor(0.95,0.15,0.15,1.0)
            renderText(bx - 0.003*self.arScale, barY, 0.009, g_i18n:getText("phone_battery_low"))
        end
    end
    self:drawRect(px, barY - 0.004, pw, 0.001, 0.2, 0.22, 0.28, 0.6)
end

function RoleplayPhone:drawPhoneFrame()
    if not self.phoneFrame then return end
    local f = self.FRAME_SCREEN; local px,py,pw,ph = self.PHONE.x,self.PHONE.y,self.PHONE.w,self.PHONE.h
    local holeW = (f.R-f.L)/f.imgW; local holeH = (f.T-f.B)/f.imgH
    local leftF = f.L/f.imgW;       local botF  = f.B/f.imgH
    local fw = pw/holeW; local fh = ph/holeH
    local fx = px - fw*leftF; local fy = py - fh*botF
    setOverlayColor(self.phoneFrame, 1, 1, 1, 1); renderOverlay(self.phoneFrame, fx, fy, fw, fh)
end
