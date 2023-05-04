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
    function(Type, Item, Id)
        -- Equip
        ClothingEquipEvent:FireServer(Type, Item, Id)
        print("Put On Clothing")
    end,
    function(Type, Item, Id)
        -- Unequip
        ClothingUnequipEvent:FireServer(Type, Item, Id)
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
    ["Head"] = ClothingFunction,
    ["Torso"] = ClothingFunction,
    ["Legs"] = ClothingFunction,
    ["Back"] = ClothingFunction,
    ["Primary"] = WeaponFunction,
    ["Secondary"] = WeaponFunction
}

function Component.Equipped(Type, Item, Id) 
    if Actions[Type] then 
        Actions[Type][1](Type, Item, Id)
    end 

    local Directory = Components:FindFirstChild(Item.Name)
    if not Directory then return end

    local Comp= require(Directory)
    if Comp then
        Comp.Equipped()
        print('\n')
    end
end 

function Component.Unequipped(Type, Item, Id) 
    if Actions[Type] then Actions[Type][2](Type, Item, Id) end

    local Directory = Components:FindFirstChild(Item.Name)
    if not Directory then return end

    local Comp= require(Directory)
    if Comp then
        Comp.Unequipped()
        print('\n')
    end
end 



return Component 














