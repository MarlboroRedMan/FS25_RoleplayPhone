-- MessageManager.lua
-- Handles in-game messaging: send, receive, contact card, and thread migration.
-- Extracted from RoleplayPhone.lua — all methods extend the RoleplayPhone table.

-- ─── Message handling ─────────────────────────────────────────────────────────
function RoleplayPhone:receiveMessage(contactKey, fromUserId, senderName, text, gameDay, sent, gameTime, msgType, cardName, cardPhone, cardFarm)
    if not self.messages[contactKey] then self.messages[contactKey] = {} end
    table.insert(self.messages[contactKey], {
        fromUserId = fromUserId, senderName = senderName,
        text = text, gameDay = gameDay or 0, gameTime = gameTime or 0, sent = sent or false,
        msgType = msgType or "text", cardName = cardName or "", cardPhone = cardPhone or "", cardFarm = cardFarm or "",
    })
    self._threadsDirty = true
    if sent then return end
    if self.isSyncing then return end  -- historical sync, no notification
    local viewing = ((self.state == self.STATE.CONTACT_DETAIL or self.state == self.STATE.MESSAGE_THREAD)
                     and self.selectedContact == contactKey)
    if not viewing then
        local displayName = senderName
        for _, c in ipairs(ContactManager.contacts) do
            if c.farmName and string.lower(c.farmName) == string.lower(senderName) then
                displayName = c.name or senderName; break
            end
        end
        self.unreadMessages[contactKey] = (self.unreadMessages[contactKey] or 0) + 1
        if self.notifSample and self.notifSample ~= 0 then
            playSample(self.notifSample, 1, 1.0, 1.0, 0, 0)
        end
        local notifText = (msgType == "contact_card") and g_i18n:getText("msg_contact_card_preview") or text
        NotificationManager:push("ping",
            string.format(g_i18n:getText("phone_notif_msg_from"), displayName, notifText))
    end
end

-- When a contact is saved (added or edited), migrate any existing u_ keyed message thread
-- that matches the contact's phone to the proper contact index key.
function RoleplayPhone:migrateThreadToContact(contactIndex, phone)
    if not phone or phone == "" then return end
    local keysToRemove = {}
    for key, _ in pairs(self.messages) do
        if type(key) == "string" and key:sub(1, 2) == "u_" then
            local info = self.messageDisplayNames[key]
            if info and info.phone == phone then
                table.insert(keysToRemove, key)
            end
        end
    end
    for _, oldKey in ipairs(keysToRemove) do
        -- Merge old messages into contact index thread
        if not self.messages[contactIndex] then self.messages[contactIndex] = {} end
        for _, msg in ipairs(self.messages[oldKey]) do
            table.insert(self.messages[contactIndex], msg)
        end
        -- Transfer unread count
        local pending = self.unreadMessages[oldKey] or 0
        self.unreadMessages[contactIndex] = (self.unreadMessages[contactIndex] or 0) + pending
        -- Remove old keys
        self.messages[oldKey]            = nil
        self.unreadMessages[oldKey]      = nil
        self.messageDisplayNames[oldKey] = nil
        print(string.format("[RoleplayPhone] Migrated thread %s -> contact %d (%s)", oldKey, contactIndex, phone))
    end
    if #keysToRemove > 0 then
        self._threadsDirty = true
    end
end

