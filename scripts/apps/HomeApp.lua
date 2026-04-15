-- scripts/apps/HomeApp.lua
-- Home screen: drawPhoneHome, drawWeatherWidget, drawAppGrid, drawDockIcons.

function RoleplayPhone:drawPhoneHome()
    local px = self.PHONE.x
    local py = self.PHONE.y
    local pw = self.PHONE.w
    local ph = self.PHONE.h
    local cx = px + pw / 2

    local dockH = 0.115
    local dockY = py + 0.006

    if not self.phoneFrame then
        self:drawRect(px-0.009, py-0.009, pw+0.018, ph+0.018, 0.01, 0.01, 0.01, 1.0)
    end

    -- Screen background
    local wp = self.WALLPAPERS[self.settings.wallpaperIndex] or self.WALLPAPERS[1]
    local wpOverlay = wp.texture and self[wp.texture] or nil
    local dimAlpha = (self.homePage == 1) and 0.38 or 0.55
    if wpOverlay and wpOverlay ~= 0 then
        setOverlayColor(wpOverlay, 1, 1, 1, 1)
        renderOverlay(wpOverlay, px, py, pw, ph)
        self:drawRect(px, py, pw, ph, 0.0, 0.0, 0.0, dimAlpha)
    else
        self:drawRect(px, py, pw, ph, wp.r, wp.g, wp.b, 1.0)
    end

    if not self.phoneFrame then
        local nw = pw * 0.20
        self:drawRect(cx - nw/2, py + ph - 0.010, nw, 0.010, 0.01, 0.01, 0.01, 1.0)
    end

    self:drawStatusBar(px, py, pw, ph)

    if self.homePage == 1 then
        self:drawWeatherWidget(px, py, pw, ph)
    else
        self:drawAppGrid(px, py, pw, ph, dockY, dockH)
    end

    -- Dock
    self:drawRect(px, dockY, pw, dockH, 0.03, 0.03, 0.04, 0.88)
    self:drawRect(px, dockY + dockH, pw, 0.002, 0.12, 0.12, 0.15, 0.5)
    self:drawDockIcons(px, py, pw, ph, dockY, dockH)

    -- Page dots
    local dotSize   = 0.005
    local dotGap    = 0.016
    local dotY      = dockY + dockH + 0.008
    local totalDots = self.homePageCount
    local dotStartX = cx - ((totalDots - 1) * dotGap) / 2
    for i = 1, totalDots do
        local alpha = (i == self.homePage) and 0.90 or 0.25
        self:drawRect(dotStartX + (i-1)*dotGap - dotSize/2, dotY, dotSize, dotSize, 1, 1, 1, alpha)
        self:addHitbox("page_dot_" .. i, dotStartX + (i-1)*dotGap - 0.012, dotY - 0.006, 0.024, 0.018, { page=i })
    end

    -- Swipe arrows
    if self.homePageCount > 1 then
        if self.homePage > 1 then
            setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false); setTextColor(1,1,1,0.75)
            renderText(px + 0.004, dotY - 0.001, 0.014, "<")
            self:addHitbox("page_prev", px, dotY - 0.015, 0.025, 0.030, {})
        end
        if self.homePage < self.homePageCount then
            setTextAlignment(RenderText.ALIGN_RIGHT); setTextColor(1,1,1,0.75)
            renderText(px + pw - 0.004, dotY - 0.001, 0.014, ">")
            self:addHitbox("page_next", px + pw - 0.025, dotY - 0.015, 0.025, 0.030, {})
        end
    end

    -- Hint text
    setTextBold(false)
    if self.homePageCount > 1 then
        setTextAlignment(RenderText.ALIGN_LEFT); setTextColor(0.85,0.87,0.90,0.75)
        renderText(px + 0.006, dockY + dockH - 0.008, 0.008, g_i18n:getText("phone_hint_close"))
        setTextAlignment(RenderText.ALIGN_RIGHT); setTextColor(0.65,0.70,0.80,0.70)
        renderText(px + pw - 0.006, dockY + dockH - 0.008, 0.008, g_i18n:getText("phone_hint_switch_pages"))
    else
        setTextAlignment(RenderText.ALIGN_CENTER); setTextColor(0.85,0.87,0.90,0.75)
        renderText(cx, dockY + dockH - 0.008, 0.008, g_i18n:getText("phone_hint_close"))
    end
