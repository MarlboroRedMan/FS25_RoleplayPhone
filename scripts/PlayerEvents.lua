-- scripts/PlayerEvents.lua
-- Network events related to player connection: PlayerHello, FarmList, ServerConfig.

-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: PlayerHello — client announces itself on connect
-- Carries playerUserId, farmId, playerName, phoneNumber, uniqueId
-- Host stores in RoleplayPhone.onlineUsers and uses for call/message routing
-- ─────────────────────────────────────────────────────────────────────────────

if RI_PlayerHelloEvent == nil then
    RI_PlayerHelloEvent    = {}
    RI_PlayerHelloEvent_mt = Class(RI_PlayerHelloEvent, Event)
    InitEventClass(RI_PlayerHelloEvent, "RI_PlayerHelloEvent")
end

function RI_PlayerHelloEvent.emptyNew()
    return Event.new(RI_PlayerHelloEvent_mt)
end

function RI_PlayerHelloEvent.new(playerUserId, farmId, playerName, phoneNumber, uniqueId)
    local self = RI_PlayerHelloEvent.emptyNew()
    self.playerUserId = playerUserId
    self.farmId       = farmId
    self.playerName   = playerName   or ""
    self.phoneNumber  = phoneNumber  or ""
    self.uniqueId     = uniqueId     or ""
    return self
end

function RI_PlayerHelloEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId,  self.playerUserId or 0)
    streamWriteInt32(streamId,  self.farmId       or 0)
    streamWriteString(streamId, self.playerName   or "")
    streamWriteString(streamId, self.phoneNumber  or "")
    streamWriteString(streamId, self.uniqueId     or "")
end

function RI_PlayerHelloEvent:readStream(streamId, connection)
    self.playerUserId = streamReadInt32(streamId)
    self.farmId       = streamReadInt32(streamId)
    self.playerName   = streamReadString(streamId)
    self.phoneNumber  = streamReadString(streamId)
    self.uniqueId     = streamReadString(streamId)
    self:run(connection)
end

