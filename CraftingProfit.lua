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

local profitTextHeadline
local profitTextDetails

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
local function UpdateCraftingProfit(recipeID)
  local itemLink = C_TradeSkillUI.GetRecipeItemLink(recipeID)
  local numItemsProduced = C_TradeSkillUI.GetRecipeNumItemsProduced(recipeID)
  local itemName, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemLink)
  local itemAuctionPrice = Atr_GetAuctionPrice(itemName) -- Cannot use Atr_GetAuctionBuyout since it crashes with enchants
  local reagentsPrice = 0
  local reagentsPriceText = {}
  local reagentsFromVendor = {}
  local numReagents = C_TradeSkillUI.GetRecipeNumReagents(recipeID)

  for i = 1, numReagents do
    local reagentName, _, reagentCount = C_TradeSkillUI.GetRecipeReagentInfo(recipeID, i)
    local reagentPrice, reagentFromVendor = GetReagentPrice(reagentName)
    if reagentPrice then
      reagentsPrice = reagentsPrice + reagentPrice * reagentCount
      if reagentFromVendor then
        table.insert(reagentsFromVendor, reagentName)
      end
    else
      -- Add text description when the price is unknown
      table.insert(reagentsPriceText, reagentCount .. "x" .. reagentName)
    end
  end

  local profitText
  local headline
  if itemAuctionPrice and reagentsPrice > 0 then
    -- We have a auction price and at least one reagent price
    local deposit = math.max(100, math.floor(0.15 * itemSellPrice))
    local cut = math.floor(0.05 * itemAuctionPrice)
    local profit = numItemsProduced * (itemAuctionPrice - deposit - cut) - reagentsPrice
    if profit > 0 then
      headline = "Profit:"
      profitText = GetCoinTextureString(math.abs(profit))
      if table.getn(reagentsPriceText) > 0 then
        profitText = profitText .. " - " .. table.concat(reagentsPriceText, " - ")
      end
    else
      headline = "Waste:"
      profitText = GetCoinTextureString(math.abs(profit))
      if table.getn(reagentsPriceText) > 0 then
        profitText = profitText .. " + " .. table.concat(reagentsPriceText, " + ")
      end
    end
  elseif reagentsPrice > 0 then
    -- At least one reagent price
    headline = "Costs:"
    profitText = GetCoinTextureString(reagentsPrice)
    if table.getn(reagentsPriceText) > 0 then
      profitText = profitText .. " + " .. table.concat(reagentsPriceText, " + ")
    end
  else
    headline = "Profit:"
    profitText = "Unknown"
  end

  if table.getn(reagentsFromVendor) > 0 then
    profitText = profitText .. "\n\nVendor: " .. table.concat(reagentsFromVendor, ", ")
  end

  profitTextHeadline:SetText(headline)
  profitTextDetails:SetText(profitText)
end

-- Updates the crafting profit without knowing the current recipeID
local function UpdateCraftingProfitCurrentSelection()
  if TradeSkillFrame then
    UpdateCraftingProfit(TradeSkillFrame.RecipeList:GetSelectedRecipeID())
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
    if addon == "Blizzard_TradeSkillUI" then
      -- Initialize after the TradeSkillUI has loaded
      Atr_RegisterFor_DBupdated(UpdateCraftingProfitCurrentSelection)
      profitTextHeadline = TradeSkillFrame.DetailsFrame.Contents:CreateFontString("CraftingProfitTextHeadline", "BACKGROUND", "GameFontNormal")
      profitTextDetails = TradeSkillFrame.DetailsFrame.Contents:CreateFontString("CraftingProfitTextDetails", "BACKGROUND", "GameFontHighlight")
      profitTextHeadline:SetPoint("TOPLEFT", TradeSkillFrame.DetailsFrame.Contents, "BOTTOMLEFT", 5, -5)
      profitTextDetails:SetPoint("TOPLEFT", profitTextHeadline, "BOTTOMLEFT", 0, -5)
      profitTextDetails:SetWidth(290)
      profitTextDetails:SetJustifyH("LEFT")
      profitTextHeadline:SetJustifyH("LEFT")

      hooksecurefunc(TradeSkillFrame.RecipeList, "SetSelectedRecipeID", function(self, recipeID)
          UpdateCraftingProfit(recipeID)
        end)
    end
  end)
