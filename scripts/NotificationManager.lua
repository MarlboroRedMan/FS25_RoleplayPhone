-- scripts/NotificationManager.lua
-- Centralized notification system for FS25 Roleplay Invoices
-- Handles: persistent HUD phone icon with badge counter + custom popup notifications
--
-- Usage from anywhere in the mod:
--   NotificationManager:push("invoice",  "New invoice from Farm 2 - $500")
--   NotificationManager:push("paid",     "Farm 3 paid your invoice - $500")
--   NotificationManager:push("rejected", "Farm 3 rejected your invoice")
--   NotificationManager:push("ping",     "PING from Farm 2: Come to my location")
--   NotificationManager:push("info",     "You have 3 unpaid invoices")

NotificationManager = {}

-- ─── Notification type definitions ───────────────────────────────────────────
-- Each type has a label and color (r, g, b) for the left accent border

NotificationManager.TYPES = {
    invoice  = { label = "INVOICE",  r = 0.25, g = 0.50, b = 0.90 },  -- blue
    paid     = { label = "PAID",     r = 0.10, g = 0.70, b = 0.25 },  -- green
    rejected = { label = "REJECTED", r = 0.80, g = 0.15, b = 0.15 },  -- red
    ping     = { label = "PING",     r = 0.10, g = 0.75, b = 0.75 },  -- teal
    info     = { label = "INFO",     r = 0.55, g = 0.55, b = 0.65 },  -- gray
    credit   = { label = "CREDIT",   r = 0.90, g = 0.70, b = 0.10 },  -- gold  (UsedPlus future)
    vehicle  = { label = "VEHICLE",  r = 0.70, g = 0.35, b = 0.90 },  -- purple (UsedPlus future)
}

-- ─── Runtime state ────────────────────────────────────────────────────────────
NotificationManager.queue        = {}    -- active popups: { type, message, timer, maxTimer }
NotificationManager.badgeCount   = 0    -- unread count shown on HUD icon
NotificationManager.whiteOverlay = nil  -- shared draw overlay (set during init)
NotificationManager.iconPhone    = nil  -- idle phone icon
NotificationManager.iconAlert    = nil  -- ringing phone icon (has notifications)

-- ─── Layout constants ─────────────────────────────────────────────────────────
-- HUD phone icon: top-right corner, just below the game's HUD bar
NotificationManager.HUD = {
    x = 0.952,   -- right side with small margin
    y = 0.845,   -- just below the game HUD bar
    w = 0.026,
    h = 0.042,
}

-- Notification popups: appear below HUD icon, right-aligned, stack downward
NotificationManager.NOTIF = {
    x      = 0.735,   -- left edge of popup (right-aligned)
    startY = 0.830,   -- Y of first popup (just below HUD icon)
    w      = 0.250,
    h      = 0.056,
    gap    = 0.006,   -- gap between stacked popups
    maxVisible = 3,   -- max popups shown at once
}

-- Popup lifetime: ~5 seconds at 60fps
NotificationManager.POPUP_LIFETIME = 300

-- ─── Init ─────────────────────────────────────────────────────────────────────
function NotificationManager:init(overlay, modDir, arScale)
    -- Reuse the white overlay from RoleplayPhone (already loaded)
    self.whiteOverlay = overlay
    self.modDir       = modDir
    self.arScale      = arScale or 1.0
    self.queue        = {}
    self.badgeCount   = 0

    -- Apply aspect ratio correction to HUD icon and popup widths
    self.HUD.w   = 0.026 * self.arScale
    self.NOTIF.w = 0.250 * self.arScale
    self.NOTIF.x = 1.0 - self.NOTIF.w - 0.015  -- right-aligned with margin

    -- Drag state
    self.dragging      = false
    self.dragOffsetX   = 0
    self.dragOffsetY   = 0
    self.dragHoldTimer = 0       -- frames held before drag activates
    self.mouseDown     = false
    self.mouseX        = 0
    self.mouseY        = 0

    -- Load HUD phone icons
    local tex = modDir .. "textures/"
    self.iconPhone = createImageOverlay(tex .. "icon_hud_phone.dds")
    self.iconAlert = createImageOverlay(tex .. "icon_hud_phone_alert.dds")

    if not self.iconPhone or self.iconPhone == 0 then
        print("[NotificationManager] WARNING: failed to load icon_hud_phone.dds")
    end
    if not self.iconAlert or self.iconAlert == 0 then
        print("[NotificationManager] WARNING: failed to load icon_hud_phone_alert.dds")
    end

    -- Load saved icon position (per-player, stored in user profile)
    self:loadHudPosition()

    print("[NotificationManager] Initialized")
