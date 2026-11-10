-- Auctionworthy for WoW 3.3.5a
-- Auctionator 2.6 / 3.1.x (Atr_GetAuctionBuyout, AUCTIONATOR_SAVEDVARS undercut)
-- /auctionworthy or /worthy

local ADDON_NAME = ...

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
    applyUndercut = true,
    showUndercut = true,
}

local options = {}

-- Auctionator 3.1 Undercutting window (AUCTIONATOR_SAVEDVARS). Keys are copper
-- thresholds; values are "Undercut by" copper. Same rows as the in-game UI:
--   over 500 gold  _5000000   (default 1g)
--   over 100 gold  _1000000   (default 25s)
--   over 20 gold   _200000    (default 10s)
--   over 5 gold    _50000     (default 5s)
--   over 1 gold    _10000     (default 2s)
--   over 20 silver _2000      (default 1s)
--   over 5 silver  _500       (default 5c)
-- Below 5 silver Auctionator subtracts 1c. STARTING_DISCOUNT is bid vs buyout
-- and is not applied to the tooltip buyout.
local UC_BRACKETS = {
    { min = 5000000, key = "_5000000", label = "over 500 gold" },
    { min = 1000000, key = "_1000000", label = "over 100 gold" },
    { min = 200000, key = "_200000", label = "over 20 gold" },
    { min = 50000, key = "_50000", label = "over 5 gold" },
    { min = 10000, key = "_10000", label = "over 1 gold" },
    { min = 2000, key = "_2000", label = "over 20 silver" },
    { min = 500, key = "_500", label = "over 5 silver" },
}

local function SafeGlobal(name)
    if type(name) ~= "string" or type(_G) ~= "table" then
        return nil
    end
    local ok, value = pcall(rawget, _G, name)
    if ok then
        return value
    end
end

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
    value = math.floor(tonumber(value) or 0)
    if GetCoinTextureString then
        return GetCoinTextureString(value)
    end
    local gold = math.floor(value / 10000)
    local silver = math.floor((value % 10000) / 100)
    local copper = math.floor(value % 100)
    local goldText = "|cFFFFFFFF" .. gold .. "|r |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"
    local silverText = "|cFFFFFFFF" .. silver .. "|r |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t"
    local copperText = "|cFFFFFFFF" .. copper .. "|r |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"
    return goldText .. " " .. silverText .. " " .. copperText
end

local function AuctionatorReady()
    return type(SafeGlobal("Atr_GetAuctionBuyout")) == "function"
end

local function getAuctionPrice(itemLink)
    if not AuctionatorReady() or type(itemLink) ~= "string" then
        return nil
    end
    local ok, price = pcall(Atr_GetAuctionBuyout, itemLink)
    if ok and type(price) == "number" and price > 0 then
        return price
    end
    return nil
end

-- In-memory copy of AUCTIONATOR_SAVEDVARS undercut rows. Never written back.
local undercutSnap = {
    loaded = false,
    source = nil,
    brackets = nil,
    startingDiscount = nil,
}

local function CopyNumber(value)
    value = tonumber(value)
    if type(value) == "number" then
        return value
    end
end

local function AuctionatorLuaPresent()
    return type(SafeGlobal("AUCTIONATOR_SAVEDVARS")) == "table"
end

local function ReadSavedBrackets()
    local vars = SafeGlobal("AUCTIONATOR_SAVEDVARS")
    if type(vars) ~= "table" then
        return nil
    end
    local brackets = {}
    local found
    for _, row in ipairs(UC_BRACKETS) do
        local amount = CopyNumber(vars[row.key])
        if amount ~= nil then
            brackets[row.key] = amount
            found = true
        end
    end
    if found then
        return brackets, CopyNumber(vars.STARTING_DISCOUNT)
    end
end

local afterFrame = CreateFrame("Frame")
afterFrame:Hide()
local afterFn
afterFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    local fn = afterFn
    afterFn = nil
    if fn then
        fn()
    end
end)

local function AfterZero(fn)
    afterFn = fn
    afterFrame:Show()
end

