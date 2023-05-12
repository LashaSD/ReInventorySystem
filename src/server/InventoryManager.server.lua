--- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

--- Libs
local Inventory = require(ReplicatedStorage.Common:WaitForChild("Inventory"))
local InventoryHandler = require(ReplicatedStorage.Common:WaitForChild("InventoryHandler"))
local StorageUnitMod = require(ReplicatedStorage.Common:WaitForChild("StorageUnit"))
--- Directories
local events = script.Parent -- directory of where the remote events are stored
local ClientEvents = ReplicatedStorage.Common.Events

--- Frequent Vars
local SetData = events.SetStorageData

---
local PlayerStorageData = {} -- Dict<UserId, Dict<"MainStorage": MainStorageInventory, "StorageUnit": StorageUnitInventory>
local StorageUnits = {}

local ItemId = 0

players.PlayerAdded:Connect(function(plr)
    local Data = {}
    local PlayerInventory = Inventory.new()
    local StorageUnitData = nil

    local HeadData = {3, 3, "Head"}
    local TorsoData = {3,3, "Torso"}
    local LegsData = {3,3, "Legs"}
    local BackData = {3,3, "Back"}
    local PrimaryWeaponData = {6,3, "Primary"}
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

    Data["MainStorage"] = PlayerInventory
    Data["StorageUnit"] = StorageUnitData

    SetData:Fire(plr, Data)
end)

ClientEvents.GetStorageData.OnServerEvent:Connect(function(Player)
    if not PlayerStorageData[Player.UserId] then return nil end
    return PlayerStorageData[Player.UserId]
end)

-- Bindable Event that updates and synces player inventory data on server and client
SetData.Event:Connect(function(Plr, Data)
    if Plr and Data then
        ClientEvents.GetStorageData:FireClient(Plr, Data)
        local PlrInventory = Data["MainStorage"]
        local UnitData = Data["StorageUnit"]
        if PlrInventory then
            PlrInventory.Queue = {} -- reset the queue so the client wont duplicate the storages
        end 
        PlayerStorageData[Plr.UserId] = Data
    end
end)

ClientEvents.EquipEvent.OnServerEvent:Connect(function(Player, Type, Item, Id) 
    local plrInventory = PlayerStorageData[Player.UserId]["MainStorage"]
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
    local plrInventory = PlayerStorageData[Player.UserId]["MainStorage"]
    if plrInventory then
        -- search the item 
          for _, ItemData in ipairs(plrInventory.Items) do
            if ItemData.Type == Type and ItemData.Id == Id then -- item exists on the server and it can be equipped
                -- search for the storage to delete 
                table.insert(plrInventory.RemovalQueue, Id)
                SetData:Fire(Player, plrInventory)
                PlayerStorageData[Player.UserId]["MainStorage"].RemovalQueue = {}
                return
            end
        end
    end
end)

-- Generate Storage Units 
local StorageUnitParts = CollectionService:GetTagged("StorageUnit")
local id = 0
for _, Part in ipairs(StorageUnitParts) do
    local width = Part:GetAttribute("InventoryWidth") -- <Number>
    local height = Part:GetAttribute("InventoryHeight") -- <Number>
    if width and height then 
        local accessible = Part:GetAttribute("Accessible") -- <Bool>
        local UnitData = InventoryHandler.GenerateStorageUnitData(width, height, id, accessible)
        id = id + 1
        local StorageUnit = StorageUnitMod.new(UnitData)
        table.insert(StorageUnits, StorageUnit)
         
        -- add a way for player to open storage units 
        if accessible then
            local ClickDetector = Instance.new("ClickDetector")
            ClickDetector.Parent = Part
            ClickDetector.MouseClick:Connect(function(Player)
                local response = StorageUnit:Authorize(Player)
                if not response then return nil end     

                local PlrStorageData = PlayerStorageData[Player.UserId] -- get Player Storage Data
                if not PlrStorageData then 
                    StorageUnit:Deauthorize()
                    return nil
                end

                local PlayerStorageUnit = PlrStorageData["StorageUnit"] -- get the player inventory for holding storage unit data
                if PlayerStorageUnit then 
                    StorageUnit:Deauthorize()
                    return nil
                end

                local data = {["StorageUnit"] = StorageUnit}

                print("Sending data")
                print(data)

                SetData:Fire(Player, data)

            end)
        end 
    end 
end