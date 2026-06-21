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
-- activeCalls is a list of groups: { {uid1, uid2, ...}, {uid3, uid4}, ... }
-- Each group is a variable-length array of session userIds currently in the same call.
-- A 1:1 call is simply a group with 2 members.
--
-- Uses voiceChatSetUserVolume with the correct voice UUID (user:getUniqueUserId()),
-- not the volatile integer userId. This was the root cause of all previous failures.

function RoleplayPhone:rebuildVoiceIsolation()
    if not self:isVoiceAvailable() then return end
    local myId = self:getMyUserId()

    -- Log current group state
    local groupStr = ""
    for i, group in ipairs(self.activeCalls) do
        groupStr = groupStr .. "{"
        for j, uid in ipairs(group) do
            groupStr = groupStr .. uid
            if j < #group then groupStr = groupStr .. "," end
        end
        groupStr = groupStr .. "}"
        if i < #self.activeCalls then groupStr = groupStr .. "," end
    end
    print(string.format("[PhoneVoice] rebuildVoiceIsolation: myId=%d activeCalls=[%s]", myId, groupStr))

    self:_applyProximityVolumes()

    -- Keep self.call.members in sync with current group membership (for UI display).
    -- This is the single source of truth — derived from activeCalls after each rebuild.
    if self.state == self.STATE.CALL_ACTIVE then
        self.call.members = {}
        for _, group in ipairs(self.activeCalls) do
            for _, uid in ipairs(group) do
                if uid == myId then
                    -- Copy the group (don't hold a reference to the activeCalls table)
                    for _, gid in ipairs(group) do
                        table.insert(self.call.members, gid)
                    end
                    break
                end
            end
            if #self.call.members > 0 then break end
        end
    end
end

-- addActiveCall: smart merge.
-- If A or B is already in a group, the other is added to that group.
-- If both are in groups, A's group absorbs B's group (merge).
-- If neither is in a group, a new {A, B} group is created.
-- Idempotent: adding an already-present member is a no-op.
function RoleplayPhone:addActiveCall(userIdA, userIdB)
    -- Find which group (if any) each userId belongs to
    local groupA, idxA = nil, nil
    local groupB, idxB = nil, nil
    for i, group in ipairs(self.activeCalls) do
        for _, uid in ipairs(group) do
            if uid == userIdA then groupA = group; idxA = i end
            if uid == userIdB then groupB = group; idxB = i end
        end
    end

    if groupA and groupB then
        if idxA == idxB then
            -- Both already in the same group — idempotent, nothing to do
            print(string.format("[PhoneVoice] addActiveCall: {%d,%d} already in same group, skipping", userIdA, userIdB))
            return
        end
        -- Merge groupB into groupA, then remove groupB
        for _, uid in ipairs(groupB) do
            table.insert(groupA, uid)
        end
        table.remove(self.activeCalls, idxB)
        print(string.format("[PhoneVoice] addActiveCall: merged groups for %d and %d, group size=%d", userIdA, userIdB, #groupA))

    elseif groupA then
        -- A is in a group, add B to it
        table.insert(groupA, userIdB)
        print(string.format("[PhoneVoice] addActiveCall: added %d to existing group (size=%d)", userIdB, #groupA))

    elseif groupB then
        -- B is in a group, add A to it
        table.insert(groupB, userIdA)
        print(string.format("[PhoneVoice] addActiveCall: added %d to existing group (size=%d)", userIdA, #groupB))

    else
        -- Neither in a group — create new 2-person group
        table.insert(self.activeCalls, { userIdA, userIdB })
        print(string.format("[PhoneVoice] addActiveCall: new group {%d,%d}", userIdA, userIdB))
    end

    self:rebuildVoiceIsolation()
end

-- removeActiveCall: remove a single member from their group.
-- Returns the remaining group members as a list (may be empty if group dissolved),
-- or nil if the userId was not found in any group.
-- The caller can use the return value to decide whether to notify remaining members.
function RoleplayPhone:removeActiveCall(userId)
    for i, group in ipairs(self.activeCalls) do
        for j, uid in ipairs(group) do
            if uid == userId then
                table.remove(group, j)

                -- Copy remaining members before potentially dissolving the group
                local remaining = {}
                for _, remaining_uid in ipairs(group) do
                    table.insert(remaining, remaining_uid)
                end

                if #group <= 1 then
                    -- Group dissolves (0 or 1 member left — 1-person call is not a call)
                    table.remove(self.activeCalls, i)
                    print(string.format("[PhoneVoice] removeActiveCall: %d left, group dissolved (remaining=%d)",
                        userId, #remaining))
                else
                    print(string.format("[PhoneVoice] removeActiveCall: %d left, group continues (remaining=%d)",
                        userId, #remaining))
                end

                self:rebuildVoiceIsolation()
                return remaining
            end
        end
    end
    -- Not found in any group
    print(string.format("[PhoneVoice] removeActiveCall: %d not found in any group", userId))
    return nil
end

-- ─── PROXIMITY VOLUME APPLICATION ─────────────────────────────────────────────
-- Core function: called by rebuildVoiceIsolation (immediate, on call events)
-- and updateProximityVoice (polled every PROX_POLL_MS ms).
--
-- Rules applied per user (from MY perspective):
--   in my group           → vol 1.0 always (call partners, regardless of distance)
--   in a different group  → vol 0.0 (call isolation between concurrent calls)
--   bystander, I'm in call→ vol based on THEIR distance to nearest call participant
--   no calls / I'm bystander → vol based on plain bilateral proximity (me ↔ them)
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

    -- Build group membership sets from activeCalls
    local myGroup         = {}  -- userId -> true for members of MY group (excluding me)
    local callParticipants = {} -- userId -> true for anyone in ANY active call
    local inACall         = false

    for _, group in ipairs(self.activeCalls) do
        local groupHasMe = false
        for _, uid in ipairs(group) do
            if uid == myId then groupHasMe = true; break end
        end

        for _, uid in ipairs(group) do
            callParticipants[uid] = true
            if groupHasMe and uid ~= myId then
                myGroup[uid] = true
                inACall = true
            end
        end
    end

    local users = g_currentMission.userManager:getUsers()
    for _, user in pairs(users) do
        local uid = user:getId()
        if uid ~= myId then
            local vol

            if myGroup[uid] then
                -- My call group member: always full volume, distance irrelevant
                vol = 1.0

            elseif inACall and callParticipants[uid] then
                -- In a DIFFERENT concurrent call (and I'm also in a call): full isolation
                vol = 0.0

            else
                -- Perspective-aware fallthrough
                local theirPos = positions[uid]
                if not theirPos or not myPos then
                    vol = 1.0  -- position unknown -> fail open
                elseif inACall and not callParticipants[uid] then
                    -- I'm in a call, they're a bystander → their proximity to nearest call participant.
                    -- Simulates mic ambient pickup: bystander bleeds in based on how close they
                    -- are to any call participant, not how close they are to the listener.
                    local minDist = math.huge
                    for _, group in ipairs(self.activeCalls) do
                        for _, pid in ipairs(group) do
                            local pPos = positions[pid]
                            if pPos then
                                local d = _dist3(theirPos, pPos)
                                if d < minDist then minDist = d end
                            end
                        end
                    end
                    vol = (minDist < math.huge) and self:_distanceToVolume(minDist) or 1.0
                else
                    -- I'm a bystander (they may be in a call, or nobody is in a call) → bilateral proximity
                    vol = self:_distanceToVolume(_dist3(myPos, theirPos))
                end
            end

            local uuid = user:getUniqueUserId()
            pcall(voiceChatSetUserVolume, uuid, vol)
        end
    end
end

-- Polled from Mission00.update every PROX_POLL_MS milliseconds.
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
    if not self.settings.rpVoiceMode then
        print("[PhoneVoice] rpVoiceMode off — voice not managed by mod")
        return
    end
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
