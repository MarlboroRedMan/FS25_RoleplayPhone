function RoleplayPhone:drawWeatherApp()
    local s  = self.BIG
    local px = s.x;  local py = s.y
    local pw = s.w;  local ph = s.h
    local cx = px + pw / 2

    -- Header
    local headerH = 0.05
    local headerY = py + ph - 0.055 - headerH
    self:drawRect(px, headerY, pw, headerH, 0.08, 0.14, 0.22, 1.0)
    self:drawButton("btn_back", px+0.006, headerY+0.010, 0.055 * self.arScale, 0.030,
                    g_i18n:getText("ui_btn_back"), 0.14, 0.18, 0.28, 0.011)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true); setTextColor(1,1,1,1)
    renderText(cx, headerY + 0.016, 0.016, g_i18n:getText("screen_title_weather"))

    -- ── Gather current conditions ─────────────────────────────────────────────
    local env     = g_currentMission and g_currentMission.environment
    local weather = env and env.weather
    local tempC      = nil
    local rainScale  = 0
    local cloudCover = 0
    local windSpeed  = 0
    local windDir    = nil
    local humidity   = nil
    local groundWet  = nil
    local isSnowing  = false
    local isHailing  = false

    if weather then
        if weather.getCurrentTemperature then tempC = weather:getCurrentTemperature()
        elseif weather.getTemperature    then tempC = weather:getTemperature()
        elseif weather.temperatureUpdater and env then
            tempC = weather.temperatureUpdater:getTemperatureAtTime(env.dayTime) end

        if weather.getRainFallScale then rainScale = weather:getRainFallScale()
        elseif weather.getRainScale  then rainScale = weather:getRainScale() end

        isSnowing = (weather.getIsSnowing and weather:getIsSnowing()) or false
        isHailing = (weather.getIsHailing and weather:getIsHailing()) or false

        if weather.getCloudCoverage then cloudCover = weather:getCloudCoverage()
        elseif env.cloudUpdater and env.cloudUpdater.getCloudCoverage then
            cloudCover = env.cloudUpdater:getCloudCoverage() end
        if cloudCover > 1.0 then cloudCover = cloudCover / 100 end

        local wu = weather.windUpdater
        if wu and wu.currentVelocity then
            windSpeed = wu.currentVelocity * 3.6
            if wu.currentDirX and wu.currentDirZ then
                local deg = math.deg(math.atan2(wu.currentDirX, wu.currentDirZ)) % 360
                local dirs = {"N","NE","E","SE","S","SW","W","NW"}
                windDir = dirs[math.floor(((deg+22.5)%360)/45)+1] end end

        -- Ground wetness and humidity — optional, only shown if exposed by map/mod
        if type(weather.groundWetness)=="number" then groundWet = weather.groundWetness end
        if weather.getHumidity then humidity = weather:getHumidity()
        elseif type(weather.humidity)=="number" then humidity = weather.humidity end
        if humidity and humidity > 1.0 then humidity = humidity / 100 end
    end

    -- Condition string, color, and ASCII symbol
    local condStr, condColor, condSymbol
    if isHailing then
        condStr=g_i18n:getText("weather_cond_hail");         condColor={0.60,0.80,0.95}; condSymbol="[o o]"
    elseif isSnowing then
        condStr=g_i18n:getText("weather_cond_snow");         condColor={0.85,0.92,1.00}; condSymbol="[* *]"
    elseif rainScale>0.70 then
        condStr=g_i18n:getText("weather_cond_thunderstorm"); condColor={0.40,0.45,0.75}; condSymbol="[/!/]"
    elseif rainScale>0.05 then
        condStr = rainScale>0.50 and g_i18n:getText("weather_cond_heavy_rain") or g_i18n:getText("weather_cond_rain")
                                condColor={0.40,0.60,0.90}; condSymbol="[~~~]"
    elseif cloudCover>0.70 then
        condStr=g_i18n:getText("weather_cond_overcast");     condColor={0.70,0.75,0.85}; condSymbol="[###]"
    elseif cloudCover>0.30 then
        condStr=g_i18n:getText("weather_cond_partly_cloudy");condColor={0.85,0.88,0.95}; condSymbol="[*~#]"
    else
        condStr=g_i18n:getText("weather_cond_clear");        condColor={1.00,0.88,0.30}; condSymbol="[***]"
    end

    local function fmtTemp(c)
        if c==nil then return "--" end
        if self.settings.tempUnit=="F" then
            return string.format("%d°F", math.floor(c*9/5+32+0.5))
        else return string.format("%d°C", math.floor(c+0.5)) end
    end

    -- ── Current conditions card ───────────────────────────────────────────────
    local cardX = px+0.010; local cardW = pw-0.020
    local cardH = 0.155;    local cardY = headerY-0.012-cardH
    self:drawRect(cardX,cardY,cardW,cardH,0.08,0.13,0.20,1.0)
    self:drawRect(cardX,cardY+cardH-0.004,cardW,0.004,condColor[1],condColor[2],condColor[3],0.90)

    -- ASCII condition symbol (left side, big)
    setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(false)
    setTextColor(condColor[1],condColor[2],condColor[3],0.70)
    renderText(cardX+0.008, cardY+cardH-0.030, 0.013, condSymbol)

    -- Condition label
    setTextColor(condColor[1],condColor[2],condColor[3],0.95)
    renderText(cardX+0.008, cardY+cardH-0.052, 0.010, condStr)

    -- Big temperature
    setTextBold(true); setTextColor(1,1,1,1)
    renderText(cardX+0.008, cardY+cardH-0.100, 0.034, fmtTemp(tempC))
    setTextBold(false)

    -- Right side details
    local detX  = cardX+cardW*0.52
    local detY  = cardY+cardH-0.028
    local detStep = 0.022
    setTextAlignment(RenderText.ALIGN_LEFT); setTextColor(0.65,0.75,0.90,0.90)

    local wStr = windSpeed>0.5
        and (string.format(g_i18n:getText("weather_wind_speed_fmt"),math.floor(windSpeed))..(windDir and "  "..windDir or ""))
        or g_i18n:getText("weather_wind_calm")
    renderText(detX, detY, 0.010, wStr)
    detY = detY - detStep

    renderText(detX, detY, 0.010, string.format(g_i18n:getText("weather_cloud_fmt"),math.floor(cloudCover*100)))
    if humidity then
        detY = detY - detStep
        renderText(detX, detY, 0.010, string.format(g_i18n:getText("weather_humidity_fmt"),math.floor(humidity*100)))
    end
    if groundWet and groundWet > 0.01 then
        detY = detY - detStep
        local wetStr = groundWet>0.7 and g_i18n:getText("weather_ground_wet")
            or groundWet>0.3 and g_i18n:getText("weather_ground_damp")
            or g_i18n:getText("weather_ground_moist")
        setTextColor(0.55,0.75,0.95,0.90)
        renderText(detX, detY, 0.010, string.format(g_i18n:getText("weather_ground_fmt"), wetStr))
    end

    -- ── Forecast ─────────────────────────────────────────────────────────────
    local fcastY = cardY - 0.026
    setTextAlignment(RenderText.ALIGN_LEFT); setTextBold(true)
    setTextColor(0.55,0.70,0.90,0.85)
    renderText(cardX+0.008, fcastY, 0.010, g_i18n:getText("weather_section_forecast")); setTextBold(false)

    -- Condition maps
    local COND_MAP = {
        [0]="Clear",[1]="Cloudy",[2]="Rain",[3]="Storm",[4]="Fog",[5]="Snow",
        SUN="Clear", CLOUDY="Cloudy", RAIN="Rain", RAIN_LIGHT="Rain", RAIN_HEAVY="Rain",
        HAIL="Hail", SNOW="Snow", SNOW_DUST="Snow", SNOW_WINDY="Snow",
        STORM="Storm", THUNDER="Storm", TWISTER="Twister",
        DUST="Dust", DUST_WINDY="Dust", FOG="Fog",
    }
    local COND_COLOR = {
        Clear={1.00,0.88,0.30}, Cloudy={0.72,0.76,0.85}, Rain={0.45,0.65,0.90},
        Storm={0.50,0.55,0.85}, Snow={0.85,0.92,1.00},   Hail={0.60,0.80,0.95},
        Fog={0.75,0.80,0.88},   Dust={0.80,0.70,0.45},   Twister={0.70,0.40,0.80},
    }
    -- Maps COND_MAP internal keys to l10n keys for forecast label rendering
    local COND_L10N = {
        Clear="weather_cond_clear",   Cloudy="weather_cond_cloudy", Rain="weather_cond_rain",
        Storm="weather_cond_storm",   Snow="weather_cond_snow",     Hail="weather_cond_hail",
        Fog="weather_cond_fog",       Dust="weather_cond_dust",     Twister="weather_cond_twister",
    }
    local function resolveCondition(entry)
        local raw = entry.weatherType or entry.conditionType or entry.condition
                    or entry.type or entry.name or entry.typeName
        if raw == nil then return "--", {0.40,0.45,0.55} end
        local key = type(raw)=="string" and COND_MAP[raw:upper()] or COND_MAP[raw]
        local label = key or (type(raw)=="string" and raw or "--")
        return label, COND_COLOR[label] or {0.70,0.75,0.85}
    end

    -- Day label helper
    local currentDay = env and env.currentDay or 0
    local dpp = (g_currentMission and g_currentMission.missionInfo
                 and g_currentMission.missionInfo.plannedDaysPerPeriod) or 1
    local MONTHS = {
        g_i18n:getText("month_mar"), g_i18n:getText("month_apr"),
        g_i18n:getText("month_may"), g_i18n:getText("month_jun"),
        g_i18n:getText("month_jul"), g_i18n:getText("month_aug"),
        g_i18n:getText("month_sep"), g_i18n:getText("month_oct"),
        g_i18n:getText("month_nov"), g_i18n:getText("month_dec"),
        g_i18n:getText("month_jan"), g_i18n:getText("month_feb"),
    }
    local currentMonthIdx = math.floor((currentDay - 1) / dpp) % 12
    local function getDayLabel(relDay)
        if dpp == 1 then
            return MONTHS[(currentMonthIdx + relDay) % 12 + 1]
        else
            return string.format(g_i18n:getText("ui_day_fmt"), currentDay + relDay)
        end
    end

    -- Build forecast rows (skip Today — current conditions card covers it)
    local xmlForecast = self:getForecastFromXML()
    local forecastRows = {}
    local fi = weather and weather.forecastItems
    if fi and #fi > 0 then
        local currentDayTime = env and env.dayTime or 0
        local relDay = 0
        local lastSdt = -1
        local seenDay = {}

        for i = 1, #fi do
            local item = fi[i]
            if item then
                local sdt = item.startDayTime
                local dur = item.duration or 0
                if sdt then
                    if lastSdt >= 0 and sdt < lastSdt then relDay = relDay + 1 end
                    lastSdt = sdt
                    if not (relDay == 0 and (sdt + dur) < currentDayTime) then
                        if not seenDay[relDay] and #forecastRows < 5 then
                            seenDay[relDay] = true
                            -- Skip Today — redundant with current conditions card above
                            if relDay > 0 then
                                local xmlEntry = xmlForecast[relDay]
                                local label, col
                                local minTemp, maxTemp = nil, nil
                                if xmlEntry then
                                    local tn = xmlEntry.typeName
                                    label   = COND_MAP[tn] or tn
                                    col     = COND_COLOR[COND_MAP[tn] or tn] or {0.70,0.75,0.85}
                                    minTemp = xmlEntry.minTemp
                                    maxTemp = xmlEntry.maxTemp
                                else
                                    label, col = resolveCondition(item)
                                end
                                table.insert(forecastRows, {
                                    relDay=relDay, label=label, col=col,
                                    minTemp=minTemp, maxTemp=maxTemp })
                            end
                        end
                    end
                end
            end
        end
    end

    if #forecastRows > 0 then
        local rowH=0.042; local rowGap=0.004
        for i, entry in ipairs(forecastRows) do
            local ry = fcastY-0.034-(i-1)*(rowH+rowGap)
            if ry < py+0.010 then break end
            local shade=(i%2==0) and 0.090 or 0.075
            self:drawRect(cardX,ry,cardW,rowH,shade,shade+0.015,shade+0.035,1.0)
            setTextAlignment(RenderText.ALIGN_LEFT); setTextColor(0.70,0.78,0.92,0.90)
            renderText(cardX+0.012, ry+rowH*0.30, 0.010, getDayLabel(entry.relDay))
            setTextColor(entry.col[1],entry.col[2],entry.col[3],0.95)
            local l10nKey = COND_L10N[entry.label]
            renderText(cardX+cardW*0.38, ry+rowH*0.30, 0.010, l10nKey and g_i18n:getText(l10nKey) or entry.label)
            setTextAlignment(RenderText.ALIGN_RIGHT); setTextColor(1,1,1,0.90)
            local tempStr
            if entry.maxTemp and entry.minTemp then
                tempStr = fmtTemp(entry.maxTemp) .. " / " .. fmtTemp(entry.minTemp)
            elseif entry.maxTemp then
                tempStr = fmtTemp(entry.maxTemp)
            else
                tempStr = "--"
            end
            renderText(cardX+cardW-0.006, ry+rowH*0.30, 0.010, tempStr)
        end
    else
        setTextAlignment(RenderText.ALIGN_CENTER); setTextColor(0.40,0.48,0.60,0.80)
        renderText(cx, fcastY-0.040, 0.011, g_i18n:getText("weather_no_forecast"))
    end
end
