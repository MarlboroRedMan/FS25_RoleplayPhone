-- scripts/MessageEvents.lua
-- Network events for messaging: RI_MessageEvent, RI_MessageSyncEvent, RI_DeleteThreadEvent.

-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: Message — direct message between two players
-- ─────────────────────────────────────────────────────────────────────────────

if RI_MessageEvent == nil then
    RI_MessageEvent    = {}
    RI_MessageEvent_mt = Class(RI_MessageEvent, Event)
    InitEventClass(RI_MessageEvent, "RI_MessageEvent")
end

function RI_MessageEvent.emptyNew()
    return Event.new(RI_MessageEvent_mt)
end

function RI_MessageEvent.new(fromUniqueId, toUniqueId, senderName, text, gameDay, gameTime, msgType, cardName, cardPhone, cardFarm)
    local self = RI_MessageEvent.emptyNew()
    self.fromUniqueId = fromUniqueId or ""
    self.toUniqueId   = toUniqueId   or ""
    self.senderName = senderName
    self.text       = text
    self.gameDay    = gameDay   or 0
    self.gameTime   = gameTime  or 0
    self.msgType    = msgType   or "text"
    self.cardName   = cardName  or ""
    self.cardPhone  = cardPhone or ""
    self.cardFarm   = cardFarm  or ""
    return self
end

function RI_MessageEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.fromUniqueId or "")
    streamWriteString(streamId, self.toUniqueId   or "")
    streamWriteString(streamId, self.senderName or "")
    streamWriteString(streamId, self.text       or "")
    streamWriteInt32(streamId,  self.gameDay    or 0)
    streamWriteInt32(streamId,  self.gameTime   or 0)
    streamWriteString(streamId, self.msgType    or "text")
    streamWriteString(streamId, self.cardName   or "")
    streamWriteString(streamId, self.cardPhone  or "")
    streamWriteString(streamId, self.cardFarm   or "")
end

function RI_MessageEvent:readStream(streamId, connection)
    self.fromUniqueId = streamReadString(streamId)
    self.toUniqueId   = streamReadString(streamId)
    self.senderName = streamReadString(streamId)
    self.text       = streamReadString(streamId)
    self.gameDay    = streamReadInt32(streamId)
    self.gameTime   = streamReadInt32(streamId)
    self.msgType    = streamReadString(streamId)
    self.cardName   = streamReadString(streamId)
    self.cardPhone  = streamReadString(streamId)
    self.cardFarm   = streamReadString(streamId)
    self:run(connection)
end

