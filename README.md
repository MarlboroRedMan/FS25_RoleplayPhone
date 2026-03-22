# FS25 RoleplayPhone

A Farming Simulator 25 mod that adds a full-featured roleplay smartphone UI for multiplayer servers. Built for serious RP communities that want an in-game economy with real accountability — invoices, contacts, messaging, calls, notifications, and more.

---

## Features

- 📱 **Phone UI** — Press F7 to open/close a modern smartphone interface with wallpaper and live weather widget
- 🌤️ **Home Screen Weather Widget** — Condition icon, temperature, and map name displayed front and center on the home screen
- 📄 **Invoice System** — Create and manage invoices between farms for rent, leases, vehicle sales, services, and more
- 📥 **Inbox / Outbox** — Separate views for received and sent invoices
- 💰 **Payment System** — Recipients can pay invoices directly (deducts from farm account), or senders can manually mark as paid
- ✅ **Invoice Actions** — Accept, reject, or mark invoices as paid with full status tracking
- 📋 **23 Invoice Categories** — Houses, campers, shops, storage, land leases, vehicle transactions, services, and more
- 📇 **Contacts** — Save farm contacts with name, farm, phone number, and notes
- 💬 **Messaging** — Send text messages between farms with conversation threads
- 📞 **Calling** — Call contacts directly from the phone; F8 answers or hangs up (works while driving)
- 🔔 **Notifications** — Color-coded on-screen notifications for invoices, messages, calls, and pings
- 📋 **Recent Calls** — View call history for the current session (resets each time you load the game)
- ⚙️ **Settings** — Tabbed settings with wallpaper picker, time format (12/24hr), temperature units (°F/°C), battery display
- 🖼️ **Wallpapers** — 5 photo wallpapers (Countryside, Barn & Silos, Big Red Barn, Winter Red Barn, Hay Bales) plus color options
- 💾 **Persistent Storage** — Invoices and contacts save with your game
- 🌐 **Multiplayer Ready** — Full server/client sync via network events
- 🌤️ **Weather App** — Full current conditions and multi-day forecast (see below)

---

## Weather App

The Weather app shows real in-game weather data pulled directly from FS25's internal systems — the same source the base game's own weather panel uses.

**Current conditions:**
- Temperature (°F or °C based on your settings)
- Condition (Clear, Rain, Snow, Thunderstorm, etc.)
- Wind speed and compass direction
- Cloud cover percentage

**Forecast:**
- Up to 5 days ahead with real conditions and temperature ranges
- Day labels automatically match your time settings:
  - **1 day/period:** Shows month names (Sep, Oct, Nov...) — matches the base game
  - **7 days/period:** Shows day numbers (Day 7, Day 8...)
- Temperatures show high/low ranges pulled from the map's weather variation data

> **Note on forecast temperatures:** Just like real-world weather apps (AccuWeather, Weather.com, etc.), forecast temperatures across different sources will vary slightly. Each app uses its own model. Our phone reads the exact per-variation temperature ranges defined in the map's weather configuration — these are the same values the game engine schedules. Minor differences from the base game's display are expected and normal, just as they are in real life.

---

## Invoice Categories

| Category | Category |
|---|---|
| Rent - House (Small) | Rent - House (Medium) |
| Rent - House (Large) | Rent - House (Luxury) |
| Rent - Camper (Full Hookup) | Rent - Camper (Water & Power) |
| Rent - Camper (Electric Only) | Rent - Camper (Land Use Only) |
| Rent - Shop (Full Use) | Rent - Shop (Single Bay) |
| Rent - Storage (Indoor) | Rent - Storage (Covered) |
| Rent - Storage (Yard) | Lease - Agricultural Land |
| Lease - Yard / Equipment Staging | Lease - Industrial / Mining Land |
| Vehicle - Sale (Paid in Full) | Vehicle - Sale (Installment Payment) |
| Vehicle - Lease / Rental | Service - Labor |
| Service - Hauling | Service - Equipment Operation |
| Service - Snow / Mowing / Cleanup | |

---

## Installation