end

function RoleplayPhone:drawWeatherWidget(px, py, pw, ph)
    local cx = px + pw / 2

    local tempStr   = "--°"
    local condStr   = "Clear"
    local condColor = { 1.0, 0.85, 0.30 }
    local condKey   = "Clear"

    if g_currentMission and g_currentMission.environment then
        local weather = g_currentMission.environment.weather
        if weather then
            local isRaining = weather.getIsRaining and weather:getIsRaining() or false
            local isSnowing = weather.getIsSnowing and weather:getIsSnowing() or false
            local isHailing = weather.getIsHailing and weather:getIsHailing() or false

            if isHailing then
                condStr = "Hail";      condColor = { 0.60, 0.80, 0.95 }; condKey = "Hail"
            elseif isSnowing then
                condStr = "Snow";      condColor = { 0.85, 0.92, 1.00 }; condKey = "Snow"
            elseif isRaining then
                local intensity = weather.getRainFallScale and weather:getRainFallScale() or 1
                if intensity > 0.6 then
                    condStr = "Heavy Rain"; condColor = { 0.45, 0.65, 0.90 }; condKey = "HeavyRain"
                else
                    condStr = "Rain";       condColor = { 0.45, 0.65, 0.90 }; condKey = "Rain"
                end
            else
                condStr = "Clear"; condColor = { 1.0, 0.85, 0.30 }; condKey = "Clear"
            end

            if weather.temperatureUpdater then
                local env  = g_currentMission.environment
                local temp = weather.temperatureUpdater:getTemperatureAtTime(env.dayTime)
                if temp then
                    if self.settings.tempUnit == "F" then
                        tempStr = string.format("%d°F", math.floor(temp * 9/5 + 32 + 0.5))
                    else
                        tempStr = string.format("%d°C", math.floor(temp + 0.5))
                    end
                end
            end
        end
    end

    local cityStr = ""
    if g_currentMission and g_currentMission.missionInfo then
        cityStr = g_currentMission.missionInfo.mapTitle or ""
    end

    local iconSz  = 0.065 * self.arScale
    local iconH   = iconSz * self.actualAR
    local iconX   = cx - iconSz / 2
    local iconTopY = py + ph * 0.62

    -- Dark backdrop
    local bgW = pw * 0.58
    local bgH = iconH + 0.110
    local bgX = cx - bgW / 2
    local bgY = iconTopY - 0.100
    self:drawRect(bgX, bgY, bgW, bgH, 0.0, 0.0, 0.0, 0.38)

    -- Weather icon
    local condIcon = self.weatherIcons and self.weatherIcons[condKey]
    if condIcon and condIcon ~= 0 then
        setOverlayColor(condIcon, 1, 1, 1, 0.95)
        renderOverlay(condIcon, iconX, iconTopY, iconSz, iconH)
    end

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true); setTextColor(1,1,1,1)
    renderText(cx, iconTopY - 0.038, 0.036, tempStr)
    setTextBold(false); setTextColor(condColor[1], condColor[2], condColor[3], 1.0)
    renderText(cx, iconTopY - 0.072, 0.014, condStr)
    if cityStr ~= "" then
        setTextColor(0.85, 0.90, 1.0, 0.90)
        renderText(cx, iconTopY - 0.090, 0.011, "@ " .. cityStr)
    end
    setTextBold(false)
end

