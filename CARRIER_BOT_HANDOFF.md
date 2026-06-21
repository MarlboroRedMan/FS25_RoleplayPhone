# Carrier Bot — Implementation Handoff

## Files Created

### `scripts/CarrierBotEvents.lua`
Two network event classes:
- **`RI_CarrierMessageEvent`** (server→client): pushes a carrier bot message (welcome or auto-reply) to a remote client. On `run()` it sets `messageDisplayNames["u_carrier_bot"]` and calls `receiveMessage`.
- **`RI_CarrierReplyEvent`** (client→server): player replied to the carrier thread. On `run()` (server-side) it resolves the sender's `uniqueId` via `onlineUsers[userId].uniqueId` and calls `carrierBotAutoReply`.

### `scripts/CarrierBot.lua`
Four methods added to `RoleplayPhone`:
- `carrierBotSendWelcome(uniqueId, playerName, fileId, connection)` — stores welcome in `playerMessages` and delivers it (event for remote clients, direct `receiveMessage` for host).
- `carrierBotAutoReply(senderUniqueId, senderText, connection)` — same delivery pattern, text determined by keyword match.
- `carrierBotMatchKeyword(text)` — searches `settings.carrierKeywords` case-insensitively; returns matched reply or `settings.carrierDefault`.
- `saveCarrierQuickConfig()` — thin wrapper over `saveServerConfig()`.

---

## Files Modified

### `scripts/PhoneHelpers.lua`
- **`loadPlayerRegistry()`** (line ~535): added `welcomed = getXMLBool(...) or false` to the table.insert.
- **`savePlayerRegistry()`** (line ~568): added `setXMLBool(... "#welcomed", entry.welcomed or false)` to the write loop.
- **`getOrCreateRegistryEntry()`** (line ~603): added `welcomed = false` to the new-player entry table so new entries are properly initialised without a disk round-trip.

### `scripts/PhoneSave.lua`
- **`loadServerConfig()`**: on first-run path (no file yet) initialises all carrier defaults in memory before calling `saveServerConfig()`. On normal load, reads `carrierEnabled`, `carrierName`, `carrierPhone`, `carrierWelcome`, `carrierDefault`, and `keyword(n)#k`/`#r` pairs from `server_config.xml`.
- **`saveServerConfig()`**: writes all of the above back to `server_config.xml` alongside the existing `rpVoiceMode` key.

### `scripts/PlayerEvents.lua`
- **`RI_PlayerHelloEvent:run()`** (after `if data then … else … end`, before the closing `end` of `if self.uniqueId ~= ""`): added welcome trigger — if `carrierEnabled` and `not entry.welcomed`, sets `entry.welcomed = true`, saves registry, and calls `carrierBotSendWelcome`.
- **`RI_ServerConfigEvent.new()`**: added `carrierName`, `carrierPhone` parameters.
- **`RI_ServerConfigEvent:writeStream()`**: added two `streamWriteString` calls for the new fields.
- **`RI_ServerConfigEvent:readStream()`**: added two `streamReadString` calls.
- **`RI_ServerConfigEvent:run()`**: if `carrierName ~= ""`, populates `messageDisplayNames["u_carrier_bot"]` so clients know the carrier display name before any message arrives.
- **Call site** (line ~138): updated `RI_ServerConfigEvent.new(...)` to pass `settings.carrierName` and `settings.carrierPhone`.

### `scripts/MessageManager.lua`
- **`sendMessage()`**, guard check: changed `if not found then return end` → `if not found and toUniqueId ~= "carrier_bot" then return end` so the carrier thread isn't silently dropped.
- **`sendMessage()`**, before `receiveMessage`: inserted the carrier intercept block — if `toUniqueId == "carrier_bot"`, locally records the sent message, routes to `carrierBotAutoReply` (host) or `RI_CarrierReplyEvent` (client), then returns early.

### `scripts/MessageEvents.lua`
- **`RI_MessageSyncEvent:run()`** (the `messageDisplayNames[key] = …` assignment): wrapped in an existence check — if an existing entry already has a non-empty phone and the sync delivers an empty phone, only `name` and `userId` are updated. This preserves the carrier phone that was set by `RI_CarrierMessageEvent` before the sync arrives.

### `scripts/Bootstrap.lua`
- **Host init block** (after `loadPlayerData(filename, true)`): added carrier welcome for the host player (same `carrierEnabled + not entry.welcomed` gate).
- **After `messageDisplayNames` repopulation loop**: added carrier phone repair — if `messages["u_carrier_bot"]` exists and `settings.carrierPhone` is set, patches `messageDisplayNames["u_carrier_bot"].phone` so the phone number is correct after restart.

### `scripts/apps/SettingsApp.lua`
- **Tab bar**: made tab count dynamic — 3 tabs for clients, 4 tabs for host (`g_server ~= nil`). Tab width becomes `pw / tabCount`. Added "Server" tab drawing and hitbox.
- **Server tab content block**: new `elseif self.settingsTab == "server" and g_server ~= nil` branch with:
  - Carrier Bot on/off toggle (same two-button pattern as rpVoiceMode).
  - Carrier Name single-line `drawField`.
  - Welcome Message multi-line `drawField` (2× row height).
  - Save button calling `carrier_save` hitbox.
- Fields display `carrierForm.name` / `carrierForm.welcome` while editing (falling back to `settings.*` values).