1. Download `FS25_RoleplayPhone.zip` from the [Releases](../../releases) page
2. Place the zip file directly into your FS25 mods folder:
   - **Windows:** `Documents\My Games\FarmingSimulator2025\mods\`
3. Enable the mod in the FS25 mod manager before loading your save
4. **Do not unzip** — FS25 reads mods directly from the zip file

> ⚠️ **Important:** Do not use the "Download ZIP" button from the main GitHub page — that version wraps the files in a subfolder and will not work. Always download from the Releases page.

---

## Key Bindings

| Key | Action |
|---|---|
| F7 | Open / Close phone |
| F8 | Answer or hang up call (works on foot and in vehicles) |

Both bindings are fully remappable in the FS25 key bindings menu under **Controls → On Foot / Vehicle**.

> ⚠️ **F-key conflicts:** Some mods and FS25's developer mode use F-keys for their own functions. If you experience key conflicts, rebind the phone keys in the FS25 Controls settings to any unused key or key combination.

---

## How to Use

### Opening the Phone
Press **F7** to toggle the phone open and closed. The phone cannot be opened while in a vehicle — but if a call comes in while driving, press **F8** to answer or hang up without needing to open the phone.

### Sending an Invoice
1. Open the phone and tap **Invoices**
2. Tap **+ New Invoice**
3. Select the recipient farm, category, amount, and add a description and notes
4. Tap **Send** — the recipient will see it in their Inbox

### Paying an Invoice
1. Open your **Inbox**
2. Select the invoice
3. Tap **Pay** — the amount is deducted from your farm account and the invoice is marked PAID

### Calling a Contact
1. Open the phone and tap **Contacts**
2. Tap a contact to open their detail screen
3. Tap **Call** — a compact call popup appears (you can still drive)
4. The other player presses **F8** to answer — or **F8** again to hang up

### Messaging
1. Open the phone and tap **Contacts**
2. Tap a contact → tap **Message**
3. Type your message and tap **Send**

### A Note on Phone Numbers
The phone number field is cosmetic RP flavor only — it doesn't route calls or do anything functional. Players can enter any format they like, up to 60 characters.

---

## Multiplayer Notes

- The **host** handles all invoice saving and loading
- Clients receive invoice, contact, and weather forecast updates in real time via network sync
- All invoice actions (pay, reject, mark paid) broadcast to all connected players
- Incoming calls do not freeze either player — the call popup is non-blocking
- **The phone is farm-based** — all players on the same farm share the same inbox, contacts, and message threads. This matches how FS25 works internally — the farm is the identity, not the individual player.
- **Messages are session-only** — message history is not saved between sessions
- **Contact farm name must match the actual farm name** in game for calls and messages to route correctly
- **The zip filename matters** — the file must stay named `FS25_RoleplayPhone.zip`

---

## Permissions

The phone uses FS25's native farm manager permission system — no configuration required.

| Action | Farm Hand | Farm Manager | Server Admin |
|--------|-----------|--------------|--------------|
| View invoices / weather / contacts | ✅ | ✅ | ✅ |
| Create / pay / reject invoices | ❌ | ✅ | ✅ |
| Send messages and make calls | ✅ | ✅ | ✅ |

Permissions are farm-specific — if a player leaves a farm their manager rights don't follow them, exactly like the base game.

---

## Current Version

**v0.3.1** — New wallpapers, tabbed settings with wallpaper picker, redesigned home screen weather widget with condition icons, F8 keybind fix

---

## 🤖 AI-Assisted Development

This mod was developed collaboratively between a human creator and Claude (Anthropic AI). The vision, direction, design decisions, and testing were all driven by MarlboroRedMan — Claude handled the code implementation based on those ideas.

### Codebase Statistics
- **~3,500 lines of code** across 12 Lua scripts
- **6 app modules** — Weather, Invoices, Contacts, Calls, Settings, and core phone logic
- **5 core systems** — Invoice, Contact, Save, Network Events, and Notifications
- Developed February–March 2026

---

## Credits

**Mod Author:** MarlboroRedMan
**Development Assistance:** Claude (Anthropic AI)

---

## License

This mod is for personal and multiplayer server use. Do not redistribute modified versions without permission.
