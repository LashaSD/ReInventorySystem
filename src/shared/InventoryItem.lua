local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local InventoryHandler = require(script.Parent.InventoryHandler)

local DragabbleItem = require(script.Parent:WaitForChild("DraggableObject"))

local TileSize 

local InventoryItem = {}
InventoryItem.__index = InventoryItem

function InventoryItem.new(Item, Storage, tileX, tileY)
	local self = setmetatable({}, InventoryItem)
	self.TileX = tileX or nil
	self.TileY = tileY or nil
	self.Item = Item
    self.StorageData = InventoryHandler.GetDataFromStorage(Storage)
    self.DragFrame = DragabbleItem.new(Item)
    self.OriginPosition = nil
    self.OriginOrientation = nil
	return self
end

function InventoryItem:Init()
    TileSize = self.StorageData.Tiles[0][0]["TileFrame"].Size.X.Offset

	local width = self.Item:GetAttribute("Width")
	local height = self.Item:GetAttribute("Height")

    self.Item.Parent = self.StorageData.Storage
    self.Item.Size = UDim2.new(0, TileSize * width, 0, TileSize * height)

    -- Initialize the Location of the Item in the Inventory
    --[[
    ToDo: 
        Find free space automatically to place items in, without given tile coords
    ]]--
	self:ChangeLocationWithinStorage(self.TileX, self.TileY)

    -- male draggable
    self.DragFrame:Enable()

    local HoverConnection = nil
    local rotateConnection = nil
    self.DragFrame.DragStarted = function()
        self.Item.ZIndex = 2 -- makes the item we're dragging overlap other items and ui
        -- make the tiles that the item was on claimable
        self:UnclaimCurrentTiles()
        HoverConnection = self:ItemHover() -- for indicating which spaces are valid for our item to be placed in 
        rotateConnection = self:Rotate() -- rotating the part when player hits "R" on keyboard
    end 

    -- lock item into a valid set of tiles
    self.DragFrame.DragEnded = function()
        -- reset the connection so the item isn't rotatable after placing it 
        rotateConnection:Disconnect()
        rotateConnection = nil
        self.Item.ZIndex = 1
        local width = self.Item:GetAttribute("Width")
        local height = self.Item:GetAttribute("Height")
        local x, y, valid = self:CheckValidLocation(width, height)
        if valid then 
            self:ChangeLocationWithinStorage(x, y)
        else 
            -- returns the item to the position it was in originally before dragging it
            self:ChangeLocationWithinStorage(self.OriginPosition.X.Offset, self.OriginPosition.Y.Offset, self.OriginOrientation)
        end 
    end

    --[[ INTERACTION MENU FOR DELETING THE ITEM (DONT DELETE THE CODE) ]]--
    -- self.Item.InputBegan:Connect(function(input)
    --     if input.UserInputType == Enum.UserInputType.MouseButton2 then
    --         if self.Item:FindFirstChild("InteractionMenu") then
    --             self.Item.InteractionMenu:Destroy()
    --             self.Item.ZIndex = 3
    --         else
    --             self.Item.ZIndex = 1
    --             local UiFrame = Instance.new("Frame")
    --             UiFrame.Name = "InteractionMenu"
    --             UiFrame.Position = UDim2.fromScale(1,0)
    --             UiFrame.Size = UDim2.new(0,TileSize, 0, 2*TileSize)
    --             UiFrame.Parent = self.Item
    --         end
    --     end
    -- end)

    return self
end

function InventoryItem:ItemHover()

    local lastX, lastY = nil, nil
    local lastWidth = self.Item:GetAttribute("Width")
    local lastHeight = self.Item:GetAttribute("Height")

    local connection = self.Item:GetPropertyChangedSignal("Position"):Connect(function()

        local width = self.Item:GetAttribute("Width")
        local height = self.Item:GetAttribute("Height")

        if lastX and lastY then 
            for X = lastX, lastX + lastWidth - 1 do
                for Y = lastY, lastY + lastHeight - 1 do 
                    self.StorageData.Tiles[X][Y]["TileFrame"].BackgroundColor3 = Color3.fromRGB(255,255,255)
                end 
            end
        end 

        local x, y, valid = self:CheckValidLocation(width, height)
        local color 
        if valid then 
            -- Color when item is possible to place
            color =Color3.fromRGB(44, 240, 125)
        else 
            -- Color when item is impossible to palce 
            color =Color3.fromRGB(215, 43, 43)
        end 
        for X = x, x + width - 1 do
            for Y = y, y + height - 1 do 
                self.StorageData.Tiles[X][Y]["TileFrame"].BackgroundColor3 = color
            end 
        end
        lastX = x
        lastY = y
        lastWidth = width
        lastHeight = height
    end)
    return connection, lastX, lastY
end 

function InventoryItem:HoverClear(lastX, lastY)
    print(lastX, lastY)
    local width = self.Item:GetAttribute("Width")
	local height = self.Item:GetAttribute("Height")
    for X = lastX, lastX + width - 1 do
        for Y = lastY, lastY + height - 1 do 
            self.StorageData.Tiles[X][Y]["TileFrame"].BackgroundColor3 = Color3.fromRGB(255,255,255)
        end 
    end
end 

function InventoryItem:Rotate()
    local connection = UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.R then
            local width = self.Item:GetAttribute("Width")
            local height = self.Item:GetAttribute("Height")
            self.Item:SetAttribute("Height", width)
            self.Item:SetAttribute("Width", height)
            self.Item.Rotation = self.Item.Rotation + 90
        end
    end)
    return connection 
end 

function InventoryItem:CheckValidLocation(width, height) 
	local ItemPosition = self.Item.Position
	local tiles = self.StorageData.Tiles
	
	local MaxTilesX = #tiles
	local MaxTilesY = #tiles[0]

    local X = ItemPosition.X.Offset
    local Y = ItemPosition.Y.Offset

    local translateX = math.floor(X/TileSize)
    local translateY = math.floor(Y/TileSize)

    if translateX > MaxTilesX - width then translateX = (MaxTilesX - width) + 1 end
	if translateX < 0 then translateX = 0 end
    if translateY > MaxTilesY - height then translateY = (MaxTilesY - height) + 1 end
	if translateY < 0 then translateY = 0 end

    local valid = true
    for X = translateX, translateX + width - 1 do
        for Y = translateY, translateY + height-1 do
            if tiles[X][Y]["Claimed"] == true then
                valid = false
            end
        end
    end

    return translateX, translateY, valid
end

function InventoryItem:ChangeLocationWithinStorage(tileX, tileY, orientation)
    local width = self.Item:GetAttribute("Width")
	local height = self.Item:GetAttribute("Height")
    self.TileX = tileX
    self.TileY = tileY
    self.StorageData.ClaimTiles(tileX, tileY, width, height, self.Item)
    self.Item.Position = UDim2.new(0, tileX * TileSize, 0, tileY * TileSize)
    print(self.Item.Position)
    if orientation then
        self.Item.Rotation = orientation
        self:HoverClear(tileX, tileY)
        self.Item:SetAttribute("Width", height)
        self.Item:SetAttribute("Height", width)
    end
    self.OriginPosition = self.Item.Position
    self.OriginOrientation = self.Item.Rotation
end

function InventoryItem:UnclaimCurrentTiles()
    local width = self.Item:GetAttribute("Width")
	local height = self.Item:GetAttribute("Height")

    self.StorageData.UnclaimTiles(self.TileX, self.TileY, width, height)
end 


return InventoryItem
