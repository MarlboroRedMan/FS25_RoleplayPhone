# RoleplayPhone — F8 in-vehicle answer handoff

**Continued from 2026-05-17 session 3 (Opus + Project)**
**Build at handoff: post-0.4.3 with untested Lua-syntax edits. Test pending.**

---

## Goal (unchanged)

F8 must answer/end calls in **both** on-foot and in-vehicle contexts. On-foot has worked the entire time. In-vehicle has not. The phone UI is intentionally NOT openable in vehicle (character freezes on foot to allow mouse operation; in-vehicle F8 is a UI-less keybind for call answer/hangup only).

---

## Current code state at handoff

### modDesc.xml

```xml
<action name="RI_OPEN_PHONE"          category="ONFOOT VEHICLE" axisType="BUTTON"/>
<action name="RI_CALL_ACTION"         axisType="BUTTON" category="ONFOOT"/>
<action name="RI_CALL_ACTION_VEHICLE" axisType="BUTTON" category="VEHICLE"/>

<actionBinding action="RI_CALL_ACTION">         <binding device="KB_MOUSE_DEFAULT" input="KEY_f8"/></actionBinding>
<actionBinding action="RI_CALL_ACTION_VEHICLE"> <binding device="KB_MOUSE_DEFAULT" input="KEY_f8"/></actionBinding>
```

l10n: `input_RI_OPEN_PHONE` and `input_RI_CALL_ACTION` present. `input_RI_CALL_ACTION_VEHICLE` absent (engine emits a warning at startup, no other observed effect).

### RoleplayPhone.lua — `registerKeybind`

Single `beginActionEventsModification("PLAYER")` / `endActionEventsModification` block. Registers RI_OPEN_PHONE → `RoleplayPhone.toggle` and RI_CALL_ACTION → `RoleplayPhone.callAction`. Target `RoleplayPhone` for both. Both succeed in PLAYER context.

A `PlayerInputComponent.registerActionEvents` appended hook is also present, intended to re-register RI_CALL_ACTION on context switches. **The hook's "re-registered" print does NOT appear in any captured log** — either the hook isn't firing on context switches, or the guards (`isOwner`, `inputRegistered`) short-circuit. Worth checking but not the primary lead.

### RoleplayPhoneVehicleSpec.lua (current — Project's post-0.4.3 edits, untested)

```lua
function RoleplayPhoneVehicleSpec.prerequisitesPresent(specializations)
    return true            -- was: Drivable+Enterable+Motorized check; changed to match EV's pattern
end

-- registerFunctions: REMOVED entirely (was empty; Project removed to match EV)

function RoleplayPhoneVehicleSpec.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", RoleplayPhoneVehicleSpec)
end

function RoleplayPhoneVehicleSpec:onRegisterActionEvents(isSelected, isOnActiveVehicle)
    if not self.isClient then return end
    if isOnActiveVehicle and self:getIsControlled() then
        local _, eventName = g_inputBinding:registerActionEvent(
            "RI_CALL_ACTION_VEHICLE", self,
            RoleplayPhoneVehicleSpec.onCallAction,
            false, true, false, true)
        if eventName then
            g_inputBinding:setActionEventTextVisibility(eventName, false)
            print("[RoleplayPhoneVehicleSpec] registered: " .. tostring(eventName))
        end
    end
end

-- Declared with dot (was colon). Behaviorally identical in Lua — see "Things NOT to retry".
function RoleplayPhoneVehicleSpec.onCallAction(self, actionName, keyStatus, ...)
    print("[RoleplayPhoneVehicleSpec] onCallAction fired")
    if RoleplayPhone and RoleplayPhone.callAction then
        RoleplayPhone:callAction()
    end
end

-- installSpecializations: unchanged
```

### Bootstrap.lua

`installSpecializations` is now called from a `Utils.prependedFunction` on `TypeManager.validateTypes`, gated on `types.typeName == "vehicle"`. This was Project's recent change. It is harmless but unnecessary — see "Verified true today."

