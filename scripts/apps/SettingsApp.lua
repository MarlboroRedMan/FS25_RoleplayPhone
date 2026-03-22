function RoleplayPhone:drawSettings()
    local s  = self.BIG
    local px = s.x
    local py = s.y
    local pw = s.w
    local ph = s.h
    local cx = px + pw / 2

    self:drawBigScreen()

    local contentY = py + ph - 0.055
    local headerH  = 0.05
    local headerY  = contentY - headerH

    -- Semi-transparent dark tint over wallpaper so text is readable
    self:drawPhoneBackground(0.0, 0.0, 0.0, 0.55)

    -- Header
    self:drawRect(px, headerY, pw, headerH, 0.12, 0.08, 0.20, 1.0)
    local backW = 0.055 * self.arScale
    self:drawButton("btn_back", px + 0.006, headerY + 0.010, backW, 0.030,
        "< Back", 0.16, 0.10, 0.24, 0.011)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(cx, headerY + headerH * 0.30, 0.016, "Settings")

    local cy     = headerY - 0.018
    local rowH   = 0.040
    local indent = px + 0.012
    local usable = pw - 0.024               -- phone width minus left+right margin
    local optGap = 0.006
    local optW   = (usable - optGap) / 2    -- two buttons fill the row
    local labelW = pw * 0.45

    -- ── Section: Clock Format ─────────────────────────────────────────────────
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(0.55, 0.45, 0.75, 0.85)
    renderText(indent, cy, 0.009, "CLOCK FORMAT")
    cy = cy - 0.028

    local is12 = self.settings.timeFormat == "12"
    self:drawButton("setting_timeformat_12",
        indent, cy - rowH, optW, rowH,
        "12 hr", is12 and 0.28 or 0.12, is12 and 0.18 or 0.10, is12 and 0.45 or 0.22, 0.012)
    if is12 then
        self:drawRect(indent, cy - rowH, 0.004, rowH, 0.70, 0.50, 1.0, 1.0)
    end
    self:drawButton("setting_timeformat_24",
        indent + optW + optGap, cy - rowH, optW, rowH,
        "24 hr", not is12 and 0.28 or 0.12, not is12 and 0.18 or 0.10,
        not is12 and 0.45 or 0.22, 0.012)
    if not is12 then
        self:drawRect(indent + optW + optGap, cy - rowH, 0.004, rowH, 0.70, 0.50, 1.0, 1.0)
    end
    cy = cy - rowH - 0.022

    -- ── Section: Temperature Unit ─────────────────────────────────────────────
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(0.55, 0.45, 0.75, 0.85)
    renderText(indent, cy, 0.009, "TEMPERATURE")
    cy = cy - 0.028

    local isF = self.settings.tempUnit == "F"
    self:drawButton("setting_temp_F",
        indent, cy - rowH, optW, rowH,
        "°F", isF and 0.28 or 0.12, isF and 0.18 or 0.10, isF and 0.45 or 0.22, 0.013)
    if isF then
        self:drawRect(indent, cy - rowH, 0.004, rowH, 0.70, 0.50, 1.0, 1.0)
    end
    self:drawButton("setting_temp_C",
        indent + optW + optGap, cy - rowH, optW, rowH,
        "°C", not isF and 0.28 or 0.12, not isF and 0.18 or 0.10,
        not isF and 0.45 or 0.22, 0.013)
    if not isF then
        self:drawRect(indent + optW + optGap, cy - rowH, 0.004, rowH, 0.70, 0.50, 1.0, 1.0)
    end
    cy = cy - rowH - 0.022

    -- ── Section: Battery Widget ───────────────────────────────────────────────
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(0.55, 0.45, 0.75, 0.85)
    renderText(indent, cy, 0.009, "BATTERY WIDGET")
    cy = cy - 0.028

    local batOn = self.settings.batteryVisible
    local batLbl = batOn and "ON" or "OFF"
    local batR = batOn and 0.08 or 0.22
    local batG = batOn and 0.42 or 0.14
    local batB = batOn and 0.18 or 0.14
    self:drawButton("setting_battery_toggle",
        indent, cy - rowH, optW, rowH,
        batLbl, batR, batG, batB, 0.013)
    if batOn then
        self:drawRect(indent, cy - rowH, 0.004, rowH, 0.20, 0.85, 0.35, 1.0)
    end
    cy = cy - rowH - 0.022

    -- ── Section: Wallpaper ────────────────────────────────────────────────────
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(0.55, 0.45, 0.75, 0.85)
    renderText(indent, cy, 0.009, "WALLPAPER")
    cy = cy - 0.028

    -- Calculate swatch size to fit all 7 within phone width
    local numSwatches = #self.WALLPAPERS
    local swatchGap = 0.006
    local totalGaps = (numSwatches - 1) * swatchGap
    local swatchSz  = (pw - (indent - px) * 2 - totalGaps) / numSwatches
    local swatchX   = indent

    for i, wp in ipairs(self.WALLPAPERS) do
        local isSelected = (self.settings.wallpaperIndex == i)
        -- Swatch square
        self:drawRect(swatchX, cy - swatchSz, swatchSz, swatchSz, wp.r, wp.g, wp.b, 1.0)
        -- Selection ring
        if isSelected then
            self:drawRect(swatchX - 0.003, cy - swatchSz - 0.003,
                swatchSz + 0.006, swatchSz + 0.006,
                0.80, 0.60, 1.0, 0.0)
            self:drawRect(swatchX - 0.003, cy - swatchSz - 0.003,
                swatchSz + 0.006, 0.002, 0.80, 0.60, 1.0, 1.0)
            self:drawRect(swatchX - 0.003, cy - 0.003,
                swatchSz + 0.006, 0.002, 0.80, 0.60, 1.0, 1.0)
            self:drawRect(swatchX - 0.003, cy - swatchSz - 0.003,
                0.002, swatchSz + 0.006, 0.80, 0.60, 1.0, 1.0)
            self:drawRect(swatchX + swatchSz + 0.001, cy - swatchSz - 0.003,
                0.002, swatchSz + 0.006, 0.80, 0.60, 1.0, 1.0)
        end
        -- Name label
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(isSelected)
        setTextColor(isSelected and 0.90 or 0.55,
                     isSelected and 0.80 or 0.50,
                     isSelected and 1.00 or 0.70, 1.0)
        renderText(swatchX + swatchSz / 2, cy - swatchSz - 0.014, 0.009, wp.name)

        self:addHitbox("setting_wallp_" .. i,
            swatchX - 0.004, cy - swatchSz - 0.018, swatchSz + 0.008, swatchSz + 0.022, {})

        swatchX = swatchX + swatchSz + swatchGap
    end
end

-- ─── Settings save / load (modSettings XML, per-player, cosmetic) ─────────────
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

-- ─── RECENT CALLS screen (small phone screen) ────────────────────────────────
