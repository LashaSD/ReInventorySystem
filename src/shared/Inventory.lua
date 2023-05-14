local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemMod = require(ReplicatedStorage.Common:WaitForChild("InventoryItem"))
local InventoryHandler = require(ReplicatedStorage.Common:WaitForChild("InventoryHandler"))

local Inventory = {}
Inventory.__index = Inventory

function Inventory.new()
	local self = setmetatable({}, Inventory)
	self.Storages = {}
	self.Queue = {} -- Array< Array< StorageData, Array<ItemData> > >
	self.RemovalQueue = {}
	self.Items = {} -- Array<ItemData>
	self.StorageUnit = nil -- <StorageUnit>
	self.TileSize = nil

	return self
end

function Inventory:GenerateQueue()
	local InventoryUi = game.Players.LocalPlayer.PlayerGui.Inventory.MainFrame.GridMainFrame
	for i = 1, #self.Queue do
		local Data = self.Queue[i]
		local StorageData = InventoryHandler.GenerateStorageData(Data[1].Width, Data[1].Height, Data[1].Type, Data[1].Id)
		local FrameDir = StorageData.Type and InventoryUi.a.a or InventoryUi.b.b
		local Frame = StorageData.Type and FrameDir:FindFirstChild(StorageData.Type) or FrameDir
		if Frame then
			local NewStorageData = self:GenerateStorage(StorageData, Frame)
			-- generate all the items 
			local ItemQueue = Data[2]
			if ItemQueue then
				for _, ItemData in ipairs(ItemQueue) do
					ItemData.StorageData = NewStorageData
					ItemData.Item = ReplicatedStorage.Items:FindFirstChild(ItemData.Item):Clone()
					ItemData.Type = ItemData.Item:GetAttribute("Type")
					local Item = ItemMod.new(ItemData):Init()
					table.insert(self.Items, Item)
				end
			end
		end
		i = i - 1
	end
	self.Queue = {}
end

function Inventory:EmptyRemovalQueue() 
	for i = 1, #self.RemovalQueue do
		local removalId = self.RemovalQueue[i]
		-- find the storage with given id 
		for Index, Storage in ipairs(self.Storages) do
			if Storage.Id == removalId then
				table.remove(self.Storages, Index)
				Storage.Storage:Destroy()
				return
			end
		end
	end
	self.RemovalQueue = {}
end 

function Inventory:GenerateStorage(Data, Frame)
	-- get tile data
    local Tile = script.Parent:WaitForChild("Tile")
	self.TileSize = Tile.Size.X.Offset

	local Width = #Data.Tiles + 1
	local Height = #Data.Tiles[1] + 1


	-- check for storage type and get storage
	local Storage = nil;
	if Data.Type then
		Storage = Frame
		Storage.Size = UDim2.new(0, self.TileSize * Width, 0, self.TileSize * Height)
	else
		Storage = script.Parent:WaitForChild("Storage"):Clone()
		Storage.Parent = Frame
		Storage.Size = UDim2.new(0, self.TileSize * Width, 0, self.TileSize * Height)
	end

	-- storage data
	Data.Storage = Storage

	-- Generate the tiles at their Positions
	for x = 0, Width-1 do
		for y = 0, Height-1 do
			local TileClone = Tile:Clone()
			TileClone.Parent = Storage
			TileClone.Position = UDim2.new(0, x * self.TileSize, 0, y * self.TileSize)
		end
	end

	Storage.MouseEnter:Connect(function()
		_G.Cache = Data
		game.ReplicatedStorage.Common.Events.StorageEnter:Fire(Storage)
	end)

	table.insert(self.Storages, Data)
    return Data;
end

function Inventory:GenerateItemData(p_StorageData, p_Item, p_Id) 
	if not p_Id or not p_StorageData then return nil end 
	local Data = {}
	Data.Storage = p_StorageData
	Data.Id = tostring(p_Id)
	Data.Item = p_Item or nil
	Data.TileX = nil 
	Data.TileY = nil
	self.Items[Data.Id] = Data
	return Data
end 

return Inventory