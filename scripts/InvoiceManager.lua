-- scripts/InvoiceManager.lua

InvoiceManager = {}
InvoiceManager.invoices     = {}
InvoiceManager.nextInvoiceId = 1   -- sequential counter; saved/loaded with the game

-- Category groups for the two-row picker
InvoiceManager.categoryGroups = {
    { name = "Rent (House)",   types = { "Small", "Medium", "Large", "Luxury" } },
    { name = "Rent (Camper)",  types = { "Full Hookup", "Water & Power", "Electric Only", "Land Use Only" } },
    { name = "Rent (Shop)",    types = { "Full Use", "Single Bay" } },
    { name = "Rent (Storage)", types = { "Indoor", "Covered", "Yard" } },
    { name = "Lease",          types = { "Agricultural Land", "Yard / Equipment Staging", "Industrial / Mining Land" } },
    { name = "Vehicle",        types = { "Sale (Paid in Full)", "Sale (Installment)", "Lease / Rental" } },
    { name = "Service",        types = { "Labor", "Equipment Operation", "Snow / Mowing / Cleanup" } },
    { name = "Field Work",     types = { "Plowing", "Cultivating", "Seeding", "Fertilizing", "Spraying", "Harvesting", "Baling", "Mowing", "Tedding", "Wrapping" } },
    { name = "Transport",      types = { "Equipment Transport", "Seed / Input Delivery", "Fuel Delivery", "Grain / Crop Hauling", "Livestock Transport" } },
    { name = "Livestock",      types = { "Animal Care", "Feeding" } },
    { name = "Fine / Penalty", types = { "Fine", "Penalty" } },
    { name = "Misc",           types = { "Custom" } },
}

function InvoiceManager:addInvoice(invoice)
    self.invoices[invoice.id] = invoice
end

-- inbox=true -> invoices sent TO farmId
-- inbox=false -> invoices sent FROM farmId
function InvoiceManager:getInvoicesForFarm(farmId, inbox)
    local list = {}
    for _, invoice in pairs(self.invoices) do
        if inbox and invoice.toFarmId == farmId then
            table.insert(list, invoice)
        elseif (not inbox) and invoice.fromFarmId == farmId then
            table.insert(list, invoice)
        end
    end
    return list
end

function InvoiceManager:copyInvoice(invoice)
    local newId = self.nextInvoiceId
    self.nextInvoiceId = self.nextInvoiceId + 1
    local newData = {
        id = newId,
        fromFarmId = invoice.fromFarmId,
        toFarmId = invoice.toFarmId,
        category = invoice.category,
        amount = invoice.amount,
        description = invoice.description,
        notes = invoice.notes,
        dueDate = invoice.dueDate,
        status = "PENDING",
        createdDate = g_currentMission.environment.currentDay
    }
    return Invoice.new(newData)
end