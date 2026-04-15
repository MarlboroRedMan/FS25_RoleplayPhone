-- scripts/InvoiceSave.lua
-- Handles save/load for invoices only.
-- Contacts are saved separately via RoleplayPhone:saveContacts()

InvoiceSave = {}

function InvoiceSave:saveToXML(xmlFile, key)
    -- Save the sequential ID counter so it continues correctly after reload
    setXMLInt(xmlFile, key .. "#nextInvoiceId", InvoiceManager.nextInvoiceId)

    local i = 0
    for _, invoice in pairs(InvoiceManager.invoices) do
        local invKey = string.format("%s.invoice(%d)", key, i)
        setXMLInt(xmlFile,    invKey .. "#id",          invoice.id          or 0)
        setXMLInt(xmlFile,    invKey .. "#createdDate",  invoice.createdDate or 0)
        setXMLString(xmlFile, invKey .. "#category",     invoice.category    or "")
        setXMLInt(xmlFile,    invKey .. "#fromFarm",     invoice.fromFarmId  or 0)
        setXMLInt(xmlFile,    invKey .. "#toFarm",       invoice.toFarmId    or 0)
        setXMLFloat(xmlFile,  invKey .. "#amount",       invoice.amount      or 0)
        setXMLString(xmlFile, invKey .. "#description",  invoice.description or "")
        setXMLString(xmlFile, invKey .. "#notes",        invoice.notes       or "")
        setXMLString(xmlFile, invKey .. "#status",       invoice.status      or "PENDING")
        setXMLString(xmlFile, invKey .. "#dueDate",      tostring(invoice.dueDate or ""))
        i = i + 1
    end

    -- Save UsedPlus deal map (no-op if UsedPlus not installed)
    UsedPlusCompat:saveToXML(xmlFile, key .. ".usedPlus")
end

function InvoiceSave:loadFromXML(xmlFile, key)
    -- Restore the sequential counter (saved value takes priority)
    local savedNext = getXMLInt(xmlFile, key .. "#nextInvoiceId")
    if savedNext and savedNext > 0 then
        InvoiceManager.nextInvoiceId = savedNext
    end

    local i = 0
    local maxId = 0
    while true do
        local invKey = string.format("%s.invoice(%d)", key, i)
        if not hasXMLProperty(xmlFile, invKey) then break end

        local data = {
            id          = getXMLInt(xmlFile,    invKey .. "#id")          or i,
            createdDate = getXMLInt(xmlFile,    invKey .. "#createdDate") or 0,
            category    = getXMLString(xmlFile, invKey .. "#category"),
            fromFarmId  = getXMLInt(xmlFile,    invKey .. "#fromFarm"),
            toFarmId    = getXMLInt(xmlFile,    invKey .. "#toFarm"),
            amount      = getXMLFloat(xmlFile,  invKey .. "#amount"),
            description = getXMLString(xmlFile, invKey .. "#description"),
            notes       = getXMLString(xmlFile, invKey .. "#notes"),
            status      = getXMLString(xmlFile, invKey .. "#status"),
            dueDate     = getXMLString(xmlFile, invKey .. "#dueDate"),
        }

        local inv = Invoice.new(data)
        InvoiceManager:addInvoice(inv)
        if inv.id and inv.id > maxId then maxId = inv.id end
        i = i + 1
    end

    -- Safety: ensure counter is always above every existing ID
    if maxId >= InvoiceManager.nextInvoiceId then
        InvoiceManager.nextInvoiceId = maxId + 1
    end

    -- Load UsedPlus deal map (no-op if UsedPlus not installed)
    UsedPlusCompat:loadFromXML(xmlFile, key .. ".usedPlus")
end
