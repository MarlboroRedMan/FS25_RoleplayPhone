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

## ✅ v0.2.0 — Current Release

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
- Centralized — any part of the mod calls one function to trigger

### 📞 Call System
- Call contacts directly from the phone
- Compact non-freezing call popup (bottom-left, out of the way while driving)
- F8 keybind to answer or hang up — works on foot AND in vehicles
- 30 second auto-timeout on unanswered calls
- Missed call notification
- Caller shows contact name (not just farm name) if saved in contacts
- Call history (current session)
- Recent Calls dock button replaces Ping

### 💬 Messaging
- Send text messages between farms
- Conversation threads per contact
- New message notification
- Backspace works correctly in message compose
- Message history (current session)

### 📇 Contacts Overhaul
- Contacts list on small phone screen
- Contact detail screen with Call, Message, and Delete Contact buttons
- Message thread on full screen
- Backspace works in all contact form fields
- Add and delete contacts

### ⚙️ Settings Screen
- Wallpaper selection
- Time format (12hr / 24hr)
- Temperature units (°F / °C)
- Battery display toggle

### 🔧 Multiplayer Fixes
- Keybind registration moved to after BaseMission.enterGame fires
- Phone UI and notifications gated behind inputRegistered (no rendering during map load)
- Incoming calls no longer freeze the receiving player
- Outgoing caller stays fully mobile during call

---

## 🔮 v0.3.0 — Planned
- Weather app — current conditions, 7-day forecast, pulls from FS25 weather/season API
- Market Prices app — crop prices with color coding (above/below average)
- Property Management app — list rentals, set prices, track tenants, auto-generate invoices
- Used Vehicle Marketplace app — player listings and broker listings (BuyUsedEquipment compatible)
- Additional wallpaper options

---

## 🔮 v0.4.0 — UsedPlus Integration
UsedPlus (github.com/XelaNull/FS25_UsedPlus) is a comprehensive finance and marketplace mod with a public API. Once it reaches a stable release, integrating with it would allow our phone to become the central hub for the entire RP economy.

**Planned apps powered by UsedPlus API:**

### Credit Score App
- Display farm's current FICO-style credit score (300-850)
- Show score history and what's affecting it
- Paying invoices through our mod reports payments to UsedPlus and builds credit

### Finance Manager App
- View all active loans, leases, and financing deals
- See monthly payments, remaining balances, and terms
- Make payments directly from the phone

### Cash Loans App
- Apply for cash loans against collateral
- View loan terms based on current credit score

### Vehicle DNA App
- Inspect a vehicle's hidden DNA (lemon, workhorse, legendary)
- View reliability rating, hours, damage, wear

**The big picture:** Invoice payments through our mod feed into UsedPlus credit scores. Farms that pay rent on time, settle invoices, and honor leases build good credit and unlock better financing rates. The entire server economy becomes interconnected.

---

*No timeline, no pressure — just a wishlist to work from!*
