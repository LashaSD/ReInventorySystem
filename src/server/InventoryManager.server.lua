local InventoryHandler = require(game.ReplicatedStorage.Common.InventoryHandler)
local Item = require(game.ReplicatedStorage.Common.InventoryItem)
local players = game:GetService("Players")
local events = script.Parent -- directory of where the remote events are stored

local Storages = {}

players.PlayerAdded:Connect(function(plr) 
    local PlayerInventory = {} 
    Storages[plr.UserId] = InventoryHandler.GenerateInventoryData()
end)

events.GetStorageData.OnServerEvent:Connect(function(Player) 
    if not Storages[Player.UserId] then return nil end
    return Storages[Player.UserId]
end)

events.SetStorageData.Event:Connect(function(ID, StorageData) 
    if ID and StorageData then
        Storages[ID] = StorageData 
    end
end)

