local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local UserInputService = game:GetService("UserInputService")
local Mouse = game:GetService("Players").LocalPlayer:GetMouse()

local InventoryHandler = require(script.Parent.InventoryHandler)

local DragabbleItem = require(script.Parent:WaitForChild("DraggableObject"))
local Events = script.Parent.Events

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

    self.PendingStorage = nil
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
    self.DragFrame.DragStarted = function()
        self.Item.Parent = self.Item.Parent.Parent.Parent
        self.Item.Position = UDim2.fromOffset(self.Item.AbsolutePosition - self.StorageData.Storage.AbsolutePosition)
        -- make the tiles that the item was on claimable
        self:UnclaimCurrentTiles()
        HoverConnection = self:GetItemHover() -- for indicating which spaces are valid for our item to be placed in 
        rotateConnection = self:GetRotate() -- rotating the part when player hits "R" on keyboard
    end 

    -- lock item into a valid set of tiles
    self.DragFrame.DragEnded = function()
        if self.PendingStorageData ~= nil then
            local pos = self.Item.AbsolutePosition - self.PendingStorageData.Storage.AbsolutePosition 
            self.Item.Parent = self.PendingStorageData.Storage
            self.Item.Position = UDim2.fromOffset(pos.X, pos.Y)
        else 
            self.Item.Parent = self.StorageData.Storage
        end
        -- reset the connection so the item isn't rotatable after placing it 
        self.DragFrame.Dragged = nil
        rotateConnection:Disconnect()
        rotateConnection = nil
        local width = self.Item:GetAttribute("Width")
        local height = self.Item:GetAttribute("Height")
        local x, y, valid = self:CheckValidLocation(width, height)
        local tileX = valid and x or self.TileX
        local tileY = valid and y or self.TileY
        if valid then
            self.CurrentOrientation = self.Item.Rotation
        else 
            self:HoverClear(x, y)

            -- Origin Storage Reset
            if self.PendingStorageData ~= self.StorageData then 
                self.Item.Parent = self.StorageData.Storage 
                self.PendingStorageData = nil
            end 

            -- Origin Orientation
            if self.Item.Rotation ~= self.CurrentOrientation then
                self.Item:SetAttribute("Width", height)
                self.Item:SetAttribute("Height", width)
            end
            if self.CurrentOrientation % 180 ~= 0 and width ~= height then 
                self.Offset = UDim2.fromOffset(TileSize/2, -TileSize/2)
            elseif width ~= height then
                self.Offset = UDim2.fromOffset(0,0)
            end 
            self.Item.Rotation = self.CurrentOrientation
        end 
        self:ChangeLocationWithinStorage(tileX, tileY)
        self:HoverClear(tileX,tileY)
        if self.PendingStorageData then
            self.StorageData = self.PendingStorageData
            self.PendingStorageData = nil
        end
        self.OriginPosition = self.Item.Position
    end


    -- [[ STORAGE CHANGE EVENT ]] --
    Events:WaitForChild("StorageEnter").Event:Connect(function(Storage, X, Y) 
        if not self.DragFrame.Dragging then return end 
        if Storage == self.StorageData.Storage  then -- when the object frame hovers back to the original storage frame
            self.PendingStorageData = nil
        end 
        -- when user hovers the frame onto another storage frame
        if (not self.PendingStorageData and self.StorageData.Storage ~= Storage) or (self.PendingStorageData and self.PendingStorageData.Storage ~= Storage) then 
            self.PendingStorageData = InventoryHandler.GetDataFromStorage(Storage)
        end 
    end)

    return self
end

function InventoryItem:GetItemHover()

    local lastX, lastY = nil, nil
    local lastWidth = self.Item:GetAttribute("Width")
    local lastHeight = self.Item:GetAttribute("Height")
    local lastStorageData = nil

    self.DragFrame.Dragged = function()
        local width = self.Item:GetAttribute("Width")
        local height = self.Item:GetAttribute("Height")

        local StorageData = self.PendingStorageData or self.StorageData

        lastStorageData = lastStorageData or StorageData
        if lastX and lastY then 
            for X = lastX, lastX + lastWidth - 1 do
                for Y = lastY, lastY + lastHeight - 1 do 
                    lastStorageData.Tiles[X][Y]["TileFrame"].BackgroundColor3 = Color3.fromRGB(255,255,255)
                end 
            end
        end 

        local x, y, valid = self:CheckValidLocation(width, height)

        local color = nil
        if valid then 
            -- Color when item is possible to place
            color =Color3.fromRGB(44, 240, 125)
        else 
            -- Color when item is impossible to palce 
            color =Color3.fromRGB(215, 43, 43)
        end 
        for X = x, x + width - 1 do
            for Y = y, y + height - 1 do 
                StorageData.Tiles[X][Y]["TileFrame"].BackgroundColor3 = color
            end 
        end

        lastX = x
        lastY = y

        lastWidth = width
        lastHeight = height

        lastStorageData = StorageData
    end
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

function InventoryItem:CheckValidLocation(width, height) 
	local ItemPosition = self.Item.Position
	
    local StorageData = self.PendingStorageData or self.StorageData

	local MaxTilesX = #StorageData.Tiles
	local MaxTilesY = #StorageData.Tiles[0]

    local tiles = StorageData.Tiles

    local YOffset = StorageData.Storage.Parent.Parent.CanvasPosition.Y

    local delta = StorageData.Storage.AbsolutePosition - StorageData.Storage.Parent.Parent.AbsolutePosition 
    local pos = ItemPosition - self.Offset - UDim2.fromOffset(delta.X, delta.Y + YOffset)

    if self.PendingStorageData and not self.DragFrame.Dragging then 
        pos = ItemPosition - self.Offset 
    end

    local X = pos.X.Offset
    local Y = pos.Y.Offset

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
    local StorageData = self.PendingStorageData or self.StorageData
    StorageData.ClaimTiles(tileX, tileY, width, height, self.Item)
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
    local StorageData = self.PendingStorageData or self.StorageData
    for X = lastX, lastX + width - 1 do
        for Y = lastY, lastY + height - 1 do 
            StorageData.Tiles[X][Y]["TileFrame"].BackgroundColor3 = Color3.fromRGB(255,255,255)
        end 
    end
end 

function InventoryItem:UnclaimCurrentTiles()
    local width = self.Item:GetAttribute("Width")
	local height = self.Item:GetAttribute("Height")

    self.StorageData.UnclaimTiles(self.TileX, self.TileY, width, height)
end 


return InventoryItem
