local Components = script.Parent.Components -- Directory of Components 

local Component = {}

local ClothingFunction = {
    function()
        -- Equip
        print("Put On Clothing TEST")
    end,
    function()
        -- Unequip
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

function Component.Equipped(Type, Item) 
    if Actions[Type] then 
        Actions[Type][1](Type)
    end 

    local Directory = Components:FindFirstChild(Item.Name)
    if not Directory then return end

    print(Directory)
    local Comp= require(Directory)
    if Comp then
        Comp.Equipped()
        print('\n')
    end
end 



function Component.Unequipped(Type, Item) 
    if Actions[Type] then Actions[Type][2](Item) end 

    local Directory = Components:FindFirstChild(Item.Name)
    if not Directory then return end

    local Comp= require(Directory)
    if Comp then
        Comp.Unequipped()
        print('\n')
    end
end 



return Component 














