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
        g_i18n:getText("ui_btn_back"), 0.16, 0.10, 0.24, 0.011)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true); setTextColor(1, 1, 1, 1)
    renderText(cx, headerY + headerH * 0.30, 0.016, g_i18n:getText("screen_title_settings"))

    -- ── Tabs ──────────────────────────────────────────────────────────────────
    local tabY      = headerY - 0.038
    local tabH      = 0.034
    local isHost    = (g_server ~= nil)
    local tabCount  = isHost and 4 or 3
    local tabW      = pw / tabCount
    local genActive  = self.settingsTab == "general"
    local ringActive = self.settingsTab == "ringtones"
    local wallActive = self.settingsTab == "wallpaper"
    local srvActive  = self.settingsTab == "server"

    local function tabBg(active)
        return active and 0.20 or 0.10, active and 0.13 or 0.08, active and 0.32 or 0.16
    end
    local r1,g1,b1 = tabBg(genActive)
    local r2,g2,b2 = tabBg(ringActive)
    local r3,g3,b3 = tabBg(wallActive)

    self:drawRect(px,         tabY, tabW, tabH, r1, g1, b1, 1.0)
    self:drawRect(px+tabW,    tabY, tabW, tabH, r2, g2, b2, 1.0)
    self:drawRect(px+tabW*2,  tabY, tabW, tabH, r3, g3, b3, 1.0)
    if isHost then
        local r4,g4,b4 = tabBg(srvActive)
        self:drawRect(px+tabW*3, tabY, tabW, tabH, r4, g4, b4, 1.0)
    end

    -- Active tab indicator
    local activeTabIdx = genActive and 0 or ringActive and 1 or wallActive and 2 or 3
    self:drawRect(px + tabW * activeTabIdx, tabY, tabW, 0.003, 0.20, 0.85, 0.35, 1.0)

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(genActive);  setTextColor(1,1,1, genActive  and 1.0 or 0.5)
    renderText(px + tabW*0.5,  tabY + tabH*0.30, 0.010, g_i18n:getText("settings_tab_general"))
    setTextBold(ringActive); setTextColor(1,1,1, ringActive and 1.0 or 0.5)
    renderText(px + tabW*1.5,  tabY + tabH*0.30, 0.010, g_i18n:getText("settings_tab_ringtones"))
    setTextBold(wallActive); setTextColor(1,1,1, wallActive and 1.0 or 0.5)
    renderText(px + tabW*2.5,  tabY + tabH*0.30, 0.010, g_i18n:getText("settings_tab_wallpaper"))
    if isHost then
        setTextBold(srvActive);  setTextColor(1,1,1, srvActive and 1.0 or 0.5)
        renderText(px + tabW*3.5,  tabY + tabH*0.30, 0.010, "Server")
    end

    self:addHitbox("settings_tab_general",   px,        tabY, tabW, tabH, {})
    self:addHitbox("settings_tab_ringtones", px+tabW,   tabY, tabW, tabH, {})
    self:addHitbox("settings_tab_wallpaper", px+tabW*2, tabY, tabW, tabH, {})
    if isHost then
        self:addHitbox("settings_tab_server", px+tabW*3, tabY, tabW, tabH, {})
    end

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
        renderText(indent, cy, 0.009, g_i18n:getText("settings_clock_format"))
        cy = cy - 0.028

        local is12 = self.settings.timeFormat == "12"
        self:drawButton("setting_timeformat_12",
            indent, cy - rowH, optW, rowH,
            g_i18n:getText("settings_12hr"), is12 and 0.28 or 0.12, is12 and 0.18 or 0.10, is12 and 0.45 or 0.22, 0.012)
        if is12 then self:drawRect(indent, cy - rowH, 0.004, rowH, 0.20, 0.85, 0.35, 1.0) end
        self:drawButton("setting_timeformat_24",
            indent + optW + optGap, cy - rowH, optW, rowH,
            g_i18n:getText("settings_24hr"), not is12 and 0.28 or 0.12, not is12 and 0.18 or 0.10,
            not is12 and 0.45 or 0.22, 0.012)
        if not is12 then self:drawRect(indent + optW + optGap, cy - rowH, 0.004, rowH, 0.20, 0.85, 0.35, 1.0) end
        cy = cy - rowH - 0.022

        -- Temperature
        setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false)
        setTextColor(0.55, 0.45, 0.75, 0.85)
        renderText(indent, cy, 0.009, g_i18n:getText("settings_temperature"))
        cy = cy - 0.028

        local isF = self.settings.tempUnit == "F"
        self:drawButton("setting_temp_F",
            indent, cy - rowH, optW, rowH,
            g_i18n:getText("settings_temp_f"), isF and 0.28 or 0.12, isF and 0.18 or 0.10, isF and 0.45 or 0.22, 0.013)
        if isF then self:drawRect(indent, cy - rowH, 0.004, rowH, 0.20, 0.85, 0.35, 1.0) end
        self:drawButton("setting_temp_C",
            indent + optW + optGap, cy - rowH, optW, rowH,
            g_i18n:getText("settings_temp_c"), not isF and 0.28 or 0.12, not isF and 0.18 or 0.10,
            not isF and 0.45 or 0.22, 0.013)
        if not isF then self:drawRect(indent + optW + optGap, cy - rowH, 0.004, rowH, 0.20, 0.85, 0.35, 1.0) end
        cy = cy - rowH - 0.022

        -- Battery Widget
        setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false)
        setTextColor(0.55, 0.45, 0.75, 0.85)
        renderText(indent, cy, 0.009, g_i18n:getText("settings_battery_widget"))
        cy = cy - 0.028

        local batOn  = self.settings.batteryVisible
        self:drawButton("setting_battery_toggle",
            indent, cy - rowH, optW, rowH,
            batOn and g_i18n:getText("settings_on") or g_i18n:getText("settings_off"),
            batOn and 0.08 or 0.22, batOn and 0.42 or 0.14, batOn and 0.18 or 0.14, 0.013)
        if batOn then self:drawRect(indent, cy - rowH, 0.004, rowH, 0.20, 0.85, 0.35, 1.0) end
        cy = cy - rowH - 0.022

        -- RP Voice Mode (host only) — stored in server_config.xml, takes effect on restart
        if g_server ~= nil then
            setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false)
            setTextColor(0.55, 0.45, 0.75, 0.85)
            renderText(indent, cy, 0.009, g_i18n:getText("settings_rp_voice_mode"))
            cy = cy - 0.028

            local vmConfig = self.rpVoiceModeConfig or false
            self:drawButton("setting_voicemode_toggle",
                indent, cy - rowH, optW, rowH,
                vmConfig and g_i18n:getText("settings_on") or g_i18n:getText("settings_off"),
                vmConfig and 0.08 or 0.22, vmConfig and 0.42 or 0.14, vmConfig and 0.18 or 0.14, 0.013)
            if vmConfig then self:drawRect(indent, cy - rowH, 0.004, rowH, 0.20, 0.85, 0.35, 1.0) end

            local isPending = (vmConfig ~= self.settings.rpVoiceMode)
            setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false)
            setTextColor(
                isPending and 0.95 or 0.40,
                isPending and 0.75 or 0.40,
                isPending and 0.15 or 0.50,
                0.90)
            renderText(indent + optW + optGap, cy - rowH * 0.65, 0.008,
                isPending and g_i18n:getText("settings_rp_voice_restart")
                          or  g_i18n:getText("settings_rp_voice_hint"))
        end


    -- ── RINGTONES TAB ─────────────────────────────────────────────────────────
    elseif self.settingsTab == "ringtones" then
        local cy = tabY - 0.030
        local arrowW = 0.030 * self.arScale
        local arrowH = 0.038
        local nameW  = pw - 0.030 - arrowW*2

        -- Current ringtone name (previewRingtone may differ from applied)
        local previewIdx = self.previewRingtone or self.settings.ringtoneIndex
        local rt = self.RINGTONES[previewIdx] or self.RINGTONES[1]

        setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false)
        setTextColor(0.55, 0.45, 0.75, 0.85)
        renderText(indent, cy, 0.009, g_i18n:getText("settings_ringtone_label"))
        cy = cy - 0.030

        -- Arrow left
        self:drawButton("ringtone_prev",
            indent, cy - arrowH, arrowW, arrowH,
            "<", 0.18, 0.12, 0.30, 0.014)
        -- Ringtone name
        self:drawRect(indent + arrowW + 0.004, cy - arrowH, nameW, arrowH, 0.12, 0.08, 0.20, 1.0)
        setTextAlignment(RenderText.ALIGN_CENTER); setTextBold(true)
        setTextColor(1, 1, 1, 1)
        renderText(indent + arrowW + 0.004 + nameW/2, cy - arrowH*0.65, 0.012, rt.name)
        setTextBold(false)
        -- Arrow right
        self:drawButton("ringtone_next",
            indent + arrowW + 0.004 + nameW + 0.004, cy - arrowH, arrowW, arrowH,
            ">", 0.18, 0.12, 0.30, 0.014)

        cy = cy - arrowH - 0.018

        -- Index indicator
        setTextAlignment(RenderText.ALIGN_CENTER); setTextColor(0.55, 0.50, 0.70, 0.70)
        renderText(cx, cy, 0.009,
            string.format(g_i18n:getText("settings_wallpaper_index_fmt"), previewIdx, #self.RINGTONES))
        cy = cy - 0.030

        -- Preview + Apply buttons
        local btnW = (pw - 0.024 - 0.006) / 2
        self:drawButton("ringtone_preview",
            indent, cy - arrowH, btnW, arrowH,
            g_i18n:getText("settings_ringtone_preview"), 0.18, 0.12, 0.35, 0.012)

        local isApplied = previewIdx == self.settings.ringtoneIndex
        if isApplied then
            setTextAlignment(RenderText.ALIGN_CENTER); setTextBold(false)
            setTextColor(0.20, 0.85, 0.35, 0.90)
            renderText(indent + btnW + 0.006 + btnW / 2, cy - arrowH * 0.35, 0.010,
                g_i18n:getText("settings_applied"))
        else
            self:drawButton("ringtone_apply",
                indent + btnW + 0.006, cy - arrowH, btnW, arrowH,
                g_i18n:getText("settings_apply"), 0.10, 0.38, 0.18, 0.012)
        end

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
            string.format(g_i18n:getText("settings_wallpaper_index_fmt"), previewIdx, #self.WALLPAPERS))

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
            renderText(cx, ctrlY - arrowH * 0.35, 0.010, g_i18n:getText("settings_applied"))
        else
            self:drawButton("wallp_apply",
                applyX, ctrlY - arrowH, applyW, arrowH,
                g_i18n:getText("settings_apply"), 0.10, 0.38, 0.18, 0.012)
        end

    -- ── SERVER TAB (host only) ────────────────────────────────────────────────
    elseif self.settingsTab == "server" and g_server ~= nil then
        local cy = tabY - 0.022
        local cf = self.carrierForm or {}

        -- Carrier Bot on/off toggle
        setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false)
        setTextColor(0.55, 0.45, 0.75, 0.85)
        renderText(indent, cy, 0.009, "Carrier Bot")
        cy = cy - 0.028

        local carrierOn = self.settings.carrierEnabled or false
        self:drawButton("setting_carrier_toggle",
            indent, cy - rowH, optW, rowH,
            carrierOn and g_i18n:getText("settings_on") or g_i18n:getText("settings_off"),
            carrierOn and 0.08 or 0.22, carrierOn and 0.42 or 0.14, carrierOn and 0.18 or 0.14, 0.013)
        if carrierOn then self:drawRect(indent, cy - rowH, 0.004, rowH, 0.20, 0.85, 0.35, 1.0) end
        cy = cy - rowH - 0.022

        -- Carrier Name field
        setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false)
        setTextColor(0.55, 0.45, 0.75, 0.85)
        renderText(indent, cy, 0.009, "Carrier Name")
        cy = cy - 0.028
        local nameActive = cf.activeField == "name"
        local nameVal    = cf.name ~= nil and cf.name or (self.settings.carrierName or "")
        self:drawField("carrier_name_field", indent, cy - rowH, usable, rowH, "", nameVal, nameActive)
        cy = cy - rowH - 0.014

        -- Welcome Message field
        setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false)
        setTextColor(0.55, 0.45, 0.75, 0.85)
        renderText(indent, cy, 0.009, "Welcome Message")
        cy = cy - 0.028
        local welcomeActive = cf.activeField == "welcome"
        local welcomeVal    = cf.welcome ~= nil and cf.welcome or (self.settings.carrierWelcome or "")
        self:drawField("carrier_welcome_field", indent, cy - rowH * 2, usable, rowH * 2, "", welcomeVal, welcomeActive, true)
        cy = cy - rowH * 2 - 0.018

        -- Save button
        self:drawButton("carrier_save",
            indent, cy - rowH, usable, rowH,
            "Save", 0.10, 0.38, 0.18, 0.012)
    end
