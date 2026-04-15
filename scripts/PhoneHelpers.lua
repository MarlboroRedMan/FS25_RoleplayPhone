-- scripts/PhoneHelpers.lua
-- Farm/player helpers, permission system, battery, badge counts, money formatter.

-- ─── Game date formatter ──────────────────────────────────────────────────────
-- Returns "Oct 3" style string from an absolute game day number.
-- Uses plannedDaysPerPeriod so it respects whatever the server has set.
-- Converts game time (ms from midnight) to formatted string using player's 12/24h setting.
function RoleplayPhone:formatGameTime(gameTime)
    if not gameTime or gameTime <= 0 then return "" end
    local hrs  = math.floor(gameTime / 3600000) % 24
    local mins = math.floor((gameTime % 3600000) / 60000)
    return self:formatTime(hrs, mins)
end

function RoleplayPhone:formatGameDate(gameDay)
    if not gameDay or gameDay <= 0 then return "" end
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
    local monthIdx   = math.floor((gameDay - 1) / dpp) % 12 + 1
    local dayInMonth = ((gameDay - 1) % dpp) + 1
    -- When dpp=1 every day is its own month — just show month name, no number
    if dpp == 1 then
        return MONTHS[monthIdx]
    end
    return string.format("%s %d", MONTHS[monthIdx], dayInMonth)
end

function RoleplayPhone:getMyFarmId()
    local now = getTimeSec()
    if self.cachedFarmId and self.cachedFarmIdTime and (now - self.cachedFarmIdTime) < 30 then
        return self.cachedFarmId
    end
    local farmId = nil
    if g_farmManager and g_currentMission and g_currentMission.playerUserId then
        local farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
        if farm and farm.farmId and farm.farmId > 0 then farmId = farm.farmId end
    end
    if not farmId and g_currentMission and g_currentMission.playerFarmId
    and g_currentMission.playerFarmId > 0 then
        farmId = g_currentMission.playerFarmId
    end
    if not farmId and g_currentMission and g_currentMission.player
    and g_currentMission.player.farmId and g_currentMission.player.farmId > 0 then
        farmId = g_currentMission.player.farmId
    end
    if not farmId then farmId = 1 end
    self.cachedFarmId = farmId; self.cachedFarmIdTime = now
    return farmId
end

function RoleplayPhone:getMyUserId()
    if g_currentMission and g_currentMission.playerUserId then
        return g_currentMission.playerUserId
    end
    return 0
end

function RoleplayPhone:getMyUniqueId()
    if g_localPlayer and g_localPlayer.uniqueUserId then
        return g_localPlayer.uniqueUserId
    end
    return ""
end

-- PHONE_FORMATS keyed by mapId.
-- digits = total digit count that hashPhone generates (no dashes).
-- format = how to display those digits (X = digit placeholder).
local PHONE_FORMATS = {
    MapUS = { digits = 10, format = "XXX-XXX-XXXX", areaCode = "406" },  -- Montana
    MapEU = { digits =  9, format = "XXX-XXX-XXX",  areaCode = "048" },  -- Warsaw
    MapAS = { digits = 10, format = "0XX-XXXX-XXXX", areaCode = "81"  },  -- Indonesia
}
local PHONE_FORMAT_DEFAULT = PHONE_FORMATS.MapUS

function RoleplayPhone:getMapPhoneFormat()
    if g_currentMission and g_currentMission.missionInfo and g_currentMission.missionInfo.mapId then
        return PHONE_FORMATS[g_currentMission.missionInfo.mapId] or PHONE_FORMAT_DEFAULT
    end
    return PHONE_FORMAT_DEFAULT
end

