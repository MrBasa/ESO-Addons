-- MatLog writ / world loot / inventory listeners.
local C = MatLog.C
local S = MatLog._

function MatLog.CraftingBusy()
    if type(GetCraftingInteractionType) ~= "function" then
        return false
    end
    local craft = GetCraftingInteractionType()
    return type(craft) == "number" and craft > 0
end

function MatLog.ExtendWritCapture(seconds, name)
    local untilT = GetTimeStamp() + (seconds or C.WRIT_LOOT_WINDOW_S)
    if S.pendingWrit then
        if untilT > (S.pendingWrit.untilTime or 0) then
            S.pendingWrit.untilTime = untilT
        end
        if type(name) == "string" and name ~= "" then
            S.pendingWrit.boxName = name
        end
        return
    end
    S.pendingWrit = {
        name = name or "box",
        items = {},
        untilTime = untilT,
        fromBox = true,
    }
end

function MatLog.WritCaptureActive()
    if not S.pendingWrit then
        return false
    end
    if type(GetTimeStamp) == "function" and S.pendingWrit.untilTime and GetTimeStamp() > S.pendingWrit.untilTime then
        if MatLog.BackpackHasWritBox() then
            S.pendingWrit.untilTime = GetTimeStamp() + C.WRIT_LOOT_WINDOW_S
            return true
        end
        MatLog.CreditWritBagDiff()
        S.pendingWrit = nil
        return false
    end
    return true
end

function MatLog.HarvestInteraction()
    if type(GetInteractionType) ~= "function" then
        return false
    end
    local interaction = GetInteractionType()
    return interaction == INTERACTION_HARVEST
        or interaction == INTERACTION_FISH
        or interaction == INTERACTION_PICKPOCKET
        or interaction == INTERACTION_HIDEYHOLE
        or interaction == INTERACTION_ANTIQUITY_DIG_SPOT
end

-- World sacks/crates/nodes are scene interactables (OBJECT / FIXTURE / AOE).
-- Daily-writ coffers are inventory items you UseItem (ITEM). There is no item
-- container type on world objects.
function MatLog.LootTargetIsWorldInteractable(name, targetType)
    if MatLog.IsWritRewardBoxName(name) then
        return false
    end
    return targetType == INTERACT_TARGET_TYPE_OBJECT
        or targetType == INTERACT_TARGET_TYPE_FIXTURE
        or targetType == INTERACT_TARGET_TYPE_AOE_LOOT
end

function MatLog.WorldLootActive()
    if S.lootingWorld then
        return true
    end
    if MatLog.HarvestInteraction() then
        return true
    end
    if type(GetLootTargetInfo) == "function" then
        local name, targetType = GetLootTargetInfo()
        return MatLog.LootTargetIsWorldInteractable(name, targetType)
    end
    return false
end

function MatLog.ShouldIgnoreInventoryGain()
    -- Mailbox inventory is credited from snapshots / bag-diff, not slot updates
    -- (craft-bag stacks often have stackCountChange 0). Do not log it as World.
    if S.mailboxOpen then
        return true
    end
    if MatLog.WritCaptureActive() or MatLog.WorldLootActive() or MatLog.IsLootingNow() then
        return false
    end
    if MatLog.CraftingBusy() then
        return true
    end
    if type(GetInteractionType) == "function" then
        local interaction = GetInteractionType()
        if C.SUPPRESS_INTERACTION[interaction] then
            return true
        end
    end
    return false
end

function MatLog.CurrentSource()
    if MatLog.WorldLootActive() then
        return C.SOURCE_WORLD
    end
    if S.lootingWritBox or MatLog.WritCaptureActive() then
        return C.SOURCE_WRIT
    end
    if S.mailboxOpen then
        return C.SOURCE_HIRELING
    end
    return C.SOURCE_WORLD
end

