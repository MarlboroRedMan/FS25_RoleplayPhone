# FS25 RoleplayPhone — Development Roadmap

---

## ✅ v0.1.0
- Phone UI (F7) with home screen, live clock and date
- Invoice system with 23 categories
- Inbox / Outbox with pay, reject, and mark as paid
- Contact manager
- Ping system
- Full multiplayer sync
- Persistent save/load

---

## ✅ v0.2.0
- Redesigned dock with DDS texture icons
- App grid with swipeable pages
- Custom notification system (color-coded, stacking, draggable HUD icon)
- Call system with compact non-freezing popup
- F8 keybind (answer / hang up, remappable, works in vehicles)
- Messaging with per-contact conversation threads
- Contact detail screen with call, message, and delete
- Settings screen: wallpaper, time format, temperature units, battery toggle

---

## ✅ v0.3.0
- Weather app: current conditions + 5-day forecast
- Weather condition icons (8 DDS textures)
- Forecast synced to clients on connect
- Farm manager permission system
- Code refactor: split into separate app files under scripts/apps/

---

## ✅ v0.3.1
- 4 new photo wallpapers
- Settings tabbed layout (General / Wallpaper)
- Wallpaper picker with preview
- Home screen weather widget redesign
- F8 remapping fix + dynamic key hint in call popup

---

## ✅ v0.3.2
- Ringtone selection (4 options + preview)
- Ringback tone for caller
- Busy signal / unavailable tone
- Notification sound for messages and invoices
- Badge fixes (visible on 32:9, clears on open)
- 7 translation files (de, fr, es, it, pl, pt, br)
- Missed call badge and history fix

---

## ✅ v0.4.0
### 🔀 Player-Based Routing
- Calls and messages now route by **playerUserId** instead of farmId
- Each player auto-assigned a deterministic phone number from userId hash
- `RI_PlayerHelloEvent` — players announce themselves on connect
- Host tracks online status in real time — busy signal fires if player offline
- Farm name kept on contacts for permissions and display

### 📇 New Contact Picker
- Add Contact screen replaced manual phone entry with online player picker
- Arrow selector cycles through connected players
- Phone number and playerUserId auto-filled from selection
- Save button only activates when a player is selected

### 🔌 Public API
- `RoleplayPhoneAPI.lua` — 9 functions for mod integration
- pushNotification, sendMessage, sendInvoice, getInvoices, getInvoiceCount
- isPlayerOnline, getOnlinePlayers, getPlayerPhone, getVersion
- Designed for TisonK's ecosystem: TaxMod, IncomeMod, RandomWorldEvents, FarmTablet

### 🐛 Fixes
- Missed calls now correctly recorded in call history
- Weather widget icon no longer bleeds into temperature text
- Steam Cloud conflict documented (disable Steam Cloud for clean saves)

---

## 🔮 v0.4.x — Planned Polish
- Split save file: separate XML for invoices and contacts
- Cover rect scroll masking for Notes field
- Ringtone preview stop-before-play (prevent overlap)
- Recurring invoice reminders (notify every X days until paid)
- Home screen Day/Season text redesign
- Fix 3 hardcoded strings in InvoiceEvents.lua missed by l10n pass
- Add new l10n keys to all 7 non-English language files

---

## 🔮 v0.5.0 — Market App
- Crop price viewer
- Used vehicle marketplace
- Property / rental management

---

## 🔮 v0.6.0 — UsedPlus Integration
- Credit Score app
- Finance Manager app (loans, leases, payments)
- Vehicle DNA app (condition, reliability, wear)

---

## 💡 Ideas Parking Lot
- **Discord Companion App** — standalone Windows app that watches for phone events and forwards to a Discord webhook
- **Controller support** — full UI navigation without mouse
- **In-game Finance screen** — track paid/received invoices as line items inside the phone
- **Formal lease agreement screen**
