# FS25 RoleplayPhone

A full-featured roleplay smartphone for multiplayer Farming Simulator 25 servers.

Built for serious RP communities that want a real in-game economy and communication system — invoices, contacts, calls, messaging, weather, notifications, and a public API for integration with other mods.

---

## Features

### 📱 Phone UI
- Realistic smartphone interface with phone frame overlay
- Home screen with live clock, date, season, and weather widget
- App grid with swipeable pages
- Dock with quick-access apps
- 6 wallpaper options (color swatches + photo wallpapers)
- Draggable HUD notification icon

### 💰 Invoice System
- 23 invoice categories (rent, services, labor, etc.)
- Inbox and outbox with full detail view
- Pay, reject, or mark invoices from the phone
- Real money transfer via FS25's economy system
- Full multiplayer sync — all players see the same invoice state

### 📇 Contacts
- Add contacts by selecting online players — phone number and routing auto-filled
- Contact detail with call and message buttons
- Per-player contact lists, synced to host and restored on reconnect

### 📞 Calls
- Call any contact directly from their detail screen
- Non-freezing call popup — player keeps full movement while on a call
- F8 keybind to answer or hang up (works on foot and in vehicles, remappable)
- Ringback tone for caller while waiting
- Busy signal when player is offline or unavailable
- 30-second auto-timeout on unanswered calls
- Missed call history with badge count

### 💬 Messaging
- Send and receive messages in per-contact conversation threads
- Message history persists for the session
- Unread message badge on contact rows

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
- Farm manager: full access
- Farm worker: view only
- Server host: full access across all farms

---

## Multiplayer

- All calls and messages route by **playerUserId** — works correctly even when multiple players share a farm
- Each player is auto-assigned a deterministic phone number (e.g. `555-3761`) based on their userId
- Players announce themselves on connect via PlayerHello — online status is tracked in real time
- Busy signal fires immediately if the target player is offline
- Contacts sync back to clients on reconnect

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
| Backspace | Delete text in active field |

---

## Compatibility

- Farming Simulator 25
- Multiplayer: host + clients, LAN and online
- Tested on 16:9 (1920x1080) and 32:9 (3840x1080)

---

## Credits

Built by MarlboroRedMan with Claude (Anthropic).