function RI_MessageEvent:run(connection)
    -- Server: route directly to recipient, store for both parties
    if g_server ~= nil and connection ~= nil and not connection:getIsServer() then
        local myUniqueId        = RoleplayPhone:getMyUniqueId()
        local senderUniqueId    = self.fromUniqueId
        local recipientUniqueId = self.toUniqueId

        local function storeForPlayer(uniqueId, key, msgEntry)
            if not uniqueId or uniqueId == "" then return end
            if not RoleplayPhone.playerMessages[uniqueId] then
                RoleplayPhone.playerMessages[uniqueId] = {}
            end
            if not RoleplayPhone.playerMessages[uniqueId][key] then
                RoleplayPhone.playerMessages[uniqueId][key] = {}
            end
            table.insert(RoleplayPhone.playerMessages[uniqueId][key], msgEntry)
        end

        local sentEntry     = { fromUniqueId=senderUniqueId, senderName=self.senderName,
                                text=self.text, gameDay=self.gameDay, gameTime=self.gameTime, sent=true,
                                msgType=self.msgType, cardName=self.cardName, cardPhone=self.cardPhone, cardFarm=self.cardFarm }
        local receivedEntry = { fromUniqueId=senderUniqueId, senderName=self.senderName,
                                text=self.text, gameDay=self.gameDay, gameTime=self.gameTime, sent=false,
                                msgType=self.msgType, cardName=self.cardName, cardPhone=self.cardPhone, cardFarm=self.cardFarm }
        storeForPlayer(senderUniqueId,    "out_" .. recipientUniqueId, sentEntry)
        storeForPlayer(recipientUniqueId, "in_"  .. senderUniqueId,   receivedEntry)

        if self.toUniqueId ~= myUniqueId then
            local recipientUserId = nil
            for uid, u in pairs(RoleplayPhone.onlineUsers) do
                if u.uniqueId == recipientUniqueId then recipientUserId = uid; break end
            end
            local ps = g_currentMission and g_currentMission.playerSystem
            local recipientPlayer = recipientUserId and ps and ps:getPlayerByUserId(recipientUserId)
            local recipientConn = recipientPlayer and recipientPlayer.connection
            if recipientConn then
                recipientConn:sendEvent(RI_MessageEvent.new(
                    self.fromUniqueId, self.toUniqueId,
                    self.senderName, self.text, self.gameDay, self.gameTime,
                    self.msgType, self.cardName, self.cardPhone, self.cardFarm))
            end
            return
        end
    end

    local myUniqueId = RoleplayPhone:getMyUniqueId()
    if self.toUniqueId ~= myUniqueId then return end

    local senderUniqueId = self.fromUniqueId
    local senderPhone    = ""
    local senderUserId   = 0
    for uid, u in pairs(RoleplayPhone.onlineUsers) do
        if u.uniqueId == senderUniqueId then
            senderPhone  = u.phone or ""
            senderUserId = uid
            break
        end
    end

    local _, contactIdx = RoleplayPhone:getContactByPhone(senderPhone)
    if contactIdx then
        RoleplayPhone:receiveMessage(contactIdx, senderUserId, self.senderName,
                                     self.text, self.gameDay, false, self.gameTime,
                                     self.msgType, self.cardName, self.cardPhone, self.cardFarm)
    else
        local key = "u_" .. senderUniqueId
        RoleplayPhone.messageDisplayNames[key] = {
            name   = self.senderName,
            phone  = senderPhone,
            userId = senderUserId,
        }
        RoleplayPhone:receiveMessage(key, senderUserId, self.senderName,
                                     self.text, self.gameDay, false, self.gameTime,
                                     self.msgType, self.cardName, self.cardPhone, self.cardFarm)
    end
end


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: MessageSync — host sends client's own message threads on connect
-- ─────────────────────────────────────────────────────────────────────────────

if RI_MessageSyncEvent == nil then
    RI_MessageSyncEvent    = {}
    RI_MessageSyncEvent_mt = Class(RI_MessageSyncEvent, Event)
    InitEventClass(RI_MessageSyncEvent, "RI_MessageSyncEvent")
end

function RI_MessageSyncEvent.emptyNew()
    return Event.new(RI_MessageSyncEvent_mt)
end

function RI_MessageSyncEvent.new(msgs)
    local self = RI_MessageSyncEvent.emptyNew()
    self.msgs = msgs or {}
    return self
end

function RI_MessageSyncEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, #self.msgs)
    for _, m in ipairs(self.msgs) do
        streamWriteString(streamId, m.fromUniqueId or "")
        streamWriteString(streamId, m.toUniqueId   or "")
        streamWriteString(streamId, m.senderName   or "")
        streamWriteString(streamId, m.text         or "")
        streamWriteInt32(streamId,  m.gameDay      or 0)
        streamWriteInt32(streamId,  m.gameTime     or 0)
        streamWriteBool(streamId,   m.sent         or false)
        streamWriteString(streamId, m.msgType      or "text")
        streamWriteString(streamId, m.cardName     or "")
        streamWriteString(streamId, m.cardPhone    or "")
        streamWriteString(streamId, m.cardFarm     or "")
    end
end

function RI_MessageSyncEvent:readStream(streamId, connection)
    local count = streamReadInt32(streamId)
    self.msgs = {}
    for i = 1, count do
        table.insert(self.msgs, {
            fromUniqueId = streamReadString(streamId),
            toUniqueId   = streamReadString(streamId),
            senderName   = streamReadString(streamId),
            text         = streamReadString(streamId),
            gameDay      = streamReadInt32(streamId),
            gameTime     = streamReadInt32(streamId),
            sent         = streamReadBool(streamId),
            msgType      = streamReadString(streamId),
            cardName     = streamReadString(streamId),
            cardPhone    = streamReadString(streamId),
            cardFarm     = streamReadString(streamId),
        })
    end
    self:run(connection)
end

