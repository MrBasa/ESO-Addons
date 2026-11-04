-- MatLog hireling mail capture + shared bag baseline/diff helpers.
local C = MatLog.C
local S = MatLog._

function MatLog.NormalizeMailText(text)
    if type(text) ~= "string" or text == "" then
        return ""
    end
    if type(zo_strformat) == "function" then
        local formatted = zo_strformat("<<1>>", text)
        if type(formatted) == "string" and formatted ~= "" then
            text = formatted
        end
    end
    return string.lower(text)
end

function MatLog.SubjectLooksLikeHireling(subject)
    if type(subject) ~= "string" or subject == "" then
        return false
    end
    if C.HIRELING_SUBJECTS[subject] then
        return true
    end
    local want = MatLog.NormalizeMailText(subject)
    for key, on in pairs(C.HIRELING_SUBJECTS) do
        if on and MatLog.NormalizeMailText(key) == want then
            return true
        end
    end
    local wc = rawget(_G, "WritCreater")
    if type(wc) == "table" and type(wc.hirelingMailSubjects) == "table" then
        if wc.hirelingMailSubjects[subject] then
            return true
        end
        for key, on in pairs(wc.hirelingMailSubjects) do
            if on and MatLog.NormalizeMailText(key) == want then
                return true
            end
        end
    end
    local lower = MatLog.NormalizeMailText(subject)
    if string.find(lower, "hireling", 1, true) then
        return true
    end
    return false
end

function MatLog.SenderLooksLikeHireling(sender)
    local lower = MatLog.NormalizeMailText(sender)
    if lower == "" then
        return false
    end
    if string.find(lower, "hireling", 1, true) then
        return true
    end
    if type(GetString) == "function" and type(HIRELING_TYPE_ITERATION_BEGIN) == "number" then
        local last = HIRELING_TYPE_ITERATION_END or HIRELING_TYPE_MAX_VALUE or 5
        for i = HIRELING_TYPE_ITERATION_BEGIN, last do
            local label = GetString("SI_HIRELINGTYPE", i)
            if type(label) == "string" and label ~= "" and string.find(lower, MatLog.NormalizeMailText(label), 1, true) then
                return true
            end
        end
    end
    return false
end

function MatLog.SenderIsGuild(sender)
    if type(sender) ~= "string" or sender == "" then
        return false
    end
    local lower = MatLog.NormalizeMailText(sender)
    if string.find(lower, "guild store", 1, true) or string.find(lower, "trading house", 1, true) then
        return true
    end
    if type(GetNumGuilds) == "function" and type(GetGuildName) == "function" then
        local n = GetNumGuilds() or 0
        for i = 1, n do
            local name = GetGuildName(i)
            if name == sender or MatLog.NormalizeMailText(name) == lower then
                return true
            end
        end
    end
    return false
end

function MatLog.MailMeta(mailId)
    if type(GetMailItemInfo) ~= "function" then
        return nil
    end
    local sender, _, subject, _, _, fromSystem, fromCustomer, returned, numAtt, _money, codAmount = GetMailItemInfo(mailId)
    return {
        sender = sender,
        subject = subject,
        fromSystem = fromSystem and true or false,
        fromCustomer = fromCustomer and true or false,
        returned = returned and true or false,
        numAtt = numAtt or 0,
        codAmount = (type(codAmount) == "number" and codAmount) or 0,
    }
end

function MatLog.LooksLikeHirelingMeta(meta)
    if type(meta) ~= "table" then
        return false
    end
    if meta.fromCustomer or meta.returned or (meta.codAmount or 0) > 0 then
        return false
    end
    if MatLog.SubjectLooksLikeHireling(meta.subject) or MatLog.SenderLooksLikeHireling(meta.sender) then
        return true
    end
    if meta.fromSystem and not MatLog.SenderIsGuild(meta.sender) then
        return true
    end
    return false
end

function MatLog.IsHirelingMail(mailId)
    return MatLog.LooksLikeHirelingMeta(MatLog.MailMeta(mailId))
end

function MatLog.ShouldSnapshotMail(mailId)
    local meta = MatLog.MailMeta(mailId)
    if not meta or meta.numAtt <= 0 then
        return false
    end
    return MatLog.LooksLikeHirelingMeta(meta)
end

function MatLog.ForEachInboxMail(fn)
    if type(GetNextMailId) ~= "function" then
        return
    end
    local id = GetNextMailId(nil)
    while id do
        fn(id)
        id = GetNextMailId(id)
    end
end

