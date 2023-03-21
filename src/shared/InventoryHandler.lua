local Storages = {}

local StorageIndex = 0

local InventoryHandler = {}

local TileSize -- Both Width and height since tiles are just squares

--[[ 
    Generate inventory with the given Width and Height (in tiles)
]]--

function InventoryHandler.GetStorageFromPosition(Pos)
	for i = 0, #Storages, 1 do 
		local storage = Storages[i].Storage
		local XFit = storage.AbsolutePosition.X < Pos.X and storage.AbsolutePosition.X + storage.AbsoluteSize.X > Pos.X -- item fits into the inventory on the X axis
		local YFit = storage.AbsolutePosition.Y > Pos.Y and storage.AbsolutePosition.Y + storage.AbsoluteSize.Y < Pos.Y -- item fits into the inventory on the Y axis
		if XFit and YFit then 
			return Storages[i]
		end
	end
end 

function InventoryHandler.GetDataFromStorage(Storage)
	for i = 0, #Storages, 1 do 
		local CurrentStorageData = Storages[i]
		if CurrentStorageData.Storage == Storage then
            return CurrentStorageData;
        end
	end
end

function InventoryHandler.GenerateInventory(Parent, Width, Height, Name)
    local Tile = script:WaitForChild("Tile")
	local Storage = script:WaitForChild("Storage"):Clone()
	TileSize = Tile.Size.X.Offset

	local Name = Name or "Storage"

	Storage.Size = UDim2.new(0, TileSize * Width, 0, TileSize * Height)
    Storage.Parent = Parent
	Storage.Name = Name
	
	local OnNewStorage = Instance.new("BindableEvent")

	local data = {}
	data.Storage = Storage
	data.Tiles = {}
	data.OnStorageHover = OnNewStorage 
	
	Storages[StorageIndex] = data
	StorageIndex = StorageIndex + 1
	
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

	Storage.MouseEnter:Connect(function()
		OnNewStorage:Fire(data)
	end)

    return data;
end 

return InventoryHandler

