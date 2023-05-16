--- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

--- Libs
local Inventory = require(ReplicatedStorage.Common:WaitForChild("Inventory"))
local InventoryHandler = require(ReplicatedStorage.Common:WaitForChild("InventoryHandler"))
local StorageUnitMod = require(ReplicatedStorage.Common:WaitForChild("StorageUnit"))
local PhysicalItemMod = require(script.Parent:WaitForChild("PhysicalItem"))

--- Directories
local events = script.Parent -- directory of where the remote events are stored
local ClientEvents = ReplicatedStorage.Common.Events

--- Events
local SetData = events.SetStorageData

--- Vars
local PlayerStorageData = {} -- Dict<UserId, Inventory>
local StorageUnits = {}

local ItemId = 0
local StorageId = 0
local unitId = 0

--- Util Functions

local function includes (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

-- returns the storage id and increments it by 1
local function getStorageId()
    local i = StorageId
    StorageId = StorageId + 1
    return i
end

-- returns the item id and increments it by 1
local function getItemId()
    local i = ItemId
    ItemId = ItemId + 1
    return i
end

-- returns the unit id and increments it by 1
local function getUnitId()
    local i = unitId
    unitId = unitId + 1
    return i
end 


players.PlayerAdded:Connect(function(plr)
    local PlayerInventory = Inventory.new()

    -- If you rename the types of the following storages, also change the name of the frames in collumn A
    local HeadData = InventoryHandler.GenerateStorageData(3, 3, "Headwear", getStorageId())
    local TorsoData = InventoryHandler.GenerateStorageData(3,3, "Shirt", getStorageId())
    local LegsData = InventoryHandler.GenerateStorageData(3,3, "Pants", getStorageId())
    local BackData = InventoryHandler.GenerateStorageData(3,3, "Backpack", getStorageId())
    local PrimaryWeaponData = InventoryHandler.GenerateStorageData(6,3, "Primary", getStorageId())
    local SecondaryWeaponData = InventoryHandler.GenerateStorageData(3,3, "Secondary", getStorageId())

    local StorageData1 = InventoryHandler.GenerateStorageData(2,2, nil, getStorageId(), true)
    local StorageData2 = InventoryHandler.GenerateStorageData(2,2, nil, getStorageId(), true)

    InventoryHandler.AppendStorageArrayToQueue(PlayerInventory, {HeadData, TorsoData, LegsData, BackData, PrimaryWeaponData, SecondaryWeaponData, StorageData1, StorageData2})

    local ItemData = PlayerInventory:GenerateItemData(StorageData1, "Helmet", getItemId())
    local ItemData1 = PlayerInventory:GenerateItemData(StorageData2, "RickAstley", getItemId())
    -- local ItemData2 = PlayerInventory:GenerateItemData(StorageData2, "RickAstley", getItemId())
    -- local ItemData3 = PlayerInventory:GenerateItemData(StorageData2, "RickAstley1", getItemId())

    InventoryHandler.AppendItemArrayToQueue(PlayerInventory, {ItemData, ItemData1})

    PlayerStorageData[plr.UserId] = PlayerInventory
    SetData:Fire(plr, PlayerInventory)
end)

players.PlayerRemoving:Connect(function(Player)
    local id = Player.UserId
    local inventory = PlayerStorageData[id]
    if not inventory or not inventory.StorageUnit then return nil end
    local storageUnit = nil
    for _, v in ipairs(StorageUnits) do
        if v.Id == inventory.StorageUnit.Id then
            storageUnit = v
        end
    end
    if storageUnit then storageUnit:Deauthorize() end
    PlayerStorageData[id] = nil
end)

ClientEvents.GetStorageData.OnServerEvent:Connect(function(Player)
    if not PlayerStorageData[Player.UserId] then return nil end
    return PlayerStorageData[Player.UserId]
end)

-- Bindable Event that updates and synces player inventory data on server and client
SetData.Event:Connect(function(Plr, p_InventoryData, p_UnitData, p_StorageDataIndex)
    if not (Plr and (p_InventoryData or p_UnitData)) then return nil end
    local storages = PlayerStorageData[Plr.UserId].Storages

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
    PlayerStorageData[Plr.UserId].Storages = storages
    if p_StorageDataIndex then
        PlayerStorageData[Plr.UserId].Storages[p_StorageDataIndex].EquippedSlot = p_InventoryData.Storages[p_StorageDataIndex].EquippedSlot
    end
end)

ClientEvents.EquipEvent.OnServerEvent:Connect(function(Player, Type, ItemInfo, Id, p_StorageId)
    local plrInventory = PlayerStorageData[Player.UserId]
    if not plrInventory or not Id or not p_StorageId then return nil end

    local StorageData = nil
    local StorageDataIndex = nil
    for index, data in ipairs(plrInventory.Storages) do
        if data.Id == p_StorageId then
            StorageData = data
            StorageDataIndex = index
            break
        end
    end

    if not StorageData then
        print("Couldn't find Storage with ID: ".. p_StorageId)
        return nil
    end

    if StorageData.EquippedSlot then
        print("Item Already Equipped")
        return nil
    end

    
    local ItemData = plrInventory.Items[tostring(Id)]
    if ItemData.Type == Type then -- item exists on the server and it can be equipped
        local width = ItemInfo.Width
        local height = ItemInfo.Height
        StorageData.EquippedSlot = ItemData
        
        -- find the starter slots
        local starterStorageDataTable = {}
        local indices = {}
        for index, data in ipairs(plrInventory.Storages) do
            if data.Starter then
                table.insert(starterStorageDataTable, data.Id)
                table.insert(indices, index)
                if ItemData.Type ~= "Backpack" then break end
            end
        end

        if width and height then -- valid to equip
            local AddedStorage = InventoryHandler.GenerateStorageData(width, height, nil, "ASBN"..ItemData.Id)
            InventoryHandler.AppendStorageToQueue(plrInventory, AddedStorage)
            if starterStorageDataTable then InventoryHandler.AppendStorageArrayToRemovalQueue(plrInventory, starterStorageDataTable) end
        end
        plrInventory.Storages[StorageDataIndex] = StorageData
        PlayerStorageData[Player.UserId] = plrInventory
        SetData:Fire(Player, plrInventory, nil, StorageDataIndex)
    end
end)

ClientEvents.UnequipEvent.OnServerEvent:Connect(function(Player, Type, Id, p_StorageId)
    local plrInventory = PlayerStorageData[Player.UserId]
    if not plrInventory or not Id or not p_StorageId then return nil end

    local StorageData = nil
    for _, data in ipairs(plrInventory.Storages) do
        if data.Id == p_StorageId then
            StorageData = data
            break
        end
    end

    if not StorageData then
        print("Couldn't find Storage with ID: ".. p_StorageId)
        return nil
    end

    if not StorageData.EquippedSlot then
        print("Item is already unequipped")
        return nil
    end

    local StarterStorages = 0
    for _, data in ipairs(plrInventory.Storages) do
        if data.Starter then
            StarterStorages = StarterStorages + 1
        end
    end

    local EquippedItems = 0 
    for _, data in ipairs(plrInventory.Storages) do
        if data.EquippedSlot and data.Id ~= StorageData.Id then
            EquippedItems = EquippedItems + 1
            if data.EquippedSlot.Type == "Backpack" then
                EquippedItems = EquippedItems + 1
            end
        end
    end

    local ItemData = plrInventory.Items[tostring(Id)]
    if ItemData.Type == Type and StorageData.EquippedSlot.Id == Id then -- item exists on the server and it can be equipped
        StorageData.EquippedSlot = nil
        if 2 - EquippedItems > 0 and StarterStorages + 1 <= 2 then
            local tab = {}
            table.insert(tab, InventoryHandler.GenerateStorageData(2,2, nil, getStorageId(), true))
            StarterStorages = StarterStorages + 1
            if 2 - EquippedItems > 1 and StarterStorages + 1 <= 2 then
                table.insert(tab, InventoryHandler.GenerateStorageData(2,2, nil, getStorageId(), true))
            end
            InventoryHandler.AppendStorageArrayToQueue(plrInventory, tab)
        end
        InventoryHandler.AppendStorageToRemovalQueue(plrInventory, "ASBN"..Id)
        SetData:Fire(Player, plrInventory)
        PlayerStorageData[Player.UserId].RemovalQueue = {}
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
        for index, Data in pairs(InventoryData.Items) do
            if Data.Id == p_ItemId then
                itemData = Data
                table.remove(InventoryData.Items, index)
                break
            end
        end
        if Player.UserId ~= StorageUnit.User then return nil end
        if not itemData then return nil end
        for k, v in pairs(ItemData) do
            itemData[k] = v
        end
        StorageUnit:InsertItem(itemData)
    elseif Action == "removeitem" then
        if Player.UserId ~= StorageUnit.User then return nil end
        local InventoryData = PlayerStorageData[Player.UserId]
        local itemData = StorageUnit:RemoveItem(p_ItemId)
        if not itemData then return nil end
        InventoryData.Items[tostring(p_ItemId)] = itemData
    elseif Action == "updatedata" then
        if Player.UserId ~= StorageUnit.User then return nil end
        local itemData = StorageUnit.Items[tostring(p_ItemId)]
        for k, v in pairs(ItemData) do
            itemData[k] = v
        end
    end
end)

ClientEvents.Inventory.OnServerEvent:Connect(function(Player, Action, p_StorageId, p_ItemId, data)
    local plrInventory = PlayerStorageData[Player.UserId]
    -- get the storage data
    local StorageData = nil
    for _, Data in ipairs(plrInventory.Storages) do
        if Data.Id == p_StorageId then
            StorageData = Data
        end
    end
    if not StorageData and Action ~= "dropitem" then
        print("Failed to fetch Storagedata and perform Action: ".. Action)
        return
    end
    if Action == "updatedata" then
        for x = 0, #StorageData.Tiles do
            for y = 0, #StorageData.Tiles[0] do
                local Data = StorageData.Tiles[x][y]
                if not data[tostring(x)] then
                    Data["Claimed"] = false
                    continue
                end
                Data["Claimed"] = includes(data[tostring(x)], y)
            end
        end
        -- for i, coords in ipairs(data) do
        --     StorageData.Tiles[coords[1]][coords[2]]["Claimed"] = true
        -- end
    elseif Action == "removeitem" then
        plrInventory.Items[p_ItemId] = nil
    elseif Action == "dropitem" then
        -- check if item exists
        local itemData = plrInventory.Items[p_ItemId]
        if not itemData then return nil end

        plrInventory.Items[p_ItemId] = nil

        local physicalItemDir = ServerStorage.Items:FindFirstChild(itemData.Item)
        if not physicalItemDir then 
            physicalItemDir = ServerStorage.Items:FindFirstChild('Default')
        end

        local char = Player.Character or Player.CharacterAdded:Wait()
        local hrp = char:WaitForChild("HumanoidRootPart")

        -- item 
        local item = physicalItemDir:Clone()
        item.Name = itemData.Item

        local PhysicalItem = PhysicalItemMod.new(item, data)

        PhysicalItem:Init()

        local offset = Vector3.new(0,0,-5)
        PhysicalItem.Part.CFrame = hrp.CFrame * CFrame.new(offset)

        local prompt = PhysicalItem:GeneratePrompt(Player)
        prompt.Triggered:Connect(function(Player) 
            if PhysicalItem.Triggered then return nil end
            PhysicalItem.Triggered = true
            local playerInventory = PlayerStorageData[Player.UserId]
            if not playerInventory then return nil end

            local itemFrame = ReplicatedStorage.ItemFrames:FindFirstChild(PhysicalItem.Part.Name)
            local width = itemFrame:GetAttribute("Width")
            local height = itemFrame:GetAttribute("Height")
            local sdata,x,y = InventoryHandler.CheckFreeSpaceInventoryWide(playerInventory, width, height)

            if not sdata then
                print("Item Doesn't fit")
                return
            end

            PhysicalItem.Part:Destroy()



            local newItemData = InventoryHandler.GenerateItemData(playerInventory, sdata, PhysicalItem.Part.Name, getItemId())
            newItemData.TileX = x
            newItemData.TileY = y
            

            InventoryHandler.AppendStorageToQueue(playerInventory, sdata)
            InventoryHandler.AppendItemToQueue(playerInventory, newItemData)

            SetData:Fire(Player, playerInventory)
        end)
    end
end)

-- Generate Storage Units
local StorageUnitParts = CollectionService:GetTagged("StorageUnit")
for index, Part in ipairs(StorageUnitParts) do
    local width = Part:GetAttribute("InventoryWidth") -- <Number>
    local height = Part:GetAttribute("InventoryHeight") -- <Number>
    if width and height then
        local accessible = Part:GetAttribute("Accessible") -- <Bool>
        local UnitData = InventoryHandler.GenerateStorageUnitData(width, height, getUnitId(), accessible)
        local StorageUnit = StorageUnitMod.new(UnitData)
        table.insert(StorageUnits, StorageUnit)

        -- add a way for player to open storage units
        local ClickDetector = Instance.new("ClickDetector")
        local ItemName = Part:GetAttribute("ItemName")
        if Part:IsA("Model") then Part = Part:FindFirstChild("Main") end
        ClickDetector.Parent = Part
        if accessible then
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
        else
            local itemData = {}
            itemData.Name = ItemName
            if not itemData.Name or not ReplicatedStorage.ItemFrames:FindFirstChild(itemData.Name) then print("Bruh") return nil end
            local item = ReplicatedStorage.ItemFrames:FindFirstChild(itemData.Name)
            
            itemData.Width = item:GetAttribute("Width")
            itemData.Height = item:GetAttribute("Height")
            itemData.Type = item:GetAttribute("Type")
            itemData.Id = getItemId()
            StorageUnit:InsertItem(itemData)
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

                local itemId, ItemData = next(StorageUnit.Items, nil)


                PlayerInventory.Items[tostring(itemId)] = ItemData
                local itemFrame = ReplicatedStorage.ItemFrames:FindFirstChild(itemData.Name)
                if not itemFrame then StorageUnit:Deauthorize(); return nil end
                local itemWidth = itemFrame:GetAttribute("Width")
                local itemHeight = itemFrame:GetAttribute("Height")
                local sdata, x, y = InventoryHandler.CheckFreeSpaceInventoryWide(PlayerInventory, itemWidth, itemHeight)

                if not sdata then print("No Space"); StorageUnit:Deauthorize();return nil end

                local newItemData = InventoryHandler.GenerateItemData(PlayerInventory, sdata, ItemName, getItemId())
                newItemData.TileX = x
                newItemData.TileY = y

                InventoryHandler.AppendStorageToQueue(PlayerInventory, sdata)
                InventoryHandler.AppendItemToQueue(PlayerInventory, newItemData)

                PlayerStorageData[Player.UserId] = PlayerInventory
                SetData:Fire(Player, PlayerInventory)
                StorageUnit:Deauthorize()
            end)
        end
    end
end