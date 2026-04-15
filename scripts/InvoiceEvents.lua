-- scripts/InvoiceEvents.lua
-- Network events for MP sync.
-- IMPORTANT: FS25 requires event classes to be top-level globals, not nested in tables.

InvoiceEvents = {}


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT 0: PlayerHello — client announces itself on connect
-- Carries playerUserId, farmId, playerName, phoneNumber
-- Host stores in RoleplayPhone.onlineUsers and uses for call/message routing
-- ─────────────────────────────────────────────────────────────────────────────

if RI_PlayerHelloEvent == nil then
    RI_PlayerHelloEvent    = {}
    RI_PlayerHelloEvent_mt = Class(RI_PlayerHelloEvent, Event)
    InitEventClass(RI_PlayerHelloEvent, "RI_PlayerHelloEvent")
end

function RI_PlayerHelloEvent.emptyNew()
    return Event.new(RI_PlayerHelloEvent_mt)
end

function RI_PlayerHelloEvent.new(playerUserId, farmId, playerName, phoneNumber, uniqueId)
    local self = RI_PlayerHelloEvent.emptyNew()
    self.playerUserId = playerUserId
    self.farmId       = farmId
    self.playerName   = playerName   or ""
    self.phoneNumber  = phoneNumber  or ""
    self.uniqueId     = uniqueId     or ""
    return self
end

function RI_PlayerHelloEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId,  self.playerUserId or 0)
    streamWriteInt32(streamId,  self.farmId       or 0)
    streamWriteString(streamId, self.playerName   or "")
    streamWriteString(streamId, self.phoneNumber  or "")
    streamWriteString(streamId, self.uniqueId     or "")
end

function RI_PlayerHelloEvent:readStream(streamId, connection)
    self.playerUserId = streamReadInt32(streamId)
    self.farmId       = streamReadInt32(streamId)
    self.playerName   = streamReadString(streamId)
    self.phoneNumber  = streamReadString(streamId)
    self.uniqueId     = streamReadString(streamId)
    self:run(connection)
end

function RI_PlayerHelloEvent:run(connection)
    -- Server: store this player in onlineUsers and broadcast to all clients
    if g_server ~= nil then
        RoleplayPhone.onlineUsers[self.playerUserId] = {
            farmId     = self.farmId,
            name       = self.playerName,
            phone      = self.phoneNumber,
            uniqueId   = self.uniqueId,
            connection = connection,
        }

        -- Ensure userContacts is keyed by uniqueId for persistence across sessions.
        -- Migrate from any old userId-keyed entry if needed.
        if self.uniqueId ~= "" then
            if not ContactManager.userContacts[self.uniqueId] then
                ContactManager.userContacts[self.uniqueId] =
                    ContactManager.userContacts[self.playerUserId] or {}
                ContactManager.userContacts[self.playerUserId] = nil
            end
        end

        -- Update playerUserId in any contact entries that reference this player
        -- by phone — handles contacts saved from a previous session with a stale userId
        if self.phoneNumber ~= "" then
            local function updateUserId(list)
                for _, c in ipairs(list) do
                    if c.phone == self.phoneNumber and c.playerUserId ~= self.playerUserId then
                        c.playerUserId = self.playerUserId
                    end
                end
            end
            updateUserId(ContactManager.contacts)
            for _, contactList in pairs(ContactManager.userContacts) do
                updateUserId(contactList)
            end
        end

        -- Broadcast to all clients so everyone knows who's online
        g_server:broadcastEvent(
            RI_PlayerHelloEvent.new(self.playerUserId, self.farmId,
                                    self.playerName, self.phoneNumber, self.uniqueId),
            false, connection)
        print(string.format("[RoleplayPhone] PlayerHello: %s (userId=%d farmId=%d phone=%s)",
            self.playerName, self.playerUserId, self.farmId, self.phoneNumber))
        return
    end
    -- Client: store in local onlineUsers table
    RoleplayPhone.onlineUsers[self.playerUserId] = {
        farmId   = self.farmId,
        name     = self.playerName,
        phone    = self.phoneNumber,
        uniqueId = self.uniqueId,
    }
    print(string.format("[RoleplayPhone] PlayerHello received: %s (userId=%d)",
        self.playerName, self.playerUserId))
end

