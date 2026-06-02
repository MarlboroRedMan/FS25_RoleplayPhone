-- scripts/apps/InvoicesInput.lua
-- Input handler for the Invoices app: list, detail, create form, pay/reject/mark-paid.
-- Called from PhoneInput:onHitboxClicked(). Returns true if the event was consumed.

function RoleplayPhone:handleInvoicesInput(hb)

    -- Invoices list: Create invoice button
    if hb.id == "btn_create_invoice" then
        self:resetForm()
        self.state = self.STATE.INVOICE_CREATE
        return true
    end

    -- Invoices list: tap row → open detail
    if hb.id == "invoice_row" and hb.data and hb.data.invoice then
        self.selectedInvoice = hb.data.invoice
        self.state = self.STATE.INVOICE_DETAIL
        return true
    end

    -- Invoice create: farm selector arrows
    if hb.id == "farm_prev" then
        local farms = self:getAvailableFarms()
        self.form.toFarmIndex = ((self.form.toFarmIndex - 2) % #farms) + 1
        return true
    end
    if hb.id == "farm_next" then
        local farms = self:getAvailableFarms()
        self.form.toFarmIndex = (self.form.toFarmIndex % #farms) + 1
        return true
    end

    -- Invoice create: category group arrows
    if hb.id == "cat_group_prev" then
        local n = #InvoiceManager.categoryGroups
        self.form.categoryGroupIndex = ((self.form.categoryGroupIndex - 2) % n) + 1
        self.form.categoryTypeIndex  = 1
        return true
    end
    if hb.id == "cat_group_next" then
        local n = #InvoiceManager.categoryGroups
        self.form.categoryGroupIndex = (self.form.categoryGroupIndex % n) + 1
        self.form.categoryTypeIndex  = 1
        return true
    end

    -- Invoice create: category type arrows
    if hb.id == "cat_type_prev" then
        local group = InvoiceManager.categoryGroups[self.form.categoryGroupIndex]
                   or InvoiceManager.categoryGroups[1]
        local n = #group.types
        self.form.categoryTypeIndex = ((self.form.categoryTypeIndex - 2) % n) + 1
        return true
    end
    if hb.id == "cat_type_next" then
        local group = InvoiceManager.categoryGroups[self.form.categoryGroupIndex]
                   or InvoiceManager.categoryGroups[1]
        local n = #group.types
        self.form.categoryTypeIndex = (self.form.categoryTypeIndex % n) + 1
        return true
    end

    -- Invoice create: text field focus
    if hb.id == "field_amount"  then self.form.activeField = "amount";  self:placeCursorAtX(self.form.amount  or "", hb.x + 0.004, 0.012, self.mouseX); return true end
    if hb.id == "field_notes"   then self.form.activeField = "notes";   self:activateFieldCursor(self.form.notes   or ""); return true end
    if hb.id == "field_dueDate" then self.form.activeField = "dueDate"; self:placeCursorAtX(self.form.dueDate or "", hb.x + 0.004, 0.012, self.mouseX); return true end

    -- Invoice create: Submit button
    if hb.id == "btn_send_invoice" then
        self:submitInvoice()
        return true
    end

    -- Invoice detail: Mark as paid (sender action on outgoing invoice)
    if hb.id == "btn_mark_paid" and self.selectedInvoice then
        local invId = self.selectedInvoice.id
        self.selectedInvoice.status = "PAID"
        local evt = InvoiceEvents.UpdateInvoiceEvent.new(invId, "PAID")
        if g_server ~= nil then
            g_server:broadcastEvent(evt)
            UsedPlusCompat:onInvoiceMarkedPaid(self.selectedInvoice)  -- server only
        elseif g_client ~= nil then
            g_client:getServerConnection():sendEvent(evt)
        end
        RoleplayPhone:saveInvoices()
        print("[RoleplayPhone] Invoice marked as paid: #" .. tostring(invId))
        return true
    end

    -- Invoice detail: Reject button
    if hb.id == "btn_reject_invoice" and self.selectedInvoice then
        local inv = self.selectedInvoice
        if inv.status == "PENDING" then
            inv.status = "REJECTED"
            local evt = InvoiceEvents.UpdateInvoiceEvent.new(inv.id, "REJECTED")
            if g_server ~= nil then
                g_server:broadcastEvent(evt)
                UsedPlusCompat:onInvoiceRejected(inv)  -- server only
            elseif g_client ~= nil then
                g_client:getServerConnection():sendEvent(evt)
            end
            RoleplayPhone:saveInvoices()
            NotificationManager:push("rejected",
                string.format(g_i18n:getText("invoices_notif_rejected"),
                    string.format("%04d", inv.id)))
            print("[RoleplayPhone] Invoice rejected: #" .. tostring(inv.id))
        end
        return true
    end

    -- Invoice detail: Pay button
    if hb.id == "btn_pay_invoice" and self.selectedInvoice then
        local inv      = self.selectedInvoice
        local amount   = inv.amount or 0
        local myFarmId = self:getMyFarmId()
        local fm       = g_farmManager or (g_currentMission and g_currentMission.farmManager)
        if fm then
            local farm = fm:getFarmById(myFarmId)
            if farm and farm.money >= amount then
                if g_server ~= nil then
                    g_currentMission:addMoney(-amount,       myFarmId,      MoneyType.OTHER, true, true)
                    g_currentMission:addMoney( amount, inv.fromFarmId, MoneyType.OTHER, true, true)
                    inv.status = "PAID"
                    g_server:broadcastEvent(InvoiceEvents.UpdateInvoiceEvent.new(inv.id, "PAID"))
                    RoleplayPhone:saveInvoices()
                    UsedPlusCompat:onInvoicePaid(inv)  -- server only
                elseif g_client ~= nil then
                    -- Do NOT set status optimistically — wait for server's RI_UpdateInvoiceEvent
                    g_client:getServerConnection():sendEvent(
                        RI_PayInvoiceEvent.new(inv.id, inv.fromFarmId, myFarmId, amount))
                end
                NotificationManager:push("paid",
                    string.format(g_i18n:getText("invoices_notif_paid"),
                        self:formatMoney(amount), self:getFarmName(inv.fromFarmId)))
                print("[RoleplayPhone] Invoice paid: #" .. tostring(inv.id))
            else
                NotificationManager:push("rejected", g_i18n:getText("invoices_insufficient_funds"))
            end
        end
        return true
    end

end