function RoleplayPhone:sendMessage()
    local text = self.messageCompose.text
    if not text or text == "" then return end
    if not self.selectedContact then return end

    local toUniqueId

    -- Unknown sender (not in contacts) — key is a string like "u_<uniqueId>"
    if type(self.selectedContact) == "string" then
        toUniqueId = self.selectedContact:sub(3)  -- strip "u_" prefix
        if not toUniqueId or toUniqueId == "" then return end
        local found = false
        for uid, u in pairs(RoleplayPhone.onlineUsers) do
            if u.uniqueId == toUniqueId then found = true; break end
        end
        if not found then return end
    else
        local c = ContactManager:getContact(self.selectedContact)
        if not c then return end
        for uid, u in pairs(RoleplayPhone.onlineUsers) do
            if u.phone and u.phone == c.phone then
                toUniqueId = u.uniqueId; break
            end
        end
        if not toUniqueId or toUniqueId == "" then
            NotificationManager:push("rejected",
                string.format(g_i18n:getText("phone_notif_farm_not_found"), c.name or c.farmName or "?"))
            return
        end
    end

    local myUniqueId = self:getMyUniqueId()
    local myUserId   = self:getMyUserId()
    local myName     = (g_currentMission and g_currentMission.playerNickname) or self:getFarmName(self:getMyFarmId())
    local gameDay  = (g_currentMission and g_currentMission.environment
                      and g_currentMission.environment.currentDay) or 0
    local gameTime = (g_currentMission and g_currentMission.environment
                      and g_currentMission.environment.dayTime) or 0
    self:receiveMessage(self.selectedContact, myUserId, myName, text, gameDay, true, gameTime)
    local evt = RI_MessageEvent.new(myUniqueId, toUniqueId, myName, text, gameDay, gameTime)
    if g_server ~= nil then
        -- resolve toUserId from onlineUsers for listen server routing
        local toUserId = nil
        for uid, u in pairs(self.onlineUsers) do
            if u.uniqueId == toUniqueId then toUserId = uid; break end
        end
        local ps   = g_currentMission and g_currentMission.playerSystem
        local rp   = toUserId and ps and ps:getPlayerByUserId(toUserId)
        local conn = rp and rp.connection
        if conn then conn:sendEvent(evt) end

        -- Store host-sent message in recipient's server-side playerMessages so it syncs on reconnect
        if toUniqueId ~= "" then
            if not self.playerMessages[toUniqueId] then
                self.playerMessages[toUniqueId] = {}
            end
            local key = "in_" .. myUniqueId
            if not self.playerMessages[toUniqueId][key] then
                self.playerMessages[toUniqueId][key] = {}
            end
            table.insert(self.playerMessages[toUniqueId][key], {
                fromUniqueId = myUniqueId,
                senderName   = myName,
                text         = text,
                gameDay      = gameDay,
                gameTime     = gameTime,
                sent         = false,
            })
        end
    elseif g_client ~= nil then
        g_client:getServerConnection():sendEvent(evt)
    end
    self.messageCompose.text = ""
end

function RoleplayPhone:sendContactCard()
    if not self.selectedContact then return end

    local toUniqueId
    if type(self.selectedContact) == "string" then
        toUniqueId = self.selectedContact:sub(3)  -- strip "u_" prefix
        if not toUniqueId or toUniqueId == "" then return end
        local found = false
        for uid, u in pairs(RoleplayPhone.onlineUsers) do
            if u.uniqueId == toUniqueId then found = true; break end
        end
        if not found then return end
    else
        local c = ContactManager:getContact(self.selectedContact)
        if not c then return end
        for uid, u in pairs(RoleplayPhone.onlineUsers) do
            if u.phone and u.phone == c.phone then
                toUniqueId = u.uniqueId; break
            end
        end
        if not toUniqueId or toUniqueId == "" then return end
    end

    local myUniqueId = self:getMyUniqueId()
    local myUserId   = self:getMyUserId()
    local myName     = (g_currentMission and g_currentMission.playerNickname) or ""
    local myPhone    = self:hashPhone(myUserId)
    local gameDay   = (g_currentMission and g_currentMission.environment and g_currentMission.environment.currentDay) or 0
    local gameTime  = (g_currentMission and g_currentMission.environment and g_currentMission.environment.dayTime) or 0

    self:receiveMessage(self.selectedContact, myUserId, myName, "", gameDay, true, gameTime,
                        "contact_card", myName, myPhone, "")

    local evt = RI_MessageEvent.new(myUniqueId, toUniqueId, myName, "", gameDay, gameTime,
                                    "contact_card", myName, myPhone, "")
    if g_server ~= nil then
        local toUserId = nil
        for uid, u in pairs(self.onlineUsers) do
            if u.uniqueId == toUniqueId then toUserId = uid; break end
        end
        local ps   = g_currentMission and g_currentMission.playerSystem
        local rp   = toUserId and ps and ps:getPlayerByUserId(toUserId)
        local conn = rp and rp.connection
        if conn then conn:sendEvent(evt) end

        -- Store contact card in recipient's server-side playerMessages so it syncs on reconnect
        if toUniqueId ~= "" then
            if not self.playerMessages[toUniqueId] then
                self.playerMessages[toUniqueId] = {}
            end
            local key = "in_" .. myUniqueId
            if not self.playerMessages[toUniqueId][key] then
                self.playerMessages[toUniqueId][key] = {}
            end
            table.insert(self.playerMessages[toUniqueId][key], {
                fromUniqueId = myUniqueId,
                senderName   = myName,
                text         = "",
                gameDay      = gameDay,
                gameTime     = gameTime,
                sent         = false,
                msgType      = "contact_card",
                cardName     = myName,
                cardPhone    = myPhone,
                cardFarm     = "",
            })
        end
    elseif g_client ~= nil then
        g_client:getServerConnection():sendEvent(evt)
    end
end
