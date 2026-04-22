# FS25 RoleplayPhone

A full-featured roleplay smartphone for multiplayer Farming Simulator 25 servers.

Built for serious RP communities that want a real in-game economy and communication system — invoices, contacts, calls, messaging, weather, notifications, and a public API for integration with other mods.

---

## Features

### 📱 Phone UI
- Realistic smartphone interface with phone frame overlay
- Home screen with live clock, date, season, and weather widget
- Two-page app grid — swipe between pages
- Dock with quick-access apps
- 12 wallpaper options (5 photo wallpapers + 7 color themes)
- Draggable HUD notification icon

### 💰 Invoice System
- 23 invoice categories (rent, services, labor, etc.)
- Inbox and outbox with full detail view
- Pay, reject, or mark invoices from the phone
- Real money transfer via FS25's economy system
- Full multiplayer sync — all players see the same invoice state

### 📇 Contacts
- Add contacts manually (name, phone, notes) or via contact card sharing in Messages
- Contact detail with Call and Message deep-link buttons
- Per-player contact lists, synced to host and pushed to clients on reconnect
- My Profile section shows your own name and phone number

### 📞 Calls
- Tabbed Calls app: Keypad / Recents / Contacts
- Dial by number on the keypad — click buttons or type on keyboard/numpad
- Call any saved contact directly from the Contacts tab
- Call back from Recents with one tap
- Clear all call history with one tap
- F8 keybind to answer or hang up (works on foot and in vehicles, remappable)
- Works correctly whether phone is open or closed when call comes in
- Ringback tone for caller, ringtone for recipient
- Busy signal when player is offline or unavailable
- 30-second auto-timeout on unanswered calls
- Missed call badge count, clears on open

### 💬 Messages
- Standalone Messages app with conversation list
- Per-contact message threads with full history
- Keyboard input — type naturally, Enter to send
- Unread message badge on Messages dock icon
- Delete individual message threads
- Message history persists across sessions and syncs to clients on reconnect
- Share your contact card via Messages — recipient can save with one tap

### 🌤️ Weather App
- Current conditions: temperature, condition, wind, cloud cover
- Weather condition icon (8 DDS icons)
- 5-day forecast with real data from the save XML
- Temperature ranges from map weather data
- Synced to clients on connect
- °F / °C toggle in settings

### 🔔 Notifications
- Color-coded by type: invoice, paid, rejected, call, message, info
- Stacks cleanly for multiple notifications
- Auto-dismisses after a few seconds
- Badge count on HUD icon

### ⚙️ Settings
- Time format: 12hr / 24hr
- Temperature units: °F / °C
- Wallpaper picker with preview
- Ringtone selection (4 options: Classic, Farm, Tractor, Old Phone) with preview
- Battery display toggle

### 🔐 Permissions
- Farm Manager: full access (post, pay, reject invoices)
- Farm worker: view only
- Server host: full access across all farms

---

## Multiplayer

- All calls and messages route by `playerUserId` — works correctly even when multiple players share a farm
- Each player is auto-assigned a stable phone number derived from their unique player ID — **the number does not change between sessions or reconnects**
- Phone number format is map-aware: US map (406-XXX-XXXX), EU map (048-XXX-XXX), AS map (081-XXXX-XXXX)
- Players announce themselves on connect via PlayerHello — online status tracked in real time and cleaned up on disconnect
- Contacts, messages, and call history sync back to clients on reconnect
- **Recommended: keep in-game autosave enabled.** Message history, call history, and contacts save with the game save — if you play a long session without saving, recent data may be lost on crash or quit

---

## Public API

Other mods can integrate with RoleplayPhone using the public API in `scripts/RoleplayPhoneAPI.lua`.

Always guard with `RoleplayPhone_checkInstalled()` first:

```lua
if RoleplayPhone_checkInstalled() then
    RoleplayPhone_pushNotification("info", "Your worker finished ploughing Field 3")
end
```

### Available functions

| Function | Description |
|---|---|
| `RoleplayPhone_checkInstalled()` | Returns true if the phone mod is loaded |
| `RoleplayPhone_pushNotification(type, message)` | Push a HUD notification |
| `RoleplayPhone_sendMessage(toFarmId, senderName, text)` | Send a message from e.g. "Tax Office" |
| `RoleplayPhone_sendInvoice(fromFarmId, toFarmId, category, amount, desc)` | Create an invoice programmatically |
| `RoleplayPhone_getInvoices(farmId, inboxOnly)` | Get invoice table for a farm |
| `RoleplayPhone_getInvoiceCount(farmId, status)` | Quick count by status |
| `RoleplayPhone_isPlayerOnline(farmId)` | Check if a farm has connected players |
| `RoleplayPhone_getOnlinePlayers()` | List all online players |
| `RoleplayPhone_getPlayerPhone(farmId)` | Get a farm's auto-assigned phone number |
| `RoleplayPhone_getVersion()` | Version string |

Notification types: `info` `invoice` `paid` `rejected` `ping` `credit` `vehicle`

---

## Installation

1. Download `FS25_RoleplayPhone.zip`
2. Place in your `FarmingSimulator2025/mods/` folder
3. Enable the mod in the mod manager
4. Load a multiplayer game — press **F7** to open the phone

Keybinds are remappable via the in-game Controls menu.

---

## Controls

| Key | Action |
|---|---|
| F7 | Open / close phone |
| F8 | Answer / hang up call |

---

## Compatibility

- Farming Simulator 25
- Multiplayer: host + clients, LAN and online
- Dedicated server compatible (grant Farm Manager via server panel for full invoice access)
- Tested on 16:9 (1920×1080) and 32:9 (3840×1080)

---

## Credits

Built by MarlboroRedMan with Claude (Anthropic).
