function RoleplayPhone:drawContacts()
    local s  = self.PHONE
    local px = s.x
    local py = s.y
    local pw = s.w
    local ph = s.h

    -- Phone background (padded to fill frame bezel edges)
    self:drawPhoneBackground(0.06, 0.07, 0.10, 0.97)

    local contentY = py + ph - 0.012

    -- Header bar
    local headerH = 0.042
    local headerY = contentY - headerH
    self:drawRect(px, headerY, pw, headerH, 0.10, 0.13, 0.20, 1.0)

    -- Back button
    self:drawButton("btn_back", px + 0.006, headerY + 0.008, 0.045 * self.arScale, 0.026,
        g_i18n:getText("ui_btn_back"), 0.18, 0.20, 0.28, 0.010)

    -- Title
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw / 2, headerY + headerH * 0.28, 0.013, g_i18n:getText("screen_title_contacts"))

    -- Add button (top-right)
    self:drawButton("btn_add_contact", px + pw - 0.068 * self.arScale, headerY + 0.008, 0.062 * self.arScale, 0.026,
        g_i18n:getText("contacts_btn_add"), 0.10, 0.38, 0.18, 0.012)

    -- ── My Profile card ──────────────────────────────────────────────────────
    local profileH = 0.054
    local profileY = headerY - 0.006
    local profileCardY = profileY - profileH
    self:drawRect(px, profileCardY, pw, profileH, 0.08, 0.14, 0.24, 1.0)
    self:drawRect(px, profileCardY, pw, 0.002, 0.20, 0.45, 0.80, 0.6)  -- top accent line

    -- Avatar
    local myName  = g_currentMission and g_currentMission.playerNickname or "?"
    local myPhone = self:hashPhone(self:getMyUserId())
    local avSz = 0.034
    local avX  = px + 0.012
    local avY  = profileCardY + (profileH - avSz) / 2
    local ac   = self:getAvatarColor(myName)
    self:drawRect(avX, avY, avSz, avSz, ac[1], ac[2], ac[3], 1.0)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(avX + avSz / 2, avY + avSz * 0.20, 0.018, string.upper(string.sub(myName, 1, 1)))

    -- Name + "Me" label
    local profileTextX = avX + avSz + 0.012
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(0.90, 0.95, 1.0, 1.0)
    renderText(profileTextX, profileCardY + profileH * 0.54, 0.013, myName)
    setTextBold(false)
    setTextColor(0.35, 0.65, 0.90, 0.85)
    renderText(profileTextX, profileCardY + profileH * 0.20, 0.010,
        g_i18n:getText("contacts_my_profile_label"))

    -- Phone number (right side, blue tint)
    setTextAlignment(RenderText.ALIGN_RIGHT)
    setTextColor(0.45, 0.75, 0.95, 0.9)
    renderText(px + pw - 0.014, profileCardY + profileH * 0.38, 0.011, myPhone)

    -- ── Contact list ──────────────────────────────────────────────────────────
    local listY    = profileCardY - 0.006
    local rowH     = 0.048
    local rowGap   = 0
    local contacts = ContactManager.contacts

    if #contacts == 0 then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextColor(0.50, 0.52, 0.60, 0.8)
        renderText(px + pw / 2, py + ph / 2, 0.013,
            g_i18n:getText("contacts_empty_state"))
        return
    end

    for i, c in ipairs(contacts) do
        local rowY = listY - (i - 1) * rowH
        if rowY - rowH < py then break end   -- clip below screen

        -- Row background (uniform, no alternating)
        self:drawRect(px, rowY - rowH, pw, rowH, 0.09, 0.10, 0.14, 1.0)

        -- Divider line at bottom of row
        self:drawRect(px + 0.010, rowY - rowH, pw - 0.020, 0.001, 0.20, 0.22, 0.30, 0.5)

        -- Avatar (small square, circle is a polish item)
        local avSize = 0.022
        local avX    = px + 0.012
        local avY    = rowY - rowH + (rowH - avSize) / 2
        local ac     = self:getAvatarColor(c.name)
        self:drawRect(avX, avY, avSize, avSize, ac[1], ac[2], ac[3], 1.0)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(1, 1, 1, 1)
        renderText(avX + avSize / 2, avY + avSize * 0.18, 0.013,
            string.upper(string.sub(c.name or "?", 1, 1)))

        -- Name only, vertically centered
        local textX = avX + avSize + 0.010
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(false)
        setTextColor(0.92, 0.94, 1.0, 1.0)
        renderText(textX, rowY - rowH + rowH * 0.35, 0.013, c.name or g_i18n:getText("phone_unknown_contact"))

        -- Chevron hint
        setTextAlignment(RenderText.ALIGN_RIGHT)
        setTextColor(0.35, 0.38, 0.50, 0.5)
        renderText(px + pw - 0.008, rowY - rowH + rowH * 0.35, 0.013, ">")

        -- Hitbox for the whole row
        self:addHitbox("contact_row", px, rowY - rowH, pw, rowH, { index = i })
    end
