-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Libs

-- Events 

local InventoryHandler = {}

-- Utility

InventoryHandler.AppendStorageToQueue = function(Inv, StorageData)
	local Data = {StorageData} -- convert to table to add items inside later
	table.insert(Inv.Queue, Data)
	if RunService:IsServer() and StorageData.Id then
		table.insert(Inv.Storages, StorageData)
	end	
	return StorageData
end

InventoryHandler.AppendStorageArrayToQueue = function(Inv, StorageDataArray)
	for Index, Data in ipairs(StorageDataArray) do
		InventoryHandler.AppendStorageToQueue(Inv, Data)
	end
end

InventoryHandler.AppendItemToQueue = function(Inv, ItemData)
	-- find the location of storage data in the queue
	for _, v in ipairs(Inv.Queue) do
		if v[1] == ItemData.Storage then
			if not v[2] then
				v[2] = {}
			end
			table.insert(v[2], ItemData)
 		end
	end
end

InventoryHandler.AppendItemArrayToQueue = function(Inv, ItemDataArray)
	for _, Data in ipairs(ItemDataArray) do
		InventoryHandler.AppendItemToQueue(Inv, Data)
	end
end

InventoryHandler.AppendStorageToRemovalQueue = function(Inv, StorageId)
	table.insert(Inv.RemovalQueue, StorageId)
end

function InventoryHandler.CheckFreeSpace(StorageData, Width, Height)
	for Y = 0, #StorageData.Tiles[0] - Height + 1 do
		local xTiles = StorageData.Tiles
		for X = 0, #xTiles - Width + 1 do
			for i = X, X + Width -1 do
				local bool = false
				for j = Y, Y + Height -1 do
					if StorageData.Tiles[i][j]["Claimed"] then
						bool = true
						break
					end
					if i == X + Width - 1 and j == Y + Height - 1 then
						return X, Y
					end 
				end
				if bool then break end
			end
		end
	end
end 

function InventoryHandler.CheckFreeSpaceInventoryWide(Inv, Width, Height)
	local storages = Inv.Storages
	for _, data in ipairs(storages) do
		local x, y = InventoryHandler.CheckFreeSpace(data, Width, Height)
		if x and y then return data,x,y end
	end
end 	

-- Data Generation

function InventoryHandler.GenerateStorageUnitData(p_Width, p_Height, p_Id, p_Accessible)
	if not p_Id or not p_Width or not p_Height then return nil end
	local data = {}
	data.Width = p_Width
	data.Height = p_Height
	data.Id = p_Id
	data.Accessible = p_Accessible or nil
	return data
end

function InventoryHandler.GenerateStorageData(Width, Height, Type, Id)
	local data = {}
	data.Storage = nil
	data.Type = Type or nil
	data.Id = Id or nil
	data.Width = Width
	data.Height = Height
	
	data.Tiles = {}

	for x = 0, Width-1 do
		local YTable = {}
		data.Tiles[x] = YTable
		for y = 0, Height-1 do
			data.Tiles[x][y] = {
				["Claimed"] = false,
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
		for i=X, X + Width -1 do
			for j=Y, Y+Height -1  do
				data.UnclaimTile(i,j)
			end
		end
	end

	-- might be useful later
	data.Trim = function()
		-- data.ParentInventory = nil
		return data
	end
	
	return data
end

-- Modified Function for generating Storage Units
function InventoryHandler:GenerateStorage(Data, Frame)
	-- get tile data
    local Tile = ReplicatedStorage.Common:WaitForChild("Tile")
	local TileSize = Tile.Size.X.Offset

	local Width = #Data.Tiles +1
	local Height = #Data.Tiles[1] +1

	-- check for storage type and get storage
	local Storage = script.Parent:WaitForChild("Storage"):Clone()
	local InvisibleFrame = Frame:FindFirstChild("InvisibleFrame1")
	local clone = InvisibleFrame:Clone()
	InvisibleFrame:Destroy()
	Storage.Parent = Frame
	clone.Parent = Frame
	Storage.Size = UDim2.new(0, self.TileSize * Width, 0, self.TileSize * Height)

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

	Storage.MouseEnter:Connect(function(x, y)
		game.ReplicatedStorage.Common.Events.StorageEnter:Fire(Storage, x, y)
	end)

	table.insert(self.Storages, Data)
    return Data;
end

return InventoryHandler