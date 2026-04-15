-- scripts/PhoneWeather.lua
-- Weather forecast XML reader and map temperature loader.

RoleplayPhone._forecastCache    = nil
RoleplayPhone._forecastCacheDay = -1
RoleplayPhone._mapWeatherTemps  = nil

function RoleplayPhone:_loadMapWeatherTemps()
    if self._mapWeatherTemps then return self._mapWeatherTemps end
    self._mapWeatherTemps = {}
    if g_server == nil then return self._mapWeatherTemps end
    local function tryLoad(tag, path)
        local f = loadXMLFile(tag, path); if f and f ~= 0 then return f end; return nil
    end
    local xmlFile = nil; local usedPath = nil
    for _, rel in ipairs({"maps/mapUS/config/environment.xml","maps/mapEU/config/environment.xml","maps/mapAS/config/environment.xml"}) do
        local path = "$data/" .. rel
        local f = tryLoad("RP_MapEnv_" .. rel:gsub("[/.]","_"), path)
        if f then xmlFile = f; usedPath = path; break end
    end
    if not xmlFile then
        local installDir = Utils and Utils.getFilename and Utils.getFilename("$data/")
        if installDir then
            for _, rel in ipairs({"maps/mapUS/config/environment.xml","maps/mapEU/config/environment.xml"}) do
                local path = installDir .. rel
                local f = tryLoad("RP_MapEnvAbs_" .. rel:gsub("[/.]","_"), path)
                if f then xmlFile = f; usedPath = path; break end
            end
        end
    end
    if not xmlFile then
        Logging.info("[RoleplayPhone] Could not load map environment.xml — using built-in temp ranges")
        self._mapWeatherTemps = {
            SPRING = { SUN={{min=10,max=18},{min=10,max=17},{min=11,max=16},{min=10,max=15}}, CLOUDY={{min=9,max=14},{min=8,max=13},{min=8,max=13},{min=7,max=12}}, RAIN={{min=7,max=13},{min=6,max=12},{min=6,max=11},{min=5,max=10}} },
            SUMMER = { SUN={{min=18,max=28},{min=17,max=27},{min=16,max=26},{min=15,max=25}}, CLOUDY={{min=15,max=22},{min=14,max=21},{min=13,max=20},{min=12,max=19}}, RAIN={{min=13,max=20},{min=12,max=19},{min=11,max=18},{min=10,max=17}} },
            AUTUMN = { SUN={{min=8,max=16},{min=7,max=15},{min=6,max=14},{min=5,max=13}}, CLOUDY={{min=5,max=12},{min=4,max=11},{min=4,max=11},{min=3,max=10}}, RAIN={{min=4,max=10},{min=3,max=9},{min=2,max=8},{min=1,max=7}}, SNOW={{min=-2,max=2},{min=-3,max=1},{min=-4,max=0},{min=-5,max=-1}} },
            WINTER = { SUN={{min=-2,max=4},{min=-3,max=3},{min=-4,max=2},{min=-5,max=1}}, CLOUDY={{min=-4,max=1},{min=-5,max=0},{min=-6,max=-1},{min=-7,max=-2}}, SNOW={{min=-8,max=-2},{min=-9,max=-3},{min=-10,max=-4},{min=-11,max=-5}} },
        }
        return self._mapWeatherTemps
    end
    Logging.info("[RoleplayPhone] Loaded map env from: " .. tostring(usedPath))
    local seasonIdx = 0
    while true do
        local sKey = string.format("environment.weather.season(%d)", seasonIdx)
        local season = getXMLString(xmlFile, sKey .. "#name")
        if season == nil then break end
        season = season:upper(); self._mapWeatherTemps[season] = {}
        local objIdx = 0
        while true do
            local oKey = string.format("%s.object(%d)", sKey, objIdx)
            local typeName = getXMLString(xmlFile, oKey .. "#typeName")
            if typeName == nil then break end
            typeName = typeName:upper(); self._mapWeatherTemps[season][typeName] = {}
            local varIdx = 0
            while true do
                local vKey = string.format("%s.variation(%d)", oKey, varIdx)
                local minT = getXMLFloat(xmlFile, vKey .. "#minTemperature")
                if minT == nil then break end
                local maxT = getXMLFloat(xmlFile, vKey .. "#maxTemperature") or minT
                self._mapWeatherTemps[season][typeName][varIdx+1] = { min=minT, max=maxT }
                varIdx = varIdx + 1
            end
            objIdx = objIdx + 1
        end
        seasonIdx = seasonIdx + 1
    end
    delete(xmlFile)
    Logging.info("[RoleplayPhone] Loaded map weather temps for " .. seasonIdx .. " seasons")
    return self._mapWeatherTemps
end

function RoleplayPhone:getForecastFromXML()
    local env = g_currentMission and g_currentMission.environment
    local currentDay = env and env.currentDay or 0
    if self._forecastCacheDay == currentDay and self._forecastCache then return self._forecastCache end
    if g_server == nil then return {} end
    if self._forecastCacheDay ~= currentDay then
        self._forecastCache = nil; self._forecastCacheDay = currentDay
    end
    if self._forecastCache then return self._forecastCache end
    local dir = g_currentMission and g_currentMission.missionInfo and g_currentMission.missionInfo.savegameDirectory
    if not dir then return {} end
    local xmlFile = loadXMLFile("RP_WeatherXML", dir .. "/environment.xml")
    if not xmlFile or xmlFile == 0 then return {} end
    local mapTemps = self:_loadMapWeatherTemps()
    local forecast = {}; local i = 0
    while true do
        local key = string.format("environment.weather.forecast.instance(%d)", i)
        local typeName = getXMLString(xmlFile, key .. "#typeName")
        if typeName == nil then break end
        local startDay = getXMLInt(xmlFile, key .. "#startDay") or 0
        local season   = getXMLString(xmlFile, key .. "#season") or "SPRING"
        local varIdx   = getXMLInt(xmlFile, key .. "#variationIndex") or 1
        local relDay   = startDay - currentDay
        if relDay >= 0 and relDay <= 6 and forecast[relDay] == nil then
            local tn = typeName:upper(); local st = season:upper()
            local minT, maxT = nil, nil
            if mapTemps[st] and mapTemps[st][tn] and mapTemps[st][tn][varIdx] then
                minT = mapTemps[st][tn][varIdx].min; maxT = mapTemps[st][tn][varIdx].max
            end
            forecast[relDay] = { typeName=tn, minTemp=minT, maxTemp=maxT }
        end
        i = i + 1
    end
    delete(xmlFile); self._forecastCache = forecast
    return forecast
end
