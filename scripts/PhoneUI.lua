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

function RoleplayPhone:drawButton(id, x, y, w, h, label, br, bg, bb, textSize)
    self:drawRect(x, y, w, h, br, bg, bb, 1.0)
    self:drawRect(x, y + h - 0.002, w, 0.002, br+0.15, bg+0.15, bb+0.15, 0.3)
    setTextAlignment(RenderText.ALIGN_CENTER); setTextBold(false); setTextColor(1, 1, 1, 0.95)
    renderText(x + w/2, y + h*0.32, textSize or 0.013, label)
    self:addHitbox(id, x, y, w, h, {})
end

function RoleplayPhone:drawField(id, x, y, w, h, label, value, active, multiline)
    local br = active and 0.15 or 0.10
    local bg = active and 0.32 or 0.14
    local bb = active and 0.55 or 0.20
    self:drawRect(x, y, w, h, br, bg, bb, 1.0)
    local alpha = active and 0.9 or 0.4
    self:drawRect(x,         y,         w,     0.002, 0.5, 0.6, 0.8, alpha)
    self:drawRect(x,         y+h-0.002, w,     0.002, 0.5, 0.6, 0.8, alpha)
    self:drawRect(x,         y,         0.002, h,     0.5, 0.6, 0.8, alpha)
    self:drawRect(x+w-0.002, y,         0.002, h,     0.5, 0.6, 0.8, alpha)
    setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false); setTextColor(0.6, 0.7, 0.8, 0.9)
    renderText(x + 0.008, y + h - 0.016, 0.010, label)
    local textPad = 0.004; local textSize = 0.012
    if multiline then
        local lineH = 0.016
        local textAreaH = h - 0.024; local maxLines = math.max(1, math.floor(textAreaH / lineH))
        local maxWidth = w - textPad * 2
        local function splitWord(word)
            local chunks = {}
            while getTextWidth(textSize, word) > maxWidth do
                local i = 1
                while i < #word and getTextWidth(textSize, word:sub(1, i+1)) <= maxWidth do i = i + 1 end
                table.insert(chunks, word:sub(1, i)); word = word:sub(i + 1)
            end
            table.insert(chunks, word); return chunks
        end
        local lines = {}; local words = {}
        for word in value:gmatch("%S+") do table.insert(words, word) end
        local currentLine = ""
        for _, word in ipairs(words) do
            local wordChunks = (getTextWidth(textSize, word) > maxWidth) and splitWord(word) or {word}
            for ci, chunk in ipairs(wordChunks) do
                if ci > 1 then table.insert(lines, currentLine); currentLine = chunk
                elseif currentLine == "" then currentLine = chunk
                else
                    local testLine = currentLine .. " " .. chunk
                    if getTextWidth(textSize, testLine) <= maxWidth then currentLine = testLine
                    else table.insert(lines, currentLine); currentLine = chunk end
                end
            end
        end
        table.insert(lines, currentLine)
        if active then lines[#lines] = lines[#lines] .. "|" end
        local startLine = math.max(1, #lines - maxLines + 1)
        setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false); setTextColor(1, 1, 1, 1)
        for i = startLine, math.min(#lines, startLine + maxLines - 1) do
            local lineY = y + textAreaH - (i - startLine + 1) * lineH + 0.004
            renderText(x + textPad, lineY, textSize, lines[i])
        end
    else
        local charW = textSize * 0.77; local maxChars = math.max(5, math.floor((w - textPad*2) / charW))
        local display
        if active then
            local withCursor = value .. "|"; local offset = self.fieldViewOffset or 0
            if #withCursor - offset > maxChars then offset = #withCursor - maxChars end
            if offset > 0 and #withCursor < offset + maxChars then offset = math.max(0, #withCursor - maxChars) end
            self.fieldViewOffset = offset; display = withCursor:sub(offset+1, offset+maxChars)
        else
            self.fieldViewOffset = 0
            display = (#value > maxChars) and (value:sub(1, maxChars-2) .. "..") or value
        end
        setTextColor(1, 1, 1, 1); renderText(x + textPad, y + 0.008, textSize, display)
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
    renderText(px + pw - 0.042*self.arScale, barY, textSize, g_i18n:getText("phone_status_4g"))
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