function MatLog.IsDailyWritQuest(journalIndex)
    if type(journalIndex) ~= "number" then
        return false
    end
    if type(GetJournalQuestRepeatType) ~= "function" or type(GetJournalQuestType) ~= "function" then
        return false
    end
    if GetJournalQuestRepeatType(journalIndex) ~= QUEST_REPEAT_DAILY then
        return false
    end
    local qType = GetJournalQuestType(journalIndex)
    if qType ~= QUEST_TYPE_CRAFTING and qType ~= QUEST_TYPE_HOLIDAY_EVENT then
        return false
    end
    if type(GetQuestConditionMasterWritInfo) == "function" then
        local master = GetQuestConditionMasterWritInfo(journalIndex, 1, 1)
        if master ~= nil then
            return false
        end
    end
    return true
end

function MatLog.ScanTrackedWrits()
    S.trackedWritNames = {}
    local n = 25
    if type(GetNumJournalQuests) == "function" then
        n = GetNumJournalQuests() or 25
    end
    for i = 1, n do
        if MatLog.IsDailyWritQuest(i) then
            local name = GetJournalQuestName(i)
            if type(name) == "string" and name ~= "" then
                S.trackedWritNames[name] = true
            end
        end
    end
end

function MatLog.SnapshotWritRewards(journalIndex)
    local items = {}
    if type(GetJournalQuestNumRewards) ~= "function" or type(GetJournalQuestRewardInfo) ~= "function" then
        return items
    end
    local num = GetJournalQuestNumRewards(journalIndex) or 0
    for i = 1, num do
        local rewardType, name, amount = GetJournalQuestRewardInfo(journalIndex, i)
        if rewardType == REWARD_TYPE_AUTO_ITEM or rewardType == REWARD_TYPE_STYLE_STONES then
            local link = nil
            if type(GetQuestRewardItemLink) == "function" then
                link = GetQuestRewardItemLink(i, LINK_STYLE_DEFAULT)
            end
            items[#items + 1] = {
                link = link,
                name = name,
                count = (type(amount) == "number" and amount > 0) and amount or 1,
            }
        end
    end
    return items
end

function MatLog.BeginWritCapture(journalIndex, questName)
    MatLog.CaptureWritBagBaseline()
    local items = MatLog.SnapshotWritRewards(journalIndex)
    MatLog.ExtendWritCapture(C.WRIT_LOOT_WINDOW_S, questName)
    S.pendingWrit.items = items
end

function MatLog.CreditWritSnapshot()
    if not S.pendingWrit then
        return
    end
    local items = S.pendingWrit.items or {}
    S.pendingWrit.items = {}
    local added = false
    for i = 1, #items do
        local item = items[i]
        if not MatLog.IsWritRewardContainerLink(item.link) then
            if MatLog.AddWritItem(item.link, item.count, item.name) then
                added = true
            end
        end
    end
    if added then
        MatLog.RefreshIfShown()
    end
end

function MatLog.StartCaptureIfWritBoxes()
    MatLog.EnsureWritBoxLookups()
    S.lastBoxScanMs = 0
    if MatLog.BackpackHasWritBox() then
        MatLog.EnsureWritBagBaseline()
        MatLog.ExtendWritCapture(C.WRIT_LOOT_WINDOW_S, "bag")
    end
end

function MatLog.OnQuestCompleteDialog(_, journalIndex)
    local name = GetJournalQuestName(journalIndex)
    if MatLog.IsDailyWritQuest(journalIndex) or (type(name) == "string" and S.trackedWritNames[name]) then
        MatLog.BeginWritCapture(journalIndex, name)
    end
end

function MatLog.OnQuestComplete(_, questName)
    if type(questName) == "string" and S.trackedWritNames[questName] then
        if not S.pendingWrit then
            S.pendingWrit = { name = questName, items = {}, untilTime = GetTimeStamp() + C.WRIT_LOOT_WINDOW_S }
        else
            S.pendingWrit.untilTime = GetTimeStamp() + C.WRIT_LOOT_WINDOW_S
        end
    end
end

