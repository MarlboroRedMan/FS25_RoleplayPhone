-- scripts/apps/MessagesInput.lua
-- Input handler for the Messages app: thread list, compose, send, card share/save, delete.
-- Called from PhoneInput:onHitboxClicked(). Returns true if the event was consumed.

function RoleplayPhone:handleMessagesInput(hb)

    -- New Message button → open dialer with message mode flag
    if hb.id == "btn_new_message" then
        self.dialerFromMessages = true
        self.keypadNumber       = ""
        self.callsTab           = "keypad"
        self.state              = self.STATE.CALLS
        return true
    end

    -- Messages list: tap thread row → open thread
    if hb.id == "msg_thread_row" and hb.data and hb.data.index then
        self.selectedContact              = hb.data.index
        self.unreadMessages[hb.data.index] = 0
        self.messageCompose.text           = ""
        self.messageCompose.active         = false
        self.messageScrollOffset           = 0
        self.state = self.STATE.MESSAGE_THREAD
        return true
    end

    -- Message compose field: tap to focus
    if hb.id == "msg_field" then
        self.messageCompose.active = true
        self:activateFieldCursor(self.messageCompose.text or "")
        return true
    end

    -- Send message button
    if hb.id == "btn_send_message" then
        self:sendMessage()
        return true
    end

    -- Share own contact card into the current thread
    if hb.id == "btn_share_card" then
        self:sendContactCard()
        return true
    end

    -- Save a received contact card from a message bubble
    if hb.id == "btn_save_contact_card" then
        local name  = hb.data and hb.data.cardName  or ""
        local phone = hb.data and hb.data.cardPhone or ""
        local farm  = hb.data and hb.data.cardFarm  or ""
        if name ~= "" and phone ~= "" then
            local existing, _ = self:getContactByPhone(phone)
            if not existing then
                local newUid     = ContactManager:generateUid()
                local newContact = { uid=newUid, name=name, farmName=farm, phone=phone, notes="", role="" }
                ContactManager:addContact(newContact)
                local myUserId   = self:getMyUserId()
                local myUniqueId = self:getMyUniqueId()
                if g_server ~= nil then
                    ContactManager.userContacts[myUniqueId] = ContactManager.contacts
                    local entry    = self:getOrCreateRegistryEntry(myUniqueId, self:hashPhone(myUserId))
                    local filename = self:buildPlayerFilename(
                        (g_currentMission and g_currentMission.playerNickname) or "player",
                        entry.fileId)
                    self:savePlayerData(filename, ContactManager.contacts, self.messages, self.callHistory)
                elseif g_client ~= nil then
                    g_client:getServerConnection():sendEvent(
                        RI_ContactEvent.new("add", myUserId, newUid, newContact))
                end
                NotificationManager:push("info",
                    string.format(g_i18n:getText("contacts_saved_notif"), name))
            end
        end
        return true
    end

    -- Delete a message thread
    if hb.id == "msg_delete_thread" and hb.data then
        local idx = hb.data.index

        -- Resolve other party's phone before clearing (needed for server-side delete)
        local otherPhone = ""
        if type(idx) == "number" then
            local contact = ContactManager.contacts[idx]
            otherPhone = contact and contact.phone or ""
        elseif type(idx) == "string" then
            local info = self.messageDisplayNames[idx]
            otherPhone = info and info.phone or ""
        end

        -- Clear locally
        self.messages[idx]       = nil
        self.unreadMessages[idx] = nil
        if type(idx) == "string" then
            self.messageDisplayNames[idx] = nil
        end

        -- Persist
        if g_server ~= nil then
            local uniqueId = self:getMyUniqueId()
            local nickname = (g_currentMission and g_currentMission.playerNickname) or "host"
            local entry    = self:getOrCreateRegistryEntry(uniqueId, self:hashPhone(self:getMyUserId()))
            self:savePlayerData(
                self:buildPlayerFilename(nickname, entry.fileId),
                ContactManager.contacts, self.messages, self.callHistory)
        elseif g_client ~= nil and otherPhone ~= "" then
            g_client:getServerConnection():sendEvent(RI_DeleteThreadEvent.new(otherPhone))
        end
        return true
    end

end
