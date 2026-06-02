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

Split into 8 focused files: RoleplayPhone.lua, PhoneHelpers.lua, PhoneUI.lua, PhoneWeather.lua, PhoneCallLogic.lua, PhoneInput.lua, RoleplayPhoneAPI.lua, apps/HomeApp.lua. All tested in-game. setContext + inputComponent.locked both in place. Weather widget backdrop fix applied.

### 3. Proportional Font Word Wrap ✅ DONE

Build a character width lookup table for the FS25 default font. Lives in RoleplayPhoneHelpers.lua once the split is done. Replaces char-count wrapping with pixel-width wrapping — solves the "too much space on right" issue permanently. FS25_FontLibrary mod available as reference for character metric approach.

### 4. CallsApp Rewrite ✅ DONE

Rewrite from scratch — current version has broken tab bar baked in. New structure: owns all 3 tabs internally (Keypad / Recents / Contacts).

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

Send your contact card through the Messages app. Three ways to add contacts:

1. Contact card — "Share Card" button in Messages compose sends your card as a special message type. Renders in thread as a card (name, phone, farm) with a Save button. Save adds to Contacts, button changes to "Saved" (greyed out).
2. Manual entry in ContactsApp — plain text fields (name, phone, notes). Player selector arrows removed entirely. For out-of-band number exchange.
3. Unknown sender "+" button — already built. Pre-fills from unknown sender info when tapped in the message thread header.

### Proximity Contact Share ("AirDrop")

Share contact info with a nearby player — no phone number exchange needed. Roleplay rationale: walk up to someone, say "I'll send you my contact info."

Flow:

1. Contacts → My Profile → "Share Nearby"
2. Scans for players within \~8 meters
3. One player nearby: sends contact request directly
4. Multiple nearby: picker showing who's in range
5. Recipient gets popup: "\[Name\] wants to share their contact — Accept / Decline"
6. Accept: saves automatically, sender gets confirmation
7. Decline: sender gets "Declined" notification

Open question: how to get remote player world positions at runtime. Proximity range configurable in Settings.

### Market App

Combined marketplace — crop prices, used vehicle listings, property management. Placeholder on Screen 2. Design TBD.

---

## Future / Someday

### UsedPlus Integration