function MatLog.OnQuestRemoved(_, isCompleted, _journalIndex, questName)
    if not isCompleted then
        if type(questName) == "string" then
            S.trackedWritNames[questName] = nil
        end
        return
    end
    if S.pendingWrit then
        MatLog.CreditWritSnapshot()
        S.pendingWrit.untilTime = GetTimeStamp() + C.WRIT_LOOT_WINDOW_S
    elseif type(questName) == "string" and S.trackedWritNames[questName] then
        S.pendingWrit = { name = questName, items = {}, untilTime = GetTimeStamp() + C.WRIT_LOOT_WINDOW_S }
    end
    if type(questName) == "string" then
        S.trackedWritNames[questName] = nil
    end
    MatLog.ScanTrackedWrits()
end

function MatLog.OnQuestAdded()
    MatLog.ScanTrackedWrits()
end

function MatLog.OnMailTake(_, mailId)
    -- Category Take all is credited from bag-diff so per-mail events do not
    -- double-count. Single-mail Take all uses TakeMailAttachments (not the
    -- older TakeMailAttachedItems) and is snapshotted in that PreHook.
    if S.takeAllInProgress then
        return
    end
    local hireling = MatLog.IsHirelingMail(mailId) or S.mailSnapshots[MatLog.MailKey(mailId)] ~= nil
    S.lastMailHireling = hireling
    if hireling then
        MatLog.BeginMailCredit()
        MatLog.CreditMail(mailId)
        MatLog.ScheduleMailBagDiff(400)
    else
        MatLog.AbsorbMailBagIntoBaseline(400)
    end
end

function MatLog.OnMailTakeAll(_, result, category)
    -- Inbox category "Take all" does not open each message. MAIL_CATEGORY_PLAYER_MAIL
    -- is 0 (falsy), so compare with == only. Hireling mail is SYSTEM; guild-store
    -- mail is too. Bag-diff whenever this mailbox had hireling mail — mixed inboxes
    -- may include other system attachments.
    S.takeAllInProgress = false
    if type(result) == "number" and result ~= MAIL_TAKE_ATTACHMENT_RESULT_SUCCESS then
        return
    end
    if category == MAIL_CATEGORY_PLAYER_MAIL then
        MatLog.AbsorbMailBagIntoBaseline(200)
        return
    end
    if S.mailCreditPending or S.sawHirelingThisMailbox then
        MatLog.BeginMailCredit()
        MatLog.ScheduleMailBagDiff(800)
    end
end

function MatLog.OnMailInboxUpdate()
    if S.mailboxOpen and not S.mailCreditPending and not S.takeAllInProgress then
        MatLog.ScanHirelingInbox()
        MatLog.ForEachInboxMail(MatLog.SnapshotMail)
    end
end

function MatLog.PrepareSingleMailTake(mailId)
    S.lastMailHireling = MatLog.IsHirelingMail(mailId)
    MatLog.SnapshotMail(mailId)
    if S.lastMailHireling then
        MatLog.BeginMailCredit()
    end
end

function MatLog.HookMailTakeApis()
    if S.mailApiHooked or type(ZO_PreHook) ~= "function" then
        return
    end
    S.mailApiHooked = true
    ZO_PreHook("TakeAllMailAttachmentsInCategory", function(category)
        if not S.listenersOn then
            return
        end
        S.takeAllInProgress = true
        MatLog.ScanHirelingInbox()
        MatLog.CaptureMailBagBaseline()
        if category == MAIL_CATEGORY_PLAYER_MAIL then
            S.mailCreditPending = false
            return
        end
        if S.sawHirelingThisMailbox or S.inboxHasHireling then
            MatLog.BeginMailCredit()
            MatLog.ScheduleMailBagDiff(1200)
        end
    end)
    -- Keyboard/gamepad "Take All" on one mail, and LWC, call TakeMailAttachments.
    ZO_PreHook("TakeMailAttachments", function(mailId)
        if not S.listenersOn then
            return
        end
        MatLog.PrepareSingleMailTake(mailId)
    end)
    ZO_PreHook("TakeMailAttachedItems", function(mailId)
        if not S.listenersOn then
            return
        end
        MatLog.PrepareSingleMailTake(mailId)
    end)
    if type(ZO_MailInboxShared_TakeAll) == "function" then
        ZO_PreHook("ZO_MailInboxShared_TakeAll", function(mailId)
            if not S.listenersOn then
                return
            end
            MatLog.PrepareSingleMailTake(mailId)
        end)
    end
