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

function InventoryHandler.GenerateInventory(Parent, Width, Height)
    local Tile = script:WaitForChild("Tile")
	local Storage = script:WaitForChild("Storage"):Clone()
	TileSize = Tile.Size.X.Offset

	Storage.Size = UDim2.new(0, TileSize * Width, 0, TileSize * Height)
    Storage.Parent = Parent
	
	local data = {}
	data.Storage = Storage
	data.Tiles = {}
	
	Storages[StorageIndex] = data
	
	for x = 0, Width-1 do
		local YTable = {}
		data.Tiles[x] = YTable
		for y = 0, Height-1 do
			local TileClone = Tile:Clone()
			TileClone.Parent = Storage
			TileClone.Position = UDim2.new(0, x * TileSize, 0, y * TileSize)
			data.Tiles[x][y] = {
				["Claimed"] = false,
				["Owner"] = nil,
				["TileFrame"] = TileClone,
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

    return data;
end 

return InventoryHandler