function RI_PlayerHelloEvent:run(connection)
    -- Server: store this player in onlineUsers and broadcast to all clients
    if g_server ~= nil then
        RoleplayPhone.onlineUsers[self.playerUserId] = {
            farmId   = self.farmId,
            name     = self.playerName,
            phone    = self.phoneNumber,
            uniqueId = self.uniqueId,
        }
        -- Update playerUserId in any contact entries that reference this player by phone
        if self.phoneNumber ~= "" then
            local function updateUserId(list)
                for _, c in ipairs(list) do
                    if c.phone == self.phoneNumber and c.playerUserId ~= self.playerUserId then
                        c.playerUserId = self.playerUserId
                    end
                end
            end
            updateUserId(ContactManager.contacts)
            for _, contactList in pairs(ContactManager.userContacts) do
                updateUserId(contactList)
            end
        end

        -- Broadcast to all clients so everyone knows who's online
        g_server:broadcastEvent(
            RI_PlayerHelloEvent.new(self.playerUserId, self.farmId,
                                    self.playerName, self.phoneNumber, self.uniqueId),
            false, connection)

        -- Load this player's per-player data file and push everything to them at once
        if self.uniqueId ~= "" then
            local entry    = RoleplayPhone:getOrCreateRegistryEntry(self.uniqueId, self.phoneNumber, self.playerName)
            local filename = RoleplayPhone:buildPlayerFilename(self.playerName, entry.fileId)
            local data     = RoleplayPhone:loadPlayerData(filename, false)
            if data then
                -- Store client data server-side for saving later
                RoleplayPhone.playerMessages[self.uniqueId] = data.messages
                RoleplayPhone.playerCalls[self.uniqueId]    = data.callHistory
                -- Remove from offline cache — live data takes over
                RoleplayPhone.offlinePlayerData[self.uniqueId] = nil
                -- Push contacts
                ContactManager.userContacts[self.uniqueId]  = data.contacts
                connection:sendEvent(RI_ContactSyncEvent.new(data.contacts))
                -- Push messages
                local msgsToSend = {}
                for key, msgs in pairs(data.messages) do
                    -- Key format: "out_<recipientUniqueId>" or "in_<senderUniqueId>"
                    local isSentKey     = key:sub(1, 4) == "out_"
                    local otherUniqueId = isSentKey and key:sub(5) or key:sub(4)
                    for _, msg in ipairs(msgs) do
                        table.insert(msgsToSend, {
                            fromUniqueId = isSentKey and self.uniqueId or otherUniqueId,
                            toUniqueId   = isSentKey and otherUniqueId or self.uniqueId,
                            senderName   = msg.senderName,
                            text         = msg.text,
                            gameDay      = msg.gameDay,
                            gameTime     = msg.gameTime,
                            sent         = msg.sent,
                            msgType      = msg.msgType   or "text",
                            cardName     = msg.cardName  or "",
                            cardPhone    = msg.cardPhone or "",
                            cardFarm     = msg.cardFarm  or "",
                        })
                    end
                end
                if #msgsToSend > 0 then
                    connection:sendEvent(RI_MessageSyncEvent.new(msgsToSend))
                end
                -- Push call history
                if #data.callHistory > 0 then
                    connection:sendEvent(RI_CallHistorySyncEvent.new(data.callHistory))
                end
                print(string.format("[RoleplayPhone] Pushed player data to %s: %d contacts, %d msgs, %d calls",
                    self.playerName, #data.contacts, #msgsToSend, #data.callHistory))
            else
                -- New player — no file yet, send empty contacts
                ContactManager.userContacts[self.uniqueId] = {}
                connection:sendEvent(RI_ContactSyncEvent.new({}))
                print(string.format("[RoleplayPhone] New player %s — no data file yet", self.playerName))
            end
        end

        -- Push current server config to the new client
        connection:sendEvent(RI_ServerConfigEvent.new(RoleplayPhone.settings.rpVoiceMode))

        print(string.format("[RoleplayPhone] PlayerHello: %s (userId=%d farmId=%d phone=%s)",
            self.playerName, self.playerUserId, self.farmId, self.phoneNumber))
        return
    end
    -- Client: store in local onlineUsers table
    RoleplayPhone.onlineUsers[self.playerUserId] = {
        farmId   = self.farmId,
        name     = self.playerName,
        phone    = self.phoneNumber,
        uniqueId = self.uniqueId,
    }
    print(string.format("[RoleplayPhone] PlayerHello received: %s (userId=%d)",
        self.playerName, self.playerUserId))
end


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: FarmList — host sends full farm list to a connecting client
-- ─────────────────────────────────────────────────────────────────────────────

if RI_FarmListEvent == nil then
    RI_FarmListEvent    = {}
    RI_FarmListEvent_mt = Class(RI_FarmListEvent, Event)
    InitEventClass(RI_FarmListEvent, "RI_FarmListEvent")
end

function RI_FarmListEvent.emptyNew()
    return Event.new(RI_FarmListEvent_mt)
end

function RI_FarmListEvent.new(farms)
    local self = RI_FarmListEvent.emptyNew()
    self.farms = farms
    return self
end

function RI_FarmListEvent:writeStream(streamId, connection)
    local farms = self.farms or {}
    streamWriteInt32(streamId, #farms)
    for _, farm in ipairs(farms) do
        streamWriteInt32(streamId,  farm.farmId or 0)
        streamWriteString(streamId, farm.name   or ("Farm " .. tostring(farm.farmId)))
    end
end

function RI_FarmListEvent:readStream(streamId, connection)
    local count = streamReadInt32(streamId)
    self.farms = {}
    for i = 1, count do
        local farmId = streamReadInt32(streamId)
        local name   = streamReadString(streamId)
        table.insert(self.farms, { farmId = farmId, name = name })
    end
    self:run(connection)
end

function RI_FarmListEvent:run(connection)
    if self.farms and #self.farms > 0 then
        RoleplayPhone.knownFarms = self.farms
        RoleplayPhone:clearFarmCache()
        print(string.format("[PlayerEvents] Received farm list: %d farms", #self.farms))
    end
    RoleplayPhone.pendingInboxCheck = true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: ServerConfig — host broadcasts server-wide settings to all clients
-- Currently carries: rpVoiceMode
-- ─────────────────────────────────────────────────────────────────────────────

if RI_ServerConfigEvent == nil then
    RI_ServerConfigEvent    = {}
    RI_ServerConfigEvent_mt = Class(RI_ServerConfigEvent, Event)
    InitEventClass(RI_ServerConfigEvent, "RI_ServerConfigEvent")
end

function RI_ServerConfigEvent.emptyNew()
    return Event.new(RI_ServerConfigEvent_mt)
end

function RI_ServerConfigEvent.new(rpVoiceMode)
    local self = RI_ServerConfigEvent.emptyNew()
    self.rpVoiceMode = rpVoiceMode or false
    return self
end

function RI_ServerConfigEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.rpVoiceMode or false)
end

function RI_ServerConfigEvent:readStream(streamId, connection)
    self.rpVoiceMode = streamReadBool(streamId)
    self:run(connection)
end

function RI_ServerConfigEvent:run(connection)
    if g_server ~= nil then return end  -- host doesn't process its own config
    RoleplayPhone.settings.rpVoiceMode = self.rpVoiceMode
    RoleplayPhone:applyVoiceMode()
    print(string.format("[PlayerEvents] ServerConfig received: rpVoiceMode=%s",
        tostring(self.rpVoiceMode)))
end

-- ─── Helper: apply voice mode to local mic ───────────────────────────────────
-- NOTE: defined here for reference only — actual implementation is in PhoneVoice.lua
-- which loads after RoleplayPhone.lua. Do not add RoleplayPhone method definitions here.

-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: PlayerGoodbye — host broadcasts when a player disconnects
-- Clients receive this and remove the player from their onlineUsers table.
-- Host side is handled in Bootstrap.lua via MessageType.USER_REMOVED subscriber.
-- ─────────────────────────────────────────────────────────────────────────────

if RI_PlayerGoodbyeEvent == nil then
    RI_PlayerGoodbyeEvent    = {}
    RI_PlayerGoodbyeEvent_mt = Class(RI_PlayerGoodbyeEvent, Event)
    InitEventClass(RI_PlayerGoodbyeEvent, "RI_PlayerGoodbyeEvent")
end

function RI_PlayerGoodbyeEvent.emptyNew()
    return Event.new(RI_PlayerGoodbyeEvent_mt)
end

function RI_PlayerGoodbyeEvent.new(userId)
    local self = RI_PlayerGoodbyeEvent.emptyNew()
    self.userId = userId
    return self
end

function RI_PlayerGoodbyeEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.userId or 0)
end

function RI_PlayerGoodbyeEvent:readStream(streamId, connection)
    self.userId = streamReadInt32(streamId)
    self:run(connection)
end

function RI_PlayerGoodbyeEvent:run(connection)
    if g_server ~= nil then return end  -- host handles disconnects via USER_REMOVED, not here
    if self.userId and self.userId ~= 0 then
        RoleplayPhone.onlineUsers[self.userId] = nil
    end
end