end

function MatLog.SlotGainCount(bagId, slotIndex, isNewItem, stackCountChange)
    if type(stackCountChange) == "number" and stackCountChange > 0 then
        return stackCountChange
    end
    -- Craft-bag slots hold the whole stack of an item. That total is not a gain.
    if bagId == BAG_VIRTUAL then
        return nil
    end
    if isNewItem or MatLog.WritCaptureActive() or MatLog.IsLootingNow() then
        if type(GetSlotStackSize) == "function" then
            local n = GetSlotStackSize(bagId, slotIndex)
            if type(n) == "number" and n > 0 then
                return n
            end
        end
        return 1
    end
    return nil
end

function MatLog.RecordGain(link, count, name, source)
    if source == C.SOURCE_WRIT then
        return MatLog.AddWritItem(link, count, name)
    end
    return MatLog.AddItem(link, count, name, source)
end

function MatLog.CreditLootWindow(source)
    if type(GetNumLootItems) ~= "function" or type(GetLootItemInfo) ~= "function" then
        return false
    end
    source = source or C.SOURCE_WRIT
    local n = GetNumLootItems() or 0
    local added = false
    for i = 1, n do
        local lootId, lootName, _, quantity = GetLootItemInfo(i)
        local link = nil
        if type(GetLootItemLink) == "function" and lootId then
            link = GetLootItemLink(lootId, LINK_STYLE_DEFAULT)
        end
        local count = quantity or 1
        if MatLog.RecordGain(link, count, lootName, source) then
            if source == C.SOURCE_WORLD and MatLog.WritCaptureActive() then
                MatLog.NoteWritBagGain(link, count)
            end
            added = true
        end
    end
    return added
end

function MatLog.OnInventorySlot(_, bagId, slotIndex, isNewItem, _sound, _reason, stackCountChange)
    if bagId ~= BAG_BACKPACK and bagId ~= BAG_VIRTUAL then
        return
    end
    S.lastBoxScanMs = 0
    if type(GetItemLink) ~= "function" then
        return
    end
    local link = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    if MatLog.IsWritRewardContainerLink(link) then
        MatLog.EnsureWritBagBaseline()
        MatLog.ExtendWritCapture(C.WRIT_LOOT_WINDOW_S, MatLog.ItemName(link))
        return
    end
    if S.mailboxOpen and S.mailCreditPending then
        MatLog.ScheduleMailBagDiff(300)
    end
    -- LWC dumps coffer mats into the craft bag after the loot window is empty.
    -- MatLog.SlotGainCount is often 0 there; bag-diff is the fallback.
    if MatLog.WritCaptureActive() and not MatLog.WorldLootActive() then
        if type(zo_callLater) == "function" then
            zo_callLater(MatLog.CreditWritBagDiff, 250)
        end
    end
    local count = MatLog.SlotGainCount(bagId, slotIndex, isNewItem, stackCountChange)
    if not count then
        return
    end
    if MatLog.ShouldIgnoreInventoryGain() then
        return
    end
    local source = MatLog.CurrentSource()
    if MatLog.RecordGain(link, count, nil, source) then
        S.lastInvAddMs = MatLog.NowMs()
        if source == C.SOURCE_HIRELING then
            MatLog.NoteMailBagGain(link, count)
        elseif source == C.SOURCE_WORLD and MatLog.WritCaptureActive() then
            MatLog.NoteWritBagGain(link, count)
        end
        MatLog.RefreshIfShown()
    end
end

