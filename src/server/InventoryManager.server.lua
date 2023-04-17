--- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

--- Libs
local Inventory = require(ReplicatedStorage.Common:WaitForChild("InventoryHandler"))
-- local Item = require(ReplicatedStorage.Common:WaitForChild("InventoryItem"))
local ItemParams = require(ReplicatedStorage.Common:WaitForChild("ItemParams"))

--- Directories
local events = script.Parent -- directory of where the remote events are stored
local ClientEvents = ReplicatedStorage.Common.Events

--- Frequent Vars
local SetData = events.SetStorageData

---
local PlayerInventories = {}

players.PlayerAdded:Connect(function(plr) 
    local PlayerInventory = Inventory.new()

    local HeadData = PlayerInventory:GenerateStorageData(3, 3, "Head").Trim()
    local TorsoData = PlayerInventory:GenerateStorageData(3,3, "Torso").Trim()
    local LegsData = PlayerInventory:GenerateStorageData(3,3, "Legs").Trim()
    local BackData = PlayerInventory:GenerateStorageData(3,4, "Back").Trim()
    local PrimaryWeaponData = PlayerInventory:GenerateStorageData(5,3, "Primary").Trim()
    local SecondaryWeaponData = PlayerInventory:GenerateStorageData(3,3, "Secondary").Trim()
    local StorageData1 = Inventory:GenerateStorageData(8,8).Trim()
    local StorageData2 = Inventory:GenerateStorageData(5,8).Trim()

    -- local ItemData = ItemParams(StorageData1)
    -- ItemData.

    PlayerInventory:AppendArrayToQueue({HeadData, TorsoData, LegsData, BackData, PrimaryWeaponData, SecondaryWeaponData, StorageData1, StorageData2})
    SetData:Fire(plr, PlayerInventory)
end)

ClientEvents.GetStorageData.OnServerInvoke = function (Player) 
    if not PlayerInventories[Player.UserId] then return nil end
    return PlayerInventories[Player.UserId]
end

SetData.Event:Connect(function(Plr, InventoryData) 
    if Plr and InventoryData then
        PlayerInventories[Plr.UserId] = InventoryData 
        ClientEvents.GetStorageData:InvokeClient(Plr)        
    end
end)