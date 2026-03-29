function RoleplayPhone:drawInvoicesList()
    local s        = self.BIG
    local px       = s.x
    local py       = s.y
    local pw       = s.w
    local ph       = s.h
    local contentY = py + ph - 0.055  -- just below status bar

    -- ── Header ──
    local headerH  = 0.05
    local headerY  = contentY - headerH
    self:drawRect(px, headerY, pw, headerH, 0.10, 0.13, 0.20, 1.0)

    -- Back button
    self:drawButton("btn_back", px+0.006, headerY+0.010, 0.055 * self.arScale, 0.030,
                    g_i18n:getText("ui_btn_back"), 0.18, 0.20, 0.28, 0.011)

    -- Title
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw/2, headerY + 0.016, 0.016, g_i18n:getText("screen_title_invoices"))

    -- ── Tabs ──
    local tabY = headerY - 0.038
    local tabH = 0.038
    local tabW = pw / 2

    -- Inbox tab
    local inboxActive  = self.currentTab == self.TAB.INBOX
    local outboxActive = self.currentTab == self.TAB.OUTBOX

    self:drawRect(px,      tabY, tabW, tabH,
                  inboxActive  and 0.13 or 0.09,
                  inboxActive  and 0.18 or 0.11,
                  inboxActive  and 0.28 or 0.15, 1.0)
    self:drawRect(px+tabW, tabY, tabW, tabH,
                  outboxActive and 0.13 or 0.09,
                  outboxActive and 0.18 or 0.11,
                  outboxActive and 0.28 or 0.15, 1.0)

    -- Active tab indicator line
    if inboxActive then
        self:drawRect(px, tabY, tabW, 0.003, 0.30, 0.55, 1.00, 1.0)
    else
        self:drawRect(px+tabW, tabY, tabW, 0.003, 0.30, 0.55, 1.00, 1.0)
    end

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(inboxActive)
    setTextColor(1, 1, 1, inboxActive and 1.0 or 0.5)
    renderText(px + tabW/2, tabY + 0.012, 0.013, g_i18n:getText("invoices_tab_inbox"))

    setTextBold(outboxActive)
    setTextColor(1, 1, 1, outboxActive and 1.0 or 0.5)
    renderText(px + tabW + tabW/2, tabY + 0.012, 0.013, g_i18n:getText("invoices_tab_outbox"))

    self:addHitbox("tab_inbox",  px,      tabY, tabW, tabH, {})
    self:addHitbox("tab_outbox", px+tabW, tabY, tabW, tabH, {})

    -- ── Invoice list area ──
    local listTopY    = tabY - 0.006
    local listBottomY = py + 0.015
    local listH       = listTopY - listBottomY

    -- Get invoices for current farm
    local myFarmId = self:getMyFarmId()
    local inbox    = self.currentTab == self.TAB.INBOX
    local invoices = InvoiceManager:getInvoicesForFarm(myFarmId, inbox)

    -- Create Invoice button (Outbox only, moderator+ only)
    if not inbox and self:canPost() then
        local btnH = 0.042
        local btnY = listBottomY
        listBottomY = listBottomY + btnH + 0.008
        listH       = listTopY - listBottomY

        self:drawButton("btn_create_invoice",
                        px + 0.015, btnY, pw - 0.030, btnH,
                        g_i18n:getText("invoices_btn_create"), 0.10, 0.38, 0.18, 0.013)
    elseif not inbox then
        -- Show read-only message so player understands why button is missing
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextColor(0.40, 0.45, 0.55, 0.70)
        renderText(px + pw/2, listBottomY + 0.018, 0.009, g_i18n:getText("invoices_manager_send_hint"))
        listBottomY = listBottomY + 0.030
        listH       = listTopY - listBottomY
    end

    -- Draw invoice rows
    if #invoices == 0 then
        -- Empty state
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextColor(0.4, 0.45, 0.55, 0.8)
        local emptyMsg = inbox and g_i18n:getText("invoices_empty_inbox") or g_i18n:getText("invoices_empty_outbox")
        renderText(px + pw/2, listBottomY + listH/2, 0.013, emptyMsg)
    else
        local rowH     = 0.072
        local rowPad   = 0.006
        local maxRows  = math.floor(listH / (rowH + rowPad))
        local shown    = math.min(#invoices, maxRows)

        for i = 1, shown do
            local inv  = invoices[i]
            local rowY = listTopY - (i * (rowH + rowPad))

            if rowY < listBottomY then break end

            self:drawInvoiceRow(inv, px + 0.010, rowY, pw - 0.020, rowH, i)
        end

        -- "X more" hint if list is longer than visible
        if #invoices > maxRows then
            setTextAlignment(RenderText.ALIGN_CENTER)
            setTextBold(false)
            setTextColor(0.4, 0.45, 0.55, 0.7)
            renderText(px + pw/2, listBottomY - 0.001, 0.010,
                       string.format(g_i18n:getText("invoices_more_fmt"), #invoices - maxRows))
        end
    end
end

-- Draw a single invoice row
function RoleplayPhone:drawInvoiceRow(inv, x, y, w, h, index)
    -- Row background (alternating slight shade)
    local shade = (index % 2 == 0) and 0.115 or 0.095
    self:drawRect(x, y, w, h, shade, shade+0.015, shade+0.030, 1.0)

    -- Status badge (right side)
    local badgeW = 0.075 * self.arScale
    local badgeH = 0.022
    local badgeX = x + w - badgeW - 0.008 * self.arScale
    local badgeY = y + h - badgeH - 0.008
    local sr, sg, sb = self:getStatusColor(inv.status)
    self:drawRect(badgeX, badgeY, badgeW, badgeH, sr, sg, sb, 1.0)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
    renderText(badgeX + badgeW/2, badgeY + 0.004, 0.009, inv.status or "PENDING")

    -- Invoice # and date
    local indent = 0.010 * self.arScale
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(0.75, 0.85, 1.0, 1.0)
    renderText(x + indent, y + h - 0.020, 0.011, string.format(g_i18n:getText("invoices_num_fmt"), inv.id or 0))

    setTextBold(false)
    setTextColor(0.5, 0.55, 0.65, 0.8)
    renderText(x + indent, y + h - 0.034, 0.010,
               string.format(g_i18n:getText("ui_day_fmt"), tostring(inv.createdDate or "?")))

    -- Category
    setTextColor(0.85, 0.85, 0.95, 0.9)
    local cat = inv.category or g_i18n:getText("invoices_uncategorized")
    if #cat > 28 then cat = cat:sub(1,26) .. ".." end
    renderText(x + indent, y + 0.030, 0.011, cat)

    -- Amount (right side, larger)
    setTextAlignment(RenderText.ALIGN_RIGHT)
    setTextBold(true)
    setTextColor(0.35, 0.95, 0.45, 1.0)
    renderText(x + w - indent, y + 0.028, 0.015,
               string.format("$%s", self:formatMoney(inv.amount or 0)))

    -- Register hitbox
    self:addHitbox("invoice_row", x, y, w, h, { invoice=inv })
end

-- ─── INVOICE DETAIL screen ───────────────────────────────────────────────────
function RoleplayPhone:drawInvoiceDetail()
    if not self.selectedInvoice then
        self.state = self.STATE.INVOICES_LIST
        return
    end

    local s   = self.BIG
    local px  = s.x
    local py  = s.y
    local pw  = s.w
    local ph  = s.h
    local inv = self.selectedInvoice

    -- Header
    local headerH = 0.05
    local headerY = py + ph - 0.055 - headerH
    self:drawRect(px, headerY, pw, headerH, 0.10, 0.13, 0.20, 1.0)
    self:drawButton("btn_back", px+0.006, headerY+0.010, 0.055 * self.arScale, 0.030,
                    g_i18n:getText("ui_btn_back"), 0.18, 0.20, 0.28, 0.011)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw/2, headerY + 0.016, 0.015,
               string.format(g_i18n:getText("invoices_detail_title_fmt"), inv.id or 0))

    -- Status banner
    local sr, sg, sb = self:getStatusColor(inv.status)
    local bannerY = headerY - 0.038
    self:drawRect(px, bannerY, pw, 0.038, sr, sg, sb, 0.85)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw/2, bannerY + 0.010, 0.016, inv.status or g_i18n:getText("invoices_status_pending"))

    -- Detail fields
    local fieldX = px + 0.020
    local fieldW = pw - 0.040
    local curY   = bannerY - 0.020

    local function drawDetail(label, value)
        curY = curY - 0.038
        self:drawRect(fieldX, curY, fieldW, 0.036, 0.10, 0.13, 0.19, 1.0)
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(false)
        setTextColor(0.55, 0.65, 0.80, 0.85)
        renderText(fieldX + 0.010, curY + 0.024, 0.009, label)
        setTextColor(1, 1, 1, 1)
        renderText(fieldX + 0.010, curY + 0.008, 0.013, tostring(value or "-"))
    end

    -- Get farm names - check farmManager first, then knownFarms for offline farms
    local fromName = self:getFarmName(inv.fromFarmId)
    local toName   = self:getFarmName(inv.toFarmId)

    drawDetail(g_i18n:getText("invoices_detail_from"),        fromName)
    drawDetail(g_i18n:getText("invoices_detail_to"),          toName)
    drawDetail(g_i18n:getText("invoices_detail_category"),    inv.category)
    drawDetail(g_i18n:getText("invoices_detail_amount"),      "$" .. self:formatMoney(inv.amount or 0))
    drawDetail(g_i18n:getText("invoices_detail_due_date"),    inv.dueDate or g_i18n:getText("invoices_detail_not_set"))
    drawDetail(g_i18n:getText("invoices_detail_created"),     string.format(g_i18n:getText("ui_day_fmt"), tostring(inv.createdDate or "?")))

    if inv.description and inv.description ~= "" then
        drawDetail(g_i18n:getText("invoices_detail_description"), inv.description)
    end
    if inv.notes and inv.notes ~= "" then
        drawDetail(g_i18n:getText("invoices_detail_notes"), inv.notes)
    end

    -- Action buttons (bottom) — only shown to moderator+
    local btnY     = py + 0.015
    local myFarmId = self:getMyFarmId()
    local canAct   = self:canAct()

    if canAct then
        -- Pay button (shown to recipient if not already paid)
        if inv.toFarmId == myFarmId and inv.status ~= "PAID" then
            self:drawButton("btn_pay_invoice",
                            px + 0.015, btnY, pw*0.44, 0.045,
                            g_i18n:getText("invoices_btn_pay"), 0.10, 0.40, 0.18, 0.013)
        end

        -- Mark Paid button (shown to sender)
        if inv.fromFarmId == myFarmId and inv.status ~= "PAID" then
            self:drawButton("btn_mark_paid",
                            px + pw*0.54, btnY, pw*0.42, 0.045,
                            g_i18n:getText("invoices_btn_mark_paid"), 0.28, 0.28, 0.10, 0.013)
        end

        -- Reject button (shown to recipient if still PENDING)
        if inv.toFarmId == myFarmId and inv.status == "PENDING" then
            self:drawButton("btn_reject_invoice",
                            px + pw*0.54, btnY, pw*0.42, 0.045,
                            g_i18n:getText("invoices_btn_reject"), 0.42, 0.10, 0.10, 0.013)
        end
    else
        -- Regular player — read only
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextColor(0.40, 0.45, 0.55, 0.70)
        renderText(px + pw/2, btnY + 0.015, 0.009, g_i18n:getText("invoices_manager_action_hint"))
    end
end

-- ─── CREATE INVOICE screen ───────────────────────────────────────────────────
function RoleplayPhone:drawCreateInvoice()
    local s   = self.BIG
    local px  = s.x
    local py  = s.y
    local pw  = s.w
    local ph  = s.h

    -- Header
    local headerH = 0.05
    local headerY = py + ph - 0.055 - headerH
    self:drawRect(px, headerY, pw, headerH, 0.10, 0.13, 0.20, 1.0)
    self:drawButton("btn_back", px+0.006, headerY+0.010, 0.055 * self.arScale, 0.030,
                    g_i18n:getText("ui_btn_back"), 0.18, 0.20, 0.28, 0.011)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw/2, headerY + 0.016, 0.015, g_i18n:getText("screen_title_create_invoice"))

    local col1X  = px + 0.015
    local colW   = pw - 0.030
    local fldH   = 0.050
    local fldGap = 0.008
    local arrowW = 0.018
    local curY   = headerY - 0.015

    -- ── To Farm selector ──
    curY = curY - fldH - fldGap
    local farms    = self:getAvailableFarms()
    local farm     = farms[self.form.toFarmIndex] or farms[1]
    local farmName = farm and farm.name or "Unknown"

    self:drawRect(col1X, curY, colW, fldH, 0.10, 0.14, 0.20, 1.0)
    self:drawRect(col1X, curY+fldH-0.002, colW, 0.002, 0.5, 0.6, 0.8, 0.4)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(0.55, 0.65, 0.80, 0.85)
    renderText(col1X + 0.010, curY + fldH - 0.016, 0.009, g_i18n:getText("invoices_field_send_to"))
    local arrowsX = col1X + colW - arrowW*2 - 0.006
    self:drawButton("farm_prev", arrowsX, curY + fldH - 0.030, arrowW, 0.020, "<", 0.20, 0.22, 0.32, 0.010)
    self:drawButton("farm_next", arrowsX + arrowW + 0.004, curY + fldH - 0.030, arrowW, 0.020, ">", 0.20, 0.22, 0.32, 0.010)
    setTextColor(1, 1, 1, 1)
    renderText(col1X + 0.010, curY + 0.010, 0.013, farmName)

    -- ── Category Group selector ──
    curY = curY - fldH - fldGap
    local groups = InvoiceManager.categoryGroups
    local group  = groups[self.form.categoryGroupIndex] or groups[1]

    self:drawRect(col1X, curY, colW, fldH, 0.10, 0.14, 0.20, 1.0)
    self:drawRect(col1X, curY+fldH-0.002, colW, 0.002, 0.5, 0.6, 0.8, 0.4)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(0.55, 0.65, 0.80, 0.85)
    renderText(col1X + 0.010, curY + fldH - 0.016, 0.009, g_i18n:getText("invoices_field_category"))
    setTextColor(1, 1, 1, 1)
    renderText(col1X + 0.010, curY + 0.010, 0.012, group.name)
    self:drawButton("cat_group_prev", col1X + colW - arrowW*2 - 0.008, curY + fldH - 0.030, arrowW, 0.020, "<", 0.20, 0.22, 0.32, 0.010)
    self:drawButton("cat_group_next", col1X + colW - arrowW - 0.004, curY + fldH - 0.030, arrowW, 0.020, ">", 0.20, 0.22, 0.32, 0.010)

    -- ── Category Type selector ──
    curY = curY - fldH - fldGap
    local types    = group.types
    local typeName = types[self.form.categoryTypeIndex] or types[1]

    self:drawRect(col1X, curY, colW, fldH, 0.10, 0.14, 0.20, 1.0)
    self:drawRect(col1X, curY+fldH-0.002, colW, 0.002, 0.5, 0.6, 0.8, 0.4)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(0.55, 0.65, 0.80, 0.85)
    renderText(col1X + 0.010, curY + fldH - 0.016, 0.009, g_i18n:getText("invoices_field_type"))
    setTextColor(1, 1, 1, 1)
    renderText(col1X + 0.010, curY + 0.010, 0.012, typeName)
    self:drawButton("cat_type_prev", col1X + colW - arrowW*2 - 0.008, curY + fldH - 0.030, arrowW, 0.020, "<", 0.20, 0.22, 0.32, 0.010)
    self:drawButton("cat_type_next", col1X + colW - arrowW - 0.004, curY + fldH - 0.030, arrowW, 0.020, ">", 0.20, 0.22, 0.32, 0.010)

    -- ── Amount field ──
    curY = curY - fldH - fldGap
    self:drawField("field_amount", col1X, curY, colW, fldH,
                   g_i18n:getText("invoices_field_amount_label"), self.form.amount,
                   self.form.activeField == "amount")

    -- ── Due Date field ──
    curY = curY - fldH - fldGap
    self:drawField("field_dueDate", col1X, curY, colW, fldH,
                   g_i18n:getText("invoices_field_due_date_label"), self.form.dueDate,
                   self.form.activeField == "dueDate")

    -- ── Notes field ──
    curY = curY - fldH - fldGap
    self:drawField("field_notes", col1X, curY, colW, fldH,
                   g_i18n:getText("invoices_field_notes_label"), self.form.notes,
                   self.form.activeField == "notes")

    -- ── Send button ──
    local sendY = py + 0.015
    self:drawButton("btn_send_invoice",
                    col1X, sendY, colW, 0.048,
                    g_i18n:getText("invoices_btn_send"), 0.10, 0.38, 0.18, 0.015)
