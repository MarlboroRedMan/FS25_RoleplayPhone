-- scripts/PhoneVoice.lua
-- Voice chat management: muting, volume control, RP voice mode, mic input mode.
-- All voice-related functions live here. PhoneCallLogic calls into this file.

-- ─── CONSTANTS ────────────────────────────────────────────────────────────────
-- VoiceChatRecordingMode: DISABLED=0, MUTED=1, ALWAYS=2, AUTOMATIC=3, TEST=4
-- VoiceChatConnectionStatus: SILENT=0, ACTIVE=1, UNAVAILABLE=2

-- ─── PROXIMITY VOICE CONSTANTS ────────────────────────────────────────────────
local PROX_MIN_DIST = 3.0    -- within this distance (m), vol = 1.0
local PROX_MAX_DIST = 20.0   -- beyond this distance (m), vol = 0.0
local PROX_POLL_MS  = 500    -- proximity rebuild interval (milliseconds)

-- ─── VOICE AVAILABILITY ───────────────────────────────────────────────────────

function RoleplayPhone:isVoiceAvailable()
    return g_currentMission ~= nil and g_currentMission.userManager ~= nil
end

-- ─── SPEAKER DISPLAY OVERRIDE ─────────────────────────────────────────────────
-- Suppress the FS25 speaking indicator when rpVoiceMode is active.
-- In RP mode the mic is muted unless in an active call, so the indicator
-- showing would be misleading. Guard with existence check — logs a warning
-- if the class isn't found so we know immediately if the name changed.
if SpeakerDisplay and SpeakerDisplay.draw then
    SpeakerDisplay.draw = Utils.overwrittenFunction(SpeakerDisplay.draw,
        function(self, superFunc, ...)
            if RoleplayPhone.settings and RoleplayPhone.settings.rpVoiceMode then
                return
            end
            superFunc(self, ...)
        end
    )
    print("[PhoneVoice] SpeakerDisplay.draw override installed")
else
    print("[PhoneVoice] WARNING: SpeakerDisplay or .draw not found — speaking indicator override skipped")
end

-- ─── RINGTONE ─────────────────────────────────────────────────────────────────

function RoleplayPhone:stopRingtone()
    if self.ringSample        and self.ringSample        ~= 0 then stopSample(self.ringSample,        0, 0) end
    if self.ringbackSample    and self.ringbackSample    ~= 0 then stopSample(self.ringbackSample,    0, 0) end
    if self.unavailableSample and self.unavailableSample ~= 0 then stopSample(self.unavailableSample, 0, 0) end
end

-- ─── CALL ISOLATION ───────────────────────────────────────────────────────────
-- activeCalls is a list of {userIdA, userIdB} pairs maintained by all peers.
-- On any change, rebuildVoiceIsolation() recomputes volumes for every user.
-- Uses voiceChatSetUserVolume with the correct voice UUID (user:getUniqueUserId()),
-- not the volatile integer userId. This was the root cause of all previous failures.

function RoleplayPhone:rebuildVoiceIsolation()
    if not self:isVoiceAvailable() then return end
    local myId = self:getMyUserId()
    local pairStr = ""
    for i, pair in ipairs(self.activeCalls) do
        pairStr = pairStr .. string.format("{%d,%d}", pair[1], pair[2])
        if i < #self.activeCalls then pairStr = pairStr .. "," end
    end
    print(string.format("[PhoneVoice] rebuildVoiceIsolation: myId=%d activeCalls=[%s]", myId, pairStr))
    self:_applyProximityVolumes()
end

