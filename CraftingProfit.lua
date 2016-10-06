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
  if CraftingProfitDebug then
    print(...)
  end
end

-- Use slash to toggle debug mode. Note: addon needs to be loaded first!
SLASH_CRAFTINGPROFIT1 = "/craftingprofit"
function SlashCmdList.CRAFTINGPROFIT(msg, editbox)
  if CraftingProfitDebug then
    CraftingProfitDebug = false
    print("CraftingProfit debug_print disabled")
  else
    CraftingProfitDebug = true
    print("CraftingProfit debug_print enabled")
  end
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

-- Gets the name of the enchant scroll
local function GetEnchantScrollName(recipeInfo)
  local categoryInfo = C_TradeSkillUI.GetCategoryInfo(recipeInfo.categoryID)
  if not categoryInfo then
    debug_print("GetEnchantScrollName", "No categoryInfo")
    return
  end
  local enchantType = categoryInfo.name:match("%w+")
  if enchantType == "Glove" then
    enchantType = "Gloves"
  end
  return "Enchant " .. enchantType .. " - " .. recipeInfo.name
end

-- Checks if all items in the recipe has been loaded
local function RecipeLoaded(recipeID)
  local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
  if not recipeInfo then
    debug_print("RecipeLoaded", "No recipeInfo")
    return false
  end
  debug_print("RecipeLoaded", recipeInfo.name, recipeInfo.alternateVerb)
  local itemLink = C_TradeSkillUI.GetRecipeItemLink(recipeID)
  if not itemLink then
    debug_print("RecipeLoaded", "No itemLink")
    return false
  end

  -- Keep going until GetItemInfo has been called for all reagents
  local foundAll = true
  if recipeInfo.alternateVerb ~= "Enchant" then
    -- Enchants are a bit special since they don't have an item
    local itemName = GetItemInfo(itemLink)
    foundAll = foundAll and itemName ~= nil
  end

  local numReagents = C_TradeSkillUI.GetRecipeNumReagents(recipeID)
  for i = 1, numReagents do
    local reagentName, _, _ = C_TradeSkillUI.GetRecipeReagentInfo(recipeID, i)
    foundAll = foundAll and reagentName ~= nil
  end
  debug_print("RecipeLoaded", foundAll)
  return foundAll
end

-- Returns the crafting profit as text
local function GetCraftingProfit(recipeID)
  local profitTextRed = false
  local profitText = "Unknown"
  local costText = "Unknown"
  local vendorText
  local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
  if not recipeInfo then
    debug_print("GetCraftingProfit", "No recipeInfo")
    return profitTextRed, profitText, costText, vendorText
  end
  debug_print("GetCraftingProfit", recipeInfo.name, recipeInfo.alternateVerb)

  local numItemsProduced = C_TradeSkillUI.GetRecipeNumItemsProduced(recipeID)
  local numReagents = C_TradeSkillUI.GetRecipeNumReagents(recipeID)
  local reagentsPrice = 0
  local reagentsPriceText = {}
  local reagentsFromVendor = {}
  debug_print("GetCraftingProfit", "numItemsProduced", numItemsProduced, "numReagents", numReagents)

  local itemName
  if recipeInfo.alternateVerb == "Enchant" then
    -- Enchants are a bit special since they don't have an item
    numItemsProduced = 1
    itemName = GetEnchantScrollName(recipeInfo)
    -- Most newer seems to be 625 c at a vendor others 1000 c
    itemSellPrice = 625
  else
    local itemLink = C_TradeSkillUI.GetRecipeItemLink(recipeID)
    if not itemLink then
      debug_print("GetCraftingProfit", "No itemLink")
      return profitTextRed, profitText, costText, vendorText
    end
    _, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemLink)
    itemName = recipeInfo.name
  end

  local itemAuctionPrice
  if itemName then
    itemAuctionPrice = Atr_GetAuctionPrice(itemName) -- Cannot use Atr_GetAuctionBuyout since it crashes with enchants
  end
  debug_print("GetCraftingProfit", itemName, "itemAuctionPrice", itemAuctionPrice, "itemSellPrice", itemSellPrice)

  for i = 1, numReagents do
    local reagentName, reagentTexture, reagentCount = C_TradeSkillUI.GetRecipeReagentInfo(recipeID, i)
    if not reagentName then
      debug_print("GetCraftingProfit", "No reagentName")
      return profitTextRed, profitText, costText, vendorText
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
  debug_print("GetCraftingProfit", "reagentsPrice", reagentsPrice)

  local profit
  if itemAuctionPrice and itemSellPrice and reagentsPrice > 0 then
    -- We have a auction price and at least one reagent price
    local deposit = math.max(100, math.floor(0.15 * itemSellPrice))
    local cut = math.floor(0.05 * itemAuctionPrice)
    profit = numItemsProduced * (itemAuctionPrice - deposit - cut) - reagentsPrice
  end
  debug_print("GetCraftingProfit", "profit", profit)

  -- Update profit
  if profit then
    profitText = GetCoinTextureString(math.abs(profit))
    if profit > 0 then
      if table.getn(reagentsPriceText) > 0 then
        profitText = profitText .. " - " .. table.concat(reagentsPriceText, " - ")
      end
    else
      profitTextRed = true
      if table.getn(reagentsPriceText) > 0 then
        profitText = profitText .. " + " .. table.concat(reagentsPriceText, " + ")
      end
    end
  end

  -- Update cost
  if reagentsPrice > 0 then
    costText = GetCoinTextureString(reagentsPrice)
    if table.getn(reagentsPriceText) > 0 then
      costText = costText .. " + " .. table.concat(reagentsPriceText, " + ")
    end
  end

  -- Update vendor
  if table.getn(reagentsFromVendor) > 0 then
    vendorText = table.concat(reagentsFromVendor, " ")
  end

  return profitTextRed, profitText, costText, vendorText
