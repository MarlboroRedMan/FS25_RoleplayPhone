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
                    "< Back", 0.18, 0.20, 0.28, 0.011)

    -- Title
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw/2, headerY + 0.016, 0.016, "INVOICES")

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
    renderText(px + tabW/2, tabY + 0.012, 0.013, "INBOX")

    setTextBold(outboxActive)
    setTextColor(1, 1, 1, outboxActive and 1.0 or 0.5)
    renderText(px + tabW + tabW/2, tabY + 0.012, 0.013, "OUTBOX")

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
                        "+ Create Invoice", 0.10, 0.38, 0.18, 0.013)
    elseif not inbox then
        -- Show read-only message so player understands why button is missing
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextColor(0.40, 0.45, 0.55, 0.70)
        renderText(px + pw/2, listBottomY + 0.018, 0.009, "Contact your farm manager to send invoices")
        listBottomY = listBottomY + 0.030
        listH       = listTopY - listBottomY
    end

    -- Draw invoice rows
    if #invoices == 0 then
        -- Empty state
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextColor(0.4, 0.45, 0.55, 0.8)
        local emptyMsg = inbox and "No invoices in your inbox" or "No invoices sent yet"
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
                       string.format("+ %d more invoices", #invoices - maxRows))
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
    renderText(x + indent, y + h - 0.020, 0.011, string.format("INV #%04d", inv.id or 0))

    setTextBold(false)
    setTextColor(0.5, 0.55, 0.65, 0.8)
    renderText(x + indent, y + h - 0.034, 0.010,
               string.format("Day %s", tostring(inv.createdDate or "?")))

    -- Category
    setTextColor(0.85, 0.85, 0.95, 0.9)
    local cat = inv.category or "Uncategorized"
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
                    "< Back", 0.18, 0.20, 0.28, 0.011)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw/2, headerY + 0.016, 0.015,
               string.format("INVOICE #%04d", inv.id or 0))

    -- Status banner
    local sr, sg, sb = self:getStatusColor(inv.status)
    local bannerY = headerY - 0.038
    self:drawRect(px, bannerY, pw, 0.038, sr, sg, sb, 0.85)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw/2, bannerY + 0.010, 0.016, inv.status or "PENDING")

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

    drawDetail("FROM",        fromName)
    drawDetail("TO",          toName)
    drawDetail("CATEGORY",    inv.category)
    drawDetail("AMOUNT",      "$" .. self:formatMoney(inv.amount or 0))
    drawDetail("DUE DATE",    inv.dueDate or "Not set")
    drawDetail("CREATED",     "Day " .. tostring(inv.createdDate or "?"))

    if inv.description and inv.description ~= "" then
        drawDetail("DESCRIPTION", inv.description)
    end
    if inv.notes and inv.notes ~= "" then
        drawDetail("NOTES", inv.notes)
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
                            "Pay Invoice", 0.10, 0.40, 0.18, 0.013)
        end

        -- Mark Paid button (shown to sender)
        if inv.fromFarmId == myFarmId and inv.status ~= "PAID" then
            self:drawButton("btn_mark_paid",
                            px + pw*0.54, btnY, pw*0.42, 0.045,
                            "Mark as Paid", 0.28, 0.28, 0.10, 0.013)
        end

        -- Reject button (shown to recipient if still PENDING)
        if inv.toFarmId == myFarmId and inv.status == "PENDING" then
            self:drawButton("btn_reject_invoice",
                            px + pw*0.54, btnY, pw*0.42, 0.045,
                            "Reject", 0.42, 0.10, 0.10, 0.013)
        end
    else
        -- Regular player — read only
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextColor(0.40, 0.45, 0.55, 0.70)
        renderText(px + pw/2, btnY + 0.015, 0.009, "Contact your farm manager to action this invoice")
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
                    "< Back", 0.18, 0.20, 0.28, 0.011)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw/2, headerY + 0.016, 0.015, "CREATE INVOICE")

    local col1X = px + 0.015
    local colW  = pw - 0.030
    local curY  = headerY - 0.015
    local fldH  = 0.050

    -- ── To Farm selector ──
    curY = curY - fldH - 0.008
    local farms   = self:getAvailableFarms()
    local farm    = farms[self.form.toFarmIndex] or farms[1]
    local farmName = farm and farm.name or "Unknown"

    self:drawRect(col1X, curY, colW, fldH, 0.10, 0.14, 0.20, 1.0)
    self:drawRect(col1X, curY+fldH-0.002, colW, 0.002, 0.5, 0.6, 0.8, 0.4)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(0.55, 0.65, 0.80, 0.85)
    renderText(col1X + 0.010, curY + fldH - 0.016, 0.009, "SEND TO")

    -- Arrow buttons (small — keeps max space for farm name)
    local arrowW = 0.018
    local arrowsX = col1X + colW - arrowW*2 - 0.006
    self:drawButton("farm_prev", arrowsX, curY + fldH - 0.030,
                    arrowW, 0.020, "<", 0.20, 0.22, 0.32, 0.010)
    self:drawButton("farm_next", arrowsX + arrowW + 0.004, curY + fldH - 0.030,
                    arrowW, 0.020, ">", 0.20, 0.22, 0.32, 0.010)
    setTextColor(1, 1, 1, 1)
    renderText(col1X + 0.010, curY + 0.010, 0.013, farmName)

    -- ── Category selector ──
    curY = curY - fldH - 0.008
    local cats = InvoiceManager.categories
    local cat  = cats[self.form.categoryIndex] or "Other"
    local catDisplay = cat
    if #catDisplay > 30 then catDisplay = catDisplay:sub(1,28) .. ".." end

    self:drawRect(col1X, curY, colW, fldH, 0.10, 0.14, 0.20, 1.0)
    self:drawRect(col1X, curY+fldH-0.002, colW, 0.002, 0.5, 0.6, 0.8, 0.4)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(0.55, 0.65, 0.80, 0.85)
    renderText(col1X + 0.010, curY + fldH - 0.016, 0.009, "CATEGORY")
    setTextColor(1, 1, 1, 1)
    renderText(col1X + 0.010, curY + 0.010, 0.012, catDisplay)

    self:drawButton("cat_prev", col1X + colW - arrowW*2 - 0.008, curY + fldH - 0.030,
                    arrowW, 0.020, "<", 0.20, 0.22, 0.32, 0.010)
    self:drawButton("cat_next", col1X + colW - arrowW - 0.004, curY + fldH - 0.030,
                    arrowW, 0.020, ">", 0.20, 0.22, 0.32, 0.010)

    -- ── Amount field ──
    curY = curY - fldH - 0.008
    self:drawField("field_amount", col1X, curY, colW, fldH,
                   "AMOUNT ($)", self.form.amount,
                   self.form.activeField == "amount")

    -- ── Due Date field ──
    curY = curY - fldH - 0.008
    self:drawField("field_dueDate", col1X, curY, colW, fldH,
                   "DUE DATE (e.g. Day 45)", self.form.dueDate,
                   self.form.activeField == "dueDate")

    -- ── Description field ──
    curY = curY - fldH - 0.008
    self:drawField("field_description", col1X, curY, colW, fldH,
                   "DESCRIPTION", self.form.description,
                   self.form.activeField == "description")

    -- ── Notes field ──
    curY = curY - fldH - 0.008
    self:drawField("field_notes", col1X, curY, colW, fldH,
                   "Notes (job details / agreement)", self.form.notes,
                   self.form.activeField == "notes")

    -- ── Send button ──
    local sendY = py + 0.015
    self:drawButton("btn_send_invoice",
                    col1X, sendY, colW, 0.048,
                    "SEND INVOICE", 0.10, 0.38, 0.18, 0.015)