InvoiceEvents.PlayerHelloEvent = RI_PlayerHelloEvent


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT 1: Send a new invoice to all clients
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
    self.showNotification = (showNotification ~= false)  -- default true
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

    -- Server assigns the canonical sequential ID (clients always send id=0)
    if g_server ~= nil and self.invoice.id == 0 then
        self.invoice.id = InvoiceManager.nextInvoiceId
        InvoiceManager.nextInvoiceId = InvoiceManager.nextInvoiceId + 1
        print(string.format("[InvoiceEvents] Server assigned Invoice #%d", self.invoice.id))
    end

    -- Avoid duplicates: use direct hash lookup on the id-keyed table
    local alreadyExists = (InvoiceManager.invoices[self.invoice.id] ~= nil)

    if not alreadyExists then
        InvoiceManager:addInvoice(self.invoice)
    end

    -- Save now that invoice is in manager (host only - clients don't have savegame)
    if g_server ~= nil then
        RoleplayPhone:saveInvoices()
    end

    -- Server broadcasts to ALL clients including the original sender so their
    -- outbox is populated with the real server-assigned ID (nil = no exclusion)
    if connection ~= nil and not connection:getIsServer() then
        g_server:broadcastEvent(RI_SendInvoiceEvent.new(self.invoice, true), false, nil)
    end

    -- Show notification to the recipient farm (skip during initial sync on connect)
    if self.showNotification and not alreadyExists then
        local myFarmId = RoleplayPhone:getMyFarmId()
        print(string.format("[InvoiceEvents] Invoice check: myFarmId=%d toFarmId=%d",
            myFarmId, self.invoice.toFarmId or -1))
        if self.invoice.toFarmId == myFarmId then
            local fromName = "Farm " .. tostring(self.invoice.fromFarmId)
            if g_farmManager then
                local ff = g_farmManager:getFarmById(self.invoice.fromFarmId)
                if ff and ff.name then fromName = ff.name end
            end
            NotificationManager:push("invoice",
                string.format(g_i18n:getText("phone_notif_invoice_received"),
                    fromName,
                    tostring(math.floor(self.invoice.amount or 0))))
            -- Play notification sound
            if RoleplayPhone.notifSample and RoleplayPhone.notifSample ~= 0 then
                playSample(RoleplayPhone.notifSample, 1, 1.0, 1.0, 0, 0)
            end
        end
    end

    print(string.format("[InvoiceEvents] Invoice #%d synced", self.invoice.id or 0))
end

-- Keep old name accessible so RoleplayPhone.lua references still work
InvoiceEvents.SendInvoiceEvent = RI_SendInvoiceEvent


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT 2: Update invoice status (PAID / REJECTED) across all clients
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
    -- Update locally by matching invoice id
    for _, inv in pairs(InvoiceManager.invoices) do
        if inv.id == self.invoiceId then
            inv.status = self.status
            print(string.format("[InvoiceEvents] Invoice #%d updated to %s",
                self.invoiceId, self.status))
            break
        end
    end

    -- Server forwards to all other clients (GIANTS pattern)
    if connection ~= nil and not connection:getIsServer() then
        g_server:broadcastEvent(
            RI_UpdateInvoiceEvent.new(self.invoiceId, self.status), false, connection)
    end
end

InvoiceEvents.UpdateInvoiceEvent = RI_UpdateInvoiceEvent


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT 3: Ping — send a message to a specific farm
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
    -- Server forwards to all other clients (GIANTS pattern)
    if connection ~= nil and not connection:getIsServer() then
        g_server:broadcastEvent(
            RI_PingEvent.new(self.fromFarmId, self.toFarmId, self.message),
            false, connection)
    end

    -- Show notification to the target farm
    local myFarmId = RoleplayPhone:getMyFarmId()
    print(string.format("[InvoiceEvents] Ping check: myFarmId=%d toFarmId=%d",
        myFarmId, self.toFarmId or -1))
    if self.toFarmId == 0 or self.toFarmId == myFarmId then
        local fromName = "Farm " .. tostring(self.fromFarmId)
        if g_farmManager then
            local ff = g_farmManager:getFarmById(self.fromFarmId)
            if ff and ff.name then fromName = ff.name end
        end
        NotificationManager:push("ping",
            string.format(g_i18n:getText("phone_notif_ping_fmt"), fromName, self.message))
    end

    print(string.format("[InvoiceEvents] Ping Farm %d -> Farm %d: %s",
        self.fromFarmId, self.toFarmId, self.message))
end

InvoiceEvents.PingEvent = RI_PingEvent


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: Direct Message — farm-to-farm private message shown in contact thread
-- ─────────────────────────────────────────────────────────────────────────────

if RI_MessageEvent == nil then
    RI_MessageEvent    = {}
    RI_MessageEvent_mt = Class(RI_MessageEvent, Event)
    InitEventClass(RI_MessageEvent, "RI_MessageEvent")
end

function RI_MessageEvent.emptyNew()
    return Event.new(RI_MessageEvent_mt)
end

function RI_MessageEvent.new(fromUserId, toUserId, senderName, text, gameDay, gameTime)
    local self = RI_MessageEvent.emptyNew()
    self.fromUserId  = fromUserId
    self.toUserId    = toUserId
    self.senderName  = senderName
    self.text        = text
    self.gameDay     = gameDay  or 0
    self.gameTime    = gameTime or 0
    return self
end

function RI_MessageEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId,  self.fromUserId or 0)
    streamWriteInt32(streamId,  self.toUserId   or 0)
    streamWriteString(streamId, self.senderName or "")
    streamWriteString(streamId, self.text       or "")
    streamWriteInt32(streamId,  self.gameDay    or 0)
    streamWriteInt32(streamId,  self.gameTime   or 0)
