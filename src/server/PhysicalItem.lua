local Item = {}
Item.__index = Item

function Item.new(p_Item, Data)
    local self = setmetatable(Data, Item)
    self.Part = p_Item
    self.Triggered = false
    return self
end

function Item:Init()
    self.Part.Anchored = false
    self.Part.Parent = workspace
end     

function Item:GeneratePrompt()
    local ProximityPrompt = Instance.new("ProximityPrompt")
    ProximityPrompt.Parent = self.Part
    ProximityPrompt.ActionText = "Pick Up"
    ProximityPrompt.ObjectText = self.Part.Name--.. "\n Rarity: ".. self.Rarity
    ProximityPrompt.ClickablePrompt = true
    return ProximityPrompt
end


return Item