function RoleplayPhone:addActiveCall(userIdA, userIdB)
    -- Idempotent: check pair doesn't already exist before adding
    for _, pair in ipairs(self.activeCalls) do
        if (pair[1] == userIdA and pair[2] == userIdB)
        or (pair[1] == userIdB and pair[2] == userIdA) then
            print(string.format("[PhoneVoice] addActiveCall: {%d,%d} already exists, skipping", userIdA, userIdB))
            return
        end
    end
    table.insert(self.activeCalls, { userIdA, userIdB })
    print(string.format("[PhoneVoice] addActiveCall: added {%d,%d}, total pairs=%d", userIdA, userIdB, #self.activeCalls))
    self:rebuildVoiceIsolation()
end

function RoleplayPhone:removeActiveCall(userIdA, userIdB)
    for i, pair in ipairs(self.activeCalls) do
        if (pair[1] == userIdA and pair[2] == userIdB)
        or (pair[1] == userIdB and pair[2] == userIdA) then
            table.remove(self.activeCalls, i)
            print(string.format("[PhoneVoice] removeActiveCall: removed {%d,%d}, total pairs=%d", userIdA, userIdB, #self.activeCalls))
            break
        end
    end
    self:rebuildVoiceIsolation()
end

-- ─── PROXIMITY VOLUME APPLICATION ─────────────────────────────────────────────
-- Core function: called by rebuildVoiceIsolation (immediate, on call events)
-- and updateProximityVoice (polled every PROX_POLL_MS ms).
--
-- Rules applied per user:
--   call partner        → vol 1.0 always (regardless of distance)
--   in a different call → vol 0.0 (isolation between concurrent calls)
--   bystander (calls active) → vol based on their distance to nearest call participant
--   no active calls anywhere → vol based on plain bilateral proximity (me <-> them)
--
-- Position data: g_currentMission.players includes remote players on every client.
-- Confirmed via Dog.lua in decompiled engine source (getWorldTranslation on remote rootNode).

local function _dist3(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

function RoleplayPhone:_distanceToVolume(dist)
    if dist <= PROX_MIN_DIST then return 1.0 end
    if dist >= PROX_MAX_DIST then return 0.0 end
    return 1.0 - (dist - PROX_MIN_DIST) / (PROX_MAX_DIST - PROX_MIN_DIST)
end

function RoleplayPhone:_applyProximityVolumes()
    if not self:isVoiceAvailable() then return end
    local myId = self:getMyUserId()

    -- Build position map: userId -> {x,y,z}
    -- g_currentMission.players contains all players (local + remote); rootNode is valid client-side.
    local positions = {}
    if g_currentMission and g_currentMission.players then
        for _, player in pairs(g_currentMission.players) do
            if player.userId and player.rootNode and player.rootNode ~= 0 then
                local x, y, z = getWorldTranslation(player.rootNode)
                positions[player.userId] = { x = x, y = y, z = z }
            end
        end
    end
    local myPos = positions[myId]

    -- Build call participation sets
    local myPartner       = nil  -- session userId of my call partner, nil if not in a call
    local callParticipants = {}  -- userId -> true for anyone in any active call
    for _, pair in ipairs(self.activeCalls) do
        local A, B = pair[1], pair[2]
        callParticipants[A] = true
        callParticipants[B] = true
        if     A == myId then myPartner = B
        elseif B == myId then myPartner = A end
    end

    local users = g_currentMission.userManager:getUsers()
    for _, user in pairs(users) do
        local uid = user:getId()
        if uid ~= myId then
            local vol

            if uid == myPartner then
                -- Call partner: always full volume, distance irrelevant
                vol = 1.0

            elseif callParticipants[uid] then
                -- In a different concurrent call: full isolation
                vol = 0.0

            else
                -- Bystander (or nobody is in a call anywhere)
                local theirPos = positions[uid]
                if not theirPos or not myPos then
                    vol = 1.0  -- position unknown -> fail open
                elseif #self.activeCalls > 0 then
                    -- There are active calls. Bystander volume = their distance to the
                    -- nearest call participant. Simulates voice bleeding into a call
                    -- if the bystander is physically near someone on the phone.
                    local minDist = math.huge
                    for _, pair in ipairs(self.activeCalls) do
                        for _, pid in ipairs({ pair[1], pair[2] }) do
                            local pPos = positions[pid]
                            if pPos then
                                local d = _dist3(theirPos, pPos)
                                if d < minDist then minDist = d end
                            end
                        end
                    end
                    vol = (minDist < math.huge) and self:_distanceToVolume(minDist) or 1.0
                else
                    -- No active calls: plain proximity between me and them
                    vol = self:_distanceToVolume(_dist3(myPos, theirPos))
                end
            end

            local uuid = user:getUniqueUserId()
            pcall(voiceChatSetUserVolume, uuid, vol)
        end
    end
end

-- Polled from Mission00.update every PROX_POLL_MS milliseconds.
-- Handles continuous volume updates as players move around.
function RoleplayPhone:updateProximityVoice(dt)
    if not self.settings or not self.settings.rpVoiceMode then return end
    self.proximityTimer = (self.proximityTimer or 0) + dt
    if self.proximityTimer < PROX_POLL_MS then return end
    self.proximityTimer = 0
    self:_applyProximityVolumes()
end

-- ─── MIC INPUT MODE ───────────────────────────────────────────────────────────

function RoleplayPhone:applyVoiceMode()
    if not self:isVoiceAvailable() then
        print("[PhoneVoice] Voice unavailable — skipping applyVoiceMode")
        return
    end
    -- If rpVoiceMode is off the mod does not manage voice at all.
    -- FS25 uses whatever the player has set (PTT, voice activity, etc.).
    if not self.settings.rpVoiceMode then
        print("[PhoneVoice] rpVoiceMode off — voice not managed by mod")
        return
    end
    -- rpVoiceMode on: mic is always hot. Voice isolation is handled entirely
    -- through per-user volume in _applyProximityVolumes — no recording mode
    -- changes during calls. This call is only for load and settings toggle.
    local ok, err = pcall(voiceChatSetRecordingMode, VoiceChatRecordingMode.ALWAYS)
    if not ok then
        print("[PhoneVoice] setRecordingMode ALWAYS failed: " .. tostring(err))
    else
        print("[PhoneVoice] Mic ALWAYS (rpVoiceMode active)")
    end
end

-- ─── SERVER CONFIG BROADCAST ──────────────────────────────────────────────────

function RoleplayPhone:broadcastServerConfig()
    if g_server == nil then return end
    local evt = RI_ServerConfigEvent.new(self.settings.rpVoiceMode)
    g_server:broadcastEvent(evt)
    print("[PhoneVoice] Broadcast ServerConfig: rpVoiceMode=" .. tostring(self.settings.rpVoiceMode))
end


