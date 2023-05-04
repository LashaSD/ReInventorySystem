local InventoryHandler = {}

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

return InventoryHandler