function MatLog.OnLootReceived(_, _receivedBy, itemName, quantity, _sound, _lootType, isSelf)
    if not isSelf then
        return
    end
    if S.mailboxOpen and not MatLog.WritCaptureActive() then
        return
    end
    if MatLog.ShouldIgnoreInventoryGain() then
        return
    end
    if not MatLog.WritCaptureActive() and (MatLog.NowMs() - S.lastInvAddMs) < 600 then
        return
    end
    local source = MatLog.CurrentSource()
    if MatLog.RecordGain(itemName, quantity or 1, MatLog.ItemName(itemName), source) then
        S.lastInvAddMs = MatLog.NowMs()
        if source == C.SOURCE_WORLD and MatLog.WritCaptureActive() then
            MatLog.NoteWritBagGain(itemName, quantity or 1)
        end
        MatLog.RefreshIfShown()
    end
end

function MatLog.OnLootUpdated()
    local name, targetType
    if type(GetLootTargetInfo) == "function" then
        name, targetType = GetLootTargetInfo()
    end
    local worldInteract = MatLog.HarvestInteraction() or MatLog.LootTargetIsWorldInteractable(name, targetType)
    local isWritBox = MatLog.IsWritRewardBoxName(name)
    -- LWC coffers are ITEM (UseItem). World sacks/crates/barrels are OBJECT/FIXTURE.
    if not isWritBox and MatLog.WritCaptureActive() and not worldInteract then
        if targetType == INTERACT_TARGET_TYPE_ITEM then
            isWritBox = true
        elseif type(GetNumLootItems) == "function" and (GetNumLootItems() or 0) > 0 then
            isWritBox = true
        end
    end
    S.lootingWorld = worldInteract and not isWritBox
    S.lootingWritBox = isWritBox
    if S.lootingWorld then
        if MatLog.CreditLootWindow(C.SOURCE_WORLD) then
            S.lastInvAddMs = MatLog.NowMs()
            MatLog.RefreshIfShown()
        end
        return
    end
    if not isWritBox then
        return
    end
    MatLog.ExtendWritCapture(C.WRIT_LOOT_WINDOW_S, name)
    if MatLog.CreditLootWindow(C.SOURCE_WRIT) then
        S.lastInvAddMs = MatLog.NowMs()
        MatLog.RefreshIfShown()
    end
end

function MatLog.OnLootClosed()
    local wasWritBox = S.lootingWritBox
    local wasWorld = S.lootingWorld
    S.lootingWritBox = false
    S.lootingWorld = false
    -- World sack/crate windows must not drain the writ bag-diff. Coffer loot
    -- (and LWC emptying the window before we see ITEM) still bag-diffs.
    if wasWorld then
        return
    end
    if not wasWritBox and not MatLog.WritCaptureActive() then
        return
    end
    if S.pendingWrit then
        S.pendingWrit.untilTime = GetTimeStamp() + C.WRIT_BOX_DRAIN_S
        if MatLog.BackpackHasWritBox() then
            S.pendingWrit.untilTime = GetTimeStamp() + C.WRIT_LOOT_WINDOW_S
        end
    end
    local function apply()
        MatLog.CreditWritBagDiff()
    end
    if type(zo_callLater) == "function" then
        zo_callLater(apply, 200)
    else
        apply()
    end
end

function MatLog.UnregisterListeners()
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_PREFIX .. "MailReadable", EVENT_MAIL_READABLE)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_PREFIX .. "MailTake", EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_PREFIX .. "MailTakeAll", EVENT_MAIL_TAKE_ALL_ATTACHMENTS_IN_CATEGORY_RESPONSE)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_PREFIX .. "MailOpen", EVENT_MAIL_OPEN_MAILBOX)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_PREFIX .. "MailClose", EVENT_MAIL_CLOSE_MAILBOX)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_PREFIX .. "MailInbox", EVENT_MAIL_INBOX_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_PREFIX .. "Inv", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_PREFIX .. "InvVirtual", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_PREFIX .. "Loot", EVENT_LOOT_RECEIVED)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_PREFIX .. "LootUpdated", EVENT_LOOT_UPDATED)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_PREFIX .. "LootClosed", EVENT_LOOT_CLOSED)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_PREFIX .. "QuestDialog", EVENT_QUEST_COMPLETE_DIALOG)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_PREFIX .. "QuestComplete", EVENT_QUEST_COMPLETE)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_PREFIX .. "QuestRemoved", EVENT_QUEST_REMOVED)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_PREFIX .. "QuestAdded", EVENT_QUEST_ADDED)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_PREFIX .. "Activated", EVENT_PLAYER_ACTIVATED)
    S.listenersOn = false
