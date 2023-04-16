-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

-- Libs
local InventoryHandler = require(ReplicatedStorage.Common:WaitForChild("InventoryHandler"))
-- local Item = require(ReplicatedStorage.Common:WaitForChild("InventoryItem"))

-- Directories
local events = script.Parent -- directory of where the remote events are stored

---
local Storages = {}

players.PlayerAdded:Connect(function(plr) 
    local PlayerInventory = {} 
    Storages[plr.UserId] = InventoryHandler.GenerateInventoryData()
    print(Storages[plr.UserId])
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


print("SCRIPT REGISTERED")