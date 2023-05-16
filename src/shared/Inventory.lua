local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemMod = require(ReplicatedStorage.Common:WaitForChild("InventoryItem"))
local InventoryHandler = require(ReplicatedStorage.Common:WaitForChild("InventoryHandler"))

local Inventory = {}
Inventory.__index = Inventory

function Inventory.new()
	local self = setmetatable({}, Inventory)
	self.Storages = {} -- Array<StorageData>
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
			local bool = false 
			local oldStorageData = nil
			for _, data in ipairs(self.Storages) do
				if data.Id == StorageData.Id then
					bool = true
					oldStorageData = data
					break
				end
			end
			local NewStorageData = nil
			if not bool then
				NewStorageData = self:GenerateStorage(StorageData, Frame)
				if not StorageData.Type then
					local InvisibleFrame = Frame:FindFirstChild("InvisibleFrame1")
					local clone = InvisibleFrame:Clone()
					clone.Name = "InvisibleFrame1"
					clone.Parent = NewStorageData.Storage.Parent
					InvisibleFrame:Destroy()
				end
			end
			-- generate all the items 
			local ItemQueue = Data[2]
			if ItemQueue then
				for _, ItemData in ipairs(ItemQueue) do
					ItemData.StorageData = NewStorageData or oldStorageData
					ItemData.Item = ReplicatedStorage.ItemFrames:FindFirstChild(ItemData.Item):Clone()
					ItemData.Type = ItemData.Item:GetAttribute("Type")
					local Item = ItemMod.new(ItemData)
					if Item then Item:Init() end
					self.Items[tostring(Item.Id)] = Item
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
				local items = self.Items 
				table.remove(self.Storages, Index)
				for id, data in pairs(items) do
					if data.StorageData.Id == Storage.Id then
						local width = data.Width or data.Item:GetAttribute("Width")
						local height = data.Height or data.Item:GetAttribute("Height")
						local SData, x, y = InventoryHandler.CheckFreeSpaceInventoryWide(self, width, height)
						if SData and x and y then
							data.StorageData = SData 
							data.Item.Parent = SData.Storage
							data:ChangeLocationWithinStorage(x, y)
						else 
							data:Destroy()
						end
					end
				end
				Storage.Storage:Destroy()
				return
			end
		end
	end
	self.RemovalQueue = {}
end 

function Inventory:GenerateStorage(Data, Frame)
	-- get tile data
    local Tile = script.Parent.UiFrames:WaitForChild("Tile")
	self.TileSize = Tile.Size.X.Offset

	local Width = #Data.Tiles + 1
	local Height = #Data.Tiles[1] + 1


	-- check for storage type and get storage
	local Storage = nil;
	if Data.Type then
		Storage = Frame
		Storage.Size = UDim2.new(0, self.TileSize * Width, 0, self.TileSize * Height)
	else
		Storage = script.Parent.UiFrames:WaitForChild("Storage"):Clone()
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
	Data.Type = ReplicatedStorage.ItemFrames:FindFirstChild(p_Item) and ReplicatedStorage.ItemFrames:FindFirstChild(p_Item):GetAttribute("Type")
	Data.TileX = nil 
	Data.TileY = nil
	self.Items[Data.Id] = Data
	return Data
end 

return Inventory