end

-- ─── Mouse event ──────────────────────────────────────────────────────────────
function RoleplayPhone:submitInvoice()
    local amount = tonumber(self.form.amount)
    if not amount or amount <= 0 then
        NotificationManager:push("rejected", g_i18n:getText("invoices_notif_invalid_amount"))
        return
    end

    local farms   = self:getAvailableFarms()
    local toFarm  = farms[self.form.toFarmIndex]
    local myFarmId = self:getMyFarmId()

    if not toFarm then
        NotificationManager:push("rejected", g_i18n:getText("invoices_notif_no_recipient"))
        return
    end

    if toFarm.farmId == myFarmId then
        NotificationManager:push("rejected", g_i18n:getText("invoices_notif_own_farm"))
        return
    end

    local groups   = InvoiceManager.categoryGroups
    local group    = groups[self.form.categoryGroupIndex] or groups[1]
    local typeName = group.types[self.form.categoryTypeIndex] or group.types[1]
    local cat      = group.name .. " - " .. typeName
    local day  = (g_currentMission and g_currentMission.environment and
                  g_currentMission.environment.currentDay) or 0

    if g_client ~= nil then
        -- MP: send with id=0 — server assigns the canonical sequential ID and
        -- broadcasts back to ALL clients (including the sender) so everyone
        -- gets the invoice with the same real ID.  Do NOT add locally here;
        -- the incoming broadcast from the server will add it.
        local mpData = {
            id          = 0,  -- placeholder; server will assign
            fromFarmId  = myFarmId,
            toFarmId    = toFarm.farmId,
            category    = cat,
            amount      = amount,
            description = "",
            notes       = self.form.notes,
            dueDate     = self.form.dueDate,
            status      = "PENDING",
            createdDate = day,
        }
        g_client:getServerConnection():sendEvent(
            InvoiceEvents.SendInvoiceEvent.new(Invoice.new(mpData)))
        print("[RoleplayPhone] Invoice submitted to server (id=0, awaiting assignment)")
    else
        -- Singleplayer: assign ID locally, add directly, and save
        local newId = InvoiceManager.nextInvoiceId
        InvoiceManager.nextInvoiceId = InvoiceManager.nextInvoiceId + 1
        local data = {
            id          = newId,
            fromFarmId  = myFarmId,
            toFarmId    = toFarm.farmId,
            category    = cat,
            amount      = amount,
            description = "",
            notes       = self.form.notes,
            dueDate     = self.form.dueDate,
            status      = "PENDING",
            createdDate = day,
        }
        local invoice = Invoice.new(data)
        InvoiceManager:addInvoice(invoice)
        RoleplayPhone:saveInvoices()
        UsedPlusCompat:onInvoiceCreated(invoice)
        print("[RoleplayPhone] Invoice created: #" .. tostring(newId))
    end

    NotificationManager:push("info",
        string.format(g_i18n:getText("invoices_notif_sent_fmt"), self:formatMoney(amount), toFarm.name))

    self:resetForm()
    self.currentTab = self.TAB.OUTBOX
    self.state = self.STATE.INVOICES_LIST
end

function RoleplayPhone:resetForm()
    self.form.toFarmIndex        = 1
    self.form.categoryGroupIndex = 1
    self.form.categoryTypeIndex  = 1
    self.form.amount        = ""
    self.form.notes         = ""
    self.form.dueDate       = ""
    self.form.activeField   = nil
end

-- ─── Key event ────────────────────────────────────────────────────────────────
