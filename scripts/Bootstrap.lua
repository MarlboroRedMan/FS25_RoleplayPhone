-- scripts/Bootstrap.lua
-- FS25 lifecycle hooks for FS25_RoleplayPhone.
-- Loads LAST so all RoleplayPhone methods and app files are defined before hooks are registered.
-- Moved here from CallsApp.lua where it was incorrectly embedded.

-- ─── Core game loop hooks ─────────────────────────────────────────────────────

Mission00.update = Utils.appendedFunction(Mission00.update, function(mission, dt)
    RoleplayPhone:updateBattery(dt / 1000)
    RoleplayPhone:updateCallTimeout(dt)
    RoleplayPhone:updateProximityVoice(dt)
end)

Mission00.draw = Utils.appendedFunction(Mission00.draw, function(mission)
    if not RoleplayPhone.inputRegistered then return end
    RoleplayPhone:draw()
end)

Mission00.mouseEvent = Utils.appendedFunction(Mission00.mouseEvent,
    function(mission, posX, posY, isDown, isUp, button)
        RoleplayPhone:mouseEvent(posX, posY, isDown, isUp, button)
    end)

-- ─── Mod event listener (required by FS25 engine for save/load) ───────────────

local _phoneKeyListener = {}

function _phoneKeyListener:keyEvent(unicode, sym, modifier, isDown)
    RoleplayPhone:keyEvent(unicode, sym, modifier, isDown)
end

-- FS25 calls these on every registered mod event listener during game save/load.
-- Without them the engine fails the entire save with Error 7.
function _phoneKeyListener:saveToXMLFile(xmlFilename, key, usedModNames)
    -- saveSavegame handles all saving now — this is intentionally empty.
    -- Engine requires this function to exist to avoid Error 7.
end

function _phoneKeyListener:loadFromXMLFile(xmlFilename, key)
    -- Loading is handled in Mission00.loadMap hook via RoleplayPhone:loadSavedData()
end

addModEventListener(_phoneKeyListener)

-- ─── Map load hook ────────────────────────────────────────────────────────────

Mission00.loadMap = Utils.appendedFunction(Mission00.loadMap, function(mission, name)
    RoleplayPhone:init()
    RoleplayPhone:loadSavedData()
    RoleplayPhone:loadServerConfig()
end)

-- ─── Mission ready: keybind + player announcement ─────────────────────────────
-- Fires after the game world is fully loaded and the local player is available.
-- This is the only safe moment to register keybinds and know the player's uniqueId.

RoleplayPhone.inputRegistered = false

g_messageCenter:subscribe(MessageType.CURRENT_MISSION_LOADED, function()
    if RoleplayPhone.inputRegistered then return end
    print("[RoleplayPhone] CURRENT_MISSION_LOADED fired, registering keybind")
    RoleplayPhone:registerKeybind()

    local myUserId   = RoleplayPhone:getMyUserId()
    local myFarmId   = RoleplayPhone:getMyFarmId()
    local myUniqueId = RoleplayPhone:getMyUniqueId()
    local myName     = (g_currentMission and g_currentMission.playerNickname)
                       or RoleplayPhone:getFarmName(myFarmId)
    local myPhone    = RoleplayPhone:hashPhone(myUserId)

    -- Load host's own player data now that uniqueId is available (local hosted sessions only).
    -- On dedicated servers all player data is pushed via sync events — no direct file load needed.
    if g_server ~= nil and myUniqueId ~= "" then
        local entry    = RoleplayPhone:getOrCreateRegistryEntry(myUniqueId, myPhone, myName)
        local filename = RoleplayPhone:buildPlayerFilename(myName, entry.fileId)
        RoleplayPhone:loadPlayerData(filename, true)
        print("[RoleplayPhone] Host data loaded: " .. filename)

        -- Cache all known offline player files so they survive a solo-session save.
        local reg = RoleplayPhone:loadPlayerRegistry()
        RoleplayPhone.cachedRegistry = reg
        for _, regEntry in ipairs(reg) do
            if regEntry.uniqueId ~= myUniqueId and regEntry.nickname ~= "" and regEntry.fileId ~= "" then
                local offlineFilename = RoleplayPhone:buildPlayerFilename(regEntry.nickname, regEntry.fileId)
                local data = RoleplayPhone:loadPlayerData(offlineFilename, false)
                if data then
                    RoleplayPhone.offlinePlayerData[regEntry.uniqueId] = {
                        filename    = offlineFilename,
                        contacts    = data.contacts,
                        messages    = data.messages,
                        callHistory = data.callHistory,
                    }
                    print("[RoleplayPhone] Cached offline player: " .. offlineFilename)
                end
            end
        end

        -- Repopulate messageDisplayNames for u_ keyed threads (unknown senders).
        for key, _ in pairs(RoleplayPhone.messages) do
            if type(key) == "string" and key:sub(1, 2) == "u_" then
                local uid  = key:sub(3)
                local info = { name = "Unknown", phone = "", userId = 0 }
                for _, regEntry in ipairs(reg) do
                    if regEntry.uniqueId == uid then
                        info.phone = regEntry.phone or ""
                        info.name  = regEntry.phone or "Unknown"
                        break
                    end
                end
                if info.name == "Unknown" then
                    local msgs = RoleplayPhone.messages[key]
                    if msgs and msgs[1] then info.name = msgs[1].senderName or "Unknown" end
                end
                RoleplayPhone.messageDisplayNames[key] = info
            end
        end
    end

    -- Announce ourselves so host and all clients know we're online.
    local helloEvt = RI_PlayerHelloEvent.new(myUserId, myFarmId, myName, myPhone, myUniqueId)
    if g_server ~= nil then
        RoleplayPhone.onlineUsers[myUserId] = {
            farmId   = myFarmId,
            name     = myName,
            phone    = myPhone,
            uniqueId = myUniqueId,
        }
        g_server:broadcastEvent(helloEvt)
    elseif g_client ~= nil then
        g_client:getServerConnection():sendEvent(helloEvt)
    end
    print(string.format("[RoleplayPhone] Sent PlayerHello: userId=%d farmId=%d phone=%s name=%s",
        myUserId, myFarmId, myPhone, myName))

    -- Show notification for any unpaid invoices awaiting action.
    local unpaid = 0
    for _, inv in pairs(InvoiceManager.invoices) do
        if inv.toFarmId == myFarmId and inv.status == "PENDING" then
            unpaid = unpaid + 1
        end
    end
    if unpaid > 0 then
        local msg = unpaid == 1
            and g_i18n:getText("phone_notif_unpaid_one")
            or  string.format(g_i18n:getText("phone_notif_unpaid_multi"), unpaid)
        NotificationManager:push("info", msg)
    end

    -- Contact sync is push-based (server pushes on connect) — no client pull needed.

    -- Apply voice mode now that settings are loaded and userManager is available.
    -- Clients get this via RI_ServerConfigEvent. The host never receives its own broadcast
    -- so must call this explicitly here.
    RoleplayPhone:applyVoiceMode()
end, RoleplayPhone)