local function RefreshAuctionatorConfig(announce)
    undercutSnap.loaded = false
    undercutSnap.source = nil
    undercutSnap.brackets = nil
    undercutSnap.startingDiscount = nil

    local brackets, startingDiscount = ReadSavedBrackets()
    if brackets then
        undercutSnap.loaded = true
        undercutSnap.source = "account"
        undercutSnap.brackets = brackets
        undercutSnap.startingDiscount = startingDiscount
    elseif AuctionatorReady() then
        undercutSnap.source = "api"
    end

    if announce then
        local prefix = "|cff00ff00Auctionworthy:|r "
        if not AuctionatorLuaPresent() and not AuctionatorReady() then
            print(prefix .. "Auctionator is not loaded yet. Enable Auctionator, then /worthy refresh.")
            return undercutSnap
        end
        if not undercutSnap.loaded then
            print(prefix .. "Auctionator is loaded, but undercut settings were empty.")
            return undercutSnap
        end
        print(prefix .. "Refreshed (AUCTIONATOR_SAVEDVARS). Undercut by:")
        for _, row in ipairs(UC_BRACKETS) do
            local amount = undercutSnap.brackets[row.key]
            if amount then
                print("  " .. row.label .. ": " .. formatGold(amount))
            end
        end
        if undercutSnap.startingDiscount ~= nil then
            print("  Starting Price Discount: " .. undercutSnap.startingDiscount .. "%")
        end
    end
    return undercutSnap
end

local function SavedUndercutAmount(key)
    if undercutSnap.loaded and undercutSnap.brackets then
        return CopyNumber(undercutSnap.brackets[key])
    end
    local vars = SafeGlobal("AUCTIONATOR_SAVEDVARS")
    if type(vars) == "table" then
        return CopyNumber(vars[key])
    end
end

local function BracketForPrice(price)
    price = tonumber(price) or 0
    for _, row in ipairs(UC_BRACKETS) do
        if price > row.min then
            return row, SavedUndercutAmount(row.key)
        end
    end
end

-- Same rounding Auctionator uses when posting (roundPriceDown / Atr_CalcUndercutPrice).
local function RoundPriceDown(price, a)
    a = tonumber(a) or 0
    if a == 0 then
        return price
    end
    local newprice = math.floor((price - 1) / a) * a
    if (price - newprice) < a / 2 then
        newprice = newprice - a
    end
    if newprice == price then
        newprice = newprice - 1
    end
    return newprice
end

local function CalcUndercutPrice(price)
    price = tonumber(price) or 0
    local _, amount = BracketForPrice(price)
    if amount then
        return RoundPriceDown(price, amount)
    end
    if price > 0 then
        return math.floor(price - 1)
    end
    return 0
end

local function ComputePosting(listingPrice)
    if type(listingPrice) ~= "number" then
        return listingPrice
    end
    local posting = CalcUndercutPrice(listingPrice)
    if type(posting) ~= "number" then
        posting = math.floor(listingPrice)
    end
    if posting < 1 then
        posting = 1
    end
    return posting
end

-- Tooltip line matches the Undercutting window: "Undercut by" for this buyout range.
local function undercutLine(listingPrice)
    local ok, line = pcall(function()
        if type(listingPrice) ~= "number" or listingPrice <= 0 then
            return
        end
        local row, amount = BracketForPrice(listingPrice)
        if row and amount then
            return "Undercut: " .. formatGold(amount) .. " (" .. row.label .. ")"
        end
        return "Undercut: " .. formatGold(1)
    end)
    if ok then
        return line
    end
end

local function applyUndercut(unitPrice)
    if not options.applyUndercut then
        return unitPrice
    end
    return ComputePosting(unitPrice)
end

-- Classic-style "what it costs to auction vs vendor": deposit-ish + listing overhead.
local function calculateAuctionCosts(vendorPrice)
    return math.floor(vendorPrice * 0.6) + vendorPrice + math.floor(vendorPrice * 0.05)
end

local function ItemInfo(itemLink)
    local ok, name, link, quality, ilvl, minLevel, itemType, subType, stackSize, equipLoc, texture, vendorPrice = pcall(GetItemInfo, itemLink)
    if not ok then
        return
    end
    return name, link, quality, ilvl, minLevel, itemType, subType, stackSize, equipLoc, texture, vendorPrice
