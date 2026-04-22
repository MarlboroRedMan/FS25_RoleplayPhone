# FS25_RoleplayPhone — Development Roadmap

No timeline, no version pressure — build it right, build it once.

---

## Done

- Phone UI with home screen, live clock and date
- Invoice system with 23 categories, inbox/outbox, pay/reject/mark paid
- Contact manager
- Full multiplayer sync via network events
- Persistent save/load
- Redesigned dock with DDS texture icons, aspect ratio fix
- App grid with swipeable pages
- Custom notification system (color coded, stackable, auto-dismiss)
- Call system — contact calling, F8 answer/hang up, 30s timeout, missed calls, recent calls
- Messaging — text messages, conversation threads per contact
- Contacts detail screen — Call, Message, Delete buttons
- Settings — wallpaper, time format, temperature units, battery toggle
- Weather app — current conditions, 5-day forecast, wind, humidity
- Farm Manager permission system using FS25 native permissions
- Code refactor — split into separate app files under scripts/apps/
- inputComponent.locked replacing setContext — movement freeze without blocking keyboard
- Backspace, Tab, Enter working correctly via confirmed FS25 constants
- RI_BACKSPACE removed from modDesc
- Note field — multiline word wrap with force-break for long strings
- Send button moved to header in create invoice

---

## Build Order (current)

Work through these in order. Don't jump ahead.

### 1. MP Tests with Jackson ✅ DONE
- inputComponent.locked on client — CONFIRMED, blocks movement
- connectionsToPlayer structure — CONFIRMED, player.userId exists on remote objects
- Word wrap visual check — CONFIRMED BROKEN on 1920x1080, proportional fix needed
- Note: game action keys (F, T) still fire through — setContext needs restoring alongside inputComponent.locked

### 2. RoleplayPhone.lua Split ✅ DONE
Split into 8 focused files: RoleplayPhone.lua, PhoneHelpers.lua, PhoneUI.lua,
PhoneWeather.lua, PhoneCallLogic.lua, PhoneInput.lua, RoleplayPhoneAPI.lua,
apps/HomeApp.lua. All tested in-game. setContext + inputComponent.locked both
in place. Weather widget backdrop fix applied.

### 3. Proportional Font Word Wrap ✅ DONE
Build a character width lookup table for the FS25 default font.
Lives in RoleplayPhoneHelpers.lua once the split is done.
Replaces char-count wrapping with pixel-width wrapping — solves the
"too much space on right" issue permanently.
FS25_FontLibrary mod available as reference for character metric approach.

### 4. CallsApp Rewrite ✅ DONE
Rewrite from scratch — current version has broken tab bar baked in.
New structure: owns all 3 tabs internally (Keypad / Recents / Contacts).
- Keypad tab: dial a number, hit call (default tab on open)
- Recents tab: call history, tap entry to call back
- Contacts tab: read-only list for calling only, no create/edit here
- Back button stays — returns to home screen
- Tab bar handles within-app navigation only

### 5. ContactsApp Cleanup ✅ DONE
- My Profile section added at top (local player name + phone number)
- Call button routes to Calls app keypad
- Message button routes to Messages app

### 6. MessagesApp ✅ DONE
- Standalone app on home screen
- Conversation list with unread badges
- Message threads with scroll, word wrap, timestamps
- Delete individual message threads
- Full MP sync — history persists across reconnects for all players

### 7. Home Screen Layout ✅ DONE
- Screen 1: Invoices, Messages, Calls, Settings (dock)
- Screen 2: Contacts, Weather, Market (placeholder)
- DDS dock icons for all apps

### 8. onlineUsers Stale Entries ✅ DONE
- Host polls playerSystem:getPlayerByUserId() every 5s
- Stale entries removed, client file saved on disconnect
- Uses engine's PlayerSystem API directly

---

## Planned Features

### Contact Card via Messages — NEXT
Send your contact card through the Messages app.
Three ways to add contacts:
1. Contact card — "Share Card" button in Messages compose sends your card as a
   special message type. Renders in thread as a card (name, phone, farm) with
   a Save button. Save adds to Contacts, button changes to "Saved" (greyed out).
2. Manual entry in ContactsApp — plain text fields (name, phone, notes).
   Player selector arrows removed entirely. For out-of-band number exchange.
3. Unknown sender "+" button — already built. Pre-fills from unknown sender info
   when tapped in the message thread header.

### Proximity Contact Share ("AirDrop")
Share contact info with a nearby player — no phone number exchange needed.
Roleplay rationale: walk up to someone, say "I'll send you my contact info."

Flow:
1. Contacts → My Profile → "Share Nearby"
2. Scans for players within ~8 meters
3. One player nearby: sends contact request directly
4. Multiple nearby: picker showing who's in range
5. Recipient gets popup: "[Name] wants to share their contact — Accept / Decline"
6. Accept: saves automatically, sender gets confirmation
7. Decline: sender gets "Declined" notification

Open question: how to get remote player world positions at runtime.
Proximity range configurable in Settings.

### Market App
Combined marketplace — crop prices, used vehicle listings, property management.
Placeholder on Screen 2. Design TBD.

---

## Future / Someday

### UsedPlus Integration
UsedPlus (github.com/XelaNull/FS25_UsedPlus) — comprehensive finance mod.
Phone becomes the central hub for the entire RP economy.
- Credit Score App
- Finance Manager App
- Vehicle DNA App

### Additional Wallpapers
More options in Settings.

### FS22 Dedi Companion — Research (not now)
github.com/FSGModding/FS22_Dedi_Companion — abandoned FS22 mod but worth studying.
Has chat logging to XML, #getUsers and #getFarms chat commands, auto-admin system.
Specifically: look at how they enumerate connected players — may answer our
connectionsToPlayer question and give us patterns for the onlineUsers stale entry fix.
FS22 Lua patterns are largely the same as FS25.
Adapt FS25-Discord-Bot (github.com/cloudmaker97/FS25-Discord-Bot) to watch
a notifications.xml written by our mod and post events to a Discord channel.
Invoice sent, message received, missed call — all show up in Discord.
Requires a small Node.js companion app running on the server machine.
Separate project from the mod itself.

### Dedicated Server Testing
Rent a 3-day server once mod is feature complete.
- getHasPlayerPermission on dedicated server
- isMasterUser false for everyone — server owner needs Farm Manager via panel
- README note for server owners

---

## Known Bugs

- tempsavegame roleplayers.xml error on autosave — harmless, fileExists check needed

---

## MP Rules (always keep in mind)

- inputComponent.locked is client-local — each player locks their own
- All state changes go through server: clients send requests, server applies and broadcasts
- Every new feature needs an event pair: request (client→server) + broadcast (server→all)
- g_currentMission:getIsServer() gates server-only logic
- Test everything with Jackson before it goes in a release
- UI is always client-local, state is always server-authoritative