function RoleplayPhone:hashPhone(userId)
    local fmt    = self:getMapPhoneFormat()
    local prefix = fmt.areaCode or ""
    local needed = fmt.digits - #prefix

    -- Try to get a stable uniqueId so phone numbers survive session reconnects
    local uniqueId = ""
    local myUserId = self:getMyUserId()
    if userId and userId == myUserId then
        uniqueId = self:getMyUniqueId()
    elseif userId and self.onlineUsers[userId] then
        uniqueId = self.onlineUsers[userId].uniqueId or ""
    end

    local n1, n2
    if uniqueId ~= "" then
        -- Stable hash derived from uniqueId bytes — survives userId changes on reconnect
        local seed = 0
        for i = 1, math.min(#uniqueId, 12) do
            seed = (seed * 37 + (string.byte(uniqueId, i) or 0)) % 9999991
        end
        n1 = (seed * 9999 + 1) % 100000
        n2 = (seed * 7919 + 3) % 100000
    else
        -- Fallback: userId-based (unstable across sessions, used when uniqueId unavailable)
        if not userId or userId == 0 then
            return self:formatPhoneDisplay(prefix .. string.rep("0", needed))
        end
        n1 = (userId * 2654435761) % 100000
        n2 = (userId * 1234567891) % 100000
    end

    local raw = prefix .. string.format("%05d%05d", n1, n2):sub(1, needed)
    return self:formatPhoneDisplay(raw)
end

-- Apply the map's format pattern to a raw digit string.
-- X chars in the pattern are replaced by digits in order; dashes are kept.
function RoleplayPhone:formatPhoneDisplay(raw)
    local fmt = self:getMapPhoneFormat()
    local pattern = fmt.format
    local result  = ""
    local di      = 1
    for i = 1, #pattern do
        local ch = pattern:sub(i, i)
        if ch == "X" then
            result = result .. (raw:sub(di, di) ~= "" and raw:sub(di, di) or "0")
            di = di + 1
        else
            result = result .. ch
        end
    end
    return result
end

-- Format typed keypad digits (raw = digits only, no dashes) for live display.
-- Fills the format pattern left-to-right as digits arrive.
function RoleplayPhone:formatKeypadDisplay(raw)
    local fmt     = self:getMapPhoneFormat()
    local pattern = fmt.format
    local result  = ""
    local di      = 1
    for i = 1, #pattern do
        local ch = pattern:sub(i, i)
        if ch == "X" then
            if di <= #raw then
                result = result .. raw:sub(di, di)
                di = di + 1
            else
                break
            end
        else
            -- Only add separator if there are still digits coming
            if di <= #raw then result = result .. ch end
        end
    end
    return result
end

function RoleplayPhone:getMaxKeypadDigits()
    return self:getMapPhoneFormat().digits
end

function RoleplayPhone:resolveUserId(contact)
    if not contact then return 0 end
    -- Validate stored userId is still active this session before trusting it
    if contact.playerUserId and contact.playerUserId ~= 0 then
        if self.onlineUsers[contact.playerUserId] then
            return contact.playerUserId
        end
        -- Stale userId — fall through to name/phone matching below
    end
    if contact.name and contact.name ~= "" then
        local lower = string.lower(contact.name)
        for uid, info in pairs(self.onlineUsers) do
            if info.name and string.lower(info.name) == lower then return uid end
        end
    end
    -- Match by stored phone number (stable across sessions now)
    if contact.phone and contact.phone ~= "" then
        for uid, info in pairs(self.onlineUsers) do
            if info.phone and info.phone == contact.phone then return uid end
        end
    end
    return 0
end

function RoleplayPhone:isUserOnline(userId)
    if not userId or userId == 0 then return false end
    if userId == self:getMyUserId() then return true end
    return self.onlineUsers[userId] ~= nil
end

function RoleplayPhone:getFarmName(farmId)
    if not farmId then return "Unknown" end
    if g_farmManager then
        local f = g_farmManager:getFarmById(farmId)
        if f and f.name and f.name ~= "" then return f.name end
    end
    if self.knownFarms then
        for _, f in ipairs(self.knownFarms) do
            if f.farmId == farmId then return f.name end
        end
    end
    return "Farm " .. tostring(farmId)
end

function RoleplayPhone:resolveFarmId(farmName)
    if not farmName or farmName == "" then return 0 end
    local lower = string.lower(farmName)
    if g_farmManager then
        for _, farm in pairs(g_farmManager:getFarms()) do
            if farm.name and string.lower(farm.name) == lower then return farm.farmId end
        end
    end
    if self.knownFarms then
        for _, farm in ipairs(self.knownFarms) do
            if farm.name and string.lower(farm.name) == lower then return farm.farmId end
        end
    end
    return 0
end

function RoleplayPhone:getAvailableFarms()
    if self._farmCache and #self._farmCache > 0 then return self._farmCache end
    local result = {}; local seenIds = {}; local xmlWhitelist = {}
    if g_server ~= nil and g_currentMission and g_currentMission.missionInfo then
        local dir = g_currentMission.missionInfo.savegameDirectory
        if dir then
            local xmlFile = loadXMLFile("farmsXML", dir .. "/farms.xml")
            if xmlFile and xmlFile ~= 0 then
                local i = 0
                while true do
                    local key = string.format("farms.farm(%d)", i)
                    if not hasXMLProperty(xmlFile, key) then break end
                    local farmId = getXMLInt(xmlFile, key .. "#farmId")
                    local name   = getXMLString(xmlFile, key .. "#name")
                    if farmId and farmId > 0 then
                        xmlWhitelist[farmId] = (name and name ~= "") and name or ("Farm " .. tostring(farmId))
                    end
                    i = i + 1
                end
                delete(xmlFile)
            end
        end
    end
    if g_farmManager then
        for _, farm in pairs(g_farmManager:getFarms()) do
            local fid = farm.farmId
            if fid and fid > 0 and xmlWhitelist[fid] then
                table.insert(result, { farmId=fid, name=(farm.name and farm.name ~= "") and farm.name or xmlWhitelist[fid] })
                seenIds[fid] = true
            end
        end
    end
    for fid, name in pairs(xmlWhitelist) do
        if not seenIds[fid] then table.insert(result, { farmId=fid, name=name }); seenIds[fid] = true end
    end
    if self.knownFarms then
        for _, farm in ipairs(self.knownFarms) do
            if not seenIds[farm.farmId] then table.insert(result, farm); seenIds[farm.farmId] = true end
        end
    end
    if #result == 0 then table.insert(result, { farmId=1, name="Farm 1" }) end
    table.sort(result, function(a, b) return a.farmId < b.farmId end)
    self._farmCache = result
    return result
end

function RoleplayPhone:clearFarmCache() self._farmCache = nil end

function RoleplayPhone:isFarmManager()
    if not g_currentMission then return false end
    if g_currentMission:getIsServer() then return true end
    if g_currentMission.isMasterUser then return true end
    if g_currentMission.getHasPlayerPermission then
        local ok, result = pcall(function() return g_currentMission:getHasPlayerPermission("farmManager") end)
        if ok and result then return true end
    end
    if g_currentMission.userPermissions then
        local ok, result = pcall(function() return g_currentMission.userPermissions:hasPermission("farmManager") end)
        if ok and result then return true end
    end
    return false
end

function RoleplayPhone:canPost()   return self:isFarmManager() end
function RoleplayPhone:canAct()    return self:isFarmManager() end
function RoleplayPhone:canDeleteAny()
    if not g_currentMission then return false end
    return g_currentMission:getIsServer() or (g_currentMission.isMasterUser == true)
end

function RoleplayPhone:updateBattery(dt)
    local bat = self.battery
    if self.state ~= self.STATE.CLOSED then
        local rate = (self.state == self.STATE.CALL_ACTIVE) and bat.callRate or bat.drainRate
        bat.level = math.max(0, bat.level - rate * dt)
    else
        bat.level = math.min(100, bat.level + bat.chargeRate * dt)
    end
end

function RoleplayPhone:updateCallTimeout(dt)
    if self.state ~= self.STATE.CALL_OUTGOING and self.state ~= self.STATE.CALL_INCOMING then return end
    self.callRingTimer = (self.callRingTimer or 0) + dt
    if self.callRingTimer >= 30000 then
        self.callRingTimer = 0
        local myUserId = self:getMyUserId()
        local remoteUser = (self.call.fromUserId == myUserId) and self.call.toUserId or self.call.fromUserId
        local evt = RI_CallEvent.new("end", myUserId, remoteUser, "", "")
        if g_server ~= nil then g_server:broadcastEvent(evt)
        elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end
        if self.state == self.STATE.CALL_INCOMING then
            local name = self.call.contactName or g_i18n:getText("phone_unknown_contact")
            NotificationManager:push("info", string.format(g_i18n:getText("phone_notif_missed_call"), name))
            table.insert(self.callHistory, 1, { direction="missed", name=name, gameTime=(g_currentMission and g_currentMission.environment and g_currentMission.environment.dayTime) or 0 })
        end
        self:_restoreAfterCall()
    end
end

function RoleplayPhone:getAppBadgeCount(appId)
    local myFarmId = self:getMyFarmId()
    if appId == "invoices" then
        local count = 0
        local invoices = InvoiceManager:getInvoicesForFarm(myFarmId, true)
        for _, inv in ipairs(invoices) do
            if inv.status == "PENDING" and not self.seenInvoiceIds[inv.id] then count = count + 1 end
        end
        return count
    elseif appId == "calls" then
        local count = 0
        for _, entry in ipairs(self.callHistory) do
            if entry.direction == "missed" then count = count + 1 end
        end
        return count
    elseif appId == "messages" then
        local count = 0
        for _, n in pairs(self.unreadMessages) do count = count + (n or 0) end
        return count
    elseif appId == "contacts" then
    end
    return 0
end

function RoleplayPhone:clearMissedCallBadge()
    for _, entry in ipairs(self.callHistory) do
        if entry.direction == "missed" then
            entry.direction = "missed_seen"
        end
    end
end

function RoleplayPhone:formatMoney(n)
    n = math.floor(n or 0)
    local s = tostring(n); local result = ""; local count = 0
    for i = #s, 1, -1 do
        if count > 0 and count % 3 == 0 then result = "," .. result end
        result = s:sub(i,i) .. result; count = count + 1
    end
    return result
end

function RoleplayPhone:getCallActionKeyName()
    local result = "F8"
    local xmlPath = getUserProfileAppPath() .. "inputBinding.xml"
    local xmlFile = loadXMLFile("RP_InputBinding", xmlPath)
    if not xmlFile or xmlFile == 0 then return result end
    local i = 0
    while true do
        local key = string.format("inputBinding.actionBinding(%d)", i)
        if not hasXMLProperty(xmlFile, key) then break end
        local action = getXMLString(xmlFile, key .. "#action")
        if action == "RI_CALL_ACTION" then
            local input = getXMLString(xmlFile, key .. ".binding(0)#input") or ""
            local name = input:match("^KEY_(.+)$")
            if name then result = name:upper() end
            break
        end
        i = i + 1
    end
    delete(xmlFile)
    return result
end
