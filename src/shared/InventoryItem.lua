local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Mouse = game:GetService("Players").LocalPlayer:GetMouse()

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
    self.Offset = UDim2.fromOffset(0,0)

    self.OriginPosition = nil

    self.OriginOrientation = self.Item.Rotation
    self.CurrentOrientation = self.Item.Rotation

    self.OriginStorageData = self.StorageData
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
    self.OriginPosition = self.Item.Position

    -- make draggable
    self.DragFrame:Enable()

    local HoverConnection = nil
    local rotateConnection = nil
    local mouseConnection = nil
    self.DragFrame.DragStarted = function()
        self.Item.ZIndex = 2 -- makes the item we're dragging overlap other items and ui
        -- make the tiles that the item was on claimable
        self:UnclaimCurrentTiles()
        HoverConnection = self:GetItemHover() -- for indicating which spaces are valid for our item to be placed in 
        rotateConnection = self:GetRotate() -- rotating the part when player hits "R" on keyboard
        mouseConnection = self:GetMouseMove() -- locks the items position to the mouse
    end 

    -- lock item into a valid set of tiles
    self.DragFrame.DragEnded = function()
        -- reset the connection so the item isn't rotatable after placing it 
        HoverConnection:Disconnect()
        HoverConnection = nil
        rotateConnection:Disconnect()
        rotateConnection = nil
        mouseConnection:Disconnect()
        mouseConnection = nil
        self.Item.ZIndex = 1
        local width = self.Item:GetAttribute("Width")
        local height = self.Item:GetAttribute("Height")
        local x, y, valid = self:CheckValidLocation(width, height)
        if valid then
            self.CurrentOrientation = self.Item.Rotation
            self:ChangeLocationWithinStorage(x, y)
        else 
            -- returns the item to the position it was in originally before dragging it
            self:HoverClear(x,y)
            self:ChangeLocationWithinStorage(self.TileX, self.TileY)
            -- self:ChangeStorage(self.OriginStorageData)
        end 
        self.OriginPosition = self.Item.Position
        -- print(self.OriginPosition)
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

function InventoryItem:GetItemHover()

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
    return connection
end 

function InventoryItem:GetRotate()
    local connection = UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.R then
            local width = self.Item:GetAttribute("Width")
            local height = self.Item:GetAttribute("Height")
            self.Item:SetAttribute("Height", width)
            self.Item:SetAttribute("Width", height)
            self.Item.Rotation = self.Item.Rotation + 90
            if self.Item.Rotation % 180 ~= 0 and width ~= height then 
                self.Offset = UDim2.fromOffset(TileSize/2, -TileSize/2)
            else 
                self.Offset = UDim2.fromOffset(0,0)
            end 
        end
    end)
    return connection 
end 

function InventoryItem:GetMouseMove()
    local connection = Mouse.Move:Connect(function()
        local mousePos = UserInputService:GetMouseLocation()
        local translatePos = self.Item.AbsolutePosition - mousePos
        self.Item.Position = UDim2.fromOffset(translatePos.X, translatePos.Y)
    end)
    return connection 
end

function InventoryItem:CheckValidLocation(width, height) 
	local ItemPosition = self.Item.Position
	
    local StorageData = InventoryHandler.GetStorageFromPosition(self.Item.AbsolutePosition)
    if self.StorageData ~= StorageData and StorageData ~= nil then
        print(StorageData.Storage.Name)
        -- self:ChangeStorage(StorageData)
    end

	local MaxTilesX = #self.StorageData.Tiles
	local MaxTilesY = #self.StorageData.Tiles[0]

    local tiles = self.StorageData.Tiles

    local X = (ItemPosition - self.Offset).X.Offset
    local Y = (ItemPosition - self.Offset).Y.Offset

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

function InventoryItem:ChangeLocationWithinStorage(tileX, tileY)
    local width = self.Item:GetAttribute("Width")
	local height = self.Item:GetAttribute("Height")
    self.TileX = tileX
    self.TileY = tileY
    self.StorageData.ClaimTiles(tileX, tileY, width, height, self.Item)
    self.Item.Position = UDim2.new(0, tileX * TileSize, 0, tileY * TileSize) + self.Offset
    if self.Item.Rotation ~= self.CurrentOrientation then
        self.Item.Rotation = self.OriginOrientation
        self.CurrentOrientation = self.Item.Rotation
    end
    self:HoverClear(tileX, tileY)
end

function InventoryItem:HoverClear(lastX, lastY)
    local width = self.Item:GetAttribute("Width")
	local height = self.Item:GetAttribute("Height")
    for X = lastX, lastX + width - 1 do
        for Y = lastY, lastY + height - 1 do 
            self.StorageData.Tiles[X][Y]["TileFrame"].BackgroundColor3 = Color3.fromRGB(255,255,255)
        end 
    end
end 

function InventoryItem:ChangeStorage(StorageData)
    self.StorageData = StorageData
    local ItemPos = self.Item.AbsolutePosition
    self.Item.Parent = StorageData.Storage
    -- self.Item.Position = UDim2.fromOffset(self.Item.AbsolutePosition - self.Item.Parent.AbsolutePosition)
    -- print(self.Item.Position)
end 

function InventoryItem:UnclaimCurrentTiles()
    local width = self.Item:GetAttribute("Width")
	local height = self.Item:GetAttribute("Height")

    self.StorageData.UnclaimTiles(self.TileX, self.TileY, width, height)
end 


return InventoryItem