end

function RI_MessageEvent:readStream(streamId, connection)
    self.fromUserId = streamReadInt32(streamId)
    self.toUserId   = streamReadInt32(streamId)
    self.senderName = streamReadString(streamId)
    self.text       = streamReadString(streamId)
    self.gameDay    = streamReadInt32(streamId)
    self.gameTime   = streamReadInt32(streamId)
    self:run(connection)
end

function RI_MessageEvent:run(connection)
    -- Server: route directly to recipient instead of broadcasting to everyone
    if g_server ~= nil and connection ~= nil and not connection:getIsServer() then
        local myUserId = RoleplayPhone:getMyUserId()
        if self.toUserId ~= myUserId then
            -- Recipient is another client — find their connection and send directly
            local recipientConn = nil
            if g_currentMission and g_currentMission.connectionsToPlayer then
                for conn, player in pairs(g_currentMission.connectionsToPlayer) do
                    if player.userId == self.toUserId then recipientConn = conn; break end
                end
            end
            if recipientConn then
                recipientConn:sendEvent(RI_MessageEvent.new(
                    self.fromUserId, self.toUserId,
                    self.senderName, self.text, self.gameDay, self.gameTime))
            end
            return  -- Server doesn't need to store this message
        end
        -- Message is for the server host — fall through to receive it locally
    end

    local myUserId = RoleplayPhone:getMyUserId()
    if self.toUserId ~= myUserId then return end  -- not for us

    -- Find matching contact by playerUserId and store message in their thread
    local contacts = ContactManager.contacts or {}
    local matched  = false
    for i, contact in ipairs(contacts) do
        if contact.playerUserId and contact.playerUserId == self.fromUserId then
            RoleplayPhone:receiveMessage(i, self.fromUserId, self.senderName,
                                         self.text, self.gameDay, false, self.gameTime)
            matched = true
            break
        end
    end

    -- Fallback: match by player name if no userId match (e.g. old contacts)
    if not matched then
        for i, contact in ipairs(contacts) do
            if contact.name and contact.name ~= ""
            and string.lower(contact.name) == string.lower(self.senderName) then
                RoleplayPhone:receiveMessage(i, self.fromUserId, self.senderName,
                                             self.text, self.gameDay, false, self.gameTime)
                matched = true
                break
            end
        end
    end

    -- Fallback: match by phone number (covers contacts saved before playerUserId fix)
    if not matched then
        local senderInfo = RoleplayPhone.onlineUsers[self.fromUserId]
        local senderPhone = senderInfo and senderInfo.phone or ""
        if senderPhone ~= "" then
            for i, contact in ipairs(contacts) do
                if contact.phone and contact.phone == senderPhone then
                    RoleplayPhone:receiveMessage(i, self.fromUserId, self.senderName,
                                                 self.text, self.gameDay, false, self.gameTime)
                    matched = true
                    break
                end
            end
        end
    end

    -- No contact match — store under uniqueId-based key (stable across reconnects)
    if not matched then
        local senderInfo     = RoleplayPhone.onlineUsers[self.fromUserId]
        local senderPhone    = senderInfo and senderInfo.phone    or ""
        local senderUniqueId = senderInfo and senderInfo.uniqueId or ""
        local key = senderUniqueId ~= "" and ("u_" .. senderUniqueId) or ("u_" .. tostring(self.fromUserId))
        RoleplayPhone.messageDisplayNames[key] = {
            name   = self.senderName,
            phone  = senderPhone,
            userId = self.fromUserId,
        }
        RoleplayPhone:receiveMessage(key, self.fromUserId, self.senderName,
                                     self.text, self.gameDay, false, self.gameTime)
    end

    print(string.format("[InvoiceEvents] Message userId %d -> userId %d: %s",
        self.fromUserId, self.toUserId, self.text))
