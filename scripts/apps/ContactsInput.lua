-- scripts/apps/ContactsInput.lua
-- Input handler for the Contacts app: list, detail, create/edit/delete.
-- Called from PhoneInput:onHitboxClicked(). Returns true if the event was consumed.

function RoleplayPhone:handleContactsInput(hb)

    -- Contacts list: tap a row → open detail
    if hb.id == "contact_row" and hb.data and hb.data.index then
        self.selectedContact      = hb.data.index
        self.unreadMessages[hb.data.index] = 0
        self.messageCompose.text   = ""
        self.messageCompose.active = false
        self.state = self.STATE.CONTACT_DETAIL
        return true
    end

    -- Contacts list: Add new contact button
    if hb.id == "btn_add_contact" then
        self:resetContactForm()
        self.state = self.STATE.CONTACT_CREATE
        return true
    end

    -- Contact detail: Message button → open thread with this contact
    if hb.id == "btn_message_contact" then
        self.messageScrollOffset   = 0
        self.state = self.STATE.MESSAGE_THREAD
        return true
    end

    -- Contact detail: Edit button
    if hb.id == "btn_edit_contact" then
        local idx = self.selectedContact
        local c   = idx and ContactManager:getContact(idx)
        if c then
            self:resetContactForm()
            self.contactForm.name  = c.name  or ""
            self.contactForm.phone = c.phone or ""
            self.contactForm.role  = c.role  or ""
            self.contactForm.notes = c.notes or ""
            self.editingContactIndex = idx
            self.state = self.STATE.CONTACT_CREATE
        end
        return true
    end

    -- Contact detail: Delete button
    if hb.id == "btn_delete_contact" then
        if self.selectedContact then
            local idx = self.selectedContact
            local c   = ContactManager:getContact(idx)
            if c then
                if g_server == nil then
                    g_client:getServerConnection():sendEvent(
                        RI_ContactEvent.new("delete", self:getMyUserId(), c.uid, {}))
                end
                ContactManager:removeContact(idx)
            end
            self.selectedContact = nil
            if g_server ~= nil then
                local uniqueId = self:getMyUniqueId()
                local nickname = (g_currentMission and g_currentMission.playerNickname) or "host"
                local entry    = self:getOrCreateRegistryEntry(uniqueId, self:hashPhone(self:getMyUserId()))
                self:savePlayerData(
                    self:buildPlayerFilename(nickname, entry.fileId),
                    ContactManager.contacts, self.messages, self.callHistory)
            end
        end
        self.state = self.STATE.CONTACTS
        return true
    end

    -- Contact create/edit: field focus
    if hb.id == "cf_name"  then self.contactForm.activeField = "name";  self:placeCursorAtX(self.contactForm.name  or "", hb.x + 0.004, 0.012, self.mouseX); return true end
    if hb.id == "cf_phone" then self.contactForm.activeField = "phone"; self:activateFieldCursor(self.contactForm.phone or ""); return true end
    if hb.id == "cf_role"  then self.contactForm.activeField = "role";  self:placeCursorAtX(self.contactForm.role  or "", hb.x + 0.004, 0.012, self.mouseX); return true end
    if hb.id == "cf_notes" then self.contactForm.activeField = "notes"; self:activateFieldCursor(self.contactForm.notes or ""); return true end

    -- Contact create/edit: Save button
    if hb.id == "btn_save_contact" then
        local f = self.contactForm
        if f.name and f.name ~= "" then
            local editIdx = self.editingContactIndex
            if editIdx then
                -- Edit existing — update local entry and send uid-keyed event to host
                local c = ContactManager:getContact(editIdx)
                if c then
                    c.name  = f.name
                    c.phone = f.phone
                    c.role  = f.role
                    c.notes = f.notes
                    if g_server == nil then
                        g_client:getServerConnection():sendEvent(
                            RI_ContactEvent.new("update", self:getMyUserId(), c.uid,
                                { uid=c.uid, name=f.name, phone=f.phone, role=f.role, notes=f.notes }))
                    end
                end
                self.editingContactIndex = nil
            else
                -- New contact — generate uid client-side so host stores same uid
                local newUid = ContactManager:generateUid()
                local data   = { uid=newUid, name=f.name, phone=f.phone, role=f.role, notes=f.notes }
                ContactManager:addContact(data)
                if g_server == nil then
                    g_client:getServerConnection():sendEvent(
                        RI_ContactEvent.new("add", self:getMyUserId(), "", data))
                end
            end
            -- Migrate any u_ keyed message thread to the new contact index
            local newIdx = editIdx or #ContactManager.contacts
            if f.phone and f.phone ~= "" then
                self:migrateThreadToContact(newIdx, f.phone)
            end
            -- Persist on host
            if g_server ~= nil then
                local uniqueId = self:getMyUniqueId()
                local nickname = (g_currentMission and g_currentMission.playerNickname) or "host"
                local entry    = self:getOrCreateRegistryEntry(uniqueId, self:hashPhone(self:getMyUserId()))
                self:savePlayerData(
                    self:buildPlayerFilename(nickname, entry.fileId),
                    ContactManager.contacts, self.messages, self.callHistory)
            end
        end
        self.contactForm.activeField = nil
        self.state = self.STATE.CONTACTS
        return true
    end

    -- Messages list: "Add unknown contact" button (shown when thread key is a u_ string)
    if hb.id == "btn_add_unknown_contact" and type(self.selectedContact) == "string" then
        local info = self.messageDisplayNames[self.selectedContact]
        if info then
            self:resetContactForm()
            self.contactForm.name  = info.name  or ""
            self.contactForm.phone = info.phone or ""
            self.state = self.STATE.CONTACT_CREATE
        end
        return true
    end

end