function RI_MessageSyncEvent:run(connection)
    if g_server ~= nil then return end
    RoleplayPhone.isSyncing = true

    for _, m in ipairs(self.msgs) do
        local isSent        = m.sent
        local otherUniqueId = isSent and m.toUniqueId or m.fromUniqueId

        -- Look up the other party's phone and userId from onlineUsers (may be offline)
        local otherPhone  = ""
        local otherUserId = 0
        if otherUniqueId and otherUniqueId ~= "" then
            for uid, u in pairs(RoleplayPhone.onlineUsers) do
                if u.uniqueId == otherUniqueId then
                    otherPhone  = u.phone or ""
                    otherUserId = uid
                    break
                end
            end
        end

        -- Prefer saved contact key; fall back to stable u_<uniqueId> key
        local _, key = RoleplayPhone:getContactByPhone(otherPhone)
        if not key then
            key = otherUniqueId ~= "" and ("u_" .. otherUniqueId) or "u_unknown"
            RoleplayPhone.messageDisplayNames[key] = {
                name   = m.senderName,
                phone  = otherPhone,
                userId = otherUserId,
            }
        end
        RoleplayPhone:receiveMessage(key, 0, m.senderName,
                                     m.text, m.gameDay, isSent, m.gameTime,
                                     m.msgType, m.cardName, m.cardPhone, m.cardFarm)
    end
    RoleplayPhone.isSyncing = false
    print(string.format("[MessageEvents] Message sync: received %d messages", #self.msgs))
end


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: DeleteThread — client asks server to remove a message thread
-- ─────────────────────────────────────────────────────────────────────────────

if RI_DeleteThreadEvent == nil then
    RI_DeleteThreadEvent    = {}
    RI_DeleteThreadEvent_mt = Class(RI_DeleteThreadEvent, Event)
    InitEventClass(RI_DeleteThreadEvent, "RI_DeleteThreadEvent")
end

function RI_DeleteThreadEvent.emptyNew()
    return Event.new(RI_DeleteThreadEvent_mt)
end

function RI_DeleteThreadEvent.new(otherPhone)
    local self = RI_DeleteThreadEvent.emptyNew()
    self.otherPhone = otherPhone or ""
    return self
end

function RI_DeleteThreadEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.otherPhone)
end

function RI_DeleteThreadEvent:readStream(streamId, connection)
    self.otherPhone = streamReadString(streamId)
    self:run(connection)
end

function RI_DeleteThreadEvent:run(connection)
    if g_server == nil then return end

    local ps           = g_currentMission and g_currentMission.playerSystem
    local clientPlayer = ps and ps:getPlayerByConnection(connection)
    local clientUserId = clientPlayer and clientPlayer.userId
    if not clientUserId then
        print("[MessageEvents] DeleteThread: could not identify client connection"); return
    end

    local info           = RoleplayPhone.onlineUsers[clientUserId]
    local clientUniqueId = info and info.uniqueId or ""
    if clientUniqueId == "" then
        print("[MessageEvents] DeleteThread: uniqueId not found for userId " .. tostring(clientUserId)); return
    end

    local otherUniqueId = ""
    local registry = RoleplayPhone:loadPlayerRegistry()
    for _, entry in ipairs(registry) do
        if entry.phone == self.otherPhone then
            otherUniqueId = entry.uniqueId or ""; break
        end
    end
    if otherUniqueId == "" then
        print("[MessageEvents] DeleteThread: phone not in registry: " .. self.otherPhone); return
    end

    local threadData = RoleplayPhone.playerMessages[clientUniqueId]
    if threadData then
        threadData["out_" .. otherUniqueId] = nil
        threadData["in_"  .. otherUniqueId] = nil
    end

    local clientEntry    = RoleplayPhone:getOrCreateRegistryEntry(clientUniqueId, info.phone or "")
    local clientFilename = RoleplayPhone:buildPlayerFilename(info.name or "player", clientEntry.fileId)
    local clientContacts = ContactManager.userContacts[clientUniqueId] or {}
    local clientMessages = RoleplayPhone.playerMessages[clientUniqueId] or {}
    local clientCalls    = RoleplayPhone.playerCalls and RoleplayPhone.playerCalls[clientUniqueId] or {}
    RoleplayPhone:savePlayerData(clientFilename, clientContacts, clientMessages, clientCalls)
    print(string.format("[MessageEvents] DeleteThread: cleared thread for client %.8s", clientUniqueId))
end