-- ─── Player disconnect handling ───────────────────────────────────────────────
-- USER_REMOVED fires on the server immediately when a player's connection drops.
-- Replaces the old 5-second polling cleanupStaleOnlineUsers approach.
-- After saving and caching, broadcasts RI_PlayerGoodbyeEvent so all clients
-- remove the departed player from their own onlineUsers tables.
g_messageCenter:subscribe(MessageType.USER_REMOVED, function(self, user, disconnectReason)
    if g_server == nil then return end
    local uniqueId = user:getUniqueUserId()
    if not uniqueId or uniqueId == "" then return end

    -- Find this player's entry in onlineUsers by matching uniqueId.
    -- userId is only used for table removal and the goodbye broadcast (session-local routing).
    local userId = nil
    local info   = nil
    for uid, u in pairs(RoleplayPhone.onlineUsers) do
        if u.uniqueId == uniqueId then userId = uid; info = u; break end
    end
    if not userId or not info then return end

    if info.uniqueId and info.uniqueId ~= "" then
        local entry    = RoleplayPhone:getOrCreateRegistryEntry(info.uniqueId, info.phone, info.name)
        local filename = RoleplayPhone:buildPlayerFilename(info.name, entry.fileId)
        local key      = info.uniqueId
        local contacts = ContactManager.userContacts[key] or {}
        local messages = RoleplayPhone.playerMessages and RoleplayPhone.playerMessages[key] or {}
        local calls    = RoleplayPhone.playerCalls    and RoleplayPhone.playerCalls[key]    or {}
        RoleplayPhone:savePlayerData(filename, contacts, messages, calls)
        RoleplayPhone.offlinePlayerData[key] = {
            filename    = filename,
            contacts    = contacts,
            messages    = messages,
            callHistory = calls,
        }
        print(string.format("[RoleplayPhone] Saved + cached offline data: %s", info.name or tostring(userId)))
    end

    RoleplayPhone.onlineUsers[userId] = nil
    g_server:broadcastEvent(RI_PlayerGoodbyeEvent.new(userId))
end, RoleplayPhone)

-- ─── Vehicle specialization: F10 in vehicles ──────────────────────────────────
-- Must hook TypeManager.validateTypes — same timing EV uses.
-- Calling installSpecializations at module load is too early; the type system
-- isn't ready and the spec registration doesn't stick.
local _modDir  = g_currentModDirectory
local _modName = g_currentModName
TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, function(types)
    if types.typeName == "vehicle" then
        RoleplayPhoneVehicleSpec.installSpecializations(
            g_vehicleTypeManager, g_specializationManager, _modDir, _modName)
    end
end)

-- ─── Late-joiner voice sync ───────────────────────────────────────────────────
-- When a new user joins mid-session, broadcast all active calls so their client
-- can build the correct voice isolation state. Without this, late joiners hear
-- calls that should be isolated from them.
FSBaseMission.onUserAdded = Utils.appendedFunction(FSBaseMission.onUserAdded,
    function(mission, user)
        if g_server == nil then return end
        for _, pair in ipairs(RoleplayPhone.activeCalls) do
            g_server:broadcastEvent(RI_VoiceCallEvent.new(pair[1], pair[2], true))
        end
    end)
