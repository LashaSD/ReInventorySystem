-- Services 
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Libs
local InventoryHandler = require(ReplicatedStorage.Common:WaitForChild("InventoryHandler"))

local StorageUnit = {}
StorageUnit.__index = StorageUnit

function StorageUnit.new(p_StorageData)
    p_StorageData = p_StorageData or {}
    local self = setmetatable(p_StorageData, StorageUnit)
    self.User = nil
    self.Items = {} -- Dictionary<ItemId, ItemData>

    -- p_StorageData includes: Width, Height, Id

    return self
end 

function StorageUnit:InsertItem(ItemData)
    print("Item Added To Storage ITEMID: " + ItemData.Id)
end 

function StorageUnit:RemoveItem(ItemData)
    print("Item Removed From Storage ITEMID: " + ItemData.Id)
end 

function StorageUnit:RetrieveItemData(ItemId)
    if self.Items[ItemId] then return self.Items[ItemId] end
end 

function StorageUnit:Authorize(Player) 
    if self.User then return false end 
    self.User = Player
    return true
end 

function StorageUnit:Deauthorize()
    self:ClearUI()
    self.User = nil
end

function StorageUnit:GenerateUi()
    print("Player Ui Updated")
end 

function StorageUnit:ClearUI()

end


return StorageUnit