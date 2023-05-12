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
	self.TileSize = nil

	return self
end

function Inventory:GenerateQueue()
	local InventoryUi = game.Players.LocalPlayer.PlayerGui.Inventory.MainFrame.GridMainFrame
	for i = 1, #self.Queue do
		local Data = self.Queue[i]
		local StorageData = InventoryHandler.GenerateStorageData(Data[1][1], Data[1][2], Data[1][3], Data[1][4])
		local FrameDir = StorageData.Type and InventoryUi.a.a or InventoryUi.b.b
		local Frame = StorageData.Type and FrameDir:FindFirstChild(StorageData.Type) or FrameDir
		if Frame then
			local NewStorageData = self:GenerateStorage(StorageData, Frame)
			-- generate all the items 
			local ItemQueue = Data[2]
			if ItemQueue then
				for _, ItemData in ipairs(ItemQueue) do
					ItemData.StorageData = NewStorageData
					ItemData.Item = ReplicatedStorage.Items:FindFirstChild(ItemData.Item)
					local Item = ItemMod.new(ItemData, 0, 0):Init()
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
			if Storage.Id and Storage.Id == removalId then
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

	local Width = #Data.Tiles +1
	local Height = #Data.Tiles[1] +1

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
	Data.ParentInventory = self

	-- Generate the tiles at their Positions
	for x = 0, Width-1 do
		for y = 0, Height-1 do
			local TileClone = Tile:Clone()
			TileClone.Parent = Storage
			TileClone.Position = UDim2.new(0, x * self.TileSize, 0, y * self.TileSize)
		end
	end

	Storage.MouseEnter:Connect(function(x, y)
		game.ReplicatedStorage.Common.Events.StorageEnter:Fire(Storage, x, y)
	end)

	table.insert(self.Storages, Data)
    return Data;
end

function Inventory:GenerateItemData(p_StorageData, p_Type, p_Item, p_Id) 
	local Data = {}
	Data.Storage = p_StorageData
	Data.Type = p_Type or nil
	Data.Item = p_Item or nil
	Data.Id = p_Id or nil
	table.insert(self.Items, Data)
	return Data
end 

function Inventory:GetDataFromStorage(Storage)
	for i = 1, #self.Storages, 1 do
		local CurrentStorageData = self.Storages[i]
		if CurrentStorageData.Storage == Storage then
            return CurrentStorageData;
        end
	end
end

function Inventory:AppendStorageToQueue(StorageData)
	local Data = {StorageData}
	table.insert(self.Queue, Data)
	return StorageData
end

function Inventory:AppendStorageArrayToQueue(StorageDataArray)
	for Index, Data in ipairs(StorageDataArray) do
		self:AppendStorageToQueue(Data)
	end
end

function Inventory:AppendItemToQueue(ItemData)
	-- find the location of storage data in the queue
	for _, v in ipairs(self.Queue) do
		if v[1] == ItemData.Storage then
			if not v[2] then
				v[2] = {}
			end
			table.insert(v[2], ItemData)
 		end
	end
end

function Inventory:AppendArrayToItemQueue(ItemDataArray)
	for _, Data in ipairs(ItemDataArray) do
		self:AppendItemToQueue(Data)
	end
end

return Inventory













