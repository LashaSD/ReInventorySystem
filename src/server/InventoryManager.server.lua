--- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

--- Libs
local Inventory = require(ReplicatedStorage.Common:WaitForChild("Inventory"))
local InventoryHandler = require(ReplicatedStorage.Common:WaitForChild("InventoryHandler"))
local StorageUnitMod = require(ReplicatedStorage.Common:WaitForChild("StorageUnit"))

--- Directories
local events = script.Parent -- directory of where the remote events are stored
local ClientEvents = ReplicatedStorage.Common.Events

--- Events
local SetData = events.SetStorageData

---
local PlayerStorageData = {} -- Dict<UserId, Inventory>
local StorageUnits = {}

local ItemId = 0

players.PlayerAdded:Connect(function(plr)
    local PlayerInventory = Inventory.new()

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
    local ItemData2 = PlayerInventory:GenerateItemData(StorageData2, nil, "RickAstley", ItemId)
    ItemId = ItemId + 1
    local ItemData3 = PlayerInventory:GenerateItemData(StorageData2, nil, "RickAstley1", ItemId)
    ItemId = ItemId + 1

    InventoryHandler.AppendItemArrayToQueue(PlayerInventory, {ItemData, ItemData1, ItemData2, ItemData3})

    SetData:Fire(plr, PlayerInventory)
end)

ClientEvents.GetStorageData.OnServerEvent:Connect(function(Player)
    if not PlayerStorageData[Player.UserId] then return nil end
    return PlayerStorageData[Player.UserId]
end)

-- Bindable Event that updates and synces player inventory data on server and client
SetData.Event:Connect(function(Plr, p_InventoryData, p_UnitData)
    if not (Plr and (p_InventoryData or p_UnitData)) then return nil end

    ClientEvents.GetStorageData:FireClient(Plr, p_InventoryData, p_UnitData) -- send data to client
    if p_InventoryData then
        p_InventoryData.Queue = {} -- reset the queue so the client wont duplicate the storages
    end
    local InventoryData = p_InventoryData
    if p_UnitData then
        InventoryData = p_InventoryData or PlayerStorageData[Plr.UserId]
        InventoryData.StorageUnit = p_UnitData
    end
    PlayerStorageData[Plr.UserId] = InventoryData
end)

ClientEvents.EquipEvent.OnServerEvent:Connect(function(Player, Type, Item, Id) 
    local plrInventory = PlayerStorageData[Player.UserId]
    if plrInventory then
        for i, ItemData in ipairs(plrInventory.Items) do
            if ItemData.Type == Type and ItemData.Id == Id then
                local width = Item.Width
                local height = Item.Height
                if width and height then
                    local AddedStorage = {width, height, nil, "ASBN"..ItemData.Id}
                    InventoryHandler.AppendStorageToQueue(plrInventory, AddedStorage)
                    SetData:Fire(Player, plrInventory)
                end
            end
        end
    end
end)

ClientEvents.UnequipEvent.OnServerEvent:Connect(function(Player, Type, Item, Id) 
    local plrInventory = PlayerStorageData[Player.UserId]
    if plrInventory then
        -- search the item 
          for _, ItemData in ipairs(plrInventory.Items) do
            if ItemData.Type == Type and ItemData.Id == Id then -- item exists on the server and it can be equipped
                table.insert(plrInventory.RemovalQueue, "ASBN"..Id)
                SetData:Fire(Player, plrInventory)
                PlayerStorageData[Player.UserId].RemovalQueue = {}
                return
            end
        end
    end
end)

local unitConnection = nil
ClientEvents.StorageUnit.OnServerEvent:Connect(function(Player, Action, StorageUnitId, p_ItemId, ItemData)
    -- get the storage unit  
    local StorageUnit 
    for _, unit in ipairs(StorageUnits) do
        if unit.Id == StorageUnitId then
            StorageUnit = unit
            break
        end
    end
    if Action == "deauthorize" then
        StorageUnit:Deauthorize()
        PlayerStorageData[Player.UserId].StorageUnit = nil
        if unitConnection then
            unitConnection:Disconnect()
        end
    elseif Action == "additem" then
        local InventoryData = PlayerStorageData[Player.UserId]
        local itemData = nil
        for index, Data in ipairs(InventoryData.Items) do
            if Data.Id == p_ItemId then
                itemData = Data
                table.remove(InventoryData.Items, index)
                break
            end
        end
        if Player.UserId ~= StorageUnit.User then return nil end 
        if not itemData then return nil end
        itemData.TileX = ItemData.TileX
        itemData.TileY = ItemData.TileY
        itemData.Name = ItemData.Name
        StorageUnit:InsertItem(itemData)
    elseif Action == "removeitem" then
        if Player.UserId ~= StorageUnit.User then return nil end 
        local InventoryData = PlayerStorageData[Player.UserId]
        local itemData = StorageUnit:RemoveItem(p_ItemId)
        if not itemData then return nil end
        table.insert(InventoryData.Items, itemData)
    elseif Action == "updatedata" then
        if Player.UserId ~= StorageUnit.User then return nil end 
        local itemData = StorageUnit.Items[tostring(p_ItemId)]
        itemData.TileX = ItemData.TileX
        itemData.TileY = ItemData.TileY
        itemData.Name = ItemData.Name
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

                local PlayerInventory = PlayerStorageData[Player.UserId] -- get Player Storage Data
                if not PlayerInventory then 
                    StorageUnit:Deauthorize()
                    return nil
                end

                local PlayerStorageUnit = PlayerInventory.StorageUnit -- get the player inventory for holding storage unit data
                if PlayerStorageUnit and PlayerStorageUnit.User then -- check if player is already authorized in another storage unit
                    StorageUnit:Deauthorize()
                    return nil
                end

                SetData:Fire(Player, nil, StorageUnit:GetData())

                local character = Player.Character
                unitConnection = RunService.Heartbeat:Connect(function(dt)
                    if character.Humanoid.MoveDirection.Magnitude > 0 then -- character is moving
                        -- check the distance from the character to the storage unit
                        local magnitude = math.abs((Part.Position - character.HumanoidRootPart.Position).Magnitude)
                        if magnitude > 25 then
                            print("deauthorized")
                            StorageUnit:Deauthorize()
                            unitConnection:Disconnect()
                            SetData:Fire(Player, nil, StorageUnit:GetData())
                        end
                    end
                end)

            end)
        end 
    end 
end