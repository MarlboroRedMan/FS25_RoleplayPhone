--[[
    UsedPlusCompat.lua - UsedPlus Credit Bureau Integration
    FS25_RoleplayPhone

    When UsedPlus is installed, registers invoices as external deals with the
    UsedPlus credit bureau.  This means:
      - Sending an invoice to a farm creates a credit obligation for that farm.
      - Paying the invoice on time improves the recipient farm's credit score.
      - Rejecting an invoice records a missed payment and hurts their credit score.

    UsedPlusAPI docs: see UsedPlus/src/utils/UsedPlusAPI.lua
    All calls are guarded by isAvailable() so the mod works fine without UsedPlus.
]]

UsedPlusCompat = {}

-- Identifier passed to UsedPlus so it can group our deals together.
-- NOTE: intentionally kept as "FS25_RoleplayPhone" — changing this after a
-- server has live deals would orphan those records in UsedPlus's saved data.
UsedPlusCompat.MOD_NAME = "FS25_RoleplayPhone"

-- invoiceId (number) -> externalDealId (string)
-- Persisted via InvoiceSave so the mapping survives a game reload.
UsedPlusCompat.dealMap = {}


-- ─── Availability check ───────────────────────────────────────────────────────
function UsedPlusCompat:isAvailable()
    return UsedPlusAPI ~= nil and UsedPlusAPI.isReady()
end


-- ─── Called when an invoice is sent ──────────────────────────────────────────
-- Registers the invoice as a credit obligation for the receiving farm.
function UsedPlusCompat:onInvoiceCreated(invoice)
    if not self:isAvailable() then return end

    local dealData = {
        dealType      = "credit",
        itemName      = string.format("Invoice #%04d – %s", invoice.id, (invoice.category or "Other")),
        originalAmount = invoice.amount,
        currentBalance = invoice.amount,
        monthlyPayment = invoice.amount,  -- one-time obligation; treated as single payment due
        termMonths    = 1,
    }

    local externalDealId = UsedPlusAPI.registerExternalDeal(
        self.MOD_NAME,
        invoice.id,
        invoice.toFarmId,   -- the farm that OWES the money
        dealData
    )

    if externalDealId then
        self.dealMap[invoice.id] = externalDealId
        print(string.format("[UsedPlusCompat] Registered deal %s for invoice #%d (farm %d, $%d)",
            externalDealId, invoice.id, invoice.toFarmId, invoice.amount))
    end
end


-- ─── Called when an invoice is paid (by recipient) ───────────────────────────
-- Records an on-time payment, boosting the payer's credit score.
function UsedPlusCompat:onInvoicePaid(invoice)
    self:_recordPayment(invoice, "Payment")
end


-- ─── Called when an invoice is rejected ──────────────────────────────────────
-- Records a missed payment and closes the deal as defaulted.
function UsedPlusCompat:onInvoiceRejected(invoice)
    if not self:isAvailable() then return end

    local externalDealId = self.dealMap[invoice.id]
    if not externalDealId then return end

    UsedPlusAPI.reportExternalDefault(externalDealId, false)  -- false = missed (not merely late)
    UsedPlusAPI.closeExternalDeal(externalDealId, "defaulted")
    self.dealMap[invoice.id] = nil
    print(string.format("[UsedPlusCompat] Default recorded for deal %s", externalDealId))
end


-- ─── Called when sender manually marks an invoice as paid ────────────────────
-- Treat as an on-time payment from the credit bureau's perspective.
function UsedPlusCompat:onInvoiceMarkedPaid(invoice)
    self:_recordPayment(invoice, "Manual paid")
end


-- Shared payment recording logic used by onInvoicePaid and onInvoiceMarkedPaid.
function UsedPlusCompat:_recordPayment(invoice, label)
    if not self:isAvailable() then return end

    local externalDealId = self.dealMap[invoice.id]
    if not externalDealId then return end

    UsedPlusAPI.reportExternalPayment(externalDealId, invoice.amount)
    self.dealMap[invoice.id] = nil
    print(string.format("[UsedPlusCompat] %s recorded for deal %s ($%d)",
        label, externalDealId, invoice.amount))
end


-- ─── Save deal map to XML ─────────────────────────────────────────────────────
function UsedPlusCompat:saveToXML(xmlFile, key)
    local i = 0
    for invoiceId, externalDealId in pairs(self.dealMap) do
        local k = string.format("%s.upDeal(%d)", key, i)
        setXMLInt(xmlFile,    k .. "#invoiceId",      invoiceId)
        setXMLString(xmlFile, k .. "#externalDealId", externalDealId)
        i = i + 1
    end
end


-- ─── Load deal map from XML ───────────────────────────────────────────────────
function UsedPlusCompat:loadFromXML(xmlFile, key)
    self.dealMap = {}
    local i = 0
    while true do
        local k = string.format("%s.upDeal(%d)", key, i)
        if not hasXMLProperty(xmlFile, k) then break end
        local invoiceId      = getXMLInt(xmlFile,    k .. "#invoiceId")
        local externalDealId = getXMLString(xmlFile, k .. "#externalDealId")
        if invoiceId and externalDealId then
            self.dealMap[invoiceId] = externalDealId
        end
        i = i + 1
    end
end

-- Note: UsedPlusAPI availability is checked at call time via isAvailable().
-- A load-time check here would always show "inactive" since other mods
-- haven't initialized yet when this script is loaded.