end


-- ─── CONTACT DETAIL screen ────────────────────────────────────────────────────
-- ─── CONTACT DETAIL screen (small phone screen) ──────────────────────────────
function RoleplayPhone:drawContactDetail()
    if not self.selectedContact then
        self.state = self.STATE.CONTACTS
        return
    end
    local c = ContactManager:getContact(self.selectedContact)
    if not c then
        self.state = self.STATE.CONTACTS
        return
    end

    local s  = self.PHONE
    local px = s.x
    local py = s.y
    local pw = s.w
    local ph = s.h

    self:drawPhoneBackground(0.06, 0.07, 0.10, 0.97)

    -- Header bar
    local headerH = 0.042
    local headerY = py + ph - 0.012 - headerH
    self:drawRect(px, headerY, pw, headerH, 0.08, 0.11, 0.18, 1.0)
    self:drawButton("btn_back", px + 0.006, headerY + 0.008, 0.045 * self.arScale, 0.026,
        g_i18n:getText("ui_btn_back"), 0.12, 0.15, 0.22, 0.010)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw / 2, headerY + headerH * 0.28, 0.013, g_i18n:getText("screen_title_contact_detail"))

    -- ── Top card: name + phone left, avatar small top-right ──────────────────
    local cardH = 0.080
    local cardY = headerY - 0.008 - cardH
    self:drawRect(px, cardY, pw, cardH, 0.10, 0.13, 0.20, 1.0)

    local infoX = px + 0.012
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(0.95, 0.97, 1.0, 1.0)
    renderText(infoX, cardY + cardH * 0.58, 0.015, c.name or g_i18n:getText("phone_unknown_contact"))
    if c.phone and c.phone ~= "" then
        setTextBold(false)
        setTextColor(0.50, 0.65, 0.80, 0.9)
        renderText(infoX, cardY + cardH * 0.22, 0.011, c.phone)
    end

    -- Notes/Role block on right side of card
    if c.role and c.role ~= "" then
        local roleX = px + pw * 0.52
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(false)
        setTextColor(0.45, 0.55, 0.70, 0.85)
        renderText(roleX, cardY + cardH * 0.78, 0.008, g_i18n:getText("contacts_label_role"))
        setTextColor(0.90, 0.95, 1.0, 1.0)
        renderText(roleX, cardY + cardH * 0.38, 0.011, c.role)
    end

    -- ── All four buttons stacked below card ───────────────────────────────────
    local btnW  = pw - 0.020
    local btnH  = 0.034
    local btnX  = px + 0.010
    local gap   = 0.006
    local btn1Y = cardY - gap - btnH

    self:drawButton("btn_call",            btnX, btn1Y,                    btnW, btnH, g_i18n:getText("contacts_btn_call"),    0.10, 0.48, 0.22, 0.011)
    self:drawButton("btn_message_contact", btnX, btn1Y - btnH - gap,       btnW, btnH, g_i18n:getText("contacts_btn_message"), 0.10, 0.35, 0.55, 0.011)
    self:drawButton("btn_edit_contact",    btnX, btn1Y - (btnH + gap) * 2, btnW, btnH, g_i18n:getText("contacts_btn_edit"),   0.28, 0.22, 0.10, 0.011)
    self:drawButton("btn_delete_contact",  btnX, btn1Y - (btnH + gap) * 3, btnW, btnH, g_i18n:getText("contacts_btn_delete"), 0.50, 0.10, 0.10, 0.010)

    -- ── Notes block below buttons ─────────────────────────────────────────────
    if c.notes and c.notes ~= "" then
        local nY      = btn1Y - (btnH + gap) * 3 - gap - 0.050
        local nBlockH = 0.050
        self:drawRect(px, nY, pw, nBlockH, 0.10, 0.13, 0.20, 1.0)
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(false)
        setTextColor(0.45, 0.55, 0.70, 0.85)
        renderText(infoX, nY + nBlockH - 0.012, 0.009, g_i18n:getText("contacts_label_notes"))
        setTextColor(0.92, 0.95, 1.0, 1.0)
        renderText(infoX, nY + nBlockH * 0.35, 0.011, c.notes)
    end
