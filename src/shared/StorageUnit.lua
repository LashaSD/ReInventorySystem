-- Services 
local DataStoreService = game:GetService("DataStoreService")
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


-- util functions

local function includes (tab, val1, val2)
    for index, value in ipairs(tab) do
        if value[1] == val1 and value[2] == val2 then
            return true
        end
    end

    return false
end

local StorageUnit = {}
StorageUnit.__index = StorageUnit

function StorageUnit.new(p_StorageData)
    local self = setmetatable(p_StorageData, StorageUnit)
    self.User = p_StorageData.User or nil
    self.Items = p_StorageData.Items or {} -- Dictionary<ItemId, ItemData>
    self.AuthorizationData = nil

    -- p_StorageData includes: Width, Height, Id, Accessible

    return self
end 

function StorageUnit:InsertItem(ItemData)
    if self.Accessible then
        print("Item Added To Storage ITEMID: ".. ItemData.Id)
        self.Items[tostring(ItemData.Id)] = ItemData
    else 
        print("Item Generated to the Storage Unit")
        self.Items['0'] = ItemData
    end
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
    local StorageData = InventoryHandler.GenerateStorageData(self.Width, self.Height, nil, self.Id, 'unit')
    local FrameDir = InventoryUi.c.c
    StorageData = PlayerInventory:GenerateStorage(StorageData, FrameDir)
    -- ITEM UI

    local Items = {}
    for id, data in pairs(self.Items) do
        local item = ReplicatedStorage.ItemFrames:FindFirstChild(data.Name):Clone()
        local itemData = PlayerInventory:GenerateItemData(StorageData, item.Name, data.Id)
        itemData.StorageData = StorageData
        itemData.Rotation = data.Rotation
        itemData.Offset = data.Offset
        itemData.Item = item
        if data.Rotation and data.Rotation % 180 ~= 0 then
            local width = item:GetAttribute("Width")
            local height = item:GetAttribute("Height")
            itemData.Item:SetAttribute("Width", height)
            itemData.Item:SetAttribute("Height", width)
        end
        local x, y = InventoryHandler.CheckFreeSpace(StorageData, item:GetAttribute("Width"), item:GetAttribute("Height"))
        if not x and not y then
            print("No More Space")
            break
        end
        itemData.TileX = data.TileX or x
        itemData.TileY = data.TileY or y
        self.Items[id].TileX = itemData.TileX
        self.Items[id].TileY = itemData.TileY
        Item.new(itemData):Init()
        table.insert(Items, self.Items[id])
    end

    local squares = InventoryHandler.EvaluateGridSquares(StorageData, Items)
    for x = 0, #StorageData.Tiles do
        for y = 0, #StorageData.Tiles[0] do
            local TileData = StorageData.Tiles[x][y]
            TileData.Claimed = includes(squares, x, y)
        end
    end
end

--- Deletes The Storage Unit Grid in the Player Inventory UI
---@return nil
function StorageUnit:ClearUI()
    local InventoryUi = game.Players.LocalPlayer.PlayerGui.Inventory.MainFrame.GridMainFrame
    local StorageData = InventoryHandler.GenerateStorageData(self.Width, self.Height, nil, self.Id)
    local FrameDir = InventoryUi.c.c
    for _, Child in ipairs(FrameDir:GetChildren()) do
        if Child:IsA("Frame") and Child.Name ~= "InvisibleFrame" and Child.Name ~= "InvisibleFrame1" then Child:Destroy() end
    end
end


return StorageUnit