function MatLog.ScanHirelingInbox()
    local hasHireling = false
    local hasOtherAtt = false
    MatLog.ForEachInboxMail(function(mailId)
        local meta = MatLog.MailMeta(mailId)
        if not meta or meta.numAtt <= 0 then
            return
        end
        if MatLog.LooksLikeHirelingMeta(meta) then
            hasHireling = true
        elseif meta.fromSystem then
            hasOtherAtt = true
        end
    end)
    S.inboxHasHireling = hasHireling
    if hasHireling then
        S.sawHirelingThisMailbox = true
    end
    return hasHireling, hasOtherAtt
end

function MatLog.ReadAttachments(mailId)
    local meta = MatLog.MailMeta(mailId)
    local n = meta and meta.numAtt or 0
    if n <= 0 then
        return nil
    end
    local items = {}
    for i = 1, n do
        local link = nil
        if type(GetAttachedItemLink) == "function" then
            link = GetAttachedItemLink(mailId, i, LINK_STYLE_DEFAULT)
        end
        local count = 1
        local iconName = nil
        if type(GetAttachedItemInfo) == "function" then
            local _tex, stack, _creator, _sell, _meets, _eq, _quality, _style, name = GetAttachedItemInfo(mailId, i)
            if type(stack) == "number" and stack > 0 then
                count = stack
            end
            if type(name) == "string" and name ~= "" then
                iconName = name
            end
        end
        if type(link) == "string" and link ~= "" then
            items[#items + 1] = { link = link, count = count, name = MatLog.ItemName(link, iconName) }
        end
    end
    if #items == 0 then
        return nil
    end
    return items
end

function MatLog.SnapshotMail(mailId)
    if not MatLog.ShouldSnapshotMail(mailId) then
        return
    end
    local items = MatLog.ReadAttachments(mailId)
    if items then
        S.mailSnapshots[MatLog.MailKey(mailId)] = items
    end
end

function MatLog.SnapshotOpenInbox()
    MatLog.ScanHirelingInbox()
    MatLog.ForEachInboxMail(MatLog.SnapshotMail)
end

function MatLog.SlotStackCount(bagId, slot)
    if type(GetSlotStackSize) == "function" then
        local n = GetSlotStackSize(bagId, slot)
        if type(n) == "number" and n > 0 then
            return n
        end
    end
    return 0
end

function MatLog.AddClassifiedSlot(bagId, slot, counts, links, kinds)
    local kind, link = MatLog.ClassifySlot(bagId, slot)
    if not kind then
        return
    end
    local itemId = MatLog.ItemIdFromLink(link)
    if type(itemId) ~= "number" or itemId <= 0 then
        return
    end
    local n = MatLog.SlotStackCount(bagId, slot)
    counts[itemId] = (counts[itemId] or 0) + n
    links[itemId] = link
    kinds[itemId] = kind
end

function MatLog.ClassifiedBackpackCounts()
    local counts = {}
    local links = {}
    local kinds = {}
    if type(GetBagSize) == "function" then
        local size = GetBagSize(BAG_BACKPACK) or 0
        for slot = 0, size - 1 do
            MatLog.AddClassifiedSlot(BAG_BACKPACK, slot, counts, links, kinds)
        end
    end
    if BAG_VIRTUAL and type(GetNextVirtualBagSlotId) == "function" then
        local slot = GetNextVirtualBagSlotId(nil)
        while slot do
            MatLog.AddClassifiedSlot(BAG_VIRTUAL, slot, counts, links, kinds)
            slot = GetNextVirtualBagSlotId(slot)
        end
    end
    return counts, links, kinds
end

-- Shared bag baseline / diff for mail (hireling) and writ coffer paths.
function MatLog.CaptureBagBaseline(kind)
    local counts = MatLog.ClassifiedBackpackCounts()
    if kind == "mail" then
        S.backpackMailCounts = counts
        S.mailBagBaselineReady = true
    else
        S.backpackWritCounts = counts
        S.writBagBaselineReady = true
    end
end

function MatLog.NoteBagGain(kind, link, count)
    if type(count) ~= "number" or count == 0 then
        return
    end
    local itemId = MatLog.ItemIdFromLink(link)
    if type(itemId) ~= "number" or itemId <= 0 then
        return
    end
    if kind == "mail" then
        S.backpackMailCounts[itemId] = (S.backpackMailCounts[itemId] or 0) + count
    else
        S.backpackWritCounts[itemId] = (S.backpackWritCounts[itemId] or 0) + count
    end
end

function MatLog.CreditBagDiff(kind)
    local ready = kind == "mail" and S.mailBagBaselineReady or S.writBagBaselineReady
    if not ready then
        return false
    end
    local baseline = kind == "mail" and S.backpackMailCounts or S.backpackWritCounts
    local source = kind == "mail" and C.SOURCE_HIRELING or C.SOURCE_WRIT
    local now, links, kinds = MatLog.ClassifiedBackpackCounts()
    local added = false
    for itemId, count in pairs(now) do
        local delta = count - (baseline[itemId] or 0)
        if delta > 0 then
            local link = links[itemId]
            if MatLog.AddItem(link, delta, MatLog.ItemName(link), source, kinds[itemId]) then
                added = true
            end
        end
    end
    if kind == "mail" then
        S.backpackMailCounts = now
        if added then
            S.mailDiffRetries = 0
            MatLog.RefreshIfShown()
        end
    else
        S.backpackWritCounts = now
        if added then
            MatLog.RefreshIfShown()
        end
    end
    return added
end

function MatLog.CaptureMailBagBaseline()
    MatLog.CaptureBagBaseline("mail")
end

function MatLog.CaptureWritBagBaseline()
    MatLog.CaptureBagBaseline("writ")
end

function MatLog.EnsureWritBagBaseline()
    if not S.writBagBaselineReady then
        MatLog.CaptureWritBagBaseline()
    end
end

function MatLog.CreditWritBagDiff()
    return MatLog.CreditBagDiff("writ")
end

function MatLog.CreditMailBagDiff()
    return MatLog.CreditBagDiff("mail")
end

function MatLog.NoteMailBagGain(link, count)
    MatLog.NoteBagGain("mail", link, count)
end

function MatLog.NoteWritBagGain(link, count)
    MatLog.NoteBagGain("writ", link, count)
end

function MatLog.ScheduleMailBagDiff(delayMs)
    if not S.mailBagBaselineReady then
        MatLog.CaptureMailBagBaseline()
    end
    S.mailDiffToken = S.mailDiffToken + 1
    local token = S.mailDiffToken
    local function apply()
        if token ~= S.mailDiffToken then
            return
        end
        local added = MatLog.CreditMailBagDiff()
        if S.mailCreditPending and not added and S.mailDiffRetries < C.MAIL_DIFF_MAX_RETRIES then
            S.mailDiffRetries = S.mailDiffRetries + 1
            MatLog.ScheduleMailBagDiff(500)
            return
        end
        if S.mailDiffAfterClose then
            S.mailDiffAfterClose = false
            S.mailCreditPending = false
            S.mailBagBaselineReady = false
            S.backpackMailCounts = {}
        elseif added and not S.mailboxOpen then
            S.mailCreditPending = false
        end
    end
    if type(zo_callLater) == "function" then
        zo_callLater(apply, delayMs or 400)
    else
        apply()
    end
end

function MatLog.BeginMailCredit()
    S.mailCreditPending = true
    S.mailDiffRetries = 0
    if not S.mailBagBaselineReady then
        MatLog.CaptureMailBagBaseline()
    end
end

function MatLog.AbsorbMailBagIntoBaseline(delayMs)
    S.mailCreditPending = false
    local function apply()
        MatLog.CaptureMailBagBaseline()
    end
    if type(zo_callLater) == "function" then
        zo_callLater(apply, delayMs or 400)
    else
        apply()
    end
end

function MatLog.CreditHirelingItems(items)
    if type(items) ~= "table" then
        return false
    end
    local added = false
    for i = 1, #items do
        local item = items[i]
        if MatLog.AddItem(item.link, item.count, item.name, C.SOURCE_HIRELING) then
            MatLog.NoteMailBagGain(item.link, item.count)
            added = true
        end
    end
    return added
end

function MatLog.CreditMail(mailId)
    local key = MatLog.MailKey(mailId)
    local items = S.mailSnapshots[key]
    if type(items) ~= "table" and MatLog.IsHirelingMail(mailId) then
        items = MatLog.ReadAttachments(mailId)
    end
    S.mailSnapshots[key] = nil
    if MatLog.CreditHirelingItems(items) then
        MatLog.RefreshIfShown()
    end
end

function MatLog.OnMailOpen()
    S.mailboxOpen = true
    S.mailDiffAfterClose = false
    S.mailCreditPending = false
    S.takeAllInProgress = false
    S.sawHirelingThisMailbox = false
    S.inboxHasHireling = false
    S.lastMailHireling = false
    S.mailDiffRetries = 0
    MatLog.SnapshotOpenInbox()
    MatLog.CaptureMailBagBaseline()
end

function MatLog.OnMailClose()
    S.mailboxOpen = false
    S.lastMailHireling = false
    S.takeAllInProgress = false
    if S.mailCreditPending then
        S.mailDiffAfterClose = true
        MatLog.ScheduleMailBagDiff(600)
    else
        S.mailDiffAfterClose = false
        S.mailBagBaselineReady = false
        S.backpackMailCounts = {}
        S.sawHirelingThisMailbox = false
    end
end

function MatLog.OnMailReadable(_, mailId)
    S.lastMailHireling = MatLog.IsHirelingMail(mailId)
    MatLog.SnapshotMail(mailId)
end
