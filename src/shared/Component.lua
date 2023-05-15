-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Directories
local EventsFolder = ReplicatedStorage.Common.Events

-- Events
local ClothingEquipEvent = EventsFolder.EquipEvent
local ClothingUnequipEvent = EventsFolder.UnequipEvent

local Components = script.Parent.Components -- Directory of Components 

local Component = {}

local ClothingFunction = {
    function(Type, Item, Id, StorageId)
        -- Equip
        local Data = {}
        Data.Width = Item:GetAttribute("InventoryWidth")
        Data.Height = Item:GetAttribute("InventoryHeight")
        ClothingEquipEvent:FireServer(Type, Data, Id, StorageId)
        print("Put On Clothing")
    end,
    function(Type, Item, Id, StorageId)
        -- Unequip
        ClothingUnequipEvent:FireServer(Type, Id, StorageId)
        print("Take Off Clothing")
    end,
}

local WeaponFunction = {
    function()
        -- Equip
        print("Equip Weapon")
    end,
    function()
        -- Unequip
        print("Unequip Weapon")
    end,
}

local Actions = {
    ["Headwear"] = ClothingFunction,
    ["Shirt"] = ClothingFunction,
    ["Pants"] = ClothingFunction,
    ["Backpack"] = ClothingFunction,
    ["Primary"] = WeaponFunction,
    ["Secondary"] = WeaponFunction
}

function Component.Equipped(Type, Item, Id, StorageId)
    if Actions[Type] then 
        Actions[Type][1](Type, Item, Id, StorageId)
    end

    local Directory = Components:FindFirstChild(Item.Name)
    if not Directory then return end

    local Comp= require(Directory)
    if Comp then
        Comp.Equipped()
    end
end 

function Component.Unequipped(Type, Item, Id, StorageId)
    if Actions[Type] then Actions[Type][2](Type, Item, Id, StorageId) end

    local Directory = Components:FindFirstChild(Item.Name)
    if not Directory then return end

    local Comp= require(Directory)
    if Comp then
        Comp.Unequipped()

    end
end 



return Component 














