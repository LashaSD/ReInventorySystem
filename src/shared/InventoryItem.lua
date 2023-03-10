local InventoryHandler = require(script.Parent.InventoryHandler)
local DragabbleItem = require(script.Parent:WaitForChild("DraggableObject"))
local RunService = game:GetService("RunService")

local TileSize = 48

local InventoryItem = {}
InventoryItem.__index = InventoryItem

function InventoryItem.new(Item, Storage, tileX, tileY)
	local self = setmetatable({}, InventoryItem)
	self.TileX = tileX or nil
	self.TileY = tileY or nil
	self.Item = Item
    self.StorageData = InventoryHandler.GetDataFromStorage(Storage)
    self.DragFrame = DragabbleItem.new(Item)
    self.OriginPosition = nil
	return self
end

function InventoryItem:Init()
	local width = self.Item:GetAttribute("Width")
	local height = self.Item:GetAttribute("Height")
    self.Item.Parent = self.StorageData.Storage
    self.Item.Size = UDim2.new(0, TileSize * width, 0, TileSize * height)
	self:ChangeLocationWithinStorage(self.TileX, self.TileY)
    self.DragFrame:Enable()
    self.DragFrame.DragEnded = function()
        print("DragEnded")
        self:CheckValidLocation()
    end 
end

function InventoryItem:CheckValidLocation() 
	local ItemPosition = self.Item.Position
	local tiles = self.StorageData.Tiles
	
	local MaxTilesX = #tiles
	local MaxTilesY = #tiles[0]

	local width = self.Item:GetAttribute("Width")
	local height = self.Item:GetAttribute("Height")

    local X = self.Item.Position.X.Offset
    local Y = self.Item.Position.Y.Offset

    local translateX = math.floor(X/TileSize)
    local translateY = math.floor(Y/TileSize)

    if translateX > MaxTilesX - width then translateX = (MaxTilesX - width) + 1 end
	if translateX < 0 then translateX = 0 end
    if translateY > MaxTilesY - height then translateY = (MaxTilesY - height) + 1 end
	if translateY < 0 then translateY = 0 end


    self:ChangeLocationWithinStorage(translateX, translateY)
end

function InventoryItem:ChangeLocationWithinStorage(tileX, tileY)
    local width = self.Item:GetAttribute("Width")
	local height = self.Item:GetAttribute("Height")
    self.StorageData.ClaimTiles(tileX, tileY, width, height, self.Item)
    self.Item.Position = UDim2.new(0, tileX * TileSize, 0, tileY * TileSize)
    self.OriginPosition = self.Item.Position
end


return InventoryItem
