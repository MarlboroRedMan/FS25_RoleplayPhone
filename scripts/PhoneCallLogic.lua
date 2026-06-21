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

    -- Host: mirror this entry into the other party's playerCalls so it syncs on their reconnect.
    -- Only mirror incoming/outgoing — NOT missed.
    -- Missed is only meaningful for the recipient and is already handled:
    --   • Client recipient: updateCallTimeout direct insert + "missed" event to host
    --   • Host recipient: direct table.insert in updateCallTimeout
    -- Mirroring "missed" to the caller would add a spurious missed entry to someone
    -- who actually initiated the call.
    if g_server ~= nil and phone and phone ~= "" and direction ~= "missed" then
        local otherUniqueId = nil
        for _, info in pairs(self.onlineUsers) do
            if info.phone == phone and info.uniqueId and info.uniqueId ~= "" then
                otherUniqueId = info.uniqueId; break
            end
        end
        if otherUniqueId then
            if not self.playerCalls[otherUniqueId] then
                self.playerCalls[otherUniqueId] = {}
            end
            -- Mirror direction from the other party's perspective
            local mirrorDir = (direction == "incoming") and "outgoing" or "incoming"
            local myName = (g_currentMission and g_currentMission.playerNickname) or ""
            local myPhone = self:hashPhone(self:getMyUserId())
            local otherTop = self.playerCalls[otherUniqueId][1]
            if otherTop and otherTop.phone == myPhone and otherTop.direction == mirrorDir then
                otherTop.count    = (otherTop.count or 1) + 1
                otherTop.gameDay  = gameDay
                otherTop.gameTime = gameTime
            else
                table.insert(self.playerCalls[otherUniqueId], 1, {
                    direction = mirrorDir,
                    name      = myName,
                    phone     = myPhone,
                    gameDay   = gameDay,
                    gameTime  = gameTime,
                    count     = 1,
                })
            end
        end
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
    self.call.wasOpen = self.isOpen
    if self.isOpen then
        if self.phoneContextEventId then g_inputBinding:removeActionEvent(self.phoneContextEventId); self.phoneContextEventId = nil end
        if self.flashlightBlockerId then g_inputBinding:removeActionEvent(self.flashlightBlockerId); self.flashlightBlockerId = nil end
        if g_localPlayer and g_localPlayer.inputComponent then g_localPlayer.inputComponent.locked = false end
        g_inputBinding:revertContext(true)
        g_inputBinding:setShowMouseCursor(false)
        self.isOpen = false
    end
    local myPhone = self:hashPhone(myUserId)
    local evt = RI_CallEvent.new("ring", myUserId, toUserId, myName, myPhone)
    if g_server ~= nil then g_server:broadcastEvent(evt) elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end
    if self.ringbackSample and self.ringbackSample ~= 0 then playSample(self.ringbackSample, 0, 1.0, 1.0, 0, 0) end
    print(string.format("[RoleplayPhone] Calling userId %d (%s)...", toUserId, c.name or "?"))
end

function RoleplayPhone:onIncomingCall(fromUserId, callerName, callerNum)
    -- Already in a call: queue as call waiting (but only one waiting call at a time)
    if self.state == self.STATE.CALL_ACTIVE and self.pendingIncoming == nil then
        local displayName = callerNum ~= "" and callerNum or g_i18n:getText("phone_unknown_contact")
        for _, c in ipairs(ContactManager.contacts) do
            if c.phone and c.phone ~= "" and c.phone == callerNum then
                displayName = c.name or displayName; break
            end
        end
        self.pendingIncoming = {
            fromUserId  = fromUserId,
            contactName = displayName,
            contactNum  = callerNum,
            ringTimer   = 0,
        }
        if self.ringSample and self.ringSample ~= 0 then playSample(self.ringSample, 0, 1.0, 0, 0, 0) end
        print(string.format("[RoleplayPhone] Call waiting: incoming from %s", displayName))
        return
    end
    -- Busy: already handling a call (outgoing, incoming, or already have a waiting call)
    if self.state == self.STATE.CALL_OUTGOING or self.state == self.STATE.CALL_INCOMING
       or self.state == self.STATE.CALL_ACTIVE then
        local myUserId = self:getMyUserId()
        local evt = RI_CallEvent.new("busy", myUserId, fromUserId, "", "")
        if g_server ~= nil then g_server:broadcastEvent(evt) elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end
        return
    end
    -- Display name: match by phone number first, then fall back to number
    local displayName = callerNum ~= "" and callerNum or g_i18n:getText("phone_unknown_contact")
    for _, c in ipairs(ContactManager.contacts) do
        if c.phone and c.phone ~= "" and c.phone == callerNum then
            displayName = c.name or displayName; break
        end
    end
    self.call.contactName = displayName; self.call.contactNum = callerNum
    self.call.fromUserId = fromUserId; self.call.toUserId = self:getMyUserId()
    self.call.startTime = 0; self.call.prevState = self.state
    self.state = self.STATE.CALL_INCOMING; self.callRingTimer = 0
    -- If phone is already open, RI_CALL_ACTION is blocked by RI_PHONE_UI context —
    -- register it inside that context so F8 can answer/decline the call
    if self.isOpen then
        g_inputBinding:beginActionEventsModification("RI_PHONE_UI")
        local _, evtId = g_inputBinding:registerActionEvent(
            "RI_CALL_ACTION", RoleplayPhone, RoleplayPhone.callAction,
            false, true, false, true)
        self.incomingCallActionEventId = evtId
        local _, decEvtId = g_inputBinding:registerActionEvent(
            "RI_DECLINE_ACTION", RoleplayPhone, RoleplayPhone.declineAction,
            false, true, false, true)
        self.incomingDeclineActionEventId = decEvtId
        g_inputBinding:endActionEventsModification()
    end
    self:addCallHistoryEntry("incoming", self.call.contactName, callerNum or "")
    if self.ringSample and self.ringSample ~= 0 then playSample(self.ringSample, 0, 1.0, 0, 0, 0) end
    print(string.format("[RoleplayPhone] Incoming call from %s", callerName))
