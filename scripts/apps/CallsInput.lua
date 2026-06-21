-- scripts/apps/CallsInput.lua
-- Input handler for the Calls app: tab bar, keypad, recents, call buttons.
-- Called from PhoneInput:onHitboxClicked(). Returns true if the event was consumed.

function RoleplayPhone:handleCallsInput(hb)

    -- Tab bar
    if hb.id == "calls_tab_keypad"   then self.callsTab = "keypad";   return true end
    if hb.id == "calls_tab_recents"  then self.callsTab = "recents";  return true end
    if hb.id == "calls_tab_contacts" then self.callsTab = "contacts"; return true end

    -- Keypad DEL button
    if hb.id == "keypad_del" then
        local n = self.keypadNumber or ""
        if #n > 0 then self.keypadNumber = n:sub(1, #n - 1) end
        return true
    end

    -- Keypad Call button
    if hb.id == "keypad_call" then
        local raw = self.keypadNumber or ""
        if raw ~= "" then
            local formatted = self:formatPhoneDisplay(raw)
            self:startCallByPhone(formatted)
            self.keypadNumber       = ""
            self.dialerFromMessages = false
        end
        return true
    end

    -- Keypad Message button (visible only when dialerFromMessages = true)
    if hb.id == "keypad_message" then
        local raw = self.keypadNumber or ""
        if raw ~= "" then
            local formatted = self:formatPhoneDisplay(raw)
            local _, idx    = self:getContactByPhone(formatted)
            local threadKey
            if idx then
                threadKey = idx
            else
                for _, user in pairs(self.onlineUsers) do
                    if user.phone == formatted then
                        threadKey = "u_" .. (user.uniqueId or "")
                        self.messageDisplayNames[threadKey] = {
                            name  = user.name  or formatted,
                            phone = formatted,
                        }
                        break
                    end
                end
            end
            if threadKey then
                self.selectedContact         = threadKey
                self.keypadNumber            = ""
                self.dialerFromMessages      = false
                self.messageCompose.text     = ""
                self.messageCompose.active   = false
                self.messageScrollOffset     = 0
                self.state                   = self.STATE.MESSAGE_THREAD
            else
                NotificationManager:push("rejected", g_i18n:getText("phone_notif_cant_reach_number"))
            end
        end
        return true
    end

    -- Keypad digit buttons (star/hash ignored — hashPhone is digits only)
    if hb.id:sub(1, 7) == "keypad_" then
        local key = hb.id:sub(8)
        if key ~= "star" and key ~= "hash" then
            if #(self.keypadNumber or "") < self:getMaxKeypadDigits() then
                self.keypadNumber = (self.keypadNumber or "") .. key
            end
        end
        return true
    end

    -- Recents: call-back button
    if hb.id == "recents_callback" and hb.data and hb.data.phone then
        self:startCallByPhone(hb.data.phone)
        return true
    end

    -- Recents: message button → open thread for this entry's phone
    if hb.id == "recents_message" and hb.data and hb.data.phone then
        local phone     = hb.data.phone
        local _, idx    = self:getContactByPhone(phone)
        local threadKey
        if idx then
            threadKey = idx
        else
            for _, user in pairs(self.onlineUsers) do
                if user.phone == phone then
                    threadKey = "u_" .. (user.uniqueId or "")
                    self.messageDisplayNames[threadKey] = {
                        name  = hb.data.name or user.name or phone,
                        phone = phone,
                    }
                    break
                end
            end
        end
        if threadKey then
            self.selectedContact       = threadKey
            self.messageCompose.text   = ""
            self.messageCompose.active = false
            self.messageScrollOffset   = 0
            self.state                 = self.STATE.MESSAGE_THREAD
        end
        return true
    end

    -- Recents: clear all history
    if hb.id == "recents_clear_all" then
        self.callHistory = {}
        if g_server ~= nil then
            -- Host: clear in-memory store and save directly
            local uniqueId = self:getMyUniqueId()
            local nickname = (g_currentMission and g_currentMission.playerNickname) or "host"
            local entry    = self:getOrCreateRegistryEntry(uniqueId, self:hashPhone(self:getMyUserId()))
            self:savePlayerData(
                self:buildPlayerFilename(nickname, entry.fileId),
                ContactManager.contacts, self.messages, self.callHistory)
        else
            -- Client: tell host to clear the saved history so it doesn't restore on reconnect
            g_client:getServerConnection():sendEvent(
                RI_ClearRecentsEvent.new(self:getMyUserId()))
        end
        return true
    end

    -- Contacts tab: Call button next to a contact
    if hb.id == "calls_contact_call" and hb.data and hb.data.index then
        self.selectedContact = hb.data.index
        self:startCall()
        return true
    end

    -- Answer / end active call
    if hb.id == "btn_answer"   then print("[RoleplayPhone] btn_answer clicked"); self:answerCall(); return true end
    if hb.id == "btn_end_call" then print("[RoleplayPhone] btn_end_call clicked"); self:endCall();    return true end

    -- Generic Call button — from contact detail or message thread → startCall,
    -- from anywhere else → open Calls app on keypad tab.
    if hb.id == "btn_call" then
        if (self.state == self.STATE.CONTACT_DETAIL or self.state == self.STATE.MESSAGE_THREAD)
           and self.selectedContact then
            self:startCall()
        else
            self.state    = self.STATE.CALLS
            self.callsTab = "keypad"
        end
        return true
    end

end