UsedPlus ([github.com/XelaNull/FS25_UsedPlus](http://github.com/XelaNull/FS25_UsedPlus)) — comprehensive finance mod. Phone becomes the central hub for the entire RP economy.

- Credit Score App
- Finance Manager App
- Vehicle DNA App

### Additional Wallpapers

More options in Settings.

### Voice Chat Integration — (testing phase)

FS25 exposes voice chat functions directly to Lua — no Discord bot or external service needed.

**How it works:**
- `voiceChatSetUserVolume(userId, volume)` — per-player volume control, 0 = muted, 1 = full
- `voiceChatSetUserPairBlocked` — block specific player pairs
- `voiceChatAddConnection` / `voiceChatRemoveConnection` — manage connections
- All confirmed present in DataDump globalFunctions.lua

**Private call implementation (built, pending test):**
- Call connects → both players' games mute everyone except each other via `voiceChatSetUserVolume`
- Call ends → both games restore everyone to full volume
- Per-client volume control means multiple simultaneous calls may work independently
- pcall wrapper catches errors safely — call still works if voice functions behave unexpectedly
- Needs test with at least 2 players (Dan + Jason/Jackson)

**RP Voice Mode — server config option:**
- When enabled: all players muted by default, voice only opens during an active phone call
- When disabled: normal FS25 voice behavior, phone calls just add the mute/unmute layer
- Configurable in server XML config file
- Game crash scenario not a concern — crashed players go to Discord OOC channel anyway
- Serious RP servers will want this on, casual servers can leave it off

### 3-Way Calling
Add a third participant to an active call. Architecture changes needed:
- Call data holds a participant list instead of single fromUserId/toUserId
- Muting logic excludes all participants, not just one player
- Active call screen UI gets an "Add" button to invite a third player
- New join event for mid-call participant addition
- All three players' games manage volume independently

Notification-only — game events post to a Discord channel. No voice channel creation.

**How it works:**
- Mod fires HTTP requests via `HttpRequest` when events happen
- Missed call, new message, invoice sent → posts to Discord channel
- FS25 supports outbound HTTP so no companion app or extra hosting needed
- Server owner pastes a Discord webhook URL into a config file — done

**Dan has done this before (DayZ/GTX Gaming):**
- Created bot in Discord Developer Portal, got token
- GTX Gaming ran the bot on their servers as part of the game server package — no extra cost
- Only permissions needed: Message Content Intent + Mention Everyone
- G-Portal doesn't offer the same built-in bot runner — webhook approach is simpler anyway

**Voice channels:**
- Not happening automatically — too complex, no hosting solution on G-Portal
- RP server owners manage their own Discord voice channels manually
- In-game call rings → players jump in a Discord voice channel themselves

**References:**
- [cloudmaker97/FS25-Discord-Bot](https://github.com/cloudmaker97/FS25-Discord-Bot) — reference for webhook/notification pattern

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


---

## Big Picture Ideas (April 24, 2026 planning session)

These came out of a single brainstorming session and belong together — they form
a cohesive RP ecosystem built on top of RoleplayPhone's existing architecture.
Not starting any of this until current features are solid. Design before code.
UI mockups will be done in-chat before touching any Lua.

### Health / Survival System (MP-Native)
Build a lightweight health, hunger, and thirst system directly into RoleplayPhone.
MP-first from day one — synced across all players the same way contacts/invoices are.
No dependency on HumanFactors or Zyzex's FS25 Life mod (both are solo only).

- Health, hunger, thirst stats tracked per player
- Stats deplete over time — configurable rates
- Small persistent HUD element showing current stats (moveable, same drag logic as phone icon)
- Health app inside the phone for detailed view and management
- Cross-mod compatibility hooks — if a supported health mod is detected, read from it instead

### 911 Emergency Call
Special contact built into the phone. When health/stats drop critically low, player
calls 911. Payment goes through the invoice system (ambulance bill).
Call logs in recent calls as "Emergency Services."
Natural fallback if no player is assigned the EMS role — auto-fulfill at a cost.

### Food & Drink
Physical food and drink items needed in game world (3D asset problem — same as desk/computer).
Options: use Zyzex's food assets (ask permission), find base game assets to repurpose,
or commission/create custom assets.
Food and drinks consumed through the Health app or interaction trigger.

### Computer Terminal (Farm Office)
Physical placeable desk with a computer model and interaction trigger.
Player walks up, presses interact, gets pulled into a full-screen UI.
Same data and systems as the phone — different presentation.
Computer = desk, Phone = pocket. Everything available on both.

Sitting animation: another player entering the room sees the character seated at the desk.
Reference mod on Itch.io (zyzexyt or similar) has sitting mechanic — study how they
did it before building our own version. Do not use assets without permission.

Hard parts: 3D model, interaction trigger, sitting animation, MP state sync (player is at computer).
Lua UI side is straightforward — reuse existing app screens in wider full-screen layout.

### Market App — Food & Drink Ordering
Extend the market app to support ordering food and drinks.
Available through both phone and computer terminal.
Order flow:
1. Player places food/drink order through market app
2. System checks: is a Delivery Driver role currently assigned on this server?
3. If yes — order routes as invoice/job notification to that player
4. If no — falls back to automated delivery (timer-based, flat fee, similar to store deliveries mod)
Fallback is critical — experience should not break when no driver is online.

### Delivery Driver Role
Assignable player role. When active, food/drink orders route to this player as jobs.
Player accepts, delivers, gets paid through existing invoice system.
Role assignment through phone or server admin settings.
The communication, ordering, payment chain is already in RoleplayPhone — just a new use case.

### Reputation System
Invisible system — players do not see a score, they feel the effects.
Built from data RoleplayPhone already tracks: invoices, calls, messages, market transactions.
Examples of how reputation manifests:
- Pay invoices on time — better market prices
- Default on payments — other players get notified, prices go up
- Reliable delivery driver — get first pick of orders
- Call 911 repeatedly — insurance costs increase
Server admin configurable. Designed to layer on top of UsedPlus credit score if installed.

### Phone Prop — Visible to Other Players

When a player opens the phone, other players see a physical phone model in their hand (third-person view).

Research confirmed feasibility:
- `g_currentMission.playerSystem:getPlayerByUserId(userId)` — access any player object
- `player.graphicsComponent.model.thirdPersonRightHandNode` — the right hand scene node other players see
- `link(handNode, phoneNode)` / `unlink(phoneNode)` — attach/detach the prop
- Engine already supports this pattern (same as tool attachment system)

Flow: player opens phone → `RI_PhoneOpenEvent` broadcasts to all clients → each client loads phone prop i3d and links it to that player's right hand node → player closes phone → `RI_PhoneCloseEvent` → unlink and hide.

Hard part: the i3d phone prop model needs to be created. Have a contact who may be able to help with that. Do not start Lua work until the asset exists.

### Bluetooth Dashboard Display
When a call comes in and the player is in a vehicle with a compatible dashboard screen
(radio/GPS display), skip the phone popup and show caller info on the dashboard instead.
Falls back to normal phone UI if vehicle has no compatible display.
Requires research into whether GIANTS exposes dashboard screen elements as scriptable.
Check dataS Lua files for vehicle display API.


### Photo System (Camera + Camera Roll) — Way Down The List
Discovered May 2026: GIANTS engine exposes everything needed natively — no companion app required.

**Engine functions confirmed via DataDump:**
- `takeScreenshot()` — captures screenshot
- `g_screenshotsDirectory` — exact path where screenshots land
- `copyFile(src, dst)` — move photo into mod's save folder
- `createFolder()` — create photos directory
- `getFiles()` — list photos for camera roll
- `fileExists()` / `textureFileExists()` — verify before loading
- `deleteFile()` — cleanup

**How it works:**
- Player hits "take photo" in mod → `takeScreenshot()` fires
- Mod copies result from `g_screenshotsDirectory` into `savegame13/FS25_RoleplayPhone/photos/`
- Since save folder is shared on host's machine, all connected players can reference photos by filename
- Filename broadcast to other players via network event — they load it as overlay locally

**Apps this enables:**
- **Camera app** — take photo, auto-saves to mod photo folder
- **Camera Roll app** — grid view of all saved photos, tap to preview/use
- **Contact avatars** — pick photo from camera roll as profile picture
- **Market listings** — attach photo to vehicle/equipment listing
- **Photo messages** — send photo in message thread (transmit filename only, not image data)

**Also worth testing:** whether `$dataS2/npc/` texture paths load via mod Lua — if yes, base game NPC character models could be used as preset contact avatars without any photography needed.

Do NOT start this until Market app exists and photo use cases are actually needed. Research first — test `takeScreenshot()` + `copyFile()` in a throwaway mod before designing anything.

### GPS Map App — Way Way Way Down The List
Live map showing player positions, vehicle locations, field boundaries.
Route navigation via pre-built waypoint data for supported maps.

**What's confirmed possible:**
- Player positions via playerSystem
- Vehicle locations via g_currentMission.vehicles
- Field boundaries via fieldManager
- Draw map overlay with positions marked

**Route navigation approach:**
- Drive routes during development, record position waypoints every few seconds
- Bake waypoint data into mod as XML or Lua table per supported map
- Player selects destination, mod draws pre-built route line on map
- "You are here" marker moves along route as player drives
- Not true pathfinding — pre-recorded routes only
- Only works for maps routes have been built for (base game maps as starting point)
- Community maps get no routes — acceptable for dedicated RP servers on one map

**True pathfinding (Google Maps style) — unknown**
- Base game workers don't path between fields — that's a mod
- Route-recording mods exist (player trains the route, worker follows)
- Whether engine exposes pathfinding API to Lua is unknown — check DataDump if ever pursuing this

Do NOT start until GPS is actually needed. Map building is significant time investment.


### GPS / Maps App — Way Way Way Down The List (updated)
Live map showing player positions, vehicle locations, field boundaries.
Styled to match the base game map so it feels familiar.

**Approach — replicate, don't hook in:**
- Do NOT try to hook into the base game map GUI — it's a modal screen, fighting it is wrong
- Load `overview.dds` from the active map as the background texture (every FS25 map ships one)
- Get player world position from playerSystem, do coordinate math to place dot on image
- Map world dimensions are known, overview.dds dimensions are known — straightforward math
- Draw other player dots with names, vehicle icons, custom pins on top
- Player can disable base game minimap entirely and use ours instead

**UX — Option B (GPS detach):**
- Player opens phone → taps Maps app
- Phone closes, but map overlay stays on screen where base game map normally lives
- Feels like mounting your phone in a dashboard holder — phone goes away, map stays visible
- Player can still receive calls/messages/notifications while GPS is visible
- To close: reopen phone and tap Maps to toggle off, OR dedicated X button on the map overlay
- Separate HUD overlay handles rendering — same pattern as existing phone icon HUD element

**Route navigation:**
- Pre-built waypoint data for supported maps (drive route once during dev, bake into mod as XML)
- Player selects destination, mod draws pre-built route line on map
- "You are here" marker moves along route as player drives
- Community maps get no routes — acceptable for dedicated RP servers

**Still needs exploring:**
- Exact coordinate math for world→image position conversion
- How to detect which map is active and load its overview.dds dynamically
- Custom player-placed pins (points of interest)
- Whether field ownership overlay is feasible
- Full UX flow for route selection UI

**True pathfinding — not pursuing:**
- Road data is baked into i3d geometry, not in parseable XML
- Traffic system XML is just vehicle definitions
- Pre-recorded routes are the practical approach

Do NOT start until Market app exists and photo system is explored. This is a big feature.


### Farmbook — The Server Social Feed (way way way at the bottom, below GPS)
Started as "Facebook but not named Facebook" — ended up as a genuinely compelling feature.
A community feed app that aggregates everything happening on the server into one scrollable timeline.
The town square of the roleplay server.

**What shows up in the feed:**
- Player posts a vehicle/equipment for sale on market → feed post
- Job board contract gets posted → feed post
- Crop price spike or market event → system feed post
- Player shares a photo → feed post
- NPC announcements based on game state (see below)
- Worker finished a field → optional player feed post
- Invoice paid, contract completed → optional activity post

**Why it makes sense:**
- Not a new system — just a new view on data already being collected
- Instead of checking market, job board, weather separately, open Farmbook and see it all
- Gives the server a feeling of life and activity
- Replaces or supplements the local market app as a discovery layer

**NPC Profiles:**
- NPCs have Farmbook profiles just like players
- They post updates driven by live game state:
  - Grain Mill: "Wheat prices up 20% today — come sell!"
  - Mechanic: "Shop's open, bring your broken equipment"
  - Auctioneer: "Equipment auction — 3 listings available"
- Posts generated by the same auto-reply/NPC engine powering their message threads
- No voice acting or dialog trees needed — text posts only
- Players can "reply" to an NPC post which routes to that NPC's message thread
- Makes the world feel populated even in single player

**Dependencies before starting:**
- Market app must exist
- Job board must exist  
- Photo system must exist
- NPC contact/messaging system must exist
- Basically everything else on this roadmap

This is a v2.0 or later feature. Do not touch until the foundation is solid.


### Claude App — In-Game AI Assistant (absolute bottom of the list)
A Claude-branded assistant app on the phone with preset farming-related responses.
XML-driven response library, no API calls, no usage costs.
Same architecture as the carrier bot/NPC auto-reply engine.

**How it would work:**
- Player opens Claude app, types a question or keyword
- Mod matches against preset XML response library
- Returns best match — farming advice, server rules, crop info, equipment tips
- Server owners can customize the response library for their own setup
- No real AI calls — purely preset responses styled as Claude

**Why Claude and not FarmBot:**
- Claude is already credited in modDesc.xml as a developer/contributor
- Mod is free, not monetized, not claiming to be Anthropic
- More of a fun easter egg / nod than impersonation

**IMPORTANT — side note:**
Before building this, reach out to Anthropic and ask if they're okay with Claude 
being represented as an in-game character in a free hobby mod. They have a usage 
inquiry process. Given Claude is already in the credits this probably isn't a crazy ask,
but get confirmation first. Do not build this until you have an answer.

Contact: https://www.anthropic.com

### Phone Bill System
Carrier bot NPC sends an automated invoice at the end of each in-game day based on call duration.
Talk too much = farm overhead goes up. Adds real RP consequence to communication.

**How it works:**
- Track total call duration per player per in-game day (data already partially available in call history)
- End of day: carrier bot NPC fires an invoice via InvoiceManager for call minutes used
- Configurable rate per minute in server XML config
- Free tier possible (first X minutes free, charged above that)
- Ties into carrier bot system already on roadmap

**Dependencies:**
- Carrier bot / NPC auto-reply system must exist first
- InvoiceManager already handles the billing side — small addition

### Call Quality / Environmental Audio
During a call, receiver hears ambient audio based on the caller's current environment.
Pure immersion — no real audio capture needed, all pre-recorded OGG samples via playSample.

**How it works:**
- On call connect, server checks caller's environment and sends a context flag to receiver
- Receiver's game plays matching ambient loop quietly under the call
- Examples:
  - Caller in rain/storm → receiver hears rain static
  - Caller in a vehicle → receiver hears engine rumble  
  - Caller near running equipment → receiver hears machinery noise
  - Caller indoors → cleaner audio, slight reverb effect
  - Caller in wind → receiver hears wind noise
- All samples played at low volume so they don't overpower the call
- Same playSample pattern as NPC voice clips

**Data already available:**
- Caller location known
- Weather via g_currentMission.environment
- Nearby vehicles via g_currentMission.vehicles
- Indoors/outdoors detectable via terrain/building data

**Dependencies:**
- Call system must be solid first
- Need a small library of ambient OGG samples (rain, engine, machinery, wind, etc.)
- Some base game audio files may be reusable from data/sounds/

### Emergency Broadcast System
Server admin contact that can force-push alerts to all players simultaneously.
Bypasses phone closed state — full screen alert regardless of what player is doing.

**How it works:**
- Special built-in contact "Emergency Services" or "Server Admin" visible to all players
- Admin-only send privilege (farm manager permission check)
- Uses NotificationManager to push full-screen alert to every connected client
- Examples: "Tornado Warning", "Server restart in 10 minutes", "Road closed at Field 12"
- Could tie into carrier bot system — same infrastructure, different permission level
- Audio alert plays on all phones simultaneously (existing notification sound or dedicated alert tone)

**Already have:** NotificationManager, broadcast events, permission system
**Small addition** — closer to near-term than bottom of list

---

### Vehicle Bluetooth / Cab Audio Sharing
Passengers in the same vehicle as a call participant hear the call through "speakers."
Opens up genuine in-cab conversation RP — driver on phone, passenger hears both sides.

**How it works:**
- When a call is active, check which vehicle the caller is in
- Any other players inside the same vehicle are added to the audio stream automatically
- Uses same mute matrix logic but scoped to vehicle occupants rather than individual players
- Passenger doesn't have to be on the call — they just "overhear" it through the cab
- Ends automatically when passenger exits the vehicle

**RP scenarios this enables:**
- Driver takes a call, passenger hears the conversation
- Business calls in the truck cab feel natural and immersive
- Passengers can interject (they have voice chat open to the caller)

**Dependencies:**
- Vehicle occupant detection (g_currentMission.vehicles + player/vehicle binding)
- Voice isolation system must be solid first
- Ties into 3-way calling architecture — participant sets, not just pairs

### Market Price Alerts
Player sets a price threshold for a crop in the Market app.
Server polls EconomyManager and fires a notification when the price is hit.

**How it works:**
- Player opens Market app, selects crop, sets alert price (e.g. "notify me when wheat hits $220")
- Server-side poll checks EconomyManager prices on a timer
- When threshold crossed, NotificationManager pushes alert to that player's phone
- Alert shows crop, current price, and quick-link to Market app
- Per-player, per-crop alerts — saved to player profile XML

**Already have:** EconomyManager access, NotificationManager, save system
**Small addition** — good near-term feature for the Market app

---

### Trade Request (Crop/Goods Transfer via Messages)
Player texts a trade offer to another player — generates a trade invoice they can accept.

**How it works:**
- In Messages compose, player can send a "Trade Request" message type
- Specifies crop type, quantity, and agreed price
- Receiver gets the message with Accept/Decline buttons
- Accept generates an invoice automatically via InvoiceManager
- On payment, trade is considered complete (physical delivery still up to players — RP handles the rest)
- Ties UsedPlus credit into trade history if installed

**Already have:** MessagesApp, InvoiceManager, special message types (contact cards, voicemail)
**Natural extension** of existing systems — fits the RP economy perfectly

### Speakerphone Mode
Toggle during an active call that leaks audio to nearby players within ~5 meters.
Same mute matrix logic, inverted — nearby players get un-muted for your call instead of isolated.

**How it works:**
- Speakerphone button appears on active call screen
- When enabled: players within 5m radius get added to the audio stream as listeners
- They hear the call but cannot participate (no two-way audio unless they call in)
- Proximity check runs on a timer while speakerphone is active
- Players entering/leaving the radius are dynamically added/removed
- Visual indicator on call screen shows speakerphone is active

**RP scenarios:**
- Standing in the shop arguing on the phone — everyone hears it
- Business deal overheard by a nearby player — emergent RP moments
- Group listening to an important call without conference calling
- Someone overhears something they weren't supposed to

**Already have:** mute matrix, proximity detection via playerSystem, active call state
**Small addition** — builds on vehicle Bluetooth cab audio concept
**Dependency:** voice isolation system must be solid first

### Location Pin (Messages)
Player sends their current world position as a special message type.
Receiver taps it to place a temporary waypoint on their in-game map.

**How it works:**
- "Share Location" button in Messages compose
- Sends a special message type containing sender's X/Z world coordinates
- Receiver sees it as a map pin card in the thread with a "Navigate" button
- Tapping Navigate places a temporary waypoint on their PDA/map
- Waypoint auto-clears after a configurable time or when manually dismissed

**Use cases:**
- "Come find me" — delivery driver or mechanic locating a breakdown
- "Meet me here" — coordinate rendezvous points
- Finding a broken tractor in a massive field at night

**Also add to invoice schema:**
- screenshotPath / imageId field on Invoice object
- Player can attach a photo from Camera Roll as proof of work
- Shows as thumbnail in InvoicesApp detail view
- "Proof of Work" — timestamped photo of completed field prevents disputes


---

### Invoices App Expansion
Full contractor business management on the phone. Inspired by competing invoice mods but lives entirely on the RoleplayPhone — no ESC menu, no separate mod needed. Everything through the phone like a real contractor would run their business.

**Features:**
- Vehicle ownership transfer via invoice — sell a vehicle to another farm, ownership transfers automatically on payment
- Consumable/physical item transfer — bales, pallets, bigbags invoiced and transferred (must be ejected from storage first)
- Product selection with automatic market pricing pulled from EconomyManager
- VAT system — multiple rate groups, editable per line item, optional simulated mode for servers that don't want tax complexity
- Net / VAT / Gross breakdown displayed on each invoice
- Automatic payment reminders via phone notification
- Late fees on unpaid invoices — configurable, notification driven
- Finance tab integration — payments post as proper income/expense entries in FS25's built-in Finance tab
- Auto-pricing based on contract economy and difficulty setting — prices feel appropriate to the server's economy

**Dependencies:** existing InvoiceManager, InvoiceEvents, FS25 EconomyManager, FinanceManager

---

### Market App — Expanded Vision
Full in-game dealership and marketplace experience. Three tabs:

- **New Vehicles** — browse dealer inventory
- **Used Vehicles** — browse used machines at the dealer lot. Clicking a vehicle spawns it physically at the dealership so the player can inspect it before buying (FS25_VisualSales concept — no dependency on that mod, replicate the behavior natively)
- **Player Listings** — player-to-player vehicle and equipment sales

**Test Drive integration (FS25_TestDrive concept — no dependency, native implementation):**
- Player taps a vehicle in Market App → vehicle spawns at dealership → test drive timer starts automatically on the phone
- Timer visible on phone screen while driving
- Configurable duration per server (default 2 minutes real-time)
- Insurance fee for vehicles over a configurable price threshold (default $100k, default 0.3% of value)
- Buy or walk away when timer expires — vehicle despawns if not purchased

**Player-to-player sales:**
- List your own vehicles/equipment for sale with asking price and photos (ties into Photo System)
- Buyer purchases via invoice — ownership transfers automatically on payment
- Ties into Invoices App Expansion above

**Food & Drink ordering:**
- Order food and drinks through Market App (ties into Health/Survival system)
- Routes to Delivery Driver if one is active on server, falls back to automated delivery otherwise

**Market Price Alerts (already documented above — surface in Market App UI)**


---

### Field Lease System
Automated land rental management through the phone. Foundation already exists — invoice system has field lease categories for manual invoicing. This adds the automated layer on top.

**Rent to AI:**
- Player selects an owned field and sets it for lease
- AI tenant pays automatically each in-game month
- Payment rate based on field value (default 2.0%) with difficulty multiplier
- Easy (1.2x) / Normal (1.0x) / Hard (0.8x)
- Configurable minimum lease duration (default 12 months)
- Early termination allowed with penalty (default 50% of remaining months)
- No penalty if terminated before first payment
- Payment and lease status notifications on phone

**Rent to players:**
- List available fields for lease in Market App (Fields for Lease tab)
- Other player browses listings, reviews terms, accepts lease on their phone
- Lease agreement locked in — both parties can see terms and status
- Monthly payments run automatically through invoice system
- Both parties get payment notifications
- Early termination triggers automatic penalty invoice
- Auto-termination probability configurable (server setting)

**Configurable settings (server XML):**
- Minimum lease duration (3–24 months)
- Monthly income rate (default 2.0% of field value)
- Difficulty multiplier
- Allow/disallow fields with placeables
- Auto-termination probability

**Dependencies:** existing InvoiceManager, invoice categories already in place, Market App for player listings