### `scripts/PhoneInput.lua`
**Not in the original plan's file list — required deviation** (SettingsApp only draws; all input is handled in PhoneInput.lua per the existing architecture).

Added:
- `settings_tab_server` hitbox handler: sets `settingsTab = "server"`, resets `carrierForm` fields from current settings.
- `setting_carrier_toggle` handler: flips `settings.carrierEnabled`, calls `saveCarrierQuickConfig()`.
- `carrier_name_field` / `carrier_welcome_field` handlers: activate `carrierForm.activeField` and call `activateFieldCursor`.
- `carrier_save` handler: copies `carrierForm.name`/`welcome` into `settings.*`, saves.
- **Carrier form key handler block** (before final `return false`): full text-editing support (backspace, forward-delete, cursor movement, Ctrl+A/C/V, Tab to cycle fields, Enter to deactivate) — mirrors the `contactForm` handler exactly.
- **TEXT_INPUT context cleanup check**: added `carrierForm.activeField ~= nil and state == SETTINGS` to `hasActiveField`.

### `scripts/RoleplayPhone.lua`
**Not in the original plan's file list — required deviation** (initialisation of new state table).

Added `RoleplayPhone.carrierForm = { name=nil, welcome=nil, activeField=nil }` alongside the existing `contactForm` declaration.

### `modDesc.xml`
- Added `<sourceFile filename="scripts/CarrierBotEvents.lua"/>` after `WeatherEvents.lua`.
- Added `<sourceFile filename="scripts/CarrierBot.lua"/>` after `PhoneHelpers.lua`.

---

## Deviations from Plan

| # | Deviation | Reason |
|---|-----------|--------|
| 1 | `PhoneInput.lua` modified (not in plan's file list) | SettingsApp.lua is draw-only; all hitbox/keyboard handling lives in PhoneInput.lua. Without this, the Server tab would render but be completely non-interactive. |
| 2 | `RoleplayPhone.lua` modified (not in plan's file list) | `carrierForm` needs to be declared at table initialisation time alongside `contactForm`, or nil-checks guard every access. A single declaration here is cleaner. |
| 3 | `getOrCreateRegistryEntry()` sets `welcomed = false` on new entries | Plan only mentioned `loadPlayerRegistry` and `savePlayerRegistry`. Without this, newly created entries lack the `welcomed` field in memory until the next disk round-trip, causing `not entry.welcomed` to evaluate as `not nil` (true) on reconnect. |
| 4 | `loadServerConfig()` first-run path initialises carrier defaults in memory | Plan's first-run path called `saveServerConfig()` and returned, leaving carrier settings as `nil` in memory for the entire session. `saveServerConfig()` handles `nil` via `or` fallbacks so the file is written correctly, but in-memory state would have been wrong until next restart. |
| 5 | `RI_CarrierReplyEvent:run()` simplified uniqueId lookup | Plan had a for-loop checking `u.userId == senderUserId`, but `onlineUsers` entries don't have a `userId` field — the map key IS the userId. Fixed to direct lookup: `onlineUsers[senderUserId].uniqueId`. |
| 6 | `playerMessages["in_carrier_bot"]` is a table (array), not a single entry | Plan stored the welcome as `playerMessages[uniqueId]["in_carrier_bot"] = { ... }` (single table). The rest of the codebase stores `playerMessages[uid]["in_<uniqueId"]` as arrays (multiple messages). Using an array keeps the structure consistent and allows multiple carrier messages per player. |

---

## Things Needing Attention Before Testing

1. **Keywords are XML-only for now.** The quick-config UI (Settings > Server tab) only exposes enable, name, and welcome message. To add keyword→reply pairs, edit `server_config.xml` directly under the savegame's `FS25_RoleplayPhone/` folder:
   ```xml
   <serverConfig carrierEnabled="true" carrierName="FarmNet" ...>
     <keyword k="HELP" r="For help, contact the farm manager."/>
     <keyword k="RULES" r="Check the Discord for server rules."/>
   </serverConfig>
   ```
   Keywords are stored uppercase in memory; matching is case-insensitive.

2. **"Server" tab label is hardcoded English.** The other tabs use `g_i18n:getText(...)`. Add a `settings_tab_server` key to the localisation files if you want it translated. For now it renders "Server" in all locales.

3. **Welcome fires once per `uniqueId`, tracked in `roleplayers.xml`.** If you need to re-trigger welcomes (e.g. after testing), delete or set `welcomed="false"` on the relevant player entries in the savegame's `FS25_RoleplayPhone/roleplayers.xml`.

4. **Carrier messages are not persisted in the player's data file on reconnect.** The `playerMessages[uid]["in_carrier_bot"]` array is stored server-side for the session, but `savePlayerData` serialises messages by iterating the messages table — the `"in_carrier_bot"` thread key doesn't match the normal `"in_<uniqueId>"` pattern so it won't be written/read back. Players who rejoin will not see their old carrier messages. This is by design (welcome fires once via the `welcomed` flag, not by reading back old messages), but worth verifying is the intended behaviour.

5. **`playerSystem:getPlayerByConnection`** — verify this API exists and returns `.userId` in your FS25 version. It's used in `RI_CarrierReplyEvent:run()` mirroring the same pattern in `RI_DeleteThreadEvent:run()` (MessageEvents.lua line 276), so it should be fine.
