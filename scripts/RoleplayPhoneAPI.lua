-- scripts/RoleplayPhoneAPI.lua
-- Public API for FS25_RoleplayPhone
-- Other mods can call these functions to interact with the phone system.
--
-- ── IMPORTANT: Cross-mod global access in FS25 ───────────────────────────────
-- FS25 runs each mod in its own Lua environment. Bare global references like
-- `RoleplayPhone_checkInstalled` only resolve within the mod that defined them.
-- To call API functions from another mod you MUST go through getfenv(0), which
-- is the shared engine-level environment visible to all mods:
--
--   local fn = getfenv(0)["RoleplayPhone_checkInstalled"]
--   if fn and fn() then
--       local push = getfenv(0)["RoleplayPhone_pushNotification"]
--       if push then push("info", "Tax due: $1,500") end
--   end
--
-- For convenience, define a small helper in your own mod:
--
--   local function rpCall(name, ...)
--       local fn = getfenv(0)[name]
--       if fn then return fn(...) end
--   end
--
--   if rpCall("RoleplayPhone_checkInstalled") then
--       rpCall("RoleplayPhone_pushNotification", "info", "Tax due: $1,500")
--   end
--
-- All functions are safe to call — they silently do nothing and return nil/false
-- if the phone mod is not installed.  Always guard with checkInstalled() first.

-- ─── RoleplayPhone_checkInstalled() ──────────────────────────────────────────
-- Returns true if the phone mod is loaded and ready.
-- Call this first before using any other API function.
--
-- @return boolean
function RoleplayPhone_checkInstalled()
    return RoleplayPhone ~= nil and RoleplayPhone.STATE ~= nil
end


-- ─── RoleplayPhone_pushNotification(type, message) ───────────────────────────
-- Push a notification to the player's phone HUD.
-- The notification appears as a small popup above the phone icon,
-- exactly the same as the mod's own internal notifications.
--
-- @param type    string  One of: "info" | "invoice" | "paid" | "rejected" | "ping" | "credit" | "vehicle"
--                        Controls the colour and label of the notification.
--                        Unknown types fall back to "info".
-- @param message string  The notification text (max ~42 chars before truncation).
-- @return boolean        true if the notification was pushed, false if phone not installed.
--
-- EXAMPLE:
--   RoleplayPhone_pushNotification("info", "Your worker finished ploughing Field 3")
--   RoleplayPhone_pushNotification("credit", "Income payment received: $2,400")
--   RoleplayPhone_pushNotification("vehicle", "Vehicle maintenance due: Fendt 516")
function RoleplayPhone_pushNotification(notifType, message)
    if not RoleplayPhone_checkInstalled() then return false end
    if not NotificationManager then return false end
    if not notifType or notifType == "" then notifType = "info" end
    if not message or message == "" then return false end
    NotificationManager:push(notifType, tostring(message))
    return true
end


-- ─── RoleplayPhone_sendMessage(toFarmId, senderName, message) ────────────────
-- Send a message directly into a player's message thread.
-- The message appears as if it came from 'senderName' —
-- useful for system/NPC messages (e.g. "Bank" or "Tax Office").
--
-- Note: This routes by farmId (not playerUserId) since external mods
-- work at the farm level. The message will appear in a thread named
-- after senderName if no contact matches.
--
-- @param toFarmId    number  The farmId of the recipient.
-- @param senderName  string  Display name shown as the sender (e.g. "Tax Office").
-- @param message     string  The message text.
-- @return boolean            true if sent, false if phone not installed or invalid args.
--
-- EXAMPLE:
--   RoleplayPhone_sendMessage(2, "Tax Office", "Your tax bill of $500 is due in 3 days.")
function RoleplayPhone_sendMessage(toFarmId, senderName, message)
    if not RoleplayPhone_checkInstalled() then return false end
    if not toFarmId or not senderName or not message then return false end
    if message == "" then return false end

    local myFarmId = RoleplayPhone:getMyFarmId()
    local gameDay  = (g_currentMission and g_currentMission.environment
                      and g_currentMission.environment.currentDay) or 0

    -- Route the message through the existing network event system
    local evt = RI_MessageEvent.new(myFarmId, toFarmId, tostring(senderName), tostring(message), gameDay)
    if g_server ~= nil then
        g_server:broadcastEvent(evt)
    elseif g_client ~= nil then
        g_client:getServerConnection():sendEvent(evt)
    end
    return true
end