end

InvoiceEvents.MessageEvent = RI_MessageEvent

-- ─── RI_MessageSyncEvent ──────────────────────────────────────────────────────
-- Server → client on connect. Sends only the connecting client's own threads.
-- Each record: { fromUserId, toUserId, senderName, text, gameDay, gameTime }
if RI_MessageSyncEvent == nil then
    RI_MessageSyncEvent    = {}
    RI_MessageSyncEvent_mt = Class(RI_MessageSyncEvent, Event)
    InitEventClass(RI_MessageSyncEvent, "RI_MessageSyncEvent")
end

function RI_MessageSyncEvent.emptyNew()
    return Event.new(RI_MessageSyncEvent_mt)
end

function RI_MessageSyncEvent.new(msgs)
    local self = RI_MessageSyncEvent.emptyNew()
    self.msgs = msgs or {}
    return self
end

function RI_MessageSyncEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, #self.msgs)
    for _, m in ipairs(self.msgs) do
        streamWriteInt32(streamId,  m.fromUserId or 0)
        streamWriteInt32(streamId,  m.toUserId   or 0)
        streamWriteString(streamId, m.senderName or "")
        streamWriteString(streamId, m.text       or "")
        streamWriteInt32(streamId,  m.gameDay    or 0)
        streamWriteInt32(streamId,  m.gameTime   or 0)
    end
end

function RI_MessageSyncEvent:readStream(streamId, connection)
    local count = streamReadInt32(streamId)
    self.msgs = {}
    for i = 1, count do
        table.insert(self.msgs, {
            fromUserId = streamReadInt32(streamId),
            toUserId   = streamReadInt32(streamId),
            senderName = streamReadString(streamId),
            text       = streamReadString(streamId),
            gameDay    = streamReadInt32(streamId),
            gameTime   = streamReadInt32(streamId),
        })
    end
    self:run(connection)
end