end

-- drawMessageThread() moved to MessagesApp.lua

-- ─── CONTACT CREATE screen ────────────────────────────────────────────────────
function RoleplayPhone:drawContactCreate()
    local s  = self.PHONE
    local px = s.x
    local py = s.y
    local pw = s.w
    local ph = s.h

    self:drawPhoneBackground(0.06, 0.07, 0.10, 0.97)

    local contentY = py + ph - 0.012

    -- Header bar
    local headerH = 0.042
    local headerY = contentY - headerH
    self:drawRect(px, headerY, pw, headerH, 0.10, 0.13, 0.20, 1.0)

    self:drawButton("btn_back", px + 0.006, headerY + 0.010, 0.055 * self.arScale, 0.030,
        g_i18n:getText("ui_btn_back"), 0.18, 0.20, 0.28, 0.011)

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(px + pw / 2, headerY + headerH * 0.30, 0.016, g_i18n:getText("screen_title_new_contact"))

    local f    = self.contactForm
    local fX   = px + 0.012
    local fW   = pw - 0.024
    local fH   = 0.044
    local fGap = 0.008
    local fY   = headerY - 0.014

    -- Name field (free text)
    fY = fY - fH
    self:drawField("cf_name", fX, fY, fW, fH, g_i18n:getText("contacts_field_name"), f.name, f.activeField == "name")

    -- Phone field (free text)
    fY = fY - fH - fGap
    self:drawField("cf_phone", fX, fY, fW, fH, g_i18n:getText("contacts_field_phone"), f.phone, f.activeField == "phone")

    -- Role/Job field
    fY = fY - fH - fGap
    self:drawField("cf_role", fX, fY, fW, fH, g_i18n:getText("contacts_field_role"), f.role, f.activeField == "role")

    -- Notes field (multiline)
    fY = fY - 0.088 - fGap
    self:drawField("cf_notes", fX, fY, fW, 0.088, g_i18n:getText("contacts_field_notes"), f.notes, f.activeField == "notes", true)

    -- Validation hint
    if f.name == "" then
        fY = fY - 0.020
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextColor(0.80, 0.55, 0.20, 0.85)
        renderText(px + pw / 2, fY + 0.006, 0.010, g_i18n:getText("contacts_validation_name"))
    end

    -- Save button
    fY = fY - fH - 0.012
    local canSave = f.name and f.name ~= ""
    local btnR = canSave and 0.10 or 0.20
    local btnG = canSave and 0.38 or 0.22
    local btnB = canSave and 0.18 or 0.22
    self:drawButton("btn_save_contact", fX, fY, fW, fH,
        g_i18n:getText("contacts_btn_save"), btnR, btnG, btnB, 0.013)
end


-- ─── resetContactForm helper ──────────────────────────────────────────────────
function RoleplayPhone:resetContactForm()
    self.contactForm = {
        name        = "",
        phone       = "",
        role        = "",
        notes       = "",
        activeField = nil,
    }
    self.editingContactIndex = nil
end