-- ─── RoleplayPhone_isPlayerOnline(farmId) ────────────────────────────────────
-- Check whether any player from a given farm is currently connected.
-- Useful for other mods that want to know if a farm is active
-- before sending notifications or messages.
--
-- @param farmId  number  The farmId to check.
-- @return boolean        true if at least one player from this farm is online.
--
-- EXAMPLE:
--   if RoleplayPhone_isPlayerOnline(2) then
--       RoleplayPhone_sendMessage(2, "Bank", "Loan payment processed.")
--   end
function RoleplayPhone_isPlayerOnline(farmId)
    if not RoleplayPhone_checkInstalled() then return false end
    if not farmId then return false end
    -- Check onlineUsers for any user belonging to this farm
    for userId, info in pairs(RoleplayPhone.onlineUsers or {}) do
        if info.farmId == farmId then return true end
    end
    -- Also check if it's the host's own farm
    if RoleplayPhone:getMyFarmId() == farmId then return true end
    return false
end


-- ─── RoleplayPhone_getInvoices(farmId, inboxOnly) ────────────────────────────
-- Returns the invoice list for a given farm.
-- Useful for other mods that want to display or react to invoice data.
--
-- @param farmId    number   The farmId to get invoices for.
-- @param inboxOnly boolean  If true, returns only invoices sent TO this farm.
--                           If false/nil, returns all invoices involving this farm.
-- @return table[]|nil  Array of invoice tables, or nil if not installed.
--
-- Each invoice table contains:
--   id, fromFarmId, toFarmId, amount, category, description, notes,
--   status ("PENDING"|"PAID"|"REJECTED"), createdDate, dueDate
--
-- EXAMPLE:
--   local invoices = RoleplayPhone_getInvoices(2, true)
--   if invoices then
--       for _, inv in ipairs(invoices) do
--           print(inv.category .. ": $" .. inv.amount .. " — " .. inv.status)
--       end
--   end
function RoleplayPhone_getInvoices(farmId, inboxOnly)
    if not RoleplayPhone_checkInstalled() then return nil end
    if not InvoiceManager then return nil end
    if not farmId then return nil end
    local result = {}
    for _, inv in pairs(InvoiceManager.invoices) do
        if inboxOnly then
            if inv.toFarmId == farmId then
                table.insert(result, inv)
            end
        else
            if inv.toFarmId == farmId or inv.fromFarmId == farmId then
                table.insert(result, inv)
            end
        end
    end
    table.sort(result, function(a, b) return (a.id or 0) > (b.id or 0) end)
    return result
end


-- ─── RoleplayPhone_getInvoiceCount(farmId, status) ───────────────────────────
-- Returns a count of invoices for a farm, optionally filtered by status.
-- Useful for badge counts or quick checks without loading the full table.
--
-- @param farmId  number          The farmId to count invoices for.
-- @param status  string|nil      Filter by status: "PENDING" | "PAID" | "REJECTED"
--                                Pass nil to count all invoices for this farm.
-- @return number|nil  Count of matching invoices, or nil if not installed.
--
-- EXAMPLE:
--   local unpaid = RoleplayPhone_getInvoiceCount(2, "PENDING")
--   if unpaid and unpaid > 0 then
--       -- show badge
--   end
function RoleplayPhone_getInvoiceCount(farmId, status)
    if not RoleplayPhone_checkInstalled() then return nil end
    if not InvoiceManager then return nil end
    if not farmId then return nil end
    local count = 0
    for _, inv in pairs(InvoiceManager.invoices) do
        if inv.toFarmId == farmId or inv.fromFarmId == farmId then
            if not status or inv.status == status then
                count = count + 1
            end
        end
    end
    return count
end


-- ─── RoleplayPhone_sendInvoice(fromFarmId, toFarmId, category, amount, desc) ─
-- Create and send an invoice programmatically from another mod.
-- Useful for mods like TaxMod or WorkerCosts that need to bill players.
-- The invoice appears in the recipient's phone inbox exactly like a normal invoice.
--
-- @param fromFarmId  number  The farm sending the invoice (billing party).
-- @param toFarmId    number  The farm receiving the invoice (paying party).
-- @param category    string  Invoice category (e.g. "Tax", "Rent - House (Small)").
-- @param amount      number  Amount in dollars.
-- @param description string  Optional description shown in the invoice detail.
-- @return boolean            true if sent, false if phone not installed or invalid args.
--
-- EXAMPLE:
--   -- TaxMod billing a player
--   RoleplayPhone_sendInvoice(1, 2, "Tax", 500, "Monthly property tax")
function RoleplayPhone_sendInvoice(fromFarmId, toFarmId, category, amount, description)
    if not RoleplayPhone_checkInstalled() then return false end
    if not fromFarmId or not toFarmId or not amount then return false end
    if fromFarmId == toFarmId then return false end

    local gameDay = (g_currentMission and g_currentMission.environment
                     and g_currentMission.environment.currentDay) or 0

    local invoiceData = {
        id          = 0,  -- server assigns real id
        fromFarmId  = fromFarmId,
        toFarmId    = toFarmId,
        category    = tostring(category or "Other"),
        description = tostring(description or ""),
        notes       = "",
        amount      = tonumber(amount) or 0,
        status      = "PENDING",
        createdDate = gameDay,
        dueDate     = "",
    }

    local inv = Invoice.new(invoiceData)
    local evt = RI_SendInvoiceEvent.new(inv, true)
    if g_server ~= nil then
        g_server:broadcastEvent(evt)
    elseif g_client ~= nil then
        g_client:getServerConnection():sendEvent(evt)
    end
    return true
