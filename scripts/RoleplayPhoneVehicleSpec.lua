-- scripts/RoleplayPhoneVehicleSpec.lua
-- Vehicle specialization that registers RI_CALL_ACTION (F10) in vehicle
-- input context, enabling call answer/end while the player is driving.
--
-- Structure mirrors FS25_EnhancedVehicle exactly:
--   - No registerFunctions (EV has none)
--   - prerequisitesPresent returns true (EV pattern)
--   - g_inputBinding:registerActionEvent with self (vehicle) as target
--   - Installed via TypeManager.validateTypes hook (EV's exact timing)

RoleplayPhoneVehicleSpec = {}

-- ─── prerequisitesPresent ─────────────────────────────────────────────────────
-- EV returns true unconditionally — filter happens in installSpecializations.
function RoleplayPhoneVehicleSpec.prerequisitesPresent(specializations)
    return true
end

-- ─── registerEventListeners ───────────────────────────────────────────────────
-- Register all events EV registers so the engine considers this spec fully live.
-- onReadStream/onWriteStream are especially important in MP — without them the
-- engine may error during vehicle sync and silently break action dispatch.
function RoleplayPhoneVehicleSpec.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad",                   RoleplayPhoneVehicleSpec)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad",               RoleplayPhoneVehicleSpec)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream",             RoleplayPhoneVehicleSpec)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream",            RoleplayPhoneVehicleSpec)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream",       RoleplayPhoneVehicleSpec)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream",      RoleplayPhoneVehicleSpec)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents",   RoleplayPhoneVehicleSpec)
    SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle",          RoleplayPhoneVehicleSpec)
    SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle",          RoleplayPhoneVehicleSpec)
end

-- ─── onLoad / onPostLoad ──────────────────────────────────────────────────────
function RoleplayPhoneVehicleSpec:onLoad(savegame)
end

function RoleplayPhoneVehicleSpec:onPostLoad(savegame)
end

-- ─── network stream stubs ─────────────────────────────────────────────────────
-- Required for the engine to consider this spec valid in multiplayer.
-- We carry no per-vehicle state so these are intentional no-ops.
function RoleplayPhoneVehicleSpec:onReadStream(streamId, connection)
end

function RoleplayPhoneVehicleSpec:onWriteStream(streamId, connection)
end

function RoleplayPhoneVehicleSpec:onReadUpdateStream(streamId, timestamp, connection)
end

function RoleplayPhoneVehicleSpec:onWriteUpdateStream(streamId, connection, dirtyMask)
end

-- ─── enter / leave stubs ─────────────────────────────────────────────────────
function RoleplayPhoneVehicleSpec:onEnterVehicle()
end

function RoleplayPhoneVehicleSpec:onLeaveVehicle()
end

-- ─── onRegisterActionEvents ───────────────────────────────────────────────────
function RoleplayPhoneVehicleSpec:onRegisterActionEvents(isSelected, isOnActiveVehicle)
    if not self.isClient then return end

    if isOnActiveVehicle and self:getIsControlled() then
        -- ── Call action (F10) ─────────────────────────────────────────────────
        local _, eventName = g_inputBinding:registerActionEvent(
            "RI_CALL_ACTION",
            self,
            RoleplayPhoneVehicleSpec.onCallAction,
            false, true, false, true
        )
        if eventName then
            g_inputBinding:setActionEventTextVisibility(eventName, false)
        else
            print("[RoleplayPhoneVehicleSpec] WARNING: RI_CALL_ACTION registration returned nil")
        end

        -- ── Decline action (F9) ───────────────────────────────────────────────
        local _, declineName = g_inputBinding:registerActionEvent(
            "RI_DECLINE_ACTION",
            self,
            RoleplayPhoneVehicleSpec.onDeclineAction,
            false, true, false, true
        )
        if declineName then
            g_inputBinding:setActionEventTextVisibility(declineName, false)
        else
            print("[RoleplayPhoneVehicleSpec] WARNING: RI_DECLINE_ACTION registration returned nil")
        end
    end
end

-- ─── onCallAction ─────────────────────────────────────────────────────────────
function RoleplayPhoneVehicleSpec.onCallAction(self, actionName, keyStatus, arg4, arg5, arg6)
    if RoleplayPhone and RoleplayPhone.callAction then
        RoleplayPhone:callAction()
    end
end

-- ─── onDeclineAction ──────────────────────────────────────────────────────────
function RoleplayPhoneVehicleSpec.onDeclineAction(self, actionName, keyStatus, arg4, arg5, arg6)
    if RoleplayPhone and RoleplayPhone.declineAction then
        RoleplayPhone:declineAction()
    end
end

-- ─── installSpecializations ───────────────────────────────────────────────────
-- Called from TypeManager.validateTypes hook in Bootstrap.lua (EV's exact timing).
function RoleplayPhoneVehicleSpec.installSpecializations(vehicleTypeManager, specializationManager, modDirectory, modName)
    specializationManager:addSpecialization(
        "vehicleCallSpec",
        "RoleplayPhoneVehicleSpec",
        Utils.getFilename("scripts/RoleplayPhoneVehicleSpec.lua", modDirectory),
        nil
    )

    if specializationManager:getSpecializationByName("vehicleCallSpec") == nil then
        print("[RoleplayPhoneVehicleSpec] ERROR: addSpecialization failed")
        return
    end

    local count = 0
    for typeName, typeDef in pairs(vehicleTypeManager.types) do
        if SpecializationUtil.hasSpecialization(Drivable,  typeDef.specializations) and
           SpecializationUtil.hasSpecialization(Enterable, typeDef.specializations) and
           SpecializationUtil.hasSpecialization(Motorized, typeDef.specializations) and
           not SpecializationUtil.hasSpecialization(Locomotive,   typeDef.specializations) and
           not SpecializationUtil.hasSpecialization(ConveyorBelt, typeDef.specializations) then
            vehicleTypeManager:addSpecialization(typeName, modName .. ".vehicleCallSpec")
            count = count + 1
        end
    end

    print(string.format("[RoleplayPhoneVehicleSpec] Installed on %d vehicle types", count))
end
