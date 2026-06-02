-- scripts/CallEvents.lua
-- Network events for phone calls: RI_CallEvent, RI_CallHistorySyncEvent.

-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: Call — ring / answer / decline / end between two players
-- callType: "ring" | "answer" | "decline" | "end"
-- ─────────────────────────────────────────────────────────────────────────────

if RI_CallEvent == nil then
    RI_CallEvent    = {}
    RI_CallEvent_mt = Class(RI_CallEvent, Event)
    InitEventClass(RI_CallEvent, "RI_CallEvent")
end

function RI_CallEvent.emptyNew()
    return Event.new(RI_CallEvent_mt)
end

function RI_CallEvent.new(callType, fromUserId, toUserId, callerName, callerNum)
    local self = RI_CallEvent.emptyNew()
    self.callType   = callType
    self.fromUserId = fromUserId
    self.toUserId   = toUserId
    self.callerName = callerName or ""
    self.callerNum  = callerNum  or ""
    return self
end

function RI_CallEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.callType   or "")
    streamWriteInt32(streamId,  self.fromUserId or 0)
    streamWriteInt32(streamId,  self.toUserId   or 0)
    streamWriteString(streamId, self.callerName or "")
    streamWriteString(streamId, self.callerNum  or "")
end

function RI_CallEvent:readStream(streamId, connection)
    self.callType   = streamReadString(streamId)
    self.fromUserId = streamReadInt32(streamId)
    self.toUserId   = streamReadInt32(streamId)
    self.callerName = streamReadString(streamId)
    self.callerNum  = streamReadString(streamId)
    self:run(connection)
end

function RI_CallEvent:run(connection)
    -- Server forwards to all other clients
    if connection ~= nil and not connection:getIsServer() then

        -- Store missed call in the client's playerCalls on the host (do NOT broadcast)
        if self.callType == "missed" then
            local clientInfo     = RoleplayPhone.onlineUsers[self.fromUserId]
            local clientUniqueId = clientInfo and clientInfo.uniqueId or ""
            if clientUniqueId ~= "" then
                if not RoleplayPhone.playerCalls[clientUniqueId] then
                    RoleplayPhone.playerCalls[clientUniqueId] = {}
                end
                table.insert(RoleplayPhone.playerCalls[clientUniqueId], 1, {
                    direction = "missed",
                    name      = self.callerName,
                    phone     = self.callerNum,
                    gameDay   = (g_currentMission and g_currentMission.environment
                                 and g_currentMission.environment.currentDay) or 0,
                    gameTime  = (g_currentMission and g_currentMission.environment
                                 and g_currentMission.environment.dayTime) or 0,
                    count     = 1,
                })
                print(string.format("[CallEvents] Stored missed call for %s from %s", clientUniqueId, self.callerName))
            end
            return
        end

        -- Voice isolation: server owns the active call table and broadcasts to bystanders.
        -- Participants (answerCall / onCallAnswered) update their own local state directly.
        if self.callType == "answer" then
            RoleplayPhone:addActiveCall(self.fromUserId, self.toUserId)
            g_server:broadcastEvent(RI_VoiceCallEvent.new(self.fromUserId, self.toUserId, true))
        elseif self.callType == "end" or self.callType == "decline" or self.callType == "busy" then
            RoleplayPhone:removeActiveCall(self.fromUserId, self.toUserId)
            g_server:broadcastEvent(RI_VoiceCallEvent.new(self.fromUserId, self.toUserId, false))
        end

        g_server:broadcastEvent(
            RI_CallEvent.new(self.callType, self.fromUserId, self.toUserId,
                             self.callerName, self.callerNum),
            false, connection)

        -- Outgoing call is recorded via addCallHistoryEntry mirror in onIncomingCall —
        -- no separate storage needed here.
    end

    local myUserId = RoleplayPhone:getMyUserId()
    if self.toUserId ~= myUserId then return end

    if     self.callType == "ring"    then RoleplayPhone:onIncomingCall(self.fromUserId, self.callerName, self.callerNum)
    elseif self.callType == "answer"  then RoleplayPhone:onCallAnswered()
    elseif self.callType == "decline" then RoleplayPhone:onCallDeclined()
    elseif self.callType == "busy"    then RoleplayPhone:onCallBusy()
    elseif self.callType == "end"     then RoleplayPhone:onCallEnded()
    end
end


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: CallHistorySync — host sends call history to a connecting client
-- ─────────────────────────────────────────────────────────────────────────────

if RI_CallHistorySyncEvent == nil then
    RI_CallHistorySyncEvent    = {}
    RI_CallHistorySyncEvent_mt = Class(RI_CallHistorySyncEvent, Event)
    InitEventClass(RI_CallHistorySyncEvent, "RI_CallHistorySyncEvent")
end

function RI_CallHistorySyncEvent.emptyNew()
    return Event.new(RI_CallHistorySyncEvent_mt)
end

function RI_CallHistorySyncEvent.new(entries)
    local self = RI_CallHistorySyncEvent.emptyNew()
    self.entries = entries or {}
    return self
