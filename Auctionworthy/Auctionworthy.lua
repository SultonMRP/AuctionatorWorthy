-- Auctionworthy for WoW 3.3.5a
-- Requires Auctionator 2.6.x (Atr_GetAuctionBuyout) for auction data

local Auctionworthy = CreateFrame("Frame")
Auctionworthy.name = "Auctionworthy"
Auctionworthy:RegisterEvent("ADDON_LOADED")
Auctionworthy:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

local defaultOptions = {
    showAuctionCosts = true,
    showAuctionPrice = true,
    showProfitOptions = true,
    showNoAuctionData = true,
    showFullStack = true,
    showDecisionText = true,
}

local options = {}

local function LoadOptions()
    if not AuctionworthySavedOptions then
        AuctionworthySavedOptions = {}
    end
    for key, value in pairs(defaultOptions) do
        if AuctionworthySavedOptions[key] == nil then
            AuctionworthySavedOptions[key] = value
        end
    end
    options = AuctionworthySavedOptions
end

local function SaveOptions()
    AuctionworthySavedOptions = options
end

local function formatGold(value)
    local gold = math.floor(value / 10000)
    local silver = math.floor((value % 10000) / 100)
    local copper = math.floor(value % 100)

    local goldText = "|cFFFFFFFF" .. gold .. "|r |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"
    local silverText = "|cFFFFFFFF" .. silver .. "|r |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t"
    local copperText = "|cFFFFFFFF" .. copper .. "|r |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"

    return goldText .. " " .. silverText .. " " .. copperText
end

local function getAuctionPriceFromAuctionator(itemLink)
    if Atr_GetAuctionBuyout then
        return Atr_GetAuctionBuyout(itemLink)
    end
    return nil
end

local function calculateAuctionCosts(vendorPrice)
    return math.floor(vendorPrice * 0.6) + vendorPrice + math.floor(vendorPrice * 0.05)
end

local function calculateProfit(auctionPrice, auctionCosts)
    return auctionPrice - auctionCosts
end

-- 3.3.5a GetItemInfo has no bind type. Read the bind line already on the tooltip.
local function isSoulboundTooltip(tooltip)
    local tooltipName = tooltip:GetName()
    if not tooltipName then
        return false
    end

    for i = 1, tooltip:NumLines() do
        local line = _G[tooltipName .. "TextLeft" .. i]
        local text = line and line:GetText()
        if text == ITEM_SOULBOUND or text == ITEM_BIND_ON_PICKUP then
            return true
        end
    end

    return false
end

local function updateTooltip(tooltip, itemLink)
    if not itemLink or isSoulboundTooltip(tooltip) then
        return
    end

    local vendorPrice = select(11, GetItemInfo(itemLink))
    local auctionPrice = getAuctionPriceFromAuctionator(itemLink)
    local stackSize = select(8, GetItemInfo(itemLink)) or 1

    local isFullStack = IsShiftKeyDown() and stackSize > 1 and options.showFullStack

    if vendorPrice and vendorPrice > 0 then
        local auctionCosts = calculateAuctionCosts(vendorPrice)
        local profit = calculateProfit(auctionPrice or 0, auctionCosts)

        if isFullStack then
            auctionCosts = auctionCosts * stackSize
            auctionPrice = auctionPrice and auctionPrice * stackSize or 0
            vendorPrice = vendorPrice * stackSize
            profit = calculateProfit(auctionPrice, auctionCosts)
            tooltip:AddLine("|cFFFFA500Calculations for Full Stack (" .. stackSize .. "x)|r")
        end

        if auctionPrice and auctionPrice > 0 then
            if options.showAuctionCosts then
                tooltip:AddLine("Auction Costs | " .. formatGold(auctionCosts))
            end
            if options.showAuctionPrice then
                tooltip:AddLine("Auction Price | " .. formatGold(auctionPrice))
            end

            if profit > 0 then
                if options.showProfitOptions then
                    tooltip:AddLine("Profit | " .. formatGold(profit), 0, 1, 0)
                end
                if options.showDecisionText then
                    if profit < auctionCosts * 0.05 or profit < 25 then
                        tooltip:AddLine("Sell to Vendor!", 1, 0.65, 0)
                    else
                        tooltip:AddLine("Auction it!", 0, 1, 0)
                    end
                end
            else
                if options.showProfitOptions then
                    tooltip:AddLine("Loss | " .. formatGold(-profit), 1, 0, 0)
                end
                if options.showDecisionText then
                    tooltip:AddLine("Sell to vendor!", 1, 0, 0)
                end
            end
        else
            if options.showNoAuctionData then
                tooltip:AddLine("No Auction Data", 1, 0, 1)
            end
        end

        tooltip:Show()
    end
end

local function HookItemTooltip(method, getLink)
    hooksecurefunc(GameTooltip, method, function(tooltip, ...)
        updateTooltip(tooltip, getLink(...))
    end)
end

HookItemTooltip("SetBagItem", function(bag, slot)
    return GetContainerItemLink(bag, slot)
end)

HookItemTooltip("SetInventoryItem", function(unit, slot)
    return GetInventoryItemLink(unit, slot)
end)

