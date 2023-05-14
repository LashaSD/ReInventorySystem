-- Services 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Libs
local InventoryHandler = require(ReplicatedStorage.Common:WaitForChild("InventoryHandler"))
local Item = require(ReplicatedStorage.Common:WaitForChild("InventoryItem"))

-- Directories
local ClientEvents = ReplicatedStorage.Common.Events

-- Events
local GetData = ClientEvents:WaitForChild("GetStorageData")
local StorageUnitActions = ClientEvents:WaitForChild("StorageUnit")


local StorageUnit = {}
StorageUnit.__index = StorageUnit

function StorageUnit.new(p_StorageData)
    local self = setmetatable(p_StorageData, StorageUnit)
    self.User = p_StorageData.User or nil
    self.Items = p_StorageData.Items or {} -- Dictionary<ItemId, ItemData>
    self.AuthorizationData = nil

    -- p_StorageData includes: Width, Height, Id

    return self
end 

function StorageUnit:InsertItem(ItemData)
    print("Item Added To Storage ITEMID: ".. ItemData.Id)
    self.Items[tostring(ItemData.Id)] = ItemData
end 

function StorageUnit:RemoveItem(ItemId)
    print("Item Removed From Storage ITEMID: ".. ItemId)
    local itemData = self.Items[tostring(ItemId)]
    self.Items[tostring(ItemId)] = nil
    return itemData
end 

function StorageUnit:GetData()
    local Data = {}
    Data.User = self.User
    Data.Id = self.Id
    Data.Width = self.Width
    Data.Height = self.Height
    Data.Items = self.Items
    Data.AuthorizationData = self.AuthorizationData
    return Data
end 

function StorageUnit:Authorize(Player) 
    if self.User then return false end

    if RunService:IsServer() and self.AuthorizationData == 'deauthorize' then
        self.AuthorizationData = nil
    end

    self.User = Player.UserId
    return true
end 

function StorageUnit:Deauthorize()
    self.User = nil
    if RunService:IsClient() then
        self:ClearUI()
        StorageUnitActions:FireServer('deauthorize', self.Id)
    else 
        self.AuthorizationData = 'deauthorize'
    end
end

-- Generates the Storage Unit Grid in the Player Inventory UI 
---@return nil
function StorageUnit:GenerateUI(PlayerInventory) 
    if game.Players.LocalPlayer.UserId ~= self.User then return end
    -- GRID UI
    local InventoryUi = game.Players.LocalPlayer.PlayerGui.Inventory.MainFrame.GridMainFrame
    local StorageData = InventoryHandler.GenerateStorageData(self.Width, self.Height, nil, self.Id)
    local FrameDir = InventoryUi.c.c
    StorageData = PlayerInventory:GenerateStorage(StorageData, FrameDir)
    -- ITEM UI

    for id, data in pairs(self.Items) do
        local itemData = PlayerInventory:GenerateItemData(StorageData, nil, nil, data.Id)
        itemData.Item = ReplicatedStorage.Items:FindFirstChild(data.Name):Clone()
        itemData.StorageData = StorageData
        itemData.TileX = data.TileX
        itemData.TileY = data.TileY
        local Item1 = Item.new(itemData):Init()
    end
end

--- Deletes The Storage Unit Grid in the Player Inventory UI
---@return nil
function StorageUnit:ClearUI()
    local InventoryUi = game.Players.LocalPlayer.PlayerGui.Inventory.MainFrame.GridMainFrame
    local StorageData = InventoryHandler.GenerateStorageData(self.Width, self.Height, nil, self.Id)
    local FrameDir = InventoryUi.c.c
    for _, Child in ipairs(FrameDir:GetChildren()) do
        if Child:IsA("Frame") and Child.Name ~= "InvisibleFrame" then Child:Destroy() end
    end
end


return StorageUnit