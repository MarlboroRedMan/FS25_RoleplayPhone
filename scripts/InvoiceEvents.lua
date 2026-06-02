-- scripts/InvoiceEvents.lua
-- Network events for invoices only: Send, Update, Pay, Ping.
-- Player, Contact, Message, Call, and Weather events are in their own files.

InvoiceEvents = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: SendInvoice — broadcast a new invoice to all clients
-- ─────────────────────────────────────────────────────────────────────────────

if RI_SendInvoiceEvent == nil then
    RI_SendInvoiceEvent    = {}
    RI_SendInvoiceEvent_mt = Class(RI_SendInvoiceEvent, Event)
    InitEventClass(RI_SendInvoiceEvent, "RI_SendInvoiceEvent")
end

function RI_SendInvoiceEvent.emptyNew()
    return Event.new(RI_SendInvoiceEvent_mt)
end

function RI_SendInvoiceEvent.new(invoice, showNotification)
    local self = RI_SendInvoiceEvent.emptyNew()
    self.invoice          = invoice
    self.showNotification = (showNotification ~= false)
    return self
end

function RI_SendInvoiceEvent:writeStream(streamId, connection)
    local inv = self.invoice
    streamWriteInt32(streamId,   inv.id          or 0)
    streamWriteInt32(streamId,   inv.fromFarmId  or 0)
    streamWriteInt32(streamId,   inv.toFarmId    or 0)
    streamWriteFloat32(streamId, inv.amount      or 0)
    streamWriteInt32(streamId,   inv.createdDate or 0)
    streamWriteString(streamId,  inv.category    or "")
    streamWriteString(streamId,  inv.description or "")
    streamWriteString(streamId,  inv.notes       or "")
    streamWriteString(streamId,  inv.dueDate     or "")
    streamWriteString(streamId,  inv.status      or "PENDING")
    streamWriteBool(streamId,    self.showNotification)
end

function RI_SendInvoiceEvent:readStream(streamId, connection)
    local data = {
        id          = streamReadInt32(streamId),
        fromFarmId  = streamReadInt32(streamId),
        toFarmId    = streamReadInt32(streamId),
        amount      = streamReadFloat32(streamId),
        createdDate = streamReadInt32(streamId),
        category    = streamReadString(streamId),
        description = streamReadString(streamId),
        notes       = streamReadString(streamId),
        dueDate     = streamReadString(streamId),
        status      = streamReadString(streamId),
    }
    self.invoice          = Invoice.new(data)
    self.showNotification = streamReadBool(streamId)
    self:run(connection)
end

function RI_SendInvoiceEvent:run(connection)
    if self.invoice == nil then return end
    -- Server: ignore the client-supplied fromFarmId and look it up directly from the
    -- connection object so a malicious client cannot spoof another farm's identity.
    if g_server ~= nil and connection ~= nil and not connection:getIsServer() then
        local sender = g_currentMission:getPlayerByConnection(connection)
        if sender then self.invoice.fromFarmId = sender:getFarmId() end
    end
    if g_server ~= nil and self.invoice.id == 0 then
        self.invoice.id = InvoiceManager.nextInvoiceId
        InvoiceManager.nextInvoiceId = InvoiceManager.nextInvoiceId + 1
    end
    local alreadyExists = (InvoiceManager.invoices[self.invoice.id] ~= nil)
    if not alreadyExists then InvoiceManager:addInvoice(self.invoice) end
    if g_server ~= nil then RoleplayPhone:saveInvoices() end
    if connection ~= nil and not connection:getIsServer() then
        g_server:broadcastEvent(RI_SendInvoiceEvent.new(self.invoice, true), false, nil)
    end
    if self.showNotification and not alreadyExists then
        local myFarmId = RoleplayPhone:getMyFarmId()
        if self.invoice.toFarmId == myFarmId then
            local fromName = "Farm " .. tostring(self.invoice.fromFarmId)
            if g_farmManager then
                local ff = g_farmManager:getFarmById(self.invoice.fromFarmId)
                if ff and ff.name then fromName = ff.name end
            end
            NotificationManager:push("invoice",
                string.format(g_i18n:getText("phone_notif_invoice_received"),
                    fromName, tostring(math.floor(self.invoice.amount or 0))))
            if RoleplayPhone.notifSample and RoleplayPhone.notifSample ~= 0 then
                playSample(RoleplayPhone.notifSample, 1, 1.0, 1.0, 0, 0)
            end
        end
    end
    print(string.format("[InvoiceEvents] Invoice #%d synced", self.invoice.id or 0))
end

InvoiceEvents.SendInvoiceEvent = RI_SendInvoiceEvent


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: UpdateInvoice — sync status change (PAID / REJECTED) to all clients
-- ─────────────────────────────────────────────────────────────────────────────

if RI_UpdateInvoiceEvent == nil then
    RI_UpdateInvoiceEvent    = {}
    RI_UpdateInvoiceEvent_mt = Class(RI_UpdateInvoiceEvent, Event)
    InitEventClass(RI_UpdateInvoiceEvent, "RI_UpdateInvoiceEvent")
end

function RI_UpdateInvoiceEvent.emptyNew()
    return Event.new(RI_UpdateInvoiceEvent_mt)
end

function RI_UpdateInvoiceEvent.new(invoiceId, status)
    local self = RI_UpdateInvoiceEvent.emptyNew()
    self.invoiceId = invoiceId
    self.status    = status
    return self
end

function RI_UpdateInvoiceEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId,  self.invoiceId or 0)
    streamWriteString(streamId, self.status    or "PAID")
end

function RI_UpdateInvoiceEvent:readStream(streamId, connection)
    self.invoiceId = streamReadInt32(streamId)
    self.status    = streamReadString(streamId)
    self:run(connection)
