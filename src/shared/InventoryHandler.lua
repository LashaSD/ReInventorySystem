local Inventory = {}
Inventory.__index = Inventory 

function Inventory.new()
	local self = setmetatable({}, Inventory)
	self.Storages = {}
	self.StorageQueue = {}
	self.Items = {}
	self.TileSize = nil

	return self
end 

function Inventory:GenerateStoragesQueue()
	local InventoryUi = game.Players.LocalPlayer.PlayerGui.Inventory.MainFrame.GridMainFrame
	for Index,Data in ipairs(self.StorageQueue) do 
		local FrameDir = Data.Type and InventoryUi.a or InventoryUi.b
		local Frame = Data.Type and FrameDir:FindFirstChild(Data.Type) or FrameDir 
		if Frame then
			self:GenerateStorage(Data, Frame)
		end 
		-- table.remove(self.StorageQueue, Index)
	end 
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

function Inventory:GenerateStorageData(Width, Height, Type)
	local data = {}
	data.Storage = nil
	data.Type = Type or nil
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

	data.Trim = function()
		-- data.ParentInventory = nil
		return data
	end 

	return data
end

function Inventory:GetDataFromStorage(Storage)
	for i = 1, #self.Storages, 1 do
		local CurrentStorageData = self.Storages[i]
		if CurrentStorageData.Storage == Storage then
            return CurrentStorageData;
        end
	end
end

function Inventory:AppendToQueue(StorageData) 
	table.insert(self.StorageQueue, Data)
	return StorageData
end 

function Inventory:AppendArrayToQueue(StorageDataArray)
	for Index, Data in ipairs(StorageDataArray) do 
		table.insert(self.StorageQueue, Data)
	end
	return StorageData
end 
return Inventory













