# CLAUDE.md — FS25_RoleplayPhone

Read this before touching any file in this repo. It exists because a past session
introduced a real bug by guessing at a convention instead of checking it — this file
is the convention, written down, so that doesn't happen again.

## What this mod is

A Farming Simulator 25 multiplayer mod adding a full in-game smartphone: calls,
messaging, contacts, invoices, weather, notifications. Built for a personal
roleplay server. Solo dev project — be precise, not fast. There is no release
deadline. Read `ROADMAP.md` for planned features and `README.md` for the feature
overview before assuming something doesn't exist.

## Hard rule: verify before claiming

Never state a line number, a function's current behavior, or "this file doesn't
have X" without actually reading the current file first. Negative search results
are not evidence of absence — re-check with a direct file read. If a plan or
handoff doc claims something about existing code, that claim still needs
verification against the live file before you build on it.

## The message schema — the #1 source of real bugs so far

Every message entry stored in `RoleplayPhone.messages[key]`,
`RoleplayPhone.playerMessages[uniqueId][key]`, or round-tripped through
`savePlayerData`/`loadPlayerData` in `PhoneSave.lua` MUST use exactly these
field names:

```lua
{
    fromUniqueId = "",   -- stable identity of the sender, NEVER fromUserId/from/senderId
    senderName   = "",
    text         = "",
    gameDay      = 0,
    gameTime     = 0,
    sent         = false,  -- NEVER isOutgoing or any other name
    msgType      = "text",
    cardName     = "",
    cardPhone    = "",
    cardFarm     = "",
}
```

`savePlayerData` in `PhoneSave.lua` iterates `pairs(messages)` with NO key
filtering — it serializes whatever is in the table, using exactly these field
names. If you invent different field names for a new kind of message (a bot,
an NPC, a system notification), `savePlayerData`/`loadPlayerData` will silently
write/read wrong or empty values for the fields it doesn't recognize. There is
no warning when this happens. This already caused a real bug in the Carrier Bot
feature — caught only by manually cross-referencing every write site against
`PhoneSave.lua` by hand. Don't make that necessary again: use the schema above
for every message-shaped table, no exceptions, even for "it's not really a
chat message" cases.

## Host vs. client are NOT symmetric — check both paths for every new action

This is the second real bug class so far. `RoleplayPhone:sendMessage()` in
`MessageManager.lua` is the canonical example: when `g_server ~= nil` (you are
the host), the function resolves the recipient's connection and routes
**inline, directly in `sendMessage()`** — it never reaches `RI_MessageEvent:run()`'s
server branch. That branch only fires for messages **received from a remote
client** (`connection ~= nil and not connection:getIsServer()`).

Consequence: if you intercept/extend behavior only inside an event's `:run()`,
it will work for clients and silently do nothing for the host, or vice versa.
**Every new "player does X" feature needs an explicit host-direct code path
AND a client-event code path.** Write both, test both mentally before
proposing a plan. Look at `sendMessage()`'s `if g_server ~= nil ... elseif
g_client ~= nil ...` split as the reference pattern.

## Identity: uniqueId vs userId

- `uniqueId` — stable UUID, persists across sessions/reconnects. Use for
  ALL persistence (registry, save files, `playerMessages`/`playerCalls` keys).
- `userId` — integer, assigned per-session, changes every reconnect. Use only
  for current-session lookups (`onlineUsers`, voice functions like
  `voiceChatSetUserVolume`, connection routing).
- Never use `userId` as a save-file key or registry key. Never assume
  `onlineUsers` entries have a `userId` field stored on them — the table key
  itself IS the userId (`onlineUsers[someUserId] = {farmId, name, phone, uniqueId}`).

## Multiplayer rules

- Server is authoritative. Clients request; server applies and broadcasts/pushes.
- New synced state needs both a request event (client→server, if client-initiated)
  and a push/broadcast event (server→client(s)). Follow the existing `RI_*Event`
  class pattern: `emptyNew`, `.new(...)`, `:writeStream`, `:readStream` (calls
  `self:run(connection)`), `:run(connection)`.
- The host doesn't receive its own broadcasts — any server-side broadcast that
  needs to also apply locally on the host needs an explicit `g_server ~= nil`
  branch that applies the effect directly, not just the broadcast call.

## File layout — `modDesc.xml` load order matters

- **Event files** (`*Events.lua`) load first, as core dependencies — they
  define event classes other files reference.
- **`RoleplayPhone.lua`** loads next — defines the `RoleplayPhone` table itself.
- **Phone extension files** (`PhoneSave.lua`, `PhoneHelpers.lua`, `PhoneUI.lua`,
  etc.) load after `RoleplayPhone.lua` — they add methods to a table that must
  already exist.
- **App files** (`scripts/apps/*.lua`) each own one app's draw function. Do NOT
  add app draw logic to `RoleplayPhone.lua` — it's the frame/home/dock/routing
  only. Input handling for apps lives in matching `*Input.lua` files
  (`CallsInput.lua`, `PhoneInput.lua`, etc.) — drawing and input are separate
  files even for the same feature; a new UI element needs hitbox-drawing code
  AND a matching handler in the right `*Input.lua` file, or it renders but does
  nothing.
- New source files need a `<sourceFile>` entry added to `modDesc.xml` in the
  correct section above, or they won't load at all.

## Scope calibration

"Small, standalone" features in this codebase still tend to touch 6-9 files —
save schema, network events, settings UI, input handling, state init. There's
rarely a feature that's truly isolated to one file. Plan for that rather than
being surprised by it.

## Before declaring a task done

Self-check: for every new table inserted into `messages`, `playerMessages`,
`contacts`, or `callHistory`, list the field names you used and confirm they
match the schema in `PhoneSave.lua` exactly. For every new player-triggered
action, confirm there's a working path for both host and remote client. State
both checks explicitly in the handoff — don't just assert "this works," show
the cross-reference.

## Build / test loop

- Rezip after every change: `py "C:\Users\danbj\Documents\V0.1.1\rezip.py"`
- Deployed mod path: `C:\Users\danbj\Documents\My Games\FarmingSimulator2025\mods\FS25_RoleplayPhone\`
- Don't ask Dan to run the rezip — run it yourself as the last step.

## Handoff docs

End every implementation task with a handoff doc covering: files created/modified
with what changed and why, any deviation from the original plan and the reason,
and an explicit "Things needing attention before testing" section. Be honest
about anything uncertain or unverified rather than asserting it works — say so
plainly if something wasn't checked against the live engine API.