function RI_MessageSyncEvent:run(connection)
    if g_server ~= nil then return end  -- only clients process this
    local myUserId = RoleplayPhone:getMyUserId()
    local contacts = ContactManager.contacts or {}

    for _, m in ipairs(self.msgs) do
        local isSent      = (m.fromUserId == myUserId)
        local otherUserId = isSent and m.toUserId or m.fromUserId

        -- Find contact key for the other person
        local key = nil
        for i, contact in ipairs(contacts) do
            if contact.playerUserId and contact.playerUserId == otherUserId then
                key = i; break
            end
        end
        if not key then
            local info       = RoleplayPhone.onlineUsers[otherUserId]
            local uniqueId   = info and info.uniqueId or ""
            key = uniqueId ~= "" and ("u_" .. uniqueId) or ("u_" .. tostring(otherUserId))
            -- Track display name so the thread header shows properly
            RoleplayPhone.messageDisplayNames[key] = {
                name   = isSent and m.senderName or (info and info.name or m.senderName),
                phone  = info and info.phone or "",
                userId = otherUserId,
            }
        end

        RoleplayPhone:receiveMessage(key, m.fromUserId, m.senderName,
                                     m.text, m.gameDay, isSent, m.gameTime)
    end
    print(string.format("[RoleplayPhone] Message sync received: %d messages", #self.msgs))
end


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT 4: Farm List — host sends full farm list to a connecting client
-- ─────────────────────────────────────────────────────────────────────────────

if RI_FarmListEvent == nil then
    RI_FarmListEvent    = {}
    RI_FarmListEvent_mt = Class(RI_FarmListEvent, Event)
    InitEventClass(RI_FarmListEvent, "RI_FarmListEvent")
end

function RI_FarmListEvent.emptyNew()
    return Event.new(RI_FarmListEvent_mt)
end

function RI_FarmListEvent.new(farms)
    local self = RI_FarmListEvent.emptyNew()
    self.farms = farms  -- array of {farmId, name}
    return self
end

function RI_FarmListEvent:writeStream(streamId, connection)
    local farms = self.farms or {}
    streamWriteInt32(streamId, #farms)
    for _, farm in ipairs(farms) do
        streamWriteInt32(streamId,  farm.farmId or 0)
        streamWriteString(streamId, farm.name   or ("Farm " .. tostring(farm.farmId)))
    end
end

function RI_FarmListEvent:readStream(streamId, connection)
    local count = streamReadInt32(streamId)
    self.farms = {}
    for i = 1, count do
        local farmId = streamReadInt32(streamId)
        local name   = streamReadString(streamId)
        table.insert(self.farms, { farmId = farmId, name = name })
    end
    self:run(connection)
end

function RI_FarmListEvent:run(connection)
    -- Store the received farm list on the phone so getAvailableFarms() can use it
    if self.farms and #self.farms > 0 then
        RoleplayPhone.knownFarms = self.farms
        RoleplayPhone:clearFarmCache()
        print(string.format("[InvoiceEvents] Received farm list: %d farms", #self.farms))
        for _, f in ipairs(self.farms) do
            print(string.format("[InvoiceEvents]   Farm %d: %s", f.farmId, f.name))
        end
    end

    -- Flag that we need to show a pending invoice notification on next phone open
    -- Can't do it now because playerUserId isn't resolved yet at connect time
    RoleplayPhone.pendingInboxCheck = true
end

InvoiceEvents.FarmListEvent = RI_FarmListEvent


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT 5: Pay Invoice — client requests server to transfer money and mark paid
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
    self.fromFarmId = fromFarmId  -- who sent the invoice (receives money)
    self.toFarmId   = toFarmId    -- who is paying (loses money)
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
    -- Only server does the actual money transfer
    if g_server ~= nil then
        local em = (g_currentMission and g_currentMission.economyManager) or g_economyManager
        local fm = (g_currentMission and g_currentMission.farmManager) or g_farmManager
        if em and fm then
            local payingFarm = fm:getFarmById(self.toFarmId)
            if payingFarm and payingFarm.money >= self.amount then
                -- Deduct from payer
                g_currentMission:addMoney(-self.amount, self.toFarmId, MoneyType.OTHER, true, true)
                -- Add to recipient
                g_currentMission:addMoney(self.amount, self.fromFarmId, MoneyType.OTHER, true, true)
                -- Mark invoice paid and broadcast status to all clients
                g_server:broadcastEvent(
                    RI_UpdateInvoiceEvent.new(self.invoiceId, "PAID"))
                -- Update server's local copy too
                for _, inv in pairs(InvoiceManager.invoices) do
                    if inv.id == self.invoiceId then
                        inv.status = "PAID"
                        break
                    end
                end
                RoleplayPhone:saveInvoices()
                print(string.format("[InvoiceEvents] Invoice #%d paid: $%.0f from Farm %d to Farm %d",
                    self.invoiceId, self.amount, self.toFarmId, self.fromFarmId))
            else
                print(string.format("[InvoiceEvents] Invoice #%d payment failed: insufficient funds",
                    self.invoiceId))
            end
        end
    end
end

InvoiceEvents.PayInvoiceEvent = RI_PayInvoiceEvent


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: Call — ring / answer / decline / end between two farms
-- callType: "ring" | "answer" | "decline" | "end"
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
    self.callType   = callType    -- "ring" | "answer" | "decline" | "end"
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
    -- Server forwards to all other clients
    if connection ~= nil and not connection:getIsServer() then
        g_server:broadcastEvent(
            RI_CallEvent.new(self.callType, self.fromUserId, self.toUserId,
                             self.callerName, self.callerNum),
            false, connection)
    end

    local myUserId = RoleplayPhone:getMyUserId()
    if self.toUserId ~= myUserId then return end  -- not for us

    if self.callType == "ring" then
        RoleplayPhone:onIncomingCall(self.fromUserId, self.callerName, self.callerNum)
    elseif self.callType == "answer" then
        RoleplayPhone:onCallAnswered()
    elseif self.callType == "decline" then
        RoleplayPhone:onCallDeclined()
    elseif self.callType == "end" then
        RoleplayPhone:onCallEnded()
    end
end

InvoiceEvents.CallEvent = RI_CallEvent


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: Contact — client sends a single add/delete operation to host for persistence
-- action: "add" | "delete"
-- ─────────────────────────────────────────────────────────────────────────────

if RI_ContactEvent == nil then
    RI_ContactEvent    = {}
    RI_ContactEvent_mt = Class(RI_ContactEvent, Event)
    InitEventClass(RI_ContactEvent, "RI_ContactEvent")
end

function RI_ContactEvent.emptyNew()
    return Event.new(RI_ContactEvent_mt)
end

function RI_ContactEvent.new(action, playerUserId, contactIndex, contactData)
    local self = RI_ContactEvent.emptyNew()
    self.action        = action
    self.playerUserId  = playerUserId
    self.contactIndex  = contactIndex  -- 1-based (used for "delete")
    self.contactData   = contactData   -- {name,farmName,phone,notes,playerUserId} (used for "add")
    return self
end

function RI_ContactEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.action       or "")
    streamWriteInt32(streamId,  self.playerUserId or 0)
    streamWriteInt32(streamId,  self.contactIndex or 0)
    local d = self.contactData or {}
    streamWriteString(streamId, d.name          or "")
    streamWriteString(streamId, d.farmName      or "")
    streamWriteString(streamId, d.phone         or "")
    streamWriteString(streamId, d.notes         or "")
    streamWriteInt32(streamId,  d.playerUserId  or 0)
end

function RI_ContactEvent:readStream(streamId, connection)
    self.action       = streamReadString(streamId)
    self.playerUserId = streamReadInt32(streamId)
    self.contactIndex = streamReadInt32(streamId)
    self.contactData  = {
        name         = streamReadString(streamId),
        farmName     = streamReadString(streamId),
        phone        = streamReadString(streamId),
        notes        = streamReadString(streamId),
        playerUserId = streamReadInt32(streamId),
    }
    self:run(connection)
end

function RI_ContactEvent:run(connection)
    if self.action == "request" then
        -- Client is asking for their saved contacts — only server handles this
        if g_server == nil then return end
        local list = ContactManager.userContacts[self.playerUserId] or {}
        connection:sendEvent(RI_ContactSyncEvent.new(list))
        print(string.format("[InvoiceEvents] Contact request from userId %d — sending %d contacts",
            self.playerUserId, #list))
        return
    end

    -- Only the server persists contact changes
    if g_server == nil then return end

    local userId = self.playerUserId
    if not ContactManager.userContacts[userId] then
        ContactManager.userContacts[userId] = {}
    end
    local list = ContactManager.userContacts[userId]

    if self.action == "add" then
        table.insert(list, {
            name         = self.contactData.name         or "",
            farmName     = self.contactData.farmName     or "",
            phone        = self.contactData.phone        or "",
            notes        = self.contactData.notes        or "",
            playerUserId = self.contactData.playerUserId or 0,
        })
        print(string.format("[InvoiceEvents] Contact added for userId %d: %s",
            userId, self.contactData.name or "?"))
    elseif self.action == "delete" then
        local idx = self.contactIndex
        if idx >= 1 and idx <= #list then
            table.remove(list, idx)
            print(string.format("[InvoiceEvents] Contact #%d deleted for userId %d", idx, userId))
        end
    end

    RoleplayPhone:saveContacts()
end

InvoiceEvents.ContactEvent = RI_ContactEvent


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: ContactSync — host sends full contact list to a connecting client
-- ─────────────────────────────────────────────────────────────────────────────

if RI_ContactSyncEvent == nil then
    RI_ContactSyncEvent    = {}
    RI_ContactSyncEvent_mt = Class(RI_ContactSyncEvent, Event)
    InitEventClass(RI_ContactSyncEvent, "RI_ContactSyncEvent")
end

function RI_ContactSyncEvent.emptyNew()
    return Event.new(RI_ContactSyncEvent_mt)
end

function RI_ContactSyncEvent.new(contacts)
    local self = RI_ContactSyncEvent.emptyNew()
    self.contacts = contacts or {}
    return self
end

function RI_ContactSyncEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, #self.contacts)
    for _, c in ipairs(self.contacts) do
        streamWriteString(streamId, c.name         or "")
        streamWriteString(streamId, c.farmName     or "")
        streamWriteString(streamId, c.phone        or "")
        streamWriteString(streamId, c.notes        or "")
        streamWriteInt32(streamId,  c.playerUserId or 0)
    end
end

function RI_ContactSyncEvent:readStream(streamId, connection)
    local count = streamReadInt32(streamId)
    self.contacts = {}
    for i = 1, count do
        table.insert(self.contacts, {
            name         = streamReadString(streamId),
            farmName     = streamReadString(streamId),
            phone        = streamReadString(streamId),
            notes        = streamReadString(streamId),
            playerUserId = streamReadInt32(streamId),
        })
    end
    self:run(connection)
end

function RI_ContactSyncEvent:run(connection)
    if g_server ~= nil then return end
    ContactManager.contacts = self.contacts
    print(string.format("[InvoiceEvents] ContactSync: loaded %d contacts from host",
        #self.contacts))
end

InvoiceEvents.ContactSyncEvent = RI_ContactSyncEvent

-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: WeatherForecast — host sends forecast data to clients
-- forecast = { [relDay] = { typeName, minTemp, maxTemp } }
-- ─────────────────────────────────────────────────────────────────────────────

if RI_WeatherForecastEvent == nil then
    RI_WeatherForecastEvent    = {}
    RI_WeatherForecastEvent_mt = Class(RI_WeatherForecastEvent, Event)
    InitEventClass(RI_WeatherForecastEvent, "RI_WeatherForecastEvent")
end

function RI_WeatherForecastEvent.emptyNew()
    return Event.new(RI_WeatherForecastEvent_mt)
end

function RI_WeatherForecastEvent.new(forecast)
    local self = RI_WeatherForecastEvent.emptyNew()
    self.forecast = forecast or {}
    return self
end

function RI_WeatherForecastEvent:writeStream(streamId, connection)
    -- Count valid entries
    local entries = {}
    for relDay, data in pairs(self.forecast) do
        table.insert(entries, { relDay=relDay, data=data })
    end
    streamWriteInt32(streamId, #entries)
    for _, e in ipairs(entries) do
        streamWriteInt32(streamId,  e.relDay)
        streamWriteString(streamId, e.data.typeName or "")
        streamWriteFloat32(streamId, e.data.minTemp or -999)
        streamWriteFloat32(streamId, e.data.maxTemp or -999)
    end
end

function RI_WeatherForecastEvent:readStream(streamId, connection)
    local count = streamReadInt32(streamId)
    self.forecast = {}
    for i = 1, count do
        local relDay  = streamReadInt32(streamId)
        local tn      = streamReadString(streamId)
        local minTemp = streamReadFloat32(streamId)
        local maxTemp = streamReadFloat32(streamId)
        self.forecast[relDay] = {
            typeName = tn,
            minTemp  = minTemp ~= -999 and minTemp or nil,
            maxTemp  = maxTemp ~= -999 and maxTemp or nil,
        }
    end
    self:run(connection)
end

function RI_WeatherForecastEvent:run(connection)
    if g_server ~= nil then return end
    -- Store forecast and set cacheDay to current day so it won't be invalidated
    local env = g_currentMission and g_currentMission.environment
    local currentDay = env and env.currentDay or 0
    RoleplayPhone._forecastCache    = self.forecast
    RoleplayPhone._forecastCacheDay = currentDay
    local count = 0
    for _ in pairs(self.forecast) do count = count + 1 end
    print(string.format("[InvoiceEvents] WeatherForecast: received %d days from host", count))
end

InvoiceEvents.WeatherForecastEvent = RI_WeatherForecastEvent

-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: CallHistorySync — host sends relevant call history to a connecting client
-- Entries: { name, phone, direction, gameDay, gameTime, count }
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
    if g_server ~= nil then return end  -- only clients process this
    if #self.entries > 0 then
        RoleplayPhone.callHistory = self.entries
        print(string.format("[RoleplayPhone] Call history sync: received %d entries", #self.entries))
    end
end

InvoiceEvents.CallHistorySyncEvent = RI_CallHistorySyncEvent