end

-- 3.3.5a GetItemInfo has no bind type. Read the bind line already on the tooltip.
local function isSoulboundTooltip(tooltip)
    if tooltip.IsForbidden and tooltip:IsForbidden() then
        return false
    end
    local tooltipName = tooltip.GetName and tooltip:GetName()
    if not tooltipName then
        return false
    end
    local n = tooltip.NumLines and tooltip:NumLines() or 0
    for i = 1, n do
        local line = _G[tooltipName .. "TextLeft" .. i]
        local text = line and line.GetText and line:GetText()
        if type(text) == "string" then
            if text == ITEM_SOULBOUND or text == ITEM_BIND_ON_PICKUP or text == ITEM_BIND_QUEST then
                return true
            end
        end
    end
    return false
end

local function updateTooltip(tooltip, itemLink)
    if not tooltip or not itemLink then
        return
    end
    if tooltip.IsForbidden and tooltip:IsForbidden() then
        return
    end
    if tooltip.AuctionworthyAdded then
        return
    end
    if isSoulboundTooltip(tooltip) then
        return
    end

    local _, _, _, _, _, _, _, stackSize, _, _, vendorPrice = ItemInfo(itemLink)
    if not vendorPrice or vendorPrice <= 0 then
        return
    end

    local marketUnit = getAuctionPrice(itemLink)
    stackSize = stackSize or 1

    local isFullStack = IsShiftKeyDown() and stackSize > 1 and options.showFullStack
    local auctionCosts = calculateAuctionCosts(vendorPrice)
    local listingPrice = marketUnit

    if isFullStack then
        auctionCosts = auctionCosts * stackSize
        listingPrice = listingPrice and listingPrice * stackSize or nil
        vendorPrice = vendorPrice * stackSize
        tooltip:AddLine("|cFFFFA500Calculations for Full Stack (" .. stackSize .. "x)|r")
    end

    -- Undercut the listing buyout (unit or stack), same as Auctionator's sell tab.
    local auctionPrice = applyUndercut(listingPrice)

    if auctionPrice then
        local profit = auctionPrice - auctionCosts
        if options.showAuctionCosts then
            tooltip:AddLine("Auction Costs: " .. formatGold(auctionCosts))
        end
        if options.showAuctionPrice then
            tooltip:AddLine("Auction Price: " .. formatGold(auctionPrice))
        end
        if profit > 0 then
            if options.showProfitOptions then
                tooltip:AddLine("Profit: " .. formatGold(profit), 0, 1, 0)
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
                tooltip:AddLine("Loss: " .. formatGold(-profit), 1, 0, 0)
            end
            if options.showDecisionText then
                tooltip:AddLine("Sell to vendor!", 1, 0, 0)
            end
        end
    elseif options.showNoAuctionData then
        tooltip:AddLine("No Auction Data", 1, 0, 1)
    end

    if options.showUndercut then
        local line = undercutLine(listingPrice)
        if line then
            tooltip:AddLine(line, 0.65, 0.85, 1)
        end
    end

    tooltip.AuctionworthyAdded = true
    tooltip:Show()
end

local function HookCleared(tooltip)
    if not tooltip or tooltip.AuctionworthyClearedHook then
        return
    end
    tooltip.AuctionworthyClearedHook = true
    tooltip:HookScript("OnTooltipCleared", function(self)
        self.AuctionworthyAdded = nil
    end)
end

local function HookItemTooltip(method, getLink)
    if not GameTooltip or not GameTooltip[method] then
        return
    end
    hooksecurefunc(GameTooltip, method, function(tooltip, ...)
        HookCleared(tooltip)
        local ok, link = pcall(getLink, ...)
        if ok then
            updateTooltip(tooltip, link)
        end
    end)
end

