-- scripts/CarrierBotEvents.lua
-- Network events for the Carrier Bot feature.
--   RI_CarrierMessageEvent  — server → client: push a carrier message (welcome or auto-reply)
--   RI_CarrierReplyEvent    — client → server: player replied to the carrier thread

-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: CarrierMessage — server pushes a carrier bot message to a client
-- ─────────────────────────────────────────────────────────────────────────────

if RI_CarrierMessageEvent == nil then
    RI_CarrierMessageEvent    = {}
    RI_CarrierMessageEvent_mt = Class(RI_CarrierMessageEvent, Event)
    InitEventClass(RI_CarrierMessageEvent, "RI_CarrierMessageEvent")
end

function RI_CarrierMessageEvent.emptyNew()
    return Event.new(RI_CarrierMessageEvent_mt)
end

function RI_CarrierMessageEvent.new(carrierName, carrierPhone, text, gameDay, gameTime)
    local self = RI_CarrierMessageEvent.emptyNew()
    self.carrierName  = carrierName  or ""
    self.carrierPhone = carrierPhone or ""
    self.text         = text         or ""
    self.gameDay      = gameDay      or 0
    self.gameTime     = gameTime     or 0
    return self
end

function RI_CarrierMessageEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.carrierName  or "")
    streamWriteString(streamId, self.carrierPhone or "")
    streamWriteString(streamId, self.text         or "")
    streamWriteInt32(streamId,  self.gameDay      or 0)
    streamWriteInt32(streamId,  self.gameTime     or 0)
end

function RI_CarrierMessageEvent:readStream(streamId, connection)
    self.carrierName  = streamReadString(streamId)
    self.carrierPhone = streamReadString(streamId)
    self.text         = streamReadString(streamId)
    self.gameDay      = streamReadInt32(streamId)
    self.gameTime     = streamReadInt32(streamId)
    self:run(connection)
end

function RI_CarrierMessageEvent:run(connection)
    RoleplayPhone.messageDisplayNames["u_carrier_bot"] = {
        name   = self.carrierName,
        phone  = self.carrierPhone,
        userId = 0,
    }
    RoleplayPhone:receiveMessage("u_carrier_bot", 0, self.carrierName,
        self.text, self.gameDay, false, self.gameTime)
end


-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT: CarrierReply — client tells server the player replied to the carrier
-- ─────────────────────────────────────────────────────────────────────────────

if RI_CarrierReplyEvent == nil then
    RI_CarrierReplyEvent    = {}
    RI_CarrierReplyEvent_mt = Class(RI_CarrierReplyEvent, Event)
    InitEventClass(RI_CarrierReplyEvent, "RI_CarrierReplyEvent")
end

function RI_CarrierReplyEvent.emptyNew()
    return Event.new(RI_CarrierReplyEvent_mt)
end

function RI_CarrierReplyEvent.new(text)
    local self = RI_CarrierReplyEvent.emptyNew()
    self.text = text or ""
    return self
end

function RI_CarrierReplyEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.text or "")
end

function RI_CarrierReplyEvent:readStream(streamId, connection)
    self.text = streamReadString(streamId)
    self:run(connection)
end

function RI_CarrierReplyEvent:run(connection)
    -- Find the sender's uniqueId via their connection
    local ps     = g_currentMission and g_currentMission.playerSystem
    local player = ps and ps:getPlayerByConnection(connection)
    if player == nil then return end
    local senderUserId = player.userId

    -- onlineUsers is keyed by userId integer → {farmId, name, phone, uniqueId}
    local info = RoleplayPhone.onlineUsers[senderUserId]
    local senderUniqueId = info and info.uniqueId or nil
    if senderUniqueId == nil then
        print("[CarrierBot] RI_CarrierReplyEvent: could not resolve uniqueId for userId " .. tostring(senderUserId))
        return
    end

    -- Store sender's outgoing message server-side
    if RoleplayPhone.playerMessages[senderUniqueId] == nil then
        RoleplayPhone.playerMessages[senderUniqueId] = {}
    end
    if RoleplayPhone.playerMessages[senderUniqueId]["out_carrier_bot"] == nil then
        RoleplayPhone.playerMessages[senderUniqueId]["out_carrier_bot"] = {}
    end
    table.insert(RoleplayPhone.playerMessages[senderUniqueId]["out_carrier_bot"], {
        fromUniqueId = senderUniqueId,
        senderName   = info.name or "",
        text         = self.text,
        gameDay      = g_currentMission.environment.currentDay,
        gameTime     = math.floor(g_currentMission.environment.dayTime / 60000),
        sent         = true,
        msgType      = "text",
        cardName     = "",
        cardPhone    = "",
        cardFarm     = "",
    })

    -- Trigger auto-reply from server
    RoleplayPhone:carrierBotAutoReply(senderUniqueId, self.text, connection)
end
