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
	if RunService:IsServer() then
		-- if it's a new storage and we're not rerendering an old one 
		local isOld = false
		for _, data in ipairs(Inv.Storages) do
			if data.Id == StorageData.Id then
				isOld = true
			end
		end
		if not isOld then
			table.insert(Inv.Storages, StorageData)
		end
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
	if RunService:IsServer() then
		for i, v in ipairs(Inv.Storages) do
			if v.Id == StorageId then
				table.remove(Inv.Storages, i)
				break
			end
		end
	end
end

InventoryHandler.AppendStorageArrayToRemovalQueue = function(Inv, Storages)
	for _, v in ipairs(Storages) do
		InventoryHandler.AppendStorageToRemovalQueue(Inv, v)
	end
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
		if data.Type then continue end
		local x, y = InventoryHandler.CheckFreeSpace(data, Width, Height)
		if x and y then return data,x,y end
	end
end 	

function InventoryHandler.EvaluateGridSquares(StorageData, Items)
	local takenSquares = {}
	for id, data in pairs(Items) do
		-- this item is in the desired storage 
		local itemFrame = ReplicatedStorage.ItemFrames:FindFirstChild(data.Item)
		if not itemFrame then continue end
		local width = itemFrame:GetAttribute("Width")
		local height = itemFrame:GetAttribute("Height")
		if data.Rotation % 180 ~= 0 then
			local i = width
			width = height
			height = i
		end
		for x = data.TileX, data.TileX + width -1 do
			for y = data.TileY, data.TileY + height -1 do
				table.insert(takenSquares, {x, y})
			end
		end
	end

	return takenSquares
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

function InventoryHandler.GenerateStorageData(Width, Height, Type, Id, StarterTag)
	if not Id then print("Id is required to generate storage data"); return nil end
	local data = {}
	data.Storage = nil
	data.Type = Type or nil
	data.EquippedSlot = nil -- only for storages with Type
	data.Id = Id or nil
	data.Width = Width
	data.Height = Height
	data.Starter = StarterTag or false
	
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

function InventoryHandler.GenerateItemData(Inventory, p_StorageData, p_Item, p_Id)
	if not p_Id or not p_StorageData then return nil end
	local Data = {}
	Data.Storage = p_StorageData
	Data.Id = tostring(p_Id)
	Data.Item = p_Item or nil
	Data.Type = ReplicatedStorage.ItemFrames:FindFirstChild(p_Item) and ReplicatedStorage.ItemFrames:FindFirstChild(p_Item):GetAttribute("Type")
	Data.TileX = nil 
	Data.TileY = nil
	Inventory.Items[Data.Id] = Data
	return Data
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
	Storage.Parent = Frame
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