function RoleplayPhone:drawAppGrid(px, py, pw, ph, dockY, dockH)
    local cols    = 3
    local iconSz  = 0.038 * self.arScale
    local iconGap = (pw - cols * iconSz) / (cols + 1)
    local rowH    = iconSz + 0.028
    local gridStartY = py + ph - 0.060 - rowH

    local pageApps = {}
    for _, app in ipairs(self.GRID_APPS) do
        if app.page == self.homePage then table.insert(pageApps, app) end
    end

    for idx, app in ipairs(pageApps) do
        local col = (idx - 1) % cols
        local row = math.floor((idx - 1) / cols)
        local ix  = px + iconGap + col * (iconSz + iconGap)
        local iy  = gridStartY - row * (rowH + 0.008)
        local iconH = iconSz * self.actualAR
        local c = app.color
        self:drawRect(ix, iy, iconSz, iconH, c[1], c[2], c[3], 1.0)
        self:drawRect(ix, iy + iconH - 0.003, iconSz, 0.003, c[1]+0.2, c[2]+0.2, c[3]+0.2, 0.3)
        local overlay = app.icon and self[app.icon] or nil
        if overlay and overlay ~= 0 then
            setOverlayColor(overlay, 1, 1, 1, 0.9)
            renderOverlay(overlay, ix + iconSz*0.15, iy + iconH*0.15, iconSz*0.70, iconH*0.70)
        end
        setTextAlignment(RenderText.ALIGN_CENTER); setTextBold(false); setTextColor(1,1,1,0.90)
        renderText(ix + iconSz/2, iy - 0.014, 0.009, app.label)
        self:addHitbox("grid_app_" .. app.id, ix, iy - 0.016, iconSz, iconH + 0.016, { appId=app.id })
    end
end

function RoleplayPhone:drawDockIcons(px, py, pw, ph, dockY, dockH)
    local cx     = px + pw / 2
    local nApps  = #self.DOCK_APPS
    local margin = 0.010
    local gap    = 0.008
    local iconSz = (pw - margin*2 - gap*(nApps-1)) / nApps
    local iconH  = iconSz * self.actualAR
    local startX = cx - (nApps*iconSz + (nApps-1)*gap) / 2
    local iconY  = dockY + (dockH - iconH) / 2

    for i, app in ipairs(self.DOCK_APPS) do
        local ix = startX + (i-1) * (iconSz + gap)
        local c  = app.color
        self:drawRect(ix, iconY, iconSz, iconH, c[1], c[2], c[3], 1.0)
        self:drawRect(ix, iconY + iconH - 0.003, iconSz, 0.003, c[1]+0.2, c[2]+0.2, c[3]+0.2, 0.3)

        -- Icon overlays
        local overlay = nil
        if     app.id == "invoices" then overlay = self.iconInvoices
        elseif app.id == "contacts" then overlay = self.iconContacts
        elseif app.id == "messages" then overlay = self.iconMessages
        elseif app.id == "calls"    then overlay = self.iconCalls
        elseif app.id == "settings" then overlay = self.iconSettings end
        if overlay and overlay ~= 0 then
            local sm, hm = iconSz*0.10, iconH*0.10
            if app.id == "settings" then
                setOverlayColor(overlay, 1,1,1,0.9)
                renderOverlay(overlay, ix+sm, iconY+hm, iconSz-sm*2, iconH-hm*2)
            elseif app.id == "calls" or app.id == "messages" then
                setOverlayColor(overlay, 1,1,1,0.9)
                renderOverlay(overlay, ix+iconSz*0.09, iconY+iconH*0.09, iconSz*0.82, iconH*0.82)
            else
                setOverlayColor(overlay, 1,1,1,0.9)
                renderOverlay(overlay, ix+iconSz*0.15, iconY+iconH*0.15, iconSz*0.70, iconH*0.70)
            end
        end

        -- Badge
        local badge = self:getAppBadgeCount(app.id)
        if badge > 0 then
            local badgeStr = badge > 99 and "99+" or tostring(badge)
            local bsz = iconSz * 0.32
            local bx  = ix + iconSz - bsz * 0.6
            local by  = iconY + iconH - bsz * 0.4
            self:drawRect(bx, by, bsz, bsz*self.actualAR, 0.90, 0.15, 0.15, 1.0)
            setTextAlignment(RenderText.ALIGN_CENTER); setTextBold(true); setTextColor(1,1,1,1)
            renderText(bx + bsz/2, by + bsz*self.actualAR*0.15, bsz*0.55, badgeStr)
            setTextBold(false)
        end

        -- Label
        setTextAlignment(RenderText.ALIGN_CENTER); setTextBold(false); setTextColor(0.85,0.87,0.90,0.85)
        renderText(ix + iconSz/2, dockY + 0.004, 0.008, app.label)

        self:addHitbox("dock_" .. app.id, ix, dockY, iconSz, dockH, { appId=app.id })
    end
end
