--- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

--- Libs
local Inventory = require(ReplicatedStorage.Common:WaitForChild("Inventory"))
local InventoryHandler = require(ReplicatedStorage.Common:WaitForChild("InventoryHandler"))
--local Item = require(ReplicatedStorage.Common:WaitForChild("InventoryItem"))

--- Directories
local events = script.Parent -- directory of where the remote events are stored
local ClientEvents = ReplicatedStorage.Common.Events

--- Frequent Vars
local SetData = events.SetStorageData

---
local PlayerInventories = {}

local ItemId = 0

players.PlayerAdded:Connect(function(plr)
    local PlayerInventory = Inventory.new()

    local HeadData = {3, 3, "Head"}
    local TorsoData = {3,3, "Torso"}
    local LegsData = {3,3, "Legs"}
    local BackData = {3,3, "Back"}
    local PrimaryWeaponData = {3,3, "Primary"}
    local SecondaryWeaponData = {3,3, "Secondary"}

    local StorageData1 = {8,8}
    local StorageData2 = {5, 8}

    InventoryHandler.AppendStorageArrayToQueue(PlayerInventory, {HeadData, TorsoData, LegsData, BackData, PrimaryWeaponData, SecondaryWeaponData, StorageData1, StorageData2})

    local ItemData = PlayerInventory:GenerateItemData(StorageData1, "Head", "Helmet", ItemId)
    ItemId = ItemId + 1
    local ItemData1 = PlayerInventory:GenerateItemData(StorageData2, "Back", "Robux", ItemId)
    ItemId = ItemId + 1
    local ItemData2 = PlayerInventory:GenerateItemData(StorageData2, "Back", "RickAstley", ItemId)
    ItemId = ItemId + 1
    local ItemData3 = PlayerInventory:GenerateItemData(StorageData2, "Back", "RickAstley1", ItemId)
    ItemId = ItemId + 1

    InventoryHandler.AppendItemArrayToQueue(PlayerInventory, {ItemData, ItemData1, ItemData2, ItemData3})

    SetData:Fire(plr, PlayerInventory)
end)

ClientEvents.GetStorageData.OnServerEvent:Connect(function(Player)
    if not PlayerInventories[Player.UserId] then return nil end
    return PlayerInventories[Player.UserId]
end)

-- Bindable Event that updates and synces player inventory data on server and client
SetData.Event:Connect(function(Plr, InventoryData)
    if Plr and InventoryData then
        ClientEvents.GetStorageData:FireClient(Plr, InventoryData)
        InventoryData.Queue = {} -- reset the queue so the client wont duplicate the storages
        PlayerInventories[Plr.UserId] = InventoryData
    end
end)

ClientEvents.EquipEvent.OnServerEvent:Connect(function(Player, Type, Item, Id) 
    local plrInventory = PlayerInventories[Player.UserId]
    if plrInventory then
        for i, ItemData in ipairs(plrInventory.Items) do
            if ItemData.Type == Type and ItemData.Id == Id then
                local width = Item:GetAttribute("InventoryWidth")
                local height = Item:GetAttribute("InventoryHeight")
                if width and height then
                    local AddedStorage = {width, height, nil, ItemData.Id}
                    InventoryHandler.AppendStorageToQueue(plrInventory, AddedStorage)
                    SetData:Fire(Player, plrInventory)
                end
            end
        end
    end
end)

ClientEvents.UnequipEvent.OnServerEvent:Connect(function(Player, Type, Item, Id) 
    local plrInventory = PlayerInventories[Player.UserId]
    if plrInventory then
        -- search the item 
          for _, ItemData in ipairs(plrInventory.Items) do
            if ItemData.Type == Type and ItemData.Id == Id then -- item exists on the server and it can be equipped
                -- search for the storage to delete 
                table.insert(plrInventory.RemovalQueue, Id)
                SetData:Fire(Player, plrInventory)
                PlayerInventories[Player.UserId].RemovalQueue = {}
                return
            end
        end
    end
end)