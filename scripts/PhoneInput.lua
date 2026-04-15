-- scripts/PhoneInput.lua
-- Mouse and keyboard input handling: mouseEvent, onHitboxClicked, keyEvent, handleBackspace.

function RoleplayPhone:mouseEvent(posX, posY, isDown, isUp, button)
    self.mouseX = posX
    self.mouseY = posY

    -- When phone is closed, let NotificationManager handle HUD icon dragging
    if self.state == self.STATE.CLOSED then
        NotificationManager:mouseEvent(posX, posY, isDown, isUp, button)
        return
    end

    -- Forward to NotificationManager from HOME — cursor is visible so icon can be dragged
    if self.state == self.STATE.HOME then
        local handled = NotificationManager:mouseEvent(posX, posY, isDown, isUp, button)
        if handled then return end
    end

    -- Scroll wheel on message thread
    if self.state == self.STATE.MESSAGE_THREAD then
        local msgs = self.selectedContact and (self.messages[self.selectedContact] or {}) or {}
        if button == Input.MOUSE_BUTTON_WHEEL_UP then
            self.messageScrollOffset = math.min(#msgs - 1, (self.messageScrollOffset or 0) + 1)
            return
        end
        if button == Input.MOUSE_BUTTON_WHEEL_DOWN then
            self.messageScrollOffset = math.max(0, (self.messageScrollOffset or 0) - 1)
            return
        end
    end

    -- Scroll wheel on create invoice form
    if self.state == self.STATE.INVOICE_CREATE then
        local scrollStep = 0.058
        local maxScroll  = scrollStep * 3
        if button == Input.MOUSE_BUTTON_WHEEL_UP then
            self.form.scrollOffset = math.max(0, self.form.scrollOffset - scrollStep)
            return
        end
        if button == Input.MOUSE_BUTTON_WHEEL_DOWN then
            self.form.scrollOffset = math.min(maxScroll, self.form.scrollOffset + scrollStep)
            return
        end
    end

    if not isDown or button ~= Input.MOUSE_BUTTON_LEFT then return end

    -- Check hitboxes
    for _, hb in ipairs(self.hitboxes) do
        if self:hitTest(posX, posY, hb.x, hb.y, hb.w, hb.h) then
            self:onHitboxClicked(hb)
            return true
        end
    end

    -- Click outside phone body closes it (HOME state only)
    if self.state == self.STATE.HOME then
        local p = self.PHONE
        if not self:hitTest(posX, posY, p.x-0.006, p.y-0.006, p.w+0.012, p.h+0.012) then
            self:close()
            return true
        end
    end
end

function RoleplayPhone:onHitboxClicked(hb)
    -- Page dot navigation
    if hb.id:sub(1,9) == "page_dot_" and hb.data and hb.data.page then
        self.homePage = hb.data.page; return
    end
    if hb.id == "page_prev" then self.homePage = math.max(1, self.homePage - 1); return end
    if hb.id == "page_next" then self.homePage = math.min(self.homePageCount, self.homePage + 1); return end

    -- Dock app clicks
    if hb.id:sub(1,5) == "dock_" and hb.data and hb.data.appId then
        local appId = hb.data.appId
        if appId == "invoices" then
            -- Mark all visible pending invoices as seen so badge clears
            local myFarmId = self:getMyFarmId()
            for _, inv in pairs(InvoiceManager.invoices) do
                if inv.toFarmId == myFarmId and inv.status == "PENDING" then
                    self.seenInvoiceIds[inv.id] = true
                end
            end
            self.state = self.STATE.INVOICES_LIST; return
        end
        if appId == "contacts" then self.state = self.STATE.CONTACTS;      return end
        if appId == "messages" then self.state = self.STATE.MESSAGES;      return end
        if appId == "calls"    then self.state = self.STATE.CALLS; self:clearMissedCallBadge(); return end
        if appId == "settings" then self.state = self.STATE.SETTINGS;      return end
        return
    end

    -- Grid app clicks (page 2+)
    if hb.id:sub(1,9) == "grid_app_" and hb.data and hb.data.appId then
        local appId = hb.data.appId
        if appId == "weather" then self.state = self.STATE.WEATHER; return end
        -- market: TODO
        return
    end

    -- Message compose field focus
    if hb.id == "msg_field" then self.messageCompose.active = true; return end

    -- Send message
    if hb.id == "btn_send_message" then self:sendMessage(); return end

    -- Message button from contact detail
    if hb.id == "btn_message_contact" then
        self.messageScrollOffset = 0
        self.state = self.STATE.MESSAGE_THREAD; return
    end

    -- Call button from contact detail or message thread → dial that contact
    if hb.id == "btn_call" then
        if (self.state == self.STATE.CONTACT_DETAIL or self.state == self.STATE.MESSAGE_THREAD)
           and self.selectedContact then
            self:startCall(); return
        end
        self.state = self.STATE.CALLS; self.callsTab = "keypad"; return
    end

    -- Answer / end call buttons
    if hb.id == "btn_answer"   then self:answerCall(); return end
    if hb.id == "btn_end_call" then self:endCall();    return end

    -- Calls app tab bar
    if hb.id == "calls_tab_keypad"   then self.callsTab = "keypad";   return end
    if hb.id == "calls_tab_recents"  then self.callsTab = "recents";  return end
    if hb.id == "calls_tab_contacts" then self.callsTab = "contacts"; return end

    -- Keypad: specific buttons before generic prefix match
    if hb.id == "keypad_del" then
        local n = self.keypadNumber or ""
        if #n > 0 then self.keypadNumber = n:sub(1, #n - 1) end; return
    end
    if hb.id == "keypad_call" then
        local raw = self.keypadNumber or ""
        if raw ~= "" then
            -- Format matches hashPhone output: "555-XXXX"
            local formatted = #raw <= 3 and raw or raw:sub(1,3) .. "-" .. raw:sub(4)
            self:startCallByPhone(formatted)
            self.keypadNumber = ""
        end; return
    end
    -- Keypad: digit buttons only (star/hash ignored — hashPhone is digits only)
    if hb.id:sub(1,7) == "keypad_" then
        local key = hb.id:sub(8)
        if key ~= "star" and key ~= "hash" then
            if #(self.keypadNumber or "") < self:getMaxKeypadDigits() then
                self.keypadNumber = (self.keypadNumber or "") .. key
            end
        end; return
    end

    -- Recents tab call-back button
    if hb.id == "recents_callback" and hb.data and hb.data.phone then
        self:startCallByPhone(hb.data.phone); return
    end

    -- Contacts tab Call button
    if hb.id == "calls_contact_call" and hb.data and hb.data.index then
        self.selectedContact = hb.data.index
        self:startCall(); return
    end

    -- Back button
    if hb.id == "btn_back" then
        if self.state == self.STATE.CALLS then
            self:clearMissedCallBadge()
            self:goHome(); return
        end
        if self.state == self.STATE.MESSAGE_THREAD then
            self.messageCompose.active = false
            self.messageCompose.text   = ""
            self.state = self.STATE.MESSAGES; return
        end
        if self.state == self.STATE.MESSAGES       then self:goHome(); return end
        if self.state == self.STATE.CONTACT_DETAIL then self.state = self.STATE.CONTACTS; return end
        if self.state == self.STATE.INVOICE_CREATE  then self.state = self.STATE.INVOICES_LIST; return end
        if self.state == self.STATE.INVOICE_DETAIL  then self.state = self.STATE.INVOICES_LIST; return end
        self:goHome(); return
    end

    -- Tabs
    if hb.id == "tab_inbox"  then self.currentTab = self.TAB.INBOX;  return end
    if hb.id == "tab_outbox" then self.currentTab = self.TAB.OUTBOX; return end

    -- Create invoice
    if hb.id == "btn_create_invoice" then self:resetForm(); self.state = self.STATE.INVOICE_CREATE; return end

    -- Invoice row -> detail
    if hb.id == "invoice_row" and hb.data and hb.data.invoice then
        self.selectedInvoice = hb.data.invoice
        self.state = self.STATE.INVOICE_DETAIL; return
    end

    -- Farm selector arrows
    if hb.id == "farm_prev" then
        local farms = self:getAvailableFarms()
        self.form.toFarmIndex = ((self.form.toFarmIndex - 2) % #farms) + 1; return
    end
    if hb.id == "farm_next" then
        local farms = self:getAvailableFarms()
        self.form.toFarmIndex = (self.form.toFarmIndex % #farms) + 1; return
    end

    -- Category group arrows
    if hb.id == "cat_group_prev" then
        local n = #InvoiceManager.categoryGroups
        self.form.categoryGroupIndex = ((self.form.categoryGroupIndex - 2) % n) + 1
        self.form.categoryTypeIndex = 1; return
    end
    if hb.id == "cat_group_next" then
        local n = #InvoiceManager.categoryGroups
        self.form.categoryGroupIndex = (self.form.categoryGroupIndex % n) + 1
        self.form.categoryTypeIndex = 1; return
    end

    -- Category type arrows
    if hb.id == "cat_type_prev" then
        local group = InvoiceManager.categoryGroups[self.form.categoryGroupIndex] or InvoiceManager.categoryGroups[1]
        local n = #group.types
        self.form.categoryTypeIndex = ((self.form.categoryTypeIndex - 2) % n) + 1; return
    end
    if hb.id == "cat_type_next" then
        local group = InvoiceManager.categoryGroups[self.form.categoryGroupIndex] or InvoiceManager.categoryGroups[1]
        local n = #group.types
        self.form.categoryTypeIndex = (self.form.categoryTypeIndex % n) + 1; return
    end

    -- Text field focus
    if hb.id == "field_amount"  then self.form.activeField = "amount";  return end
    if hb.id == "field_notes"   then self.form.activeField = "notes";   return end
    if hb.id == "field_dueDate" then self.form.activeField = "dueDate"; return end

    -- Clear buttons
    if hb.id == "clear_amount"      then self.form.amount      = ""; self.form.activeField = "amount";      return end
    if hb.id == "clear_dueDate"     then self.form.dueDate     = ""; self.form.activeField = "dueDate";     return end
    if hb.id == "clear_description" then self.form.description = ""; self.form.activeField = "description"; return end
    if hb.id == "clear_notes"       then self.form.notes       = ""; self.form.activeField = "notes";       return end

    -- Send invoice
    if hb.id == "btn_send_invoice" then self:submitInvoice(); return end

    -- Mark as paid (sender action on their own outgoing invoice)
    if hb.id == "btn_mark_paid" and self.selectedInvoice then
        local invId = self.selectedInvoice.id
        self.selectedInvoice.status = "PAID"
        local evt = InvoiceEvents.UpdateInvoiceEvent.new(invId, "PAID")
        if g_server ~= nil then g_server:broadcastEvent(evt)
        elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end
        RoleplayPhone:saveInvoices()
        UsedPlusCompat:onInvoiceMarkedPaid(self.selectedInvoice)
        print("[RoleplayPhone] Invoice marked as paid: #" .. tostring(invId)); return
    end

    -- Reject invoice
    if hb.id == "btn_reject_invoice" and self.selectedInvoice then
        local inv = self.selectedInvoice
        if inv.status == "PENDING" then
            inv.status = "REJECTED"
            local evt = InvoiceEvents.UpdateInvoiceEvent.new(inv.id, "REJECTED")
            if g_server ~= nil then g_server:broadcastEvent(evt)
            elseif g_client ~= nil then g_client:getServerConnection():sendEvent(evt) end
            RoleplayPhone:saveInvoices()
            UsedPlusCompat:onInvoiceRejected(inv)
            NotificationManager:push("rejected",
                string.format(g_i18n:getText("invoices_notif_rejected"),
                    string.format("%04d", inv.id)))
            print("[RoleplayPhone] Invoice rejected: #" .. tostring(inv.id))
        end; return
    end

    -- Pay invoice
    if hb.id == "btn_pay_invoice" and self.selectedInvoice then
        local inv = self.selectedInvoice
        local amount = inv.amount or 0
        local myFarmId = self:getMyFarmId()
        local fm = g_farmManager or (g_currentMission and g_currentMission.farmManager)
        if fm then
            local farm = fm:getFarmById(myFarmId)
            if farm and farm.money >= amount then
                if g_server ~= nil then
                    g_currentMission:addMoney(-amount, myFarmId,    MoneyType.OTHER, true, true)
                    g_currentMission:addMoney( amount, inv.fromFarmId, MoneyType.OTHER, true, true)
                    inv.status = "PAID"
                    g_server:broadcastEvent(InvoiceEvents.UpdateInvoiceEvent.new(inv.id, "PAID"))
                    RoleplayPhone:saveInvoices()
                elseif g_client ~= nil then
                    inv.status = "PAID"
                    g_client:getServerConnection():sendEvent(
                        RI_PayInvoiceEvent.new(inv.id, inv.fromFarmId, myFarmId, amount))
                end
                UsedPlusCompat:onInvoicePaid(inv)
                NotificationManager:push("paid",
                    string.format(g_i18n:getText("invoices_notif_paid"),
                        self:formatMoney(amount), self:getFarmName(inv.fromFarmId)))
                print("[RoleplayPhone] Invoice paid: #" .. tostring(inv.id))
            else
                NotificationManager:push("rejected", g_i18n:getText("invoices_insufficient_funds"))
            end
        end; return
    end

    -- Messages list: tap thread row → open that thread
    if hb.id == "msg_thread_row" and hb.data and hb.data.index then
        self.selectedContact = hb.data.index
        self.unreadMessages[hb.data.index] = 0
        self.messageCompose.text   = ""
        self.messageCompose.active = false
        self.messageScrollOffset   = 0
        self.state = self.STATE.MESSAGE_THREAD; return
    end

    -- Contacts list row
    if hb.id == "btn_add_unknown_contact" and type(self.selectedContact) == "string" then
        local info = self.messageDisplayNames[self.selectedContact]
        if info then
            self:resetContactForm()
            self.contactForm.name  = info.name  or ""
            self.contactForm.phone = info.phone or ""
            -- Pre-select the matching online player if still online
            if info.userId and info.userId ~= 0 then
                local onlineList = {}
                local myUserId = self:getMyUserId()
                for uid, uinfo in pairs(self.onlineUsers) do
                    if uid ~= myUserId then
                        table.insert(onlineList, { userId=uid, name=uinfo.name, phone=uinfo.phone, farmId=uinfo.farmId })
                    end
                end
                table.sort(onlineList, function(a,b) return a.name < b.name end)
                for idx, p in ipairs(onlineList) do
                    if p.userId == info.userId then
                        self.contactForm.playerPickerIdx = idx
                        self.contactForm.playerUserId    = p.userId
                        self.contactForm.phone           = p.phone or info.phone or ""
                        self.contactForm.farmName        = self:getFarmName(p.farmId)
                        break
                    end
                end
            end
            self.state = self.STATE.CONTACT_CREATE
        end
        return
    end

    -- Contacts list row
    if hb.id == "contact_row" and hb.data and hb.data.index then
        self.selectedContact = hb.data.index
        self.unreadMessages[hb.data.index] = 0
        self.messageCompose.text   = ""
        self.messageCompose.active = false
        self.state = self.STATE.CONTACT_DETAIL; return
    end

    if hb.id == "btn_add_contact" then
        self:resetContactForm(); self.state = self.STATE.CONTACT_CREATE; return
    end

    -- Delete contact
    if hb.id == "btn_delete_contact" then
        if self.selectedContact then
            local idx = self.selectedContact
            if g_server == nil then
                local myUserId = self:getMyUserId()
                g_client:getServerConnection():sendEvent(
                    RI_ContactEvent.new("delete", myUserId, idx, {}))
            end
            ContactManager:removeContact(idx)
            self.selectedContact = nil
            RoleplayPhone:saveContacts()
        end
        self.state = self.STATE.CONTACTS; return
    end

    -- Contact create field focus
    if hb.id == "cf_name"     then self.contactForm.activeField = "name";     return end
    if hb.id == "cf_notes"    then self.contactForm.activeField = "notes";    return end

    -- Contact create clear buttons
    if hb.id == "cclear_name"     then self.contactForm.name     = ""; self.contactForm.activeField = "name";     return end
    if hb.id == "cclear_notes"    then self.contactForm.notes    = ""; self.contactForm.activeField = "notes";    return end

    -- Save contact
    if hb.id == "btn_save_contact" then
        local f = self.contactForm
        if f.name and f.name ~= "" then
            local data = { name=f.name, farmName=f.farmName, phone=f.phone, notes=f.notes, playerUserId=f.playerUserId or 0 }
            ContactManager:addContact(data)
            if g_server == nil then
                g_client:getServerConnection():sendEvent(
                    RI_ContactEvent.new("add", self:getMyUserId(), 0, data))
            end
            RoleplayPhone:saveContacts()
        end
        self.contactForm.activeField = nil
        self.state = self.STATE.CONTACTS; return
    end

    -- Settings tabs
    if hb.id == "settings_tab_general"   then self.settingsTab = "general";   return end
    if hb.id == "settings_tab_ringtones" then self.settingsTab = "ringtones"; return end
    if hb.id == "settings_tab_wallpaper" then self.settingsTab = "wallpaper"; return end

    -- Wallpaper preview / apply
    if hb.id == "wallp_prev" then
        local cur = self.previewWallpaper or self.settings.wallpaperIndex
        self.previewWallpaper = ((cur - 2) % #self.WALLPAPERS) + 1; return
    end
    if hb.id == "wallp_next" then
        local cur = self.previewWallpaper or self.settings.wallpaperIndex
        self.previewWallpaper = (cur % #self.WALLPAPERS) + 1; return
    end
    if hb.id == "wallp_apply" then
        if self.previewWallpaper then
            self.settings.wallpaperIndex = self.previewWallpaper
            self:saveSettings()
        end; return
    end

    -- Settings toggles
    if hb.id == "setting_timeformat_12"  then self.settings.timeFormat = "12"; self:saveSettings(); return end
    if hb.id == "setting_timeformat_24"  then self.settings.timeFormat = "24"; self:saveSettings(); return end
    if hb.id == "setting_temp_F"         then self.settings.tempUnit = "F";    self:saveSettings(); return end
    if hb.id == "setting_temp_C"         then self.settings.tempUnit = "C";    self:saveSettings(); return end
    if hb.id == "setting_battery_toggle" then
        self.settings.batteryVisible = not self.settings.batteryVisible
        self:saveSettings(); return
    end
    -- Ringtone arrows
    if hb.id == "ringtone_prev" then
        local n = #self.RINGTONES
        self.settings.ringtoneIndex = ((self.settings.ringtoneIndex - 2) % n) + 1
        self.ringSample = self.ringtoneSamples[self.settings.ringtoneIndex]
        self:saveSettings(); return
    end
    if hb.id == "ringtone_next" then
        local n = #self.RINGTONES
        self.settings.ringtoneIndex = (self.settings.ringtoneIndex % n) + 1
        self.ringSample = self.ringtoneSamples[self.settings.ringtoneIndex]
        self:saveSettings(); return
    end
    if hb.id == "ringtone_preview" then
        local s = self.ringtoneSamples[self.settings.ringtoneIndex]
        if s and s ~= 0 then playSample(s, 1, 1.0, 1.0, 0, 0) end; return
    end
end

function RoleplayPhone:keyEvent(unicode, sym, modifier, isDown)
    if not isDown then return false end

    -- FS25 constants are lowercase (Input.KEY_backspace, not KEY_BackSpace)
    local isBackspace = (unicode == 8)
        or (Input.KEY_backspace ~= nil and sym == Input.KEY_backspace)

    -- Keypad digit entry (keyboard + numpad both send unicode 48-57)
    if self.state == self.STATE.CALLS and (self.callsTab or "keypad") == "keypad" then
        if isBackspace then
            local n = self.keypadNumber or ""
            if #n > 0 then self.keypadNumber = n:sub(1, #n - 1) end
            return true
        end
        if unicode and unicode >= 48 and unicode <= 57 then
            if #(self.keypadNumber or "") < self:getMaxKeypadDigits() then
                self.keypadNumber = (self.keypadNumber or "") .. string.char(unicode)
            end
            return true
        end
        return false
    end

    -- Invoice create text input
    if self.form.activeField and self.state == self.STATE.INVOICE_CREATE then
        local field = self.form.activeField
        local val   = self.form[field] or ""
        if isBackspace then
            if #val > 0 then self.form[field] = val:sub(1, #val - 1) end
            return true
        end
        if unicode and unicode > 31 and unicode < 127 then
            local maxLen = (field == "amount") and 10 or 200
            if #val < maxLen then self.form[field] = val .. string.char(unicode) end
            return true
        end
        if sym == Input.KEY_tab or sym == Input.KEY_return then
            local order = { "amount", "dueDate", "description", "notes" }
            for i, f in ipairs(order) do
                if f == field then self.form.activeField = order[i+1] or nil; break end
            end
            return true
        end
    end

    -- Contact create text input
    if self.contactForm.activeField and self.state == self.STATE.CONTACT_CREATE then
        local field = self.contactForm.activeField
        local val   = self.contactForm[field] or ""
        if isBackspace then
            if #val > 0 then self.contactForm[field] = val:sub(1, #val - 1) end
            return true
        end
        if unicode and unicode > 31 and unicode < 127 then
            if #val < 60 then self.contactForm[field] = val .. string.char(unicode) end
            return true
        end
    end

    -- Message compose text input
    if self.messageCompose.active and self.state == self.STATE.MESSAGE_THREAD then
        local val = self.messageCompose.text or ""
        if isBackspace then
            if #val > 0 then self.messageCompose.text = val:sub(1, #val - 1) end
            return true
        end
        if sym == Input.KEY_return then self:sendMessage(); return true end
        if unicode and unicode > 31 and unicode < 127 then
            if #val < 120 then self.messageCompose.text = val .. string.char(unicode) end
            return true
        end
    end

    return false
end

function RoleplayPhone:handleBackspace()
    if self.state == self.STATE.CALLS and (self.callsTab or "keypad") == "keypad" then
        local n = self.keypadNumber or ""
        if #n > 0 then self.keypadNumber = n:sub(1, #n - 1) end
    elseif self.state == self.STATE.INVOICE_CREATE and self.form.activeField then
        local f = self.form.activeField
        local v = self.form[f] or ""
        if #v > 0 then self.form[f] = v:sub(1, #v - 1) end
    elseif self.state == self.STATE.CONTACT_CREATE and self.contactForm.activeField then
        local f = self.contactForm.activeField
        local v = self.contactForm[f] or ""
        if #v > 0 then self.contactForm[f] = v:sub(1, #v - 1) end
    elseif self.state == self.STATE.MESSAGE_THREAD and self.messageCompose.active then
        local v = self.messageCompose.text or ""
        if #v > 0 then self.messageCompose.text = v:sub(1, #v - 1) end
    end
end