end

function RoleplayPhone:answerCall()
    self:stopRingtone()
    -- Track whether phone was open so _restoreAfterCall can reopen it after hang-up
    self.call.wasOpen = self.isOpen
    -- If phone was open when call came in, close it so movement is restored during the call
    if self.isOpen then
        if self.phoneContextEventId then g_inputBinding:removeActionEvent(self.phoneContextEventId); self.phoneContextEventId = nil end
        if self.flashlightBlockerId then g_inputBinding:removeActionEvent(self.flashlightBlockerId); self.flashlightBlockerId = nil end
        if self.incomingCallActionEventId then g_inputBinding:removeActionEvent(self.incomingCallActionEventId); self.incomingCallActionEventId = nil end
        if self.incomingDeclineActionEventId then g_inputBinding:removeActionEvent(self.incomingDeclineActionEventId); self.incomingDeclineActionEventId = nil end
        if g_localPlayer and g_localPlayer.inputComponent then g_localPlayer.inputComponent.locked = false end
        g_inputBinding:revertContext(true)
        g_inputBinding:setShowMouseCursor(false)
        self.isOpen = false
    end
    self.call.startTime = g_currentMission and g_currentMission.time or 0
    self.state = self.STATE.CALL_ACTIVE
    local myUserId = self:getMyUserId()
    local evt = RI_CallEvent.new("answer", myUserId, self.call.fromUserId, "", "")
    if g_server ~= nil then g_server:broadcastEvent(evt) elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end
    -- Add to active calls — server relay in RI_CallEvent will broadcast to bystanders
    self:addActiveCall(self.call.fromUserId, myUserId)
end

function RoleplayPhone:onCallAnswered()
    self:stopRingtone()
    self.call.startTime = g_currentMission and g_currentMission.time or 0
    self.state = self.STATE.CALL_ACTIVE
    -- Add to active calls — server already broadcast RI_VoiceCallEvent to bystanders
    self:addActiveCall(self.call.fromUserId, self.call.toUserId)
end

function RoleplayPhone:onCallDeclined()
    self:stopRingtone()
    NotificationManager:push("rejected", g_i18n:getText("phone_notif_call_declined"))
    self:_restoreAfterCall()
end