local hooked
local function InstallHooks()
    if hooked then
        return
    end
    hooked = true

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
        local _, link = ItemInfo(name)
        return link
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
        local _, link = ItemInfo(name)
        return link
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
            local _, link = ItemInfo(id)
            return link
        end
    end)

    HookItemTooltip("SetHyperlink", function(itemString)
        local _, link = ItemInfo(itemString)
        return link or itemString
    end)

    if ItemRefTooltip and ItemRefTooltip.SetHyperlink then
        hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(tooltip, itemString)
            HookCleared(tooltip)
            local _, link = ItemInfo(itemString)
            updateTooltip(tooltip, link or itemString)
        end)
    end
end

local hookedOptionsFrames = {}
local lastOptionsRefresh = 0

local function OnAuctionatorOptionsClosed()
    local function run()
        local now = GetTime and GetTime() or 0
        if now - lastOptionsRefresh < 0.25 then
            return
        end
        lastOptionsRefresh = now
        -- After Auctionator's own OnHide Save() so we copy the new undercut.
        RefreshAuctionatorConfig(false)
    end
    AfterZero(run)
end

local function HookAuctionatorOptionsClose()
    local names = {
        "InterfaceOptionsFrame",
        "Atr_UCConfigFrame",
        "Atr_BasicOptionsFrame",
    }
    for _, name in ipairs(names) do
        if not hookedOptionsFrames[name] then
            local frame = SafeGlobal(name)
            if type(frame) == "table" and frame.HookScript then
                local ok = pcall(frame.HookScript, frame, "OnHide", OnAuctionatorOptionsClosed)
                if ok then
                    hookedOptionsFrames[name] = true
                end
            end
        end
    end
end

function Auctionworthy:ADDON_LOADED(name)
    if name == ADDON_NAME then
        LoadOptions()
        InstallHooks()
        HookAuctionatorOptionsClose()
        RefreshAuctionatorConfig(false)
        return
    end
    if name == "Auctionator" then
        HookAuctionatorOptionsClose()
        RefreshAuctionatorConfig(false)
    end
end

function Auctionworthy:PLAYER_ENTERING_WORLD()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    HookAuctionatorOptionsClose()
    RefreshAuctionatorConfig(false)
    if not AuctionatorReady() then
        print("|cffff7f00Auctionworthy:|r Auctionator is off. Prices stay empty until you enable it. /worthy refresh after it loads.")
    end
end
Auctionworthy:RegisterEvent("PLAYER_ENTERING_WORLD")

local function openOptionsPanel()
    if AuctionworthyOptionsFrame then
        AuctionworthyOptionsFrame:Show()
        return
    end

    local frame = CreateFrame("Frame", "AuctionworthyOptionsFrame", UIParent)
    frame:SetWidth(400)
    frame:SetHeight(410)
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
    info:SetText("Uses Auctionator's Undercutting brackets (over 500g, 100g, …). Shift shows a full stack when that option is on. /worthy refresh re-reads AUCTIONATOR_SAVEDVARS.")

    local checkboxes = {
        { label = "Show Auction Costs", key = "showAuctionCosts" },
        { label = "Show Auction Price", key = "showAuctionPrice" },
        { label = "Show Profit/Loss Options", key = "showProfitOptions" },
        { label = "Show No Auction Data", key = "showNoAuctionData" },
        { label = "Show Full Stack Calculations", key = "showFullStack" },
        { label = "Show Decision Text", key = "showDecisionText" },
        { label = "Apply Auctionator undercut", key = "applyUndercut" },
        { label = "Show Undercut", key = "showUndercut" },
    }

    local yOffset = -100
    for i, checkbox in ipairs(checkboxes) do
        local cb = CreateFrame("CheckButton", "AuctionworthyOption" .. i, frame, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 20, yOffset)
        local label = _G[cb:GetName() .. "Text"]
        label:SetFontObject(GameFontHighlight)
        label:SetText(checkbox.label)
        cb:SetChecked(options[checkbox.key] and true or false)
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
SlashCmdList["AUCTIONWORTHY"] = function(msg)
    msg = strlower(strtrim(tostring(msg or "")))
    if msg == "refresh" or msg == "reload" then
        RefreshAuctionatorConfig(true)
        return
    end
    if msg == "help" then
        print("|cff00ff00Auctionworthy:|r /worthy — options")
        print("  /worthy refresh — re-read Auctionator undercut (no /reload)")
        return
    end
    openOptionsPanel()
end