end

-- ─── Settings save / load ─────────────────────────────────────────────────────
function RoleplayPhone:saveSettings()
    local xmlPath = getUserProfileAppPath()
        .. "modSettings/FS25_RoleplayPhone_settings.xml"
    local xmlFile = createXMLFile("RP_Settings", xmlPath, "phoneSettings")
    if not xmlFile or xmlFile == 0 then return end

    setXMLString(xmlFile, "phoneSettings#timeFormat",    self.settings.timeFormat    or "12")
    setXMLString(xmlFile, "phoneSettings#tempUnit",      self.settings.tempUnit      or "F")
    setXMLInt(xmlFile,    "phoneSettings#wallpaperIndex",self.settings.wallpaperIndex or 1)
    setXMLBool(xmlFile,   "phoneSettings#batteryVisible",self.settings.batteryVisible)
    setXMLInt(xmlFile,    "phoneSettings#ringtoneIndex", self.settings.ringtoneIndex  or 1)

    saveXMLFile(xmlFile)
    delete(xmlFile)
    print("[RoleplayPhone] Settings saved")
end

function RoleplayPhone:loadSettings()
    local newPath = getUserProfileAppPath() .. "modSettings/FS25_RoleplayPhone_settings.xml"
    local oldPath = getUserProfileAppPath() .. "modSettings/FS25_RoleplayInvoices_settings.xml"

    -- Try new path first; fall back to old name for one-time migration
    local xmlPath = fileExists(newPath) and newPath or oldPath
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

    local ri = getXMLInt(xmlFile, "phoneSettings#ringtoneIndex")
    if ri and ri >= 1 and ri <= #self.RINGTONES then
        self.settings.ringtoneIndex = ri
        self.ringSample = self.ringtoneSamples[ri]
    end

    delete(xmlFile)
    print(string.format("[RoleplayPhone] Settings loaded: %s, %s, wallpaper=%d, battery=%s",
        self.settings.timeFormat, self.settings.tempUnit,
        self.settings.wallpaperIndex, tostring(self.settings.batteryVisible)))
end