end

-- ─── Mouse event ──────────────────────────────────────────────────────────────
function RoleplayPhone:submitInvoice()
    local amount = tonumber(self.form.amount)
    if not amount or amount <= 0 then
        NotificationManager:push("rejected", "Enter a valid amount.")
        return
    end

    local farms   = self:getAvailableFarms()
    local toFarm  = farms[self.form.toFarmIndex]
    local myFarmId = self:getMyFarmId()

    if not toFarm then
        NotificationManager:push("rejected", "No recipient farm selected.")
        return
    end

    if toFarm.farmId == myFarmId then
        NotificationManager:push("rejected", "Can't invoice your own farm.")
        return
    end

    local cats = InvoiceManager.categories
    local cat  = cats[self.form.categoryIndex] or "Other"
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
            description = self.form.description,
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
            description = self.form.description,
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
        string.format("Invoice for $%s sent to %s", self:formatMoney(amount), toFarm.name))

    self:resetForm()
    self.currentTab = self.TAB.OUTBOX
    self.state = self.STATE.INVOICES_LIST
end

function RoleplayPhone:resetForm()
    self.form.toFarmIndex   = 1
    self.form.categoryIndex = 1
    self.form.amount        = ""
    self.form.description   = ""
    self.form.notes         = ""
    self.form.dueDate       = ""
    self.form.activeField   = nil
end

-- ─── Key event ────────────────────────────────────────────────────────────────
