-- scripts/CarrierBot.lua
-- Carrier Bot logic: welcome message on first join, keyword-matched auto-replies.
-- All methods are added to RoleplayPhone. No new global tables.
-- State lives in RoleplayPhone.settings (loaded from server_config.xml by PhoneSave.lua).

-- ─────────────────────────────────────────────────────────────────────────────
-- Send the welcome message to a player who just connected for the first time.
-- uniqueId   — the new player's uniqueId
-- playerName — their display name
-- fileId     — their registry fileId (not used here but kept for future use)
-- connection — their network connection, or nil if this is the host player
-- ─────────────────────────────────────────────────────────────────────────────
function RoleplayPhone:carrierBotSendWelcome(uniqueId, playerName, fileId, connection)
    local settings    = self.settings
    local carrierName = settings.carrierName    or "FarmNet"
    local carrierPhone = settings.carrierPhone  or "000-CARRIER"
    local welcomeText = settings.carrierWelcome or "Welcome to the server!"
    local gameDay     = g_currentMission.environment.currentDay
    local gameTime    = math.floor(g_currentMission.environment.dayTime / 60000)

    -- Store in player's persistent server-side messages so it survives reconnects
    if self.playerMessages[uniqueId] == nil then
        self.playerMessages[uniqueId] = {}
    end
    if self.playerMessages[uniqueId]["in_carrier_bot"] == nil then
        self.playerMessages[uniqueId]["in_carrier_bot"] = {}
    end
    table.insert(self.playerMessages[uniqueId]["in_carrier_bot"], {
        fromUniqueId = "carrier_bot",
        senderName   = carrierName,
        text         = welcomeText,
        gameDay      = gameDay,
        gameTime     = gameTime,
        sent         = false,
        msgType      = "text",
        cardName     = "",
        cardPhone    = "",
        cardFarm     = "",
    })

    if connection ~= nil then
        -- Remote client: deliver via network event
        connection:sendEvent(RI_CarrierMessageEvent.new(
            carrierName, carrierPhone, welcomeText, gameDay, gameTime))
    else
        -- Host player: apply directly to local state
        self.messageDisplayNames["u_carrier_bot"] = {
            name   = carrierName,
            phone  = carrierPhone,
            userId = 0,
        }
        self:receiveMessage("u_carrier_bot", 0, carrierName,
            welcomeText, gameDay, false, gameTime)
        if self.messages["u_carrier_bot"] == nil then
            self.messages["u_carrier_bot"] = {}
        end
    end

    print(string.format("[CarrierBot] Welcome sent to %s (%s)", playerName, uniqueId))
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Send an automatic reply to a player who messaged the carrier thread.
-- senderUniqueId — the replying player's uniqueId
-- senderText     — the text they sent
-- connection     — their network connection, or nil if this is the host player
-- ─────────────────────────────────────────────────────────────────────────────
function RoleplayPhone:carrierBotAutoReply(senderUniqueId, senderText, connection)
    local settings     = self.settings
    local carrierName  = settings.carrierName   or "FarmNet"
    local carrierPhone = settings.carrierPhone  or "000-CARRIER"
    local replyText    = self:carrierBotMatchKeyword(senderText)
    local gameDay      = g_currentMission.environment.currentDay
    local gameTime     = math.floor(g_currentMission.environment.dayTime / 60000)

    if connection ~= nil then
        -- Remote client: store server-side and deliver via event
        if self.playerMessages[senderUniqueId] == nil then
            self.playerMessages[senderUniqueId] = {}
        end
        if self.playerMessages[senderUniqueId]["in_carrier_bot"] == nil then
            self.playerMessages[senderUniqueId]["in_carrier_bot"] = {}
        end
        table.insert(self.playerMessages[senderUniqueId]["in_carrier_bot"], {
            fromUniqueId = "carrier_bot",
            senderName   = carrierName,
            text         = replyText,
            gameDay      = gameDay,
            gameTime     = gameTime,
            sent         = false,
            msgType      = "text",
            cardName     = "",
            cardPhone    = "",
            cardFarm     = "",
        })
        connection:sendEvent(RI_CarrierMessageEvent.new(
            carrierName, carrierPhone, replyText, gameDay, gameTime))
    else
        -- Host player: apply directly to local state
        self:receiveMessage("u_carrier_bot", 0, carrierName,
            replyText, gameDay, false, gameTime)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Match a player's text against keyword→reply pairs from settings.
-- Returns the matched reply, or the default fallback.
-- ─────────────────────────────────────────────────────────────────────────────
function RoleplayPhone:carrierBotMatchKeyword(text)
    local upper    = (text or ""):upper()
    local keywords = self.settings.carrierKeywords or {}
    for _, kw in ipairs(keywords) do
        if kw.k and upper:find(kw.k, 1, true) then
            return kw.r or ""
        end
    end
    return self.settings.carrierDefault or "Sorry, I didn't understand that."
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Persist the current carrier quick-config (name, phone, welcome, enabled flag).
-- Called from the Settings > Server tab Save button.
-- Keywords are not touched by the quick-config UI — edit server_config.xml directly.
-- ─────────────────────────────────────────────────────────────────────────────
function RoleplayPhone:saveCarrierQuickConfig()
    self:saveServerConfig()
    print("[CarrierBot] Quick config saved")
end