end

-- ─── Push a new notification ──────────────────────────────────────────────────
function NotificationManager:push(notifType, message)
    local typeDef = self.TYPES[notifType] or self.TYPES.info

    -- Cap queue at maxVisible + a small buffer so we don't leak memory
    if #self.queue >= self.NOTIF.maxVisible + 2 then
        table.remove(self.queue, 1)
    end

    table.insert(self.queue, {
        typeDef  = typeDef,
        message  = message or "",
        timer    = self.POPUP_LIFETIME,
        maxTimer = self.POPUP_LIFETIME,
    })

    -- Increment badge
    self.badgeCount = self.badgeCount + 1

    print(string.format("[NotificationManager] Push [%s]: %s", notifType, message or ""))
end

-- ─── Clear badge (call when phone is opened) ─────────────────────────────────
function NotificationManager:clearBadge()
    self.badgeCount = 0
end

-- ─── HUD position persistence (per-player, user profile folder) ──────────────
function NotificationManager:getPositionFilePath()
    return getUserProfileAppPath() .. "modSettings/FS25_RoleplayInvoices_hud.xml"
end

function NotificationManager:saveHudPosition()
    createFolder(getUserProfileAppPath() .. "modSettings/")
    local path = self:getPositionFilePath()
    local xmlFile = XMLFile.create("RI_HudPos", path, "hudPosition")
    if xmlFile then
        xmlFile:setFloat("hudPosition#x", self.HUD.x)
        xmlFile:setFloat("hudPosition#y", self.HUD.y)
        xmlFile:save()
        xmlFile:delete()
    end
end

function NotificationManager:loadHudPosition()
    local path = self:getPositionFilePath()
    if fileExists(path) then
        local xmlFile = XMLFile.load("RI_HudPos", path)
        if xmlFile then
            local x = xmlFile:getFloat("hudPosition#x", self.HUD.x)
            local y = xmlFile:getFloat("hudPosition#y", self.HUD.y)
            xmlFile:delete()
            -- Clamp to safe screen bounds
            self.HUD.x = math.max(0.01, math.min(0.97, x))
            self.HUD.y = math.max(0.01, math.min(0.97, y))
            print(string.format("[NotificationManager] Loaded HUD position: %.3f, %.3f", self.HUD.x, self.HUD.y))
        end
    end
end

-- ─── Mouse event handler (called from RoleplayPhone:mouseEvent when phone CLOSED)
-- Handles click-hold-drag on the HUD icon
function NotificationManager:mouseEvent(posX, posY, isDown, isUp, button)
    -- Always track mouse position so drag follows cursor during movement events
    self.mouseX = posX
    self.mouseY = posY

    if button ~= Input.MOUSE_BUTTON_LEFT then return false end

    local hud = self.HUD

    -- Mouse pressed
    if isDown then
        -- Check if click is on the HUD icon
        if posX >= hud.x and posX <= hud.x + hud.w and
           posY >= hud.y and posY <= hud.y + hud.h then
            self.mouseDown     = true
            self.dragHoldTimer = 0
            self.dragOffsetX   = posX - hud.x
            self.dragOffsetY   = posY - hud.y
            return true
        end
    end

    -- Mouse released
    if isUp then
        if self.dragging then
            -- Save final position
            self:saveHudPosition()
            NotificationManager:push("info", g_i18n:getText("notif_hud_saved"))
            print(string.format("[NotificationManager] HUD position saved: %.3f, %.3f", hud.x, hud.y))
        end
        self.mouseDown     = false
        self.dragging      = false
        self.dragHoldTimer = 0
        return self.dragging  -- consume event if we were dragging
    end

    return false
end

