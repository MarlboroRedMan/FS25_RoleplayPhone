-- scripts/PhoneCallLogic.lua
-- Call state machine: outgoing, incoming, active, end, decline.

-- ─── Call history helper ──────────────────────────────────────────────────────
-- Stacks repeated calls from the same person rather than adding duplicate rows.
function RoleplayPhone:addCallHistoryEntry(direction, name, phone)
    local gameDay  = (g_currentMission and g_currentMission.environment
                     and g_currentMission.environment.currentDay) or 0
    local gameTime = (g_currentMission and g_currentMission.environment
                     and g_currentMission.environment.dayTime) or 0
    local top = self.callHistory[1]
    if top and top.name == name and top.direction == direction then
        top.count    = (top.count or 1) + 1
        top.gameDay  = gameDay
        top.gameTime = gameTime
    else
        table.insert(self.callHistory, 1, {
            direction = direction,
            name      = name  or "",
            phone     = phone or "",
            gameDay   = gameDay,
            gameTime  = gameTime,
            count     = 1,
        })
    end
end

function RoleplayPhone:startCall()
    if not self.selectedContact then return end
    local c = ContactManager:getContact(self.selectedContact)
    if not c then return end
    local toUserId = self:resolveUserId(c)
    if toUserId == 0 then
        if self.unavailableSample and self.unavailableSample ~= 0 then playSample(self.unavailableSample, 1, 1.0, 1.0, 0, 0) end
        NotificationManager:push("rejected", string.format(g_i18n:getText("phone_notif_cant_reach"), c.name or c.farmName or "?")); return
    end
    if g_server ~= nil and not self:isUserOnline(toUserId) then
        if self.unavailableSample and self.unavailableSample ~= 0 then playSample(self.unavailableSample, 1, 1.0, 1.0, 0, 0) end
        NotificationManager:push("rejected", string.format(g_i18n:getText("phone_notif_cant_reach"), c.name or c.farmName or "?")); return
    end
    local myUserId = self:getMyUserId()
    -- FIX: use playerNickname so callee sees "Dan" not "Dan's Farm"
    local myName = (g_currentMission and g_currentMission.playerNickname)
                   or self:getFarmName(self:getMyFarmId())
    self.call.contactName = c.name or c.farmName; self.call.contactNum = c.phone or ""
    self.call.toUserId = toUserId; self.call.fromUserId = myUserId
    self.call.startTime = 0; self.call.prevState = self.STATE.CLOSED
    self.state = self.STATE.CALL_OUTGOING; self.callRingTimer = 0
    self:addCallHistoryEntry("outgoing", self.call.contactName, c.phone or "")
    self.isOpen = false
    g_inputBinding:setShowMouseCursor(false)
    if self.phoneContextEventId then g_inputBinding:removeActionEvent(self.phoneContextEventId); self.phoneContextEventId = nil end
    if self.flashlightBlockerId then g_inputBinding:removeActionEvent(self.flashlightBlockerId); self.flashlightBlockerId = nil end
    if g_localPlayer and g_localPlayer.inputComponent then g_localPlayer.inputComponent.locked = false end
    g_inputBinding:revertContext(true)
    local evt = RI_CallEvent.new("ring", myUserId, toUserId, myName, "")
    if g_server ~= nil then g_server:broadcastEvent(evt) elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end
    if self.ringbackSample and self.ringbackSample ~= 0 then playSample(self.ringbackSample, 0, 1.0, 1.0, 0, 0) end
    print(string.format("[RoleplayPhone] Calling userId %d (%s)...", toUserId, c.name or "?"))
end

function RoleplayPhone:onIncomingCall(fromUserId, callerName, callerNum)
    if self.state == self.STATE.CALL_OUTGOING or self.state == self.STATE.CALL_INCOMING or self.state == self.STATE.CALL_ACTIVE then
        local myUserId = self:getMyUserId()
        local evt = RI_CallEvent.new("decline", myUserId, fromUserId, "", "")
        if g_server ~= nil then g_server:broadcastEvent(evt) elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end
        return
    end
    -- Display name: saved contact only — unknown callers show their number
    local displayName = callerNum ~= "" and callerNum or g_i18n:getText("phone_unknown_contact")
    for _, c in ipairs(ContactManager.contacts) do
        if c.playerUserId and c.playerUserId == fromUserId then
            displayName = c.name or displayName; break
        end
    end
    self.call.contactName = displayName; self.call.contactNum = callerNum
    self.call.fromUserId = fromUserId; self.call.toUserId = self:getMyUserId()
    self.call.startTime = 0; self.call.prevState = self.state
    self.state = self.STATE.CALL_INCOMING; self.callRingTimer = 0
    self:addCallHistoryEntry("incoming", self.call.contactName, callerNum or "")
    if self.ringSample and self.ringSample ~= 0 then playSample(self.ringSample, 0, 1.0, 0, 0, 0) end
    print(string.format("[RoleplayPhone] Incoming call from %s", callerName))
end

function RoleplayPhone:answerCall()
    self:stopRingtone()
    self.call.startTime = g_currentMission and g_currentMission.time or 0
    self.state = self.STATE.CALL_ACTIVE
    local myUserId = self:getMyUserId()
    local evt = RI_CallEvent.new("answer", myUserId, self.call.fromUserId, "", "")
    if g_server ~= nil then g_server:broadcastEvent(evt) elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end
end

function RoleplayPhone:onCallAnswered()
    self:stopRingtone()
    self.call.startTime = g_currentMission and g_currentMission.time or 0
    self.state = self.STATE.CALL_ACTIVE
end

