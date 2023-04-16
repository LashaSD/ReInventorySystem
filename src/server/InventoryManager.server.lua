--- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

--- Libs
local Inventory = require(ReplicatedStorage.Common:WaitForChild("InventoryHandler"))
-- local Item = require(ReplicatedStorage.Common:WaitForChild("InventoryItem"))

--- Directories
local events = script.Parent -- directory of where the remote events are stored
local ClientEvents = ReplicatedStorage.Common.Events

---
local Storages = {}

players.PlayerAdded:Connect(function(plr) 
    local PlayerInventory = Inventory.new()
    print(plr.UserId)
    Storages[plr.UserId] = PlayerInventory

    local HeadData = PlayerInventory:GenerateStorageData(3, 3, "Head").Trim()
    local TorsoData = PlayerInventory:GenerateStorageData(3,3, "Torso").Trim()
    local LegsData = PlayerInventory:GenerateStorageData(3,3, "Legs").Trim()
    local BackData = PlayerInventory:GenerateStorageData(3,4, "Back").Trim()
    local PrimaryWeaponData = PlayerInventory:GenerateStorageData(5,3, "Primary").Trim()
    local SecondaryWeaponData = PlayerInventory:GenerateStorageData(3,3, "Secondary").Trim()
    local StorageData1 = Inventory:GenerateStorageData(8,8).Trim()
    local StorageData2 = Inventory:GenerateStorageData(5,8).Trim()

    PlayerInventory:AppendArrayToQueue({HeadData, TorsoData, LegsData, BackData, PrimaryWeaponData, SecondaryWeaponData, StorageData1, StorageData2})
    print("appended to queue")
end)

ClientEvents.GetStorageData.OnServerInvoke = function (Player) 
    if not Storages[Player.UserId] then return nil end
    return Storages[Player.UserId]
end

events.SetStorageData.Event:Connect(function(ID, StorageData) 
    if ID and StorageData then
        Storages[ID] = StorageData 
    end
end)