end

function RI_CallHistorySyncEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, #self.entries)
    for _, e in ipairs(self.entries) do
        streamWriteString(streamId, e.name      or "")
        streamWriteString(streamId, e.phone     or "")
        streamWriteString(streamId, e.direction or "")
        streamWriteInt32(streamId,  e.gameDay   or 0)
        streamWriteInt32(streamId,  e.gameTime  or 0)
        streamWriteInt32(streamId,  e.count     or 1)
    end
end

function RI_CallHistorySyncEvent:readStream(streamId, connection)
    local count = streamReadInt32(streamId)
    self.entries = {}
    for i = 1, count do
        table.insert(self.entries, {
            name      = streamReadString(streamId),
            phone     = streamReadString(streamId),
            direction = streamReadString(streamId),
            gameDay   = streamReadInt32(streamId),
            gameTime  = streamReadInt32(streamId),
            count     = streamReadInt32(streamId),
        })
    end
    self:run(connection)
end

function RI_CallHistorySyncEvent:run(connection)
    if g_server ~= nil then return end
    if #self.entries > 0 then
        RoleplayPhone.callHistory = self.entries
        print(string.format("[CallEvents] Call history sync: received %d entries", #self.entries))
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: VoiceCall — host broadcasts active call pair to all clients
-- Each client applies voiceChatSetUserPairBlocked locally for isolation.
-- blocked: true when call starts, false when call ends
-- ─────────────────────────────────────────────────────────────────────────────

if RI_VoiceCallEvent == nil then
    RI_VoiceCallEvent    = {}
    RI_VoiceCallEvent_mt = Class(RI_VoiceCallEvent, Event)
    InitEventClass(RI_VoiceCallEvent, "RI_VoiceCallEvent")
end

function RI_VoiceCallEvent.emptyNew()
    return Event.new(RI_VoiceCallEvent_mt)
end

function RI_VoiceCallEvent.new(userIdA, userIdB, blocked)
    local self = RI_VoiceCallEvent.emptyNew()
    self.userIdA  = userIdA
    self.userIdB  = userIdB
    self.blocked  = blocked
    return self
end

function RI_VoiceCallEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.userIdA)
    streamWriteInt32(streamId, self.userIdB)
    streamWriteBool(streamId,  self.blocked)
end

function RI_VoiceCallEvent:readStream(streamId, connection)
    self.userIdA = streamReadInt32(streamId)
    self.userIdB = streamReadInt32(streamId)
    self.blocked = streamReadBool(streamId)
    self:run(connection)
end

function RI_VoiceCallEvent:run(connection)
    -- Server sends this; clients apply isolation locally.
    if g_server ~= nil then return end
    print(string.format("[CallEvents] VoiceCallEvent received: {%d,%d} blocked=%s",
        self.userIdA, self.userIdB, tostring(self.blocked)))
    if self.blocked then
        RoleplayPhone:addActiveCall(self.userIdA, self.userIdB)
    else
        RoleplayPhone:removeActiveCall(self.userIdA, self.userIdB)
    end
end


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: ClearRecents — client requests host to clear their saved call history
-- ─────────────────────────────────────────────────────────────────────────────

if RI_ClearRecentsEvent == nil then
    RI_ClearRecentsEvent    = {}
    RI_ClearRecentsEvent_mt = Class(RI_ClearRecentsEvent, Event)
    InitEventClass(RI_ClearRecentsEvent, "RI_ClearRecentsEvent")
end

function RI_ClearRecentsEvent.emptyNew()
    return Event.new(RI_ClearRecentsEvent_mt)
end

function RI_ClearRecentsEvent.new(playerUserId)
    local self = RI_ClearRecentsEvent.emptyNew()
    self.playerUserId = playerUserId
    return self
end

function RI_ClearRecentsEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.playerUserId or 0)
end

function RI_ClearRecentsEvent:readStream(streamId, connection)
    self.playerUserId = streamReadInt32(streamId)
    self:run(connection)
end

function RI_ClearRecentsEvent:run(connection)
    if g_server == nil then return end
    local info     = RoleplayPhone.onlineUsers[self.playerUserId]
    local uniqueId = info and info.uniqueId or ""
    if uniqueId == "" then return end
    -- Clear the server-side call history for this player and save immediately
    RoleplayPhone.playerCalls[uniqueId] = {}
    local entry    = RoleplayPhone:getOrCreateRegistryEntry(uniqueId, info.phone or "", info.name or "")
    local filename = RoleplayPhone:buildPlayerFilename(info.name or "unknown", entry.fileId)
    local contacts = ContactManager.userContacts[uniqueId] or {}
    local messages = RoleplayPhone.playerMessages and RoleplayPhone.playerMessages[uniqueId] or {}
    RoleplayPhone:savePlayerData(filename, contacts, messages, {})
    print(string.format("[CallEvents] ClearRecents: cleared call history for %s", info.name or tostring(self.playerUserId)))
end
