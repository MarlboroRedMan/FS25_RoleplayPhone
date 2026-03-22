function RoleplayPhone:drawSettings()
    local s  = self.BIG
    local px = s.x
    local py = s.y
    local pw = s.w
    local ph = s.h
    local cx = px + pw / 2

    self:drawBigScreen()
    self:drawPhoneBackground(0.0, 0.0, 0.0, 0.55)

    -- ── Header ────────────────────────────────────────────────────────────────
    local contentY = py + ph - 0.055
    local headerH  = 0.05
    local headerY  = contentY - headerH

    self:drawRect(px, headerY, pw, headerH, 0.12, 0.08, 0.20, 1.0)
    local backW = 0.055 * self.arScale
    self:drawButton("btn_back", px + 0.006, headerY + 0.010, backW, 0.030,
        "< Back", 0.16, 0.10, 0.24, 0.011)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true); setTextColor(1, 1, 1, 1)
    renderText(cx, headerY + headerH * 0.30, 0.016, "Settings")

    -- ── Tabs ──────────────────────────────────────────────────────────────────
    local tabY  = headerY - 0.038
    local tabH  = 0.034
    local tabW  = pw / 2
    local genActive  = self.settingsTab == "general"
    local wallActive = self.settingsTab == "wallpaper"

    self:drawRect(px,      tabY, tabW, tabH,
        genActive  and 0.20 or 0.10,
        genActive  and 0.13 or 0.08,
        genActive  and 0.32 or 0.16, 1.0)
    self:drawRect(px+tabW, tabY, tabW, tabH,
        wallActive and 0.20 or 0.10,
        wallActive and 0.13 or 0.08,
        wallActive and 0.32 or 0.16, 1.0)

    -- Active tab indicator
    if genActive then
        self:drawRect(px, tabY, tabW, 0.003, 0.70, 0.50, 1.0, 1.0)
    else
        self:drawRect(px+tabW, tabY, tabW, 0.003, 0.70, 0.50, 1.0, 1.0)
    end

    setTextAlignment(RenderText.ALIGN_CENTER); setTextBold(genActive)
    setTextColor(1, 1, 1, genActive and 1.0 or 0.5)
    renderText(px + tabW/2, tabY + tabH*0.30, 0.011, "General")
    setTextBold(wallActive)
    setTextColor(1, 1, 1, wallActive and 1.0 or 0.5)
    renderText(px + tabW + tabW/2, tabY + tabH*0.30, 0.011, "Wallpaper")

    self:addHitbox("settings_tab_general",   px,      tabY, tabW, tabH, {})
    self:addHitbox("settings_tab_wallpaper", px+tabW, tabY, tabW, tabH, {})

    local rowH   = 0.040
    local indent = px + 0.012
    local usable = pw - 0.024
    local optGap = 0.006
    local optW   = (usable - optGap) / 2

    -- ── GENERAL TAB ───────────────────────────────────────────────────────────
    if self.settingsTab == "general" then
        local cy = tabY - 0.022

        -- Clock Format
        setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false)
        setTextColor(0.55, 0.45, 0.75, 0.85)
        renderText(indent, cy, 0.009, "CLOCK FORMAT")
        cy = cy - 0.028

        local is12 = self.settings.timeFormat == "12"
        self:drawButton("setting_timeformat_12",
            indent, cy - rowH, optW, rowH,
            "12 hr", is12 and 0.28 or 0.12, is12 and 0.18 or 0.10, is12 and 0.45 or 0.22, 0.012)
        if is12 then self:drawRect(indent, cy - rowH, 0.004, rowH, 0.70, 0.50, 1.0, 1.0) end
        self:drawButton("setting_timeformat_24",
            indent + optW + optGap, cy - rowH, optW, rowH,
            "24 hr", not is12 and 0.28 or 0.12, not is12 and 0.18 or 0.10,
            not is12 and 0.45 or 0.22, 0.012)
        if not is12 then self:drawRect(indent + optW + optGap, cy - rowH, 0.004, rowH, 0.70, 0.50, 1.0, 1.0) end
        cy = cy - rowH - 0.022

        -- Temperature
        setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false)
        setTextColor(0.55, 0.45, 0.75, 0.85)
        renderText(indent, cy, 0.009, "TEMPERATURE")
        cy = cy - 0.028

        local isF = self.settings.tempUnit == "F"
        self:drawButton("setting_temp_F",
            indent, cy - rowH, optW, rowH,
            "\xC2\xB0F", isF and 0.28 or 0.12, isF and 0.18 or 0.10, isF and 0.45 or 0.22, 0.013)
        if isF then self:drawRect(indent, cy - rowH, 0.004, rowH, 0.70, 0.50, 1.0, 1.0) end
        self:drawButton("setting_temp_C",
            indent + optW + optGap, cy - rowH, optW, rowH,
            "\xC2\xB0C", not isF and 0.28 or 0.12, not isF and 0.18 or 0.10,
            not isF and 0.45 or 0.22, 0.013)
        if not isF then self:drawRect(indent + optW + optGap, cy - rowH, 0.004, rowH, 0.70, 0.50, 1.0, 1.0) end
        cy = cy - rowH - 0.022

        -- Battery Widget
        setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false)
        setTextColor(0.55, 0.45, 0.75, 0.85)
        renderText(indent, cy, 0.009, "BATTERY WIDGET")
        cy = cy - 0.028

        local batOn  = self.settings.batteryVisible
        self:drawButton("setting_battery_toggle",
            indent, cy - rowH, optW, rowH,
            batOn and "ON" or "OFF",
            batOn and 0.08 or 0.22, batOn and 0.42 or 0.14, batOn and 0.18 or 0.14, 0.013)
        if batOn then self:drawRect(indent, cy - rowH, 0.004, rowH, 0.20, 0.85, 0.35, 1.0) end


    -- ── WALLPAPER TAB ─────────────────────────────────────────────────────────
    elseif self.settingsTab == "wallpaper" then
        -- Preview index — what we're currently showing (may differ from applied)
        local previewIdx = self.previewWallpaper or self.settings.wallpaperIndex
        local wp = self.WALLPAPERS[previewIdx] or self.WALLPAPERS[1]

        -- Full screen preview area
        local previewY  = tabY - 0.006
        local previewH  = ph - (ph - previewY + py) - 0.100  -- leave room for controls
        local previewBY = previewY - previewH

        -- Draw wallpaper preview
        local wpOverlay = wp.texture and self[wp.texture] or nil
        if wpOverlay and wpOverlay ~= 0 then
            setOverlayColor(wpOverlay, 1, 1, 1, 1)
            renderOverlay(wpOverlay, px, previewBY, pw, previewH)
            self:drawRect(px, previewBY, pw, previewH, 0.0, 0.0, 0.0, 0.30)
        else
            self:drawRect(px, previewBY, pw, previewH, wp.r, wp.g, wp.b, 1.0)
        end

        -- Wallpaper name centered over preview
        setTextAlignment(RenderText.ALIGN_CENTER); setTextBold(true)
        setTextColor(1, 1, 1, 0.95)
        renderText(cx, previewBY + previewH * 0.50, 0.016, wp.name)
        setTextBold(false)

        -- Index indicator (e.g. "3 / 7")
        setTextColor(1, 1, 1, 0.55)
        renderText(cx, previewBY + previewH * 0.35, 0.010,
            string.format("%d / %d", previewIdx, #self.WALLPAPERS))

        -- Arrow buttons + Apply
        local ctrlY  = previewBY - 0.010
        local arrowW = 0.040 * self.arScale
        local arrowH = 0.038
        local applyW = pw * 0.44
        local applyH = 0.040
        local applyX = cx - applyW / 2

        self:drawButton("wallp_prev",
            px + 0.010, ctrlY - arrowH, arrowW, arrowH,
            "<", 0.18, 0.12, 0.30, 0.014)
        self:drawButton("wallp_next",
            px + pw - arrowW - 0.010, ctrlY - arrowH, arrowW, arrowH,
            ">", 0.18, 0.12, 0.30, 0.014)

        -- Applied indicator
        local isApplied = previewIdx == self.settings.wallpaperIndex
        if isApplied then
            setTextAlignment(RenderText.ALIGN_CENTER); setTextBold(false)
            setTextColor(0.20, 0.85, 0.35, 0.90)
            renderText(cx, ctrlY - arrowH * 0.35, 0.010, "Applied")
        else
            self:drawButton("wallp_apply",
                applyX, ctrlY - arrowH, applyW, arrowH,
                "Apply", 0.10, 0.38, 0.18, 0.012)
        end
    end
end

-- ─── Settings save / load ─────────────────────────────────────────────────────
function RoleplayPhone:saveSettings()
    local xmlPath = getUserProfileAppPath()
        .. "modSettings/FS25_RoleplayInvoices_settings.xml"
    local xmlFile = createXMLFile("RP_Settings", xmlPath, "phoneSettings")
    if not xmlFile or xmlFile == 0 then return end

    setXMLString(xmlFile, "phoneSettings#timeFormat",    self.settings.timeFormat    or "12")
    setXMLString(xmlFile, "phoneSettings#tempUnit",      self.settings.tempUnit      or "F")
    setXMLInt(xmlFile,    "phoneSettings#wallpaperIndex",self.settings.wallpaperIndex or 1)
    setXMLBool(xmlFile,   "phoneSettings#batteryVisible",self.settings.batteryVisible)

    saveXMLFile(xmlFile)
    delete(xmlFile)
    print("[RoleplayPhone] Settings saved")
end

function RoleplayPhone:loadSettings()
    local xmlPath = getUserProfileAppPath()
        .. "modSettings/FS25_RoleplayInvoices_settings.xml"
    local xmlFile = loadXMLFile("RP_Settings", xmlPath)
    if not xmlFile or xmlFile == 0 then
        print("[RoleplayPhone] No settings file found, using defaults")
        return
    end

    local tf = getXMLString(xmlFile, "phoneSettings#timeFormat")
    if tf == "12" or tf == "24" then self.settings.timeFormat = tf end

    local tu = getXMLString(xmlFile, "phoneSettings#tempUnit")
    if tu == "F" or tu == "C" then self.settings.tempUnit = tu end

    local wi = getXMLInt(xmlFile, "phoneSettings#wallpaperIndex")
    if wi and wi >= 1 and wi <= #self.WALLPAPERS then
        self.settings.wallpaperIndex = wi
    end

    local bv = getXMLBool(xmlFile, "phoneSettings#batteryVisible")
    if bv ~= nil then self.settings.batteryVisible = bv end

    delete(xmlFile)
    print(string.format("[RoleplayPhone] Settings loaded: %s, %s, wallpaper=%d, battery=%s",
        self.settings.timeFormat, self.settings.tempUnit,
        self.settings.wallpaperIndex, tostring(self.settings.batteryVisible)))
end
