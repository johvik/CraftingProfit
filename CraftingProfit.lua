local VENDOR_PRICES = {
  -- TODO Add more as needed
  ["Crystal Vial"] = 20,
  ["Flaked Sea Salt"] = 5000,
  ["Dalapeño Pepper"] = 2780,
  ["Muskenbutter"] = 5000,
  ["River Onion"] = 5000,
  ["Royal Olive"] = 5000,
  ["Stonedark Snail"] = 5000
}

CraftingProfitMixin = {}

local function debug_print(...)
  -- Uncomment to get debug information
  -- print(...)
end

-- Returns the minimum of auction and vendor price and if the price is from a vendor
local function GetReagentPrice(reagentName)
  local auctionPrice = Atr_GetAuctionPrice(reagentName)
  local vendorPrice = VENDOR_PRICES[reagentName]
  if auctionPrice and vendorPrice then
    if vendorPrice <= auctionPrice then
      return vendorPrice, true
    else
      return auctionPrice, false
    end
  elseif auctionPrice then
    return auctionPrice, false
  else
    return vendorPrice, true
  end
end

-- Updates the crafting profit information for the given recipeID
function CraftingProfitMixin:UpdateCraftingProfit(recipeID, callback)
  debug_print("UpdateCraftingProfit", recipeID, callback)
  self:Hide()
  if not recipeID then
    return
  end
  local itemLink = C_TradeSkillUI.GetRecipeItemLink(recipeID)
  local numItemsProduced = C_TradeSkillUI.GetRecipeNumItemsProduced(recipeID)
  local itemName, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemLink)
  local reagentsPrice = 0
  local reagentsPriceText = {}
  local reagentsFromVendor = {}
  local numReagents = C_TradeSkillUI.GetRecipeNumReagents(recipeID)

  if not itemName then
    if not callback then
      -- Limit callback to one try
      C_Timer.After(0.1, function() self:UpdateCraftingProfit(recipeID, true) end)
    end
    return
  end

  debug_print("Getting reagents for ", itemName)
  for i = 1, numReagents do
    local reagentName, reagentTexture, reagentCount = C_TradeSkillUI.GetRecipeReagentInfo(recipeID, i)
    if not reagentName then
      if not callback then
        -- Limit callback to one try
        C_Timer.After(0.1, function() self:UpdateCraftingProfit(recipeID, true) end)
      end
      return
    end
    local reagentTextureString = "|T"..reagentTexture..":0|t"
    local reagentPrice, reagentFromVendor = GetReagentPrice(reagentName)
    if reagentPrice then
      reagentsPrice = reagentsPrice + reagentPrice * reagentCount
      if reagentFromVendor then
        table.insert(reagentsFromVendor, reagentTextureString)
      end
    else
      -- Add text description when the price is unknown
      table.insert(reagentsPriceText, reagentCount .. reagentTextureString)
    end
  end

  debug_print("Getting auction price")
  local itemAuctionPrice = Atr_GetAuctionPrice(itemName) -- Cannot use Atr_GetAuctionBuyout since it crashes with enchants
  local profit
  if itemAuctionPrice and reagentsPrice > 0 then
    -- We have a auction price and at least one reagent price
    local deposit = math.max(100, math.floor(0.15 * itemSellPrice))
    local cut = math.floor(0.05 * itemAuctionPrice)
    profit = numItemsProduced * (itemAuctionPrice - deposit - cut) - reagentsPrice
  end

  debug_print("Updating UI", profit)
  -- Update profit
  if profit then
    local profitText = GetCoinTextureString(math.abs(profit))
    if profit > 0 then
      self.ProfitText:SetFontObject("GameFontHighlight")
      if table.getn(reagentsPriceText) > 0 then
        profitText = profitText .. " - " .. table.concat(reagentsPriceText, " - ")
      end
    else
      self.ProfitText:SetFontObject("GameFontRed")
      if table.getn(reagentsPriceText) > 0 then
        profitText = profitText .. " + " .. table.concat(reagentsPriceText, " + ")
      end
    end
    self.ProfitText:SetText(profitText)
  else
    self.ProfitText:SetFontObject("GameFontHighlight")
    self.ProfitText:SetText("Unknown")
  end

  -- Update cost
  if reagentsPrice > 0 then
    local costText = GetCoinTextureString(reagentsPrice)
    if table.getn(reagentsPriceText) > 0 then
      costText = costText .. " + " .. table.concat(reagentsPriceText, " + ")
    end
    self.CostText:SetText(costText)
    self.CostHeadline:Show()
    self.CostText:Show()
  else
    self.CostHeadline:Hide()
    self.CostText:Hide()
  end

  -- Update vendor
  if table.getn(reagentsFromVendor) > 0 then
    local vendorText = table.concat(reagentsFromVendor, " ")
    self.VendorText:SetText(vendorText)
    self.VendorHeadline:Show()
    self.VendorText:Show()
  else
    self.VendorHeadline:Hide()
    self.VendorText:Hide()
  end

  self:Show()
  debug_print("UpdateCraftingProfit done")
end

-- Updates the crafting profit without knowing the current recipeID
local function UpdateCraftingProfitCurrentSelection()
  debug_print("UpdateCraftingProfitCurrentSelection")
  if TradeSkillFrame then
    CraftingProfitFrame:UpdateCraftingProfit(TradeSkillFrame.RecipeList:GetSelectedRecipeID())
  end
  debug_print("UpdateCraftingProfitCurrentSelection done")
end

function CraftingProfitMixin:OnLoad()
  debug_print("CraftingProfit OnLoad")
  self:SetParent(TradeSkillFrame.DetailsFrame.Contents)
  self:SetPoint("TOPLEFT", TradeSkillFrame.DetailsFrame.Contents, "BOTTOMLEFT", 5, -5)

  Atr_RegisterFor_DBupdated(UpdateCraftingProfitCurrentSelection)

  hooksecurefunc(TradeSkillFrame.RecipeList, "SetSelectedRecipeID", function(_, recipeID)
      self:UpdateCraftingProfit(recipeID)
    end)
  debug_print("CraftingProfit Loaded")
end