end

function RI_UpdateInvoiceEvent:run(connection)
    if self.status == "INSUFFICIENT_FUNDS" then
        -- Don't change invoice status — just notify the local player
        NotificationManager:push("invoice", "Payment Failed: Insufficient funds.")
        return
    end
    for _, inv in pairs(InvoiceManager.invoices) do
        if inv.id == self.invoiceId then
            inv.status = self.status; break
        end
    end
    if connection ~= nil and not connection:getIsServer() then
        g_server:broadcastEvent(
            RI_UpdateInvoiceEvent.new(self.invoiceId, self.status), false, connection)
    end
end

InvoiceEvents.UpdateInvoiceEvent = RI_UpdateInvoiceEvent

-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: Ping — farm-to-farm notification message
-- ─────────────────────────────────────────────────────────────────────────────

if RI_PingEvent == nil then
    RI_PingEvent    = {}
    RI_PingEvent_mt = Class(RI_PingEvent, Event)
    InitEventClass(RI_PingEvent, "RI_PingEvent")
end

function RI_PingEvent.emptyNew()
    return Event.new(RI_PingEvent_mt)
end

function RI_PingEvent.new(fromFarmId, toFarmId, message)
    local self = RI_PingEvent.emptyNew()
    self.fromFarmId = fromFarmId
    self.toFarmId   = toFarmId
    self.message    = message
    return self
end

function RI_PingEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId,  self.fromFarmId or 0)
    streamWriteInt32(streamId,  self.toFarmId   or 0)
    streamWriteString(streamId, self.message    or "")
end

function RI_PingEvent:readStream(streamId, connection)
    self.fromFarmId = streamReadInt32(streamId)
    self.toFarmId   = streamReadInt32(streamId)
    self.message    = streamReadString(streamId)
    self:run(connection)
end

function RI_PingEvent:run(connection)
    if connection ~= nil and not connection:getIsServer() then
        -- Override client-supplied fromFarmId with the verified sender farmId.
        local sender = g_currentMission:getPlayerByConnection(connection)
        if sender then self.fromFarmId = sender:getFarmId() end
        g_server:broadcastEvent(
            RI_PingEvent.new(self.fromFarmId, self.toFarmId, self.message), false, connection)
    end
    local myFarmId = RoleplayPhone:getMyFarmId()
    if self.toFarmId == 0 or self.toFarmId == myFarmId then
        local fromName = "Farm " .. tostring(self.fromFarmId)
        if g_farmManager then
            local ff = g_farmManager:getFarmById(self.fromFarmId)
            if ff and ff.name then fromName = ff.name end
        end
        NotificationManager:push("ping",
            string.format(g_i18n:getText("phone_notif_ping_fmt"), fromName, self.message))
    end
end

InvoiceEvents.PingEvent = RI_PingEvent


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: PayInvoice — client requests server to transfer money and mark paid
-- ─────────────────────────────────────────────────────────────────────────────

if RI_PayInvoiceEvent == nil then
    RI_PayInvoiceEvent    = {}
    RI_PayInvoiceEvent_mt = Class(RI_PayInvoiceEvent, Event)
    InitEventClass(RI_PayInvoiceEvent, "RI_PayInvoiceEvent")
end

function RI_PayInvoiceEvent.emptyNew()
    return Event.new(RI_PayInvoiceEvent_mt)
end

function RI_PayInvoiceEvent.new(invoiceId, fromFarmId, toFarmId, amount)
    local self = RI_PayInvoiceEvent.emptyNew()
    self.invoiceId  = invoiceId
    self.fromFarmId = fromFarmId
    self.toFarmId   = toFarmId
    self.amount     = amount
    return self
end

function RI_PayInvoiceEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId,   self.invoiceId  or 0)
    streamWriteInt32(streamId,   self.fromFarmId or 0)
    streamWriteInt32(streamId,   self.toFarmId   or 0)
    streamWriteFloat32(streamId, self.amount     or 0)
end

function RI_PayInvoiceEvent:readStream(streamId, connection)
    self.invoiceId  = streamReadInt32(streamId)
    self.fromFarmId = streamReadInt32(streamId)
    self.toFarmId   = streamReadInt32(streamId)
    self.amount     = streamReadFloat32(streamId)
    self:run(connection)
end

function RI_PayInvoiceEvent:run(connection)
    if g_server ~= nil then
        local fm = (g_currentMission and g_currentMission.farmManager) or g_farmManager
        if fm then
            local payingFarm = fm:getFarmById(self.toFarmId)
            if payingFarm and payingFarm.money >= self.amount then
                g_currentMission:addMoney(-self.amount, self.toFarmId,   MoneyType.OTHER, true, true)
                g_currentMission:addMoney( self.amount, self.fromFarmId, MoneyType.OTHER, true, true)
                g_server:broadcastEvent(RI_UpdateInvoiceEvent.new(self.invoiceId, "PAID"))
                for _, inv in pairs(InvoiceManager.invoices) do
                    if inv.id == self.invoiceId then inv.status = "PAID"; break end
                end
                RoleplayPhone:saveInvoices()
            else
                -- Insufficient funds — notify only the paying client, not everyone
                local evt = RI_UpdateInvoiceEvent.new(self.invoiceId, "INSUFFICIENT_FUNDS")
                if connection ~= nil then
                    connection:sendEvent(evt)  -- client initiated: send back to them only
                else
                    evt:run(nil)  -- host initiated: run locally
                end
                print(string.format("[InvoiceEvents] Pay rejected: farm %d has insufficient funds for invoice %s", self.toFarmId, tostring(self.invoiceId)))
            end
        end
    end
end

InvoiceEvents.PayInvoiceEvent = RI_PayInvoiceEvent