end

-- Updates the crafting profit information for the given recipeID
function CraftingProfitMixin:UpdateCraftingProfit(recipeID, callback)
  debug_print("UpdateCraftingProfit", recipeID, callback)
  self:Hide()
  if not recipeID then
    return
  end
  if RecipeLoaded(recipeID) then
    profitTextRed, profitText, costText, vendorText = GetCraftingProfit(recipeID)
    if profitTextRed then
      self.ProfitText:SetFontObject("GameFontRed")
    else
      self.ProfitText:SetFontObject("GameFontHighlight")
    end
    self.ProfitText:SetText(profitText)
    self.CostText:SetText(costText)
    if vendorText then
      self.VendorText:SetText(vendorText)
      self.VendorHeadline:Show()
      self.VendorText:Show()
    else
      self.VendorHeadline:Hide()
      self.VendorText:Hide()
    end
    self:Show()
    debug_print("UpdateCraftingProfit done")
  else
    if not callback then
      -- Limit callback to one try
      debug_print("UpdateCraftingProfit", "trying again...")
      C_Timer.After(0.1, function() self:UpdateCraftingProfit(recipeID, true) end)
    else
      debug_print("UpdateCraftingProfit", "already tried :(")
    end
  end
end

-- Updates the crafting profit without knowing the current recipeID
local function UpdateCraftingProfitCurrentSelection()
  debug_print("UpdateCraftingProfitCurrentSelection")
  if TradeSkillFrame and TradeSkillFrame:IsShown() then
    CraftingProfitFrame:UpdateCraftingProfit(TradeSkillFrame.RecipeList:GetSelectedRecipeID())
  end
  debug_print("UpdateCraftingProfitCurrentSelection done")
end

function CraftingProfitMixin:Load()
  debug_print("CraftingProfit load")
  self:SetParent(TradeSkillFrame.DetailsFrame.Contents)
  self:SetPoint("TOPLEFT", TradeSkillFrame.DetailsFrame.Contents, "BOTTOMLEFT", 5, -5)

  Atr_RegisterFor_DBupdated(UpdateCraftingProfitCurrentSelection)

  hooksecurefunc(TradeSkillFrame.RecipeList, "SetSelectedRecipeID", function(_, recipeID)
      self:UpdateCraftingProfit(recipeID)
    end)
  debug_print("CraftingProfit loaded")
end

function CraftingProfitMixin:OnEvent(event, addon)
  if event == "ADDON_LOADED" and addon == "Blizzard_TradeSkillUI" then
    debug_print("CraftingProfit", "Blizzard_TradeSkillUI loaded")
    self:Load()
  end
end

function CraftingProfitMixin:OnLoad()
  debug_print("CraftingProfit", "OnLoad")
  self:RegisterEvent("ADDON_LOADED")
end