end

function MatLog.RegisterListeners()
    if S.listenersOn then
        return
    end
    EVENT_MANAGER:RegisterForEvent(C.EVENT_PREFIX .. "MailReadable", EVENT_MAIL_READABLE, MatLog.OnMailReadable)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_PREFIX .. "MailTake", EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, MatLog.OnMailTake)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_PREFIX .. "MailTakeAll", EVENT_MAIL_TAKE_ALL_ATTACHMENTS_IN_CATEGORY_RESPONSE, MatLog.OnMailTakeAll)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_PREFIX .. "MailOpen", EVENT_MAIL_OPEN_MAILBOX, MatLog.OnMailOpen)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_PREFIX .. "MailClose", EVENT_MAIL_CLOSE_MAILBOX, MatLog.OnMailClose)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_PREFIX .. "MailInbox", EVENT_MAIL_INBOX_UPDATE, MatLog.OnMailInboxUpdate)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_PREFIX .. "Inv", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, MatLog.OnInventorySlot)
    if type(EVENT_MANAGER.AddFilterForEvent) == "function" and REGISTER_FILTER_BAG_ID and BAG_BACKPACK then
        EVENT_MANAGER:AddFilterForEvent(C.EVENT_PREFIX .. "Inv", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    end
    if BAG_VIRTUAL then
        EVENT_MANAGER:RegisterForEvent(C.EVENT_PREFIX .. "InvVirtual", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, MatLog.OnInventorySlot)
        if type(EVENT_MANAGER.AddFilterForEvent) == "function" and REGISTER_FILTER_BAG_ID then
            EVENT_MANAGER:AddFilterForEvent(C.EVENT_PREFIX .. "InvVirtual", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_VIRTUAL)
        end
    end
    MatLog.HookMailTakeApis()
    EVENT_MANAGER:RegisterForEvent(C.EVENT_PREFIX .. "Loot", EVENT_LOOT_RECEIVED, MatLog.OnLootReceived)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_PREFIX .. "LootUpdated", EVENT_LOOT_UPDATED, MatLog.OnLootUpdated)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_PREFIX .. "LootClosed", EVENT_LOOT_CLOSED, MatLog.OnLootClosed)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_PREFIX .. "QuestDialog", EVENT_QUEST_COMPLETE_DIALOG, MatLog.OnQuestCompleteDialog)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_PREFIX .. "QuestComplete", EVENT_QUEST_COMPLETE, MatLog.OnQuestComplete)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_PREFIX .. "QuestRemoved", EVENT_QUEST_REMOVED, MatLog.OnQuestRemoved)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_PREFIX .. "QuestAdded", EVENT_QUEST_ADDED, MatLog.OnQuestAdded)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_PREFIX .. "Activated", EVENT_PLAYER_ACTIVATED, function()
        MatLog.EnsureWritBoxLookups()
        MatLog.ScanTrackedWrits()
        MatLog.StartCaptureIfWritBoxes()
        MatLog.PruneOldDays()
    end)
    S.listenersOn = true
end

function MatLog.SetEnabled(enabled)
    if enabled then
        MatLog.RegisterListeners()
        MatLog.ScanTrackedWrits()
        MatLog.StartCaptureIfWritBoxes()
        MatLog.PruneOldDays()
    else
        MatLog.UnregisterListeners()
    end
end