---

## Verified true today (with log evidence — 0.4.3)

- ✅ **Spec installs.** Line 373: `[RoleplayPhoneVehicleSpec] Installed on 38 vehicle types`. With install at module-load OR via TypeManager.validateTypes — both work; vehicle type system is ready by the time Bootstrap.lua loads.
- ✅ **modDesc parses RI_CALL_ACTION_VEHICLE.** Engine emits `Warning: Missing l10n 'input_RI_CALL_ACTION_VEHICLE'` at line 282, proving the action node was read.
- ✅ **Spec's `onRegisterActionEvents` fires every vehicle entry.** Lines 2013/2029/2040/2044 all print `registered: RI_CALL_ACTION_VEHICLE|table: 0x000001be2fdbc118|1` with the same vehicle-context table address.
- ✅ **`g_inputBinding:registerActionEvent` returns a valid event name in vehicle context.** The print only fires if the registration call returned non-nil.
- ✅ **PLAYER-context registrations don't share a "slot" — they coexist.** RI_OPEN_PHONE and RI_CALL_ACTION print with the same target table address but are independent named actions; both dispatch correctly on-foot.
- ✅ **F8 on-foot answers/ends calls.** `callAction fired, state=10` then `state=11` in the 0.4.2 log.
- ✅ **F7 in vehicle does NOTHING.** Confirmed by Dan in session 3. Despite `category="ONFOOT VEHICLE"` on RI_OPEN_PHONE, the PLAYER-context registration is not dispatched in vehicle. This is by design here (no UI in vehicle), but the dispatch fact matters: **category="ONFOOT VEHICLE" on a PLAYER-context registration is NOT sufficient to carry dispatch into vehicle context.**

---

## What's broken (observed in 0.4.3 log)

Timeline around the test:
```
16:38:26.530  spec re-registered (Dan in vehicle)
16:38:35.918  Incoming call from jacks
16:39:05.924  Missed call notification (30s timeout)
```

No `callAction fired` print. No `[RoleplayPhoneVehicleSpec] onCallAction fired` print. F8 in vehicle reached zero listeners.

Conclusion: registration is succeeding at the API level, but the engine is not routing the F8 keypress to the spec's registered listener. This is the gap.

---

## Dead paths — DO NOT retry (added to handoff #2's list)

Already ruled out in earlier sessions: see prior handoff entries 1–7.

New as of session 3:

8. **`TypeManager.validateTypes` prepended hook for installSpecializations timing.** No effect — install was already working at module-load time; the log proves the spec attaches to 38 types and onRegisterActionEvents fires every entry. Project's change is harmless but solves a non-problem. **Worth reverting** for cleanliness; not required.
9. **PLAYER-context single registration with `category="ONFOOT VEHICLE"` expecting in-vehicle dispatch.** F7 proves this doesn't work in FS25. PLAYER-context registrations do not dispatch when player is in a vehicle, regardless of the action's declared category.
10. **Colon-vs-dot function declaration in Lua.** `function T:foo(a)` and `function T.foo(self, a)` produce *the same function value*. There is no semantic difference and no engine-level behavior tied to the declaration syntax. Project's pending test isolates this as the "real fix" — it is not. The pending test should still be run because it's already staged, but expect the same null result as 0.4.3.
11. **Removing an empty `registerFunctions`.** Lua and the FS25 specialization system both tolerate empty functions; this is cosmetic.
12. **Changing `prerequisitesPresent` to `return true`.** Affects which vehicle types the spec attaches to (would attach to non-drivable types). Does not affect dispatch on tractors, which already had the spec attached.

---

## What to actually do in the next conversation

**Stop theorizing. Read the working reference.** Every "fix" attempted across three sessions has been a theory-first patch followed by a failed test. The break in that pattern is to read EV's full spec file end-to-end, not snippets, and compare structurally against ours.