-- ─── Draw helper (reuses RoleplayPhone's draw rect pattern) ──────────────────
function NotificationManager:drawRect(x, y, w, h, r, g, b, a)
    if not self.whiteOverlay or self.whiteOverlay == 0 then return end
    setOverlayColor(self.whiteOverlay, r, g, b, a or 1.0)
    renderOverlay(self.whiteOverlay, x, y, w, h)
end

-- ─── Draw the persistent HUD phone icon ──────────────────────────────────────
function NotificationManager:drawHudIcon()
    local hud = self.HUD
    local x, y, w, h = hud.x, hud.y, hud.w, hud.h

    -- Choose icon based on notification state
    local icon = (self.badgeCount > 0 and self.iconAlert) or self.iconPhone

    if icon and icon ~= 0 then
        -- Slightly transparent when idle, full opacity when alerting
        local alpha = (self.badgeCount > 0) and 1.0 or 0.75
        setOverlayColor(icon, 1, 1, 1, alpha)
        renderOverlay(icon, x, y, w, h)
    else
        -- Fallback: draw simple rectangle if textures failed to load
        self:drawRect(x, y, w, h, 0.06, 0.06, 0.08, 0.90)
    end

    -- Badge (unread count) - red circle top-right of icon
    if self.badgeCount > 0 then
        local bSize = 0.014
        local bx    = x + w - bSize * 0.5
        local by    = y + h - bSize * 0.5

        -- Red circle background
        self:drawRect(bx, by, bSize, bSize, 0.85, 0.12, 0.12, 1.0)

        -- Badge count number
        local countStr = self.badgeCount > 9 and "9+" or tostring(self.badgeCount)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(1, 1, 1, 1)
        renderText(bx + bSize/2, by + bSize * 0.15, 0.008, countStr)
    end
end

-- ─── Draw active popup notifications ─────────────────────────────────────────
function NotificationManager:drawNotifications()
    local notif    = self.NOTIF
    local visible  = 0
    local toRemove = {}

    -- Popups anchor to the left edge of the HUD icon, just below it
    local popupStartY = self.HUD.y - notif.h - 0.008
    local popupX      = math.max(0.01, self.HUD.x + self.HUD.w - notif.w)

    for i, n in ipairs(self.queue) do
        -- Tick down timer
        n.timer = n.timer - 1
        if n.timer <= 0 then
            table.insert(toRemove, i)
        else
            if visible < notif.maxVisible then
                local alpha = 1.0
                -- Fade out in last 60 frames (~1 second)
                if n.timer < 60 then
                    alpha = n.timer / 60
                end
                -- Fade in during first 20 frames
                local age = n.maxTimer - n.timer
                if age < 20 then
                    alpha = math.min(alpha, age / 20)
                end

                local nx = popupX
                local ny = popupStartY - visible * (notif.h + notif.gap)

                self:drawPopup(n, nx, ny, notif.w, notif.h, alpha)
                visible = visible + 1
            end
        end
    end

    -- Remove expired notifications (reverse order to preserve indices)
    for i = #toRemove, 1, -1 do
        table.remove(self.queue, toRemove[i])
    end
end

-- ─── Draw a single popup notification ────────────────────────────────────────
function NotificationManager:drawPopup(n, x, y, w, h, alpha)
    local td = n.typeDef

    -- Background (dark, semi-transparent)
    self:drawRect(x,       y,       w,       h,       0.06, 0.07, 0.09, 0.92 * alpha)

    -- Colored left accent border
    self:drawRect(x,       y,       0.005,   h,       td.r, td.g, td.b, alpha)

    -- Subtle top highlight line
    self:drawRect(x,       y+h-0.001, w,     0.001,   0.30, 0.32, 0.40, 0.40 * alpha)

    -- Type label (small, colored)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(td.r, td.g, td.b, alpha)
    renderText(x + 0.010, y + h - 0.016, 0.009, g_i18n:getText("notif_type_" .. td.label:lower()))

    -- Message text (white, slightly smaller)
    local msg = n.message or ""
    -- Truncate if too long for the popup width
    if #msg > 42 then
        msg = msg:sub(1, 40) .. ".."
    end
    setTextBold(false)
    setTextColor(0.90, 0.92, 1.00, 0.95 * alpha)
    renderText(x + 0.010, y + 0.010, 0.011, msg)
end

-- ─── Master draw call (called every frame from Mission00.draw) ────────────────
-- This runs even when the phone is CLOSED so the HUD icon is always visible
function NotificationManager:draw()
    if not self.whiteOverlay or self.whiteOverlay == 0 then return end

    -- Handle drag hold timer — requires holding ~0.3s before drag activates
    if self.mouseDown and not self.dragging then
        self.dragHoldTimer = self.dragHoldTimer + 1
        if self.dragHoldTimer > 18 then  -- ~0.3s at 60fps
            self.dragging = true
        end
    end

    -- Update icon position while dragging
    if self.dragging then
        self.HUD.x = math.max(0.01, math.min(1.0 - self.HUD.w - 0.01,
            self.mouseX - self.dragOffsetX))
        self.HUD.y = math.max(0.01, math.min(1.0 - self.HUD.h - 0.01,
            self.mouseY - self.dragOffsetY))
        -- Draw a subtle glow border while dragging so player knows it's moving
        self:drawRect(
            self.HUD.x - 0.003, self.HUD.y - 0.003,
            self.HUD.w + 0.006, self.HUD.h + 0.006,
            0.30, 0.70, 1.00, 0.60)
    end

    self:drawHudIcon()
    self:drawNotifications()
end