function RoleplayPhone:onCallBusy()
    self:stopRingtone()
    -- Use contact name if known, otherwise show generic "Person" — don't expose player
    -- usernames to callers who don't have them saved as a contact.
    local name = (self.call.contactName ~= "" and self.call.contactName ~= self.call.contactNum)
                 and self.call.contactName
                 or g_i18n:getText("phone_unknown_contact")
    NotificationManager:push("rejected", string.format(g_i18n:getText("phone_notif_call_busy"), name))
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
    -- Remove from active calls. If host, broadcast updated snapshot to all clients so
    -- bystanders recompute isolation. If client, the server handles this via RI_CallEvent handler.
    local myUserId = self:getMyUserId()
    self:removeActiveCall(myUserId)
    if g_server ~= nil then
        g_server:broadcastEvent(RI_VoiceCallEvent.new(self.activeCalls))
    end
    local wasOpen = self.call.wasOpen or false
    self.call = { prevState=self.STATE.HOME, startTime=0, fromUserId=0, toUserId=0, contactName="", contactNum="", wasOpen=false, members={} }
    if prevState ~= self.STATE.CLOSED and self.isOpen then
        -- Decline case: phone stayed open throughout — just restore state
        if self.incomingCallActionEventId then
            g_inputBinding:removeActionEvent(self.incomingCallActionEventId)
            self.incomingCallActionEventId = nil
        end
        if self.incomingDeclineActionEventId then
            g_inputBinding:removeActionEvent(self.incomingDeclineActionEventId)
            self.incomingDeclineActionEventId = nil
        end
        self.state = prevState
    elseif prevState ~= self.STATE.CLOSED and wasOpen then
        -- Answered call: phone was open before call, reopen it to previous state
        self.state  = prevState
        self.isOpen = true
        g_inputBinding:setShowMouseCursor(true)
        if g_localPlayer and g_localPlayer.inputComponent then
            g_localPlayer.inputComponent.locked = true
        end
        g_inputBinding:setContext("RI_PHONE_UI", true, false)
        g_inputBinding:beginActionEventsModification("RI_PHONE_UI")
        local _, evtId = g_inputBinding:registerActionEvent(
            "RI_OPEN_PHONE", RoleplayPhone, RoleplayPhone.toggle, false, true, false, true)
        self.phoneContextEventId = evtId
        if evtId then
            g_inputBinding:setActionEventText(evtId, g_i18n:getText("input_RI_OPEN_PHONE"))
        end
        local _noop = function() end
        local _, flashBlockId = g_inputBinding:registerActionEvent(
            "TOGGLE_LIGHTS_FPS", RoleplayPhone, _noop, false, true, false, true)
        self.flashlightBlockerId = flashBlockId
        g_inputBinding:endActionEventsModification()
    else
        -- Phone was closed before call or prevState was CLOSED — keep closed
        if self.isOpen then
            if self.phoneContextEventId then g_inputBinding:removeActionEvent(self.phoneContextEventId); self.phoneContextEventId = nil end
            if self.flashlightBlockerId then g_inputBinding:removeActionEvent(self.flashlightBlockerId); self.flashlightBlockerId = nil end
            if self.incomingCallActionEventId then g_inputBinding:removeActionEvent(self.incomingCallActionEventId); self.incomingCallActionEventId = nil end
            if self.incomingDeclineActionEventId then g_inputBinding:removeActionEvent(self.incomingDeclineActionEventId); self.incomingDeclineActionEventId = nil end
            if g_localPlayer and g_localPlayer.inputComponent then g_localPlayer.inputComponent.locked = false end
            g_inputBinding:revertContext(true); g_inputBinding:setShowMouseCursor(false)
        end
        self.state = self.STATE.CLOSED; self.isOpen = false
    end
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

    self.call.wasOpen = self.isOpen
    if self.isOpen then
        if self.phoneContextEventId then g_inputBinding:removeActionEvent(self.phoneContextEventId); self.phoneContextEventId = nil end
        if self.flashlightBlockerId then g_inputBinding:removeActionEvent(self.flashlightBlockerId); self.flashlightBlockerId = nil end
        if g_localPlayer and g_localPlayer.inputComponent then g_localPlayer.inputComponent.locked = false end
        g_inputBinding:revertContext(true)
        g_inputBinding:setShowMouseCursor(false)
        self.isOpen = false
    end

    local myPhone = self:hashPhone(myUserId)
    local evt = RI_CallEvent.new("ring", myUserId, toUserId, myName, myPhone)
    if g_server ~= nil then g_server:broadcastEvent(evt)
    elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end

    if self.ringbackSample and self.ringbackSample ~= 0 then
        playSample(self.ringbackSample, 0, 1.0, 1.0, 0, 0)
    end
    print(string.format("[RoleplayPhone] Calling by number %s -> userId %d (%s)",
        phoneNum, toUserId, callerName))
end

-- ─── CALL WAITING ─────────────────────────────────────────────────────────────

-- Answer the waiting call while staying in the current call.
-- The waiting caller joins the existing call group (group call begins).
-- Triggered by F10 when state == CALL_ACTIVE and pendingIncoming ~= nil.
function RoleplayPhone:answerWaiting()
    if not self.pendingIncoming then return end
    self:stopRingtone()
    local myUserId = self:getMyUserId()
    local fromId   = self.pendingIncoming.fromUserId

    if g_server ~= nil then
        -- Host: update group directly, then broadcast snapshot + answer event
        RoleplayPhone:addActiveCall(myUserId, fromId)
        g_server:broadcastEvent(RI_VoiceCallEvent.new(self.activeCalls))
        g_server:broadcastEvent(RI_CallEvent.new("answer", myUserId, fromId, "", ""))
    else
        -- Client: send answer to server; server handles group merge + broadcast
        g_client:getServerConnection():sendEvent(
            RI_CallEvent.new("answer", myUserId, fromId, "", ""))
    end

    -- Log a call history entry for the newly joined member
    self:addCallHistoryEntry("incoming", self.pendingIncoming.contactName, self.pendingIncoming.contactNum)
    self.pendingIncoming = nil
    print(string.format("[RoleplayPhone] Answered waiting call from userId %d — group call started", fromId))
end

-- Decline the waiting call, keeping the current call active.
-- Triggered by F9 when state == CALL_ACTIVE and pendingIncoming ~= nil.
function RoleplayPhone:declineWaiting()
    if not self.pendingIncoming then return end
    self:stopRingtone()
    local myUserId = self:getMyUserId()
    local fromId   = self.pendingIncoming.fromUserId
    local evt = RI_CallEvent.new("decline", myUserId, fromId, "", "")
    if g_server ~= nil then g_server:broadcastEvent(evt)
    elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end
    self.pendingIncoming = nil
    print(string.format("[RoleplayPhone] Declined waiting call from userId %d", fromId))
end