### Concrete plan

1. **Extract `C:\Users\danbj\Downloads\FS25_EnhancedVehicle.zip`** to a temp location and locate the vehicle-spec Lua file(s). The handoff's working-reference line is line 1411 of `FS25_EnhancedVehicle.lua`, but that's the registration call only — context around it matters more.

2. **Diff our spec against EV's, comprehensively.** Specifically look at:
   - Full list of events EV registers via `registerEventListeners` — we only register `onRegisterActionEvents`; EV probably registers more (`onLoad`, `onReadStream`, etc.) and one of them may be required for the action-event subsystem to consider the spec "live."
   - Whether EV initializes a spec-local table in `onLoad` (e.g., `spec.actionEvents = {}`) and stores the returned event ID there. The Giants vehicle input subsystem traditionally tracks event IDs in `spec_<name>.actionEvents`; if it walks those tables to determine what to dispatch, a registration NOT in such a table might be invisible to dispatch even though `g_inputBinding` accepted it.
   - Anything EV does AFTER `registerActionEvent` returns (text visibility, priority, icon, ignore-collisions flag).
   - The exact value of the four boolean trailing args. Spec passes `false, true, false, true`. EV's line 1411 supposedly matches — but verify all four.

3. **Check `_reference/` for the dataS source on input dispatch.** Specifically `dataS/scripts/input/InputBinding.lua` and `dataS/scripts/vehicles/Vehicle.lua` — search for how the engine resolves a keypress to a listener in vehicle context. Look for any code path that walks `spec.actionEvents` tables vs. global `g_inputBinding` registrations. That will answer whether the "must be in spec.actionEvents" theory holds.

4. **Verify `category="VEHICLE"` is the correct category string** by grepping the dataS Lua for action category values. It's possible FS25 uses a different keyword (`DRIVING`, `INVEHICLE`, etc.) and "VEHICLE" silently parses but never matches dispatch.

5. **Only after the above reading**, propose a single-variable change and test. No more multi-change zips.

### Reference paths

- **EV zip**: `C:\Users\danbj\Downloads\FS25_EnhancedVehicle.zip`
- **Mod source**: `C:\Users\danbj\Documents\V0.1.1\FS25_RoleplayPhone\`
- **dataS reference**: `C:\Users\danbj\Documents\V0.1.1\_reference\`
- **Working zip in mods folder**: whatever Dan has deployed (rezip after every change)
- **Game log**: standard FS25 log location

---

## Workflow / diagnostic discipline (lessons from sessions 2–3)

- **Read evidence before theorizing.** Both Project and Opus have proposed fixes that the existing logs already disproved. Always check the captured log for what's actually firing before naming a cause.
- **One variable per test.** Bundled changes (begin/end block + category change; or prerequisites + registerFunctions + colon-vs-dot all at once) destroy diagnostic value.
- **"Matches at line 1411" is not "matches EV."** A single-line agreement on the registration call does not mean the surrounding structure matches. The actual reference is the full file.
- **Lua syntax sugar is sugar.** Don't claim semantic differences between colon and dot method declarations.
- **Conversation length matters.** Both prior handoff and this one were prompted by deep debugging cycles burning context. Reset early with a tight handoff; don't push a stale thread.

---

## Things NOT to do

- ❌ Don't re-litigate any path in the dead-paths list (1–12)
- ❌ Don't propose another fix without first reading EV's full spec file end-to-end
- ❌ Don't make multi-change builds — isolate one variable per test
- ❌ Don't claim colon-vs-dot Lua declarations are semantically different — they aren't
- ❌ Don't blame install timing — the log proves install works
- ❌ Don't expect category="ONFOOT VEHICLE" + PLAYER-only registration to dispatch in vehicle — F7 disproves it
- ❌ Don't extract the EV zip into the mod folder or any version-controlled location — use a temp directory
