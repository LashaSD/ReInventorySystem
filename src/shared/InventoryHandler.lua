local InventoryHandler = {}

-- Utility

InventoryHandler.GetDataFromStorage = function(Inventory, Storage)
    for i = 1, #Inventory.Storages, 1 do
		local CurrentStorageData = Inventory.Storages[i]
		if CurrentStorageData.Storage == Storage then
            return CurrentStorageData;
        end
	end
end

InventoryHandler.AppendStorageToQueue = function(Inv, StorageData)
	local Data = {StorageData}
	table.insert(Inv.Queue, Data)
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

-- Data

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
	
	return data
end


return InventoryHandler