end


-- ─── RoleplayPhone_getPlayerPhone(farmId) ────────────────────────────────────
-- Get the auto-assigned phone number for any online player by farmId.
-- Returns nil if the player is not currently connected.
--
-- @param farmId  number  The farmId to look up.
-- @return string|nil     Phone number string (e.g. "555-6522") or nil.
--
-- EXAMPLE:
--   local phone = RoleplayPhone_getPlayerPhone(2)
--   if phone then print("Farm 2 is reachable at " .. phone) end
function RoleplayPhone_getPlayerPhone(farmId)
    if not RoleplayPhone_checkInstalled() then return nil end
    for userId, info in pairs(RoleplayPhone.onlineUsers or {}) do
        if info.farmId == farmId then
            return info.phone
        end
    end
    -- Check if it's the host
    if RoleplayPhone:getMyFarmId() == farmId then
        return RoleplayPhone:hashPhone(RoleplayPhone:getMyUserId())
    end
    return nil
end


-- ─── RoleplayPhone_getVersion() ──────────────────────────────────────────────
-- Returns the current version string of the phone mod.
-- Useful for compatibility checks.
--
-- @return string|nil  Version string (e.g. "0.4.0") or nil if not installed.
--
-- EXAMPLE:
--   local ver = RoleplayPhone_getVersion()
--   if ver then print("Phone version: " .. ver) end
function RoleplayPhone_getVersion()
    if not RoleplayPhone_checkInstalled() then return nil end
    -- Read version from g_modManager if available
    if g_modManager then
        local mod = g_modManager:getModByName("FS25_RoleplayPhone")
        if mod and mod.version then return mod.version end
    end
    return "unknown"
end


-- ─── RoleplayPhone_getOnlinePlayers() ────────────────────────────────────────
-- Returns a list of all currently online players.
-- Each entry has: { userId, farmId, name, phone }
--
-- @return table[]|nil  Array of player info tables, or nil if not installed.
--
-- EXAMPLE:
--   local players = RoleplayPhone_getOnlinePlayers()
--   if players then
--       for _, p in ipairs(players) do
--           print(p.name .. " is online on farm " .. p.farmId)
--       end
--   end
function RoleplayPhone_getOnlinePlayers()
    if not RoleplayPhone_checkInstalled() then return nil end
    local result = {}
    for userId, info in pairs(RoleplayPhone.onlineUsers or {}) do
        table.insert(result, {
            userId = userId,
            farmId = info.farmId,
            name   = info.name,
            phone  = info.phone,
        })
    end
    -- Include the host themselves
    local myUserId = RoleplayPhone:getMyUserId()
    local found = false
    for _, p in ipairs(result) do
        if p.userId == myUserId then found = true; break end
    end
    if not found then
        local myFarmId = RoleplayPhone:getMyFarmId()
        table.insert(result, {
            userId = myUserId,
            farmId = myFarmId,
            name   = RoleplayPhone:getFarmName(myFarmId),
            phone  = RoleplayPhone:hashPhone(myUserId),
        })
    end
    return result
end


-- ─── Self-register into the shared engine environment ────────────────────────
-- FS25 isolates each mod in its own Lua env. Bare globals defined here are NOT
-- visible to other mods unless we explicitly write them into getfenv(0).
--
-- We register every public API function under its own name so any external mod
-- can reach it with:
--
--   local fn = getfenv(0)["RoleplayPhone_checkInstalled"]
--
-- This block runs once at script-load time. getfenv(0) is always available.
do
    local env  = getfenv(0)
    local self = getfenv(1)   -- this script's own env, where the functions live
    local apiFunctions = {
        "RoleplayPhone_checkInstalled",
        "RoleplayPhone_pushNotification",
        "RoleplayPhone_sendMessage",
        "RoleplayPhone_isPlayerOnline",
        "RoleplayPhone_getInvoices",
        "RoleplayPhone_getInvoiceCount",
        "RoleplayPhone_sendInvoice",
        "RoleplayPhone_getPlayerPhone",
        "RoleplayPhone_getVersion",
        "RoleplayPhone_getOnlinePlayers",
    }
    local registered = 0
    for _, name in ipairs(apiFunctions) do
        if self[name] then
            env[name] = self[name]
            registered = registered + 1
        end
    end
    print(string.format("[RoleplayPhone] API self-registered into shared env (%d functions)", registered))
end