function RoleplayPhone:onCallDeclined()
    self:stopRingtone()
    NotificationManager:push("rejected", g_i18n:getText("phone_notif_call_declined"))
    self:_restoreAfterCall()
end

function RoleplayPhone:onCallEnded()
    self:stopRingtone()
    if self.state == self.STATE.CALL_INCOMING then
        local name = self.call.contactName or g_i18n:getText("phone_unknown_contact")
        NotificationManager:push("info", string.format(g_i18n:getText("phone_notif_missed_call"), name))
        self:addCallHistoryEntry("missed", name, self.call.contactNum or "")
    end
    self:_restoreAfterCall()
end

function RoleplayPhone:endCall()
    self:stopRingtone()
    local myUserId = self:getMyUserId()
    local remoteUser = (self.call.fromUserId == myUserId) and self.call.toUserId or self.call.fromUserId
    local evtType = (self.state == self.STATE.CALL_INCOMING) and "decline" or "end"
    local evt = RI_CallEvent.new(evtType, myUserId, remoteUser, "", "")
    if g_server ~= nil then g_server:broadcastEvent(evt) elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end
    self:_restoreAfterCall()
end

function RoleplayPhone:_restoreAfterCall()
    local prevState = self.call.prevState or self.STATE.HOME
    self:stopRingtone()
    self.call = { prevState=self.STATE.HOME, startTime=0, fromUserId=0, toUserId=0, contactName="", contactNum="" }
    if prevState == self.STATE.CLOSED or not self.isOpen then
        if self.isOpen then
            if self.phoneContextEventId then g_inputBinding:removeActionEvent(self.phoneContextEventId); self.phoneContextEventId = nil end
            if self.flashlightBlockerId then g_inputBinding:removeActionEvent(self.flashlightBlockerId); self.flashlightBlockerId = nil end
            if self.incomingCallActionEventId then g_inputBinding:removeActionEvent(self.incomingCallActionEventId); self.incomingCallActionEventId = nil end
            if g_localPlayer and g_localPlayer.inputComponent then g_localPlayer.inputComponent.locked = false end
            g_inputBinding:revertContext(true); g_inputBinding:setShowMouseCursor(false)
        end
        self.state = self.STATE.CLOSED; self.isOpen = false
    else
        self.state = prevState
    end
end

function RoleplayPhone:stopRingtone()
    if self.ringSample       and self.ringSample       ~= 0 then stopSample(self.ringSample, 0, 0) end
    if self.ringbackSample   and self.ringbackSample   ~= 0 then stopSample(self.ringbackSample, 0, 0) end
    if self.unavailableSample and self.unavailableSample ~= 0 then stopSample(self.unavailableSample, 0, 0) end
end

-- ─── CALL BY PHONE NUMBER ────────────────────────────────────────────────────
-- Used by the Keypad tab and Recents call-back button.
-- Looks up the target player in onlineUsers by phone number, then proceeds
-- identically to startCall().
function RoleplayPhone:startCallByPhone(phoneNum)
    if not phoneNum or phoneNum == "" then return end

    -- Find userId matching this phone number (onlineUsers only used for routing)
    local toUserId = 0
    for uid, info in pairs(self.onlineUsers) do
        if info.phone == phoneNum then toUserId = uid; break end
    end

    -- Display name: saved contact only — unknown callers show their number
    local callerName = phoneNum
    for _, c in ipairs(ContactManager.contacts) do
        if c.phone == phoneNum then
            callerName = c.name or phoneNum; break
        end
    end

    if toUserId == 0 then
        if self.unavailableSample and self.unavailableSample ~= 0 then
            playSample(self.unavailableSample, 1, 1.0, 1.0, 0, 0)
        end
        NotificationManager:push("rejected",
            g_i18n:getText("phone_notif_cant_reach_number"))
        return
    end

    if g_server ~= nil and not self:isUserOnline(toUserId) then
        if self.unavailableSample and self.unavailableSample ~= 0 then
            playSample(self.unavailableSample, 1, 1.0, 1.0, 0, 0)
        end
        NotificationManager:push("rejected",
            string.format(g_i18n:getText("phone_notif_cant_reach"), callerName))
        return
    end

    local myUserId = self:getMyUserId()
    local myName   = (g_currentMission and g_currentMission.playerNickname)
                     or self:getFarmName(self:getMyFarmId())

    self.call.contactName = callerName
    self.call.contactNum  = phoneNum
    self.call.toUserId    = toUserId
    self.call.fromUserId  = myUserId
    self.call.startTime   = 0
    self.call.prevState   = self.STATE.CLOSED
    self.state            = self.STATE.CALL_OUTGOING
    self.callRingTimer    = 0

    self:addCallHistoryEntry("outgoing", callerName, phoneNum)

    self.isOpen = false
    g_inputBinding:setShowMouseCursor(false)
    if self.phoneContextEventId then
        g_inputBinding:removeActionEvent(self.phoneContextEventId)
        self.phoneContextEventId = nil
    end
    if self.flashlightBlockerId then
        g_inputBinding:removeActionEvent(self.flashlightBlockerId)
        self.flashlightBlockerId = nil
    end
    if g_localPlayer and g_localPlayer.inputComponent then
        g_localPlayer.inputComponent.locked = false
    end
    g_inputBinding:revertContext(true)

    local evt = RI_CallEvent.new("ring", myUserId, toUserId, myName, "")
    if g_server ~= nil then g_server:broadcastEvent(evt)
    elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end

    if self.ringbackSample and self.ringbackSample ~= 0 then
        playSample(self.ringbackSample, 0, 1.0, 1.0, 0, 0)
    end
    print(string.format("[RoleplayPhone] Calling by number %s -> userId %d (%s)",
        phoneNum, toUserId, callerName))
end
