# FS25 RoleplayPhone — Development Roadmap

---

## ✅ v0.1.0 — Released
- Phone UI (F7) with home screen, live clock and date
- Invoice system with 23 categories
- Inbox / Outbox with pay, reject, and mark as paid
- Contact manager
- Ping system
- Full multiplayer sync via network events
- Persistent save/load

---

## ✅ v0.2.0 — Released
### 📱 Phone UI Overhaul
- Redesigned dock with proper square icons (aspect ratio fix for FS25 coordinate system)
- DDS texture icons for all dock apps
- App grid with swipeable pages and dot indicators
- Wallpaper shows through settings screen

### 🔔 Custom Notification System
- Color coded by type: green (paid/credit), red (rejected/missed), blue (new invoice/message), yellow (warning)
- Stacks cleanly for multiple notifications
- Draggable HUD icon
- Auto-dismisses after a few seconds

### 📞 Call System
- Call contacts directly from the phone
- Compact non-freezing call popup (bottom-left, works while driving)
- F8 keybind to answer or hang up — works on foot AND in vehicles
- 30 second auto-timeout on unanswered calls
- Missed call notification
- Recent Calls history (current session)

### 💬 Messaging
- Send text messages between farms
- Conversation threads per contact
- Message history (current session only)

### 📇 Contacts Overhaul
- Contact detail screen with Call, Message, and Delete buttons
- Full message thread screen

### ⚙️ Settings Screen
- Wallpaper selection (7 options)
- Time format (12hr / 24hr)
- Temperature units (°F / °C)
- Battery display toggle

---

## ✅ v0.3.0 — Current Release
### 🌤️ Weather App
- Current conditions: temperature, condition label, wind speed/direction, cloud cover
- ASCII condition symbol in current conditions card
- 5-day forecast with real condition data read directly from save XML
- Temperature ranges pulled from map's weather variation data (same source as base game)
- Day labels match your time settings (month names at 1 day/period, day numbers at 7 days/period)
- Forecast synced to clients via network event on connect
- Humidity and ground wetness shown automatically if exposed by weather mods

### 🔐 Farm Manager Permissions
- Uses FS25's native farm manager permission system — no configuration needed
- Farm hands: view only (invoices, weather, contacts)
- Farm managers: full access (create/pay/reject invoices, send messages, calls)
- Server admin (host / master user): full access across all farms
- Permissions are farm-specific — leaving a farm removes permissions instantly

### 🏗️ Code Refactor
- Split monolithic RoleplayPhone.lua into separate app files
- scripts/apps/WeatherApp.lua, InvoicesApp.lua, ContactsApp.lua, CallsApp.lua, SettingsApp.lua
- Core file reduced from 3,482 to ~2,000 lines
- Easier to maintain and extend going forward

### 🐛 Bug Fixes & Polish
- Spectator farm (Farm 14) no longer appears in invoice send-to list
- Contact detail screen: farm name removed, shows phone and notes only
- Message thread header: simplified to just contact name
- Call popup Answer/Decline buttons fit correctly inside popup box
- Settings labels (Temperature, Battery, Wallpaper) aligned correctly
- Mod size reduced from 615 KB to 492 KB (dead textures removed, wallpaper recompressed)

---

## 🔮 v0.3.x — Planned Polish
- Market app (combined: crop prices + used vehicle marketplace + property management)
- Additional wallpaper options
- Weather widget icon on home screen page 1

---

## 🔮 v0.4.0 — UsedPlus Integration
UsedPlus (github.com/XelaNull/FS25_UsedPlus) is a comprehensive finance and marketplace mod.
Once stable, integrating with it would make our phone the central hub for the entire RP economy.

**Planned apps powered by UsedPlus API:**

### Credit Score App
- Display farm's FICO-style credit score
- Paying invoices through our mod builds credit history

### Finance Manager App
- View all active loans, leases, and financing deals
- Make payments directly from the phone

### Vehicle DNA App
- Inspect a vehicle's hidden DNA (lemon, workhorse, legendary)
- View reliability rating, hours, damage, wear

---

*No timeline, no pressure — just a wishlist to work from!*
