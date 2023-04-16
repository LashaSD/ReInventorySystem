local Storages = {}

local StorageIndex = 0

local InventoryHandler = {}

local TileSize -- Both Width and height since tiles are just squares

--[[
    Generate inventory with the given Width and Height (in tiles)
]]--

function InventoryHandler.GetDataFromStorage(Storage)
	for i = 0, #Storages, 1 do
		local CurrentStorageData = Storages[i]
		if CurrentStorageData.Storage == Storage then
            return CurrentStorageData;
        end
	end
end

function InventoryHandler.GenerateStorage(Frame, Width, Height, Type)
    local Tile = script.Parent:WaitForChild("Tile")
	TileSize = Tile.Size.X.Offset

	local Storage = nil;
	if Type then
		Storage = Frame.Parent
		Storage.Size = UDim2.new(0, TileSize * Width, 0, TileSize * Height)
	else
		Storage = script.Parent:WaitForChild("Storage"):Clone()
		Storage.Parent = Frame
		Storage.Size = UDim2.new(0, TileSize * Width, 0, TileSize * Height)
	end

	local data = InventoryHandler.GenerateStorageData(Width, Height)
	data.Storage = Storage
	data.Type = Type or nil

	Storages[StorageIndex] = data
	StorageIndex = StorageIndex + 1

	for x = 0, Width-1 do
		for y = 0, Height-1 do
			local TileClone = Tile:Clone()
			TileClone.Parent = Storage
			TileClone.Position = UDim2.new(0, x * TileSize, 0, y * TileSize)
		end
	end
	
	Storage.MouseEnter:Connect(function(x, y)
		game.ReplicatedStorage.Common.Events.StorageEnter:Fire(Storage, x, y)
	end)

    return data;
end

function InventoryHandler.GenerateStorageData(Width, Height)
	local data = {}
	data.Storage = nil
	data.Tiles = {}
	data.Items = {}

	for x = 0, Width-1 do
		local YTable = {}
		data.Tiles[x] = YTable
		for y = 0, Height-1 do
			data.Tiles[x][y] = {
				["Claimed"] = false,
				["Owner"] = nil,
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

	return data
end

function InventoryHandler.GenerateInventory()
	local InventoryData = {}
	local storages = {}
	local ItemList = {}
	InventoryData.Storages = storages
	InventoryData.ItemList = ItemList
	return InventoryData
end 

return InventoryHandler

