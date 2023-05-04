local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemMod = require(ReplicatedStorage.Common:WaitForChild("InventoryItem"))

local Inventory = {}
Inventory.__index = Inventory

function Inventory.new()
	local self = setmetatable({}, Inventory)
	self.Storages = {}
	self.Queue = {} -- { [1] = {StorageData, {ItemData, ItemData, ....}}, [2] = {StorageData, {ItemData, ItemData, .....}}}
	self.RemovalQueue = {}
	self.Items = {} -- Seperate List of Items 
	self.TileSize = nil

	return self
end

function Inventory:GenerateQueue()
	local InventoryUi = game.Players.LocalPlayer.PlayerGui.Inventory.MainFrame.GridMainFrame
	for i = 1, #self.Queue do
		local Data = self.Queue[i]
		local StorageData = self:GenerateStorageData(Data[1][1], Data[1][2], Data[1][3], Data[1][4])
		local FrameDir = StorageData.Type and InventoryUi.a or InventoryUi.b
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

	-- get storage data
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

    return Data;
end

function Inventory:GenerateStorageData(Width, Height, Type, Id)
	local data = {}
	data.Storage = nil
	data.Type = Type or nil
	data.Id = Id or nil
	data.Tiles = {}

	for x = 0, Width-1 do
		local YTable = {}
		data.Tiles[x] = YTable
		for y = 0, Height-1 do
			data.Tiles[x][y] = {
				["Claimed"] = false,
				-- ["Owner"] = nil,
				-- ["TileFrame"] = TileClone,
			}
		end
	end

	data.ClaimTile = function(TileX, TileY, Owner)
		data.Tiles[TileX][TileY]["Claimed"] = true
		data.Tiles[TileX][TileY]["Owner"] = Owner
	end

	data.UnclaimTile = function(TileX, TileY)
		data.Tiles[TileX][TileY]["Claimed"] = false
		data.Tiles[TileX][TileY]["Owner"] = nil
	end

	data.ClaimTiles = function(X, Y, Width, Height, Owner)
		for i=X, X + Width -1  do
			for j=Y, Y+Height -1 do
				data.ClaimTile(i,j,Owner)
			end
		end
	end

	data.UnclaimTiles = function(X, Y, Width, Height)
		for i=X, X + Width-1 do
			for j=Y, Y+Height-1 do
				data.UnclaimTile(i,j)
			end
		end
	end

	-- might be useful later
	data.Trim = function()
		-- data.ParentInventory = nil
		return data
	end
	
	table.insert(self.Storages, data)
	return data
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













