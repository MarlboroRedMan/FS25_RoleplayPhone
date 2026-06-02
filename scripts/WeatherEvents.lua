-- scripts/WeatherEvents.lua
-- Network event for weather forecast: RI_WeatherForecastEvent.

if RI_WeatherForecastEvent == nil then
    RI_WeatherForecastEvent    = {}
    RI_WeatherForecastEvent_mt = Class(RI_WeatherForecastEvent, Event)
    InitEventClass(RI_WeatherForecastEvent, "RI_WeatherForecastEvent")
end

function RI_WeatherForecastEvent.emptyNew()
    return Event.new(RI_WeatherForecastEvent_mt)
end

function RI_WeatherForecastEvent.new(forecast)
    local self = RI_WeatherForecastEvent.emptyNew()
    self.forecast = forecast or {}
    return self
end

function RI_WeatherForecastEvent:writeStream(streamId, connection)
    local entries = {}
    for relDay, data in pairs(self.forecast) do
        table.insert(entries, { relDay=relDay, data=data })
    end
    streamWriteInt32(streamId, #entries)
    for _, e in ipairs(entries) do
        streamWriteInt32(streamId,   e.relDay)
        streamWriteString(streamId,  e.data.typeName or "")
        streamWriteFloat32(streamId, e.data.minTemp  or -999)
        streamWriteFloat32(streamId, e.data.maxTemp  or -999)
    end
end

function RI_WeatherForecastEvent:readStream(streamId, connection)
    local count = streamReadInt32(streamId)
    self.forecast = {}
    for i = 1, count do
        local relDay  = streamReadInt32(streamId)
        local tn      = streamReadString(streamId)
        local minTemp = streamReadFloat32(streamId)
        local maxTemp = streamReadFloat32(streamId)
        self.forecast[relDay] = {
            typeName = tn,
            minTemp  = minTemp ~= -999 and minTemp or nil,
            maxTemp  = maxTemp ~= -999 and maxTemp or nil,
        }
    end
    self:run(connection)
end

function RI_WeatherForecastEvent:run(connection)
    if g_server ~= nil then return end
    local env = g_currentMission and g_currentMission.environment
    RoleplayPhone._forecastCache    = self.forecast
    RoleplayPhone._forecastCacheDay = env and env.currentDay or 0
    local count = 0
    for _ in pairs(self.forecast) do count = count + 1 end
    print(string.format("[WeatherEvents] Forecast received: %d days", count))
end
