-- scripts/CallEvents.lua
-- Network events for phone calls: RI_CallEvent, RI_CallHistorySyncEvent.

-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: Call — ring / answer / decline / end between two players
-- callType: "ring" | "answer" | "decline" | "end" | "busy" | "missed"
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
    -- ── SERVER-SIDE HANDLING ─────────────────────────────────────────────────
    -- Fires when a CLIENT sends an event to the server (connection from client).
    if connection ~= nil and not connection:getIsServer() then

        -- "missed" is stored on the host only, never forwarded
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

        if self.callType == "answer" then
            -- Add to the call group (smart merge: if either party is already in a group,
            -- the other joins it; otherwise a new 2-person group is created).
            RoleplayPhone:addActiveCall(self.fromUserId, self.toUserId)
            -- Broadcast the full activeCalls snapshot — all clients (including bystanders)
            -- replace their local state and recompute voice isolation.
            g_server:broadcastEvent(RI_VoiceCallEvent.new(RoleplayPhone.activeCalls))
            -- If the host placed this call and a client just answered, update host UI state.
            -- The host never runs the client-side handler, so onCallAnswered() won't fire
            -- otherwise — leaving the host stuck on CALL_OUTGOING/"Ringing" indefinitely.
            if self.toUserId == RoleplayPhone:getMyUserId() then
                RoleplayPhone:onCallAnswered()
            end

        elseif self.callType == "end" then
            -- Remove the leaver from their group.
            local remaining = RoleplayPhone:removeActiveCall(self.fromUserId)
            -- Always broadcast updated snapshot first — all clients stay in sync.
            g_server:broadcastEvent(RI_VoiceCallEvent.new(RoleplayPhone.activeCalls))

            -- If exactly 1 member remains, the group dissolved — notify them.
            if remaining and #remaining == 1 then
                local lastId = remaining[1]
                local myHostId = RoleplayPhone:getMyUserId()
                if lastId == myHostId then
                    -- Host is the last remaining member — handle locally
                    RoleplayPhone:onCallEnded()
                else
                    -- A client is the last remaining member — send "end" to them
                    g_server:broadcastEvent(RI_CallEvent.new("end", self.fromUserId, lastId, "", ""))
                end
                print(string.format("[CallEvents] Group dissolved: last member=%d notified", lastId))
            elseif remaining and #remaining >= 2 then
                -- Group continues with remaining members — VoiceCallEvent already sent, nothing else needed.
                print(string.format("[CallEvents] %d left group, %d members remain", self.fromUserId, #remaining))
            end
            -- "end" is NOT forwarded blindly — the server handles group dissolution above.
            -- Forward and return here so the general forward below doesn't also send it.
            return

        elseif self.callType == "decline" or self.callType == "busy" then
            -- Pre-call events: no group context yet. No removeActiveCall needed.
            -- Fall through to the general broadcast below to forward to toUserId.
        end

        -- Forward to all other clients (ring, answer, decline, busy)
        g_server:broadcastEvent(
            RI_CallEvent.new(self.callType, self.fromUserId, self.toUserId,
                             self.callerName, self.callerNum),
            false, connection)
        return
    end

    -- ── CLIENT-SIDE HANDLING ─────────────────────────────────────────────────
    -- Fires on the local machine when an event is received from the server.
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
-- EVENT: VoiceCall — host broadcasts the full activeCalls snapshot to all clients.
-- Each client replaces its local activeCalls entirely and rebuilds voice isolation.
--
-- Wire format: [ numGroups | [numMembers | userId...] ... ]
-- This replaces the old pair+blocked format, enabling group calls of any size.
-- ─────────────────────────────────────────────────────────────────────────────

if RI_VoiceCallEvent == nil then
    RI_VoiceCallEvent    = {}
    RI_VoiceCallEvent_mt = Class(RI_VoiceCallEvent, Event)
    InitEventClass(RI_VoiceCallEvent, "RI_VoiceCallEvent")
end

function RI_VoiceCallEvent.emptyNew()
    return Event.new(RI_VoiceCallEvent_mt)
end

-- Pass the full activeCalls table (array of groups, each group an array of userIds).
function RI_VoiceCallEvent.new(activeCalls)
    local self = RI_VoiceCallEvent.emptyNew()
    -- Deep copy so we don't hold a stale reference
    self.groups = {}
    for _, group in ipairs(activeCalls or {}) do
        local g = {}
        for _, uid in ipairs(group) do table.insert(g, uid) end
        table.insert(self.groups, g)
    end
    return self
end

function RI_VoiceCallEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, #self.groups)
    for _, group in ipairs(self.groups) do
        streamWriteInt32(streamId, #group)
        for _, uid in ipairs(group) do
            streamWriteInt32(streamId, uid)
        end
    end
end

function RI_VoiceCallEvent:readStream(streamId, connection)
    local numGroups = streamReadInt32(streamId)
    self.groups = {}
    for i = 1, numGroups do
        local numMembers = streamReadInt32(streamId)
        local group = {}
        for j = 1, numMembers do
            table.insert(group, streamReadInt32(streamId))
        end
        table.insert(self.groups, group)
    end
    self:run(connection)
end

function RI_VoiceCallEvent:run(connection)
    -- Server sends this; clients replace their local activeCalls entirely.
    if g_server ~= nil then return end
    RoleplayPhone.activeCalls = self.groups
    print(string.format("[CallEvents] VoiceCallEvent: replaced activeCalls (%d group(s))", #self.groups))
    RoleplayPhone:rebuildVoiceIsolation()
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
    RoleplayPhone.playerCalls[uniqueId] = {}
    local entry    = RoleplayPhone:getOrCreateRegistryEntry(uniqueId, info.phone or "", info.name or "")
    local filename = RoleplayPhone:buildPlayerFilename(info.name or "unknown", entry.fileId)
    local contacts = ContactManager.userContacts[uniqueId] or {}
    local messages = RoleplayPhone.playerMessages and RoleplayPhone.playerMessages[uniqueId] or {}
    RoleplayPhone:savePlayerData(filename, contacts, messages, {})
    print(string.format("[CallEvents] ClearRecents: cleared call history for %s", info.name or tostring(self.playerUserId)))
end