HookItemTooltip("SetAuctionItem", function(listType, index)
    return GetAuctionItemLink(listType, index)
end)

HookItemTooltip("SetAuctionSellItem", function()
    local name = GetAuctionSellItemInfo()
    if not name or name == "" then
        return nil
    end
    return select(2, GetItemInfo(name))
end)

HookItemTooltip("SetLootItem", function(slot)
    if LootSlotIsItem(slot) then
        return GetLootSlotLink(slot)
    end
end)

HookItemTooltip("SetLootRollItem", function(slot)
    return GetLootRollItemLink(slot)
end)

HookItemTooltip("SetMerchantItem", function(index)
    return GetMerchantItemLink(index)
end)

HookItemTooltip("SetBuybackItem", function(index)
    return GetBuybackItemLink(index)
end)

HookItemTooltip("SetQuestItem", function(questType, index)
    return GetQuestItemLink(questType, index)
end)

HookItemTooltip("SetQuestLogItem", function(questType, index)
    return GetQuestLogItemLink(questType, index)
end)

HookItemTooltip("SetInboxItem", function(index, attachIndex)
    return GetInboxItemLink(index, attachIndex)
end)

HookItemTooltip("SetSendMailItem", function(index)
    local name = GetSendMailItem(index)
    if not name then
        return nil
    end
    return select(2, GetItemInfo(name))
end)

HookItemTooltip("SetTradePlayerItem", function(index)
    return GetTradePlayerItemLink(index)
end)

HookItemTooltip("SetTradeTargetItem", function(index)
    return GetTradeTargetItemLink(index)
end)

HookItemTooltip("SetTradeSkillItem", function(skillIndex, reagentIndex)
    if reagentIndex then
        return GetTradeSkillReagentItemLink(skillIndex, reagentIndex)
    end
    return GetTradeSkillItemLink(skillIndex)
end)

HookItemTooltip("SetGuildBankItem", function(tab, slot)
    return GetGuildBankItemLink(tab, slot)
end)

HookItemTooltip("SetAction", function(slot)
    local actionType, id = GetActionInfo(slot)
    if actionType == "item" then
        return select(2, GetItemInfo(id))
    end
end)

HookItemTooltip("SetHyperlink", function(itemString)
    return select(2, GetItemInfo(itemString))
end)

hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(tooltip, itemString)
    updateTooltip(tooltip, select(2, GetItemInfo(itemString)))
end)

StaticPopupDialogs["AUCTIONWORTHY_MISSING_AUCTIONATOR"] = StaticPopupDialogs["AUCTIONWORTHY_MISSING_AUCTIONATOR"] or {
    text = "Auctionator is required for Auctionworthy to function. Please install Auctionator.",
    button1 = "Okay",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function Auctionworthy:ADDON_LOADED(name)
    if name == "Auctionworthy" then
        LoadOptions()
        if not Atr_GetAuctionBuyout then
            StaticPopup_Show("AUCTIONWORTHY_MISSING_AUCTIONATOR")
        else
            print("|cFF00FF00[Auctionworthy]:|r Addon loaded. Type /auctionworthy or /worthy to open the options menu.")
        end
    end
end

local function openOptionsPanel()
    if AuctionworthyOptionsFrame then
        AuctionworthyOptionsFrame:Show()
        return
    end

    local frame = CreateFrame("Frame", "AuctionworthyOptionsFrame", UIParent)
    frame:SetWidth(400)
    frame:SetHeight(350)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    table.insert(UISpecialFrames, "AuctionworthyOptionsFrame")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Auctionworthy Settings")

    local info = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    info:SetPoint("TOPLEFT", 20, -40)
    info:SetJustifyH("LEFT")
    info:SetWidth(360)
    info:SetText("Customize your auction tooltip settings. Check or uncheck the options below to enable or disable specific tooltip lines.")

    local checkboxes = {
        { label = "Show Auction Costs", key = "showAuctionCosts" },
        { label = "Show Auction Price", key = "showAuctionPrice" },
        { label = "Show Profit/Loss Options", key = "showProfitOptions" },
        { label = "Show No Auction Data", key = "showNoAuctionData" },
        { label = "Show Full Stack Calculations", key = "showFullStack" },
        { label = "Show Decision Text", key = "showDecisionText" },
    }

    local yOffset = -100
    for i, checkbox in ipairs(checkboxes) do
        local cb = CreateFrame("CheckButton", "AuctionworthyOption" .. i, frame, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 20, yOffset)
        local label = _G[cb:GetName() .. "Text"]
        label:SetFontObject(GameFontHighlight)
        label:SetText(checkbox.label)
        cb:SetChecked(options[checkbox.key])

        cb:SetScript("OnClick", function(self)
            options[checkbox.key] = self:GetChecked() and true or false
            SaveOptions()
        end)

        yOffset = yOffset - 30
    end

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeButton:SetWidth(100)
    closeButton:SetHeight(30)
    closeButton:SetPoint("BOTTOM", 0, 10)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame:Show()
end

SLASH_AUCTIONWORTHY1 = "/auctionworthy"
SLASH_AUCTIONWORTHY2 = "/worthy"
SlashCmdList["AUCTIONWORTHY"] = openOptionsPanel
