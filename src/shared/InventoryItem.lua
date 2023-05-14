-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Libs
local DragabbleItem = require(ReplicatedStorage.Common:WaitForChild("DraggableObject"))
local InventoryHandler = require(ReplicatedStorage.Common:WaitForChild("InventoryHandler"))

-- Directory Paths 
local Events = script.Parent.Events

-- Events 
local StorageUnitActions = Events:WaitForChild("StorageUnit")
local InventoryActions = Events:WaitForChild("Inventory")

local TileSize 

local InventoryItem = {}
InventoryItem.__index = InventoryItem

function InventoryItem.new(ItemData)
	local self = setmetatable(ItemData, InventoryItem)

    local x, y = InventoryHandler.CheckFreeSpace(self.StorageData, tonumber(self.Item:GetAttribute("Width")), tonumber(self.Item:GetAttribute("Height")))

	self.TileX = ItemData.TileX or x
	self.TileY = ItemData.TileY or y

    self.Equipped = self.Type and false or nil

    self.DragFrame = DragabbleItem.new(self.Item)

    self.Offset = UDim2.fromOffset(0,0)

    self.OriginPosition = nil

    self.OriginOrientation = self.Item.Rotation
    self.CurrentOrientation = self.Item.Rotation

    self.PendingStorage = nil

	return self
end

function InventoryItem:Init()
    TileSize = 30

	local width = self.Item:GetAttribute("Width")
	local height = self.Item:GetAttribute("Height")

    self.Item.Parent = self.StorageData.Storage
    self.Item.Size = UDim2.new(0, TileSize * width, 0, TileSize * height)

	self:ChangeLocationWithinStorage(self.TileX, self.TileY)
    local ClaimedTiles = self:GetClaimedTiles()
    InventoryActions:FireServer('updatedata', self.StorageData.Id, self.Id, ClaimedTiles)

    self.OriginPosition = self.Item.Position

    -- make draggable
    self.DragFrame:Enable()

    local HoverConnection = nil
    local rotateConnection = nil
    self.DragFrame.DragStarted = function()
        self.Item.Parent = self.Item.Parent.Parent.Parent.Parent
        if self.StorageData.Type then self.Item.Parent = self.Item.Parent.Parent end  
        self.Item.Position = UDim2.fromOffset(self.Item.AbsolutePosition - self.StorageData.Storage.AbsolutePosition)
        -- make the tiles that the item was on claimable
        self:UnclaimCurrentTiles()
        -- HoverConnection = self:GetItemHover() -- for indicating which spaces are valid for our item to be placed in 
        rotateConnection = self:GetRotate() -- rotating the part when player hits "R" on keyboard
    end 

    -- lock item into a valid set of tiles
    self.DragFrame.DragEnded = function()
        if self.PendingStorageData then
            -- translates the relative position to the pending storage
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

        -- we redefine width and height because it might change when rotating the item
        width = self.Item:GetAttribute("Width")
        height = self.Item:GetAttribute("Height")
        local x, y, valid = self:CheckValidLocation(width, height)

        local tileX = valid and x or self.TileX
        local tileY = valid and y or self.TileY
        
        if valid then
            self.CurrentOrientation = self.Item.Rotation
            local parsedData = {["TileX"] = x, ["TileY"] = y, ["Name"] = self.Item.Name}

            -- Storage Unit Logic Update Item Location
            if not self.PendingStorageData and self.StorageData.Storage.Parent.Name == 'c' then 
                StorageUnitActions:FireServer("updatedata", self.StorageData.Id, self.Id, parsedData)
            end

            -- Storage Unit Logic Remove Item
            if (self.PendingStorageData and self.PendingStorageData.Storage.Parent.Name ~= "c") and self.StorageData.Storage.Parent.Name == "c" then
                StorageUnitActions:FireServer("removeitem", self.StorageData.Id, self.Id, parsedData)
            end 

            -- Interaction Component Handler
            if self.Type then
                local BaseComp = require(script.Parent:FindFirstChild("Component"))
                if self.PendingStorageData and self.PendingStorageData.Type then
                    if not self.Equipped then
                        self.Equipped = true
                        BaseComp.Equipped(self.Type, self.Item, self.Id)
                    end
                elseif self.PendingStorageData and not self.PendingStorageData.Type then
                    if self.Equipped then
                        self.Equipped = false
                        BaseComp.Unequipped(self.Type, self.Item, self.Id)
                    end
                end
            end

            -- Storage Unit Logic Add Item
            if self.PendingStorageData and self.PendingStorageData.Storage.Parent.Name == "c" then -- when we add item to storage unit
                StorageUnitActions:FireServer("additem", self.PendingStorageData.Id, self.Id, parsedData)
            end
        else

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
        if valid then
            local ClaimedTiles = self:GetClaimedTiles()
            InventoryActions:FireServer('updatedata', self.StorageData.Id, self.Id, ClaimedTiles)
        end
        if self.PendingStorageData then
            self.StorageData = self.PendingStorageData
            self.PendingStorageData = nil
            if valid then
                local ClaimedTiles = self:GetClaimedTiles()
                InventoryActions:FireServer('updatedata', self.StorageData.Id, self.Id, ClaimedTiles)
            end
        end
        self.OriginPosition = self.Item.Position
    end


    -- [[ STORAGE CHANGE EVENT ]] --
    Events:WaitForChild("StorageEnter").Event:Connect(function(Inventory, Storage) 
        if not self.DragFrame.Dragging then return end 
        -- when the object frame hovers back to the original storage frame
        if Storage == self.StorageData.Storage  then 
            self.PendingStorageData = nil
        end 
        -- when the object frame hovers on another storage frame
        if (not self.PendingStorageData and self.StorageData.Storage ~= Storage) or (self.PendingStorageData and self.PendingStorageData.Storage ~= Storage) then 
            self.PendingStorageData = _G.Cache
            _G.Cache = nil
        end 
    end)
    local frame = nil
    self.Item.InputBegan:Connect(function(InputObject)
        if InputObject.UserInputType == Enum.UserInputType.MouseButton2 then
            if frame then frame:Destroy() end
            local Mouse = Players.LocalPlayer:GetMouse()

            local x = Mouse.X
            local y = Mouse.Y 
            local pos = Vector2.new(x, y) - self.Item.Parent.Parent.AbsolutePosition
            frame = ReplicatedStorage.Common:WaitForChild("ItemInfo"):Clone()
            frame.ItemFrame.ItemName.Text = self.Item.Name
            local invWidth = self.Item:GetAttribute("InventoryWidth")
            local invHeight = self.Item:GetAttribute("InventoryHeight")
            frame.InfoFrame.StorageInfo.Text = invWidth and "Added Storage: ".. invWidth.. "x".. invHeight or "0x0"
            frame.Parent = self.StorageData.Storage.Parent.Parent
            frame.Position = UDim2.fromOffset(pos.x, pos.y)

            local bool = true
            local bool1 = true

            local connection2 = nil
            connection2 = self.Item.MouseLeave:Connect(function()
                bool1 = true
                if bool then
                    frame:Destroy()
                    connection2:Disconnect()
                end
            end)
            frame.MouseEnter:Connect(function() bool = false end)
            frame.MouseLeave:Connect(function()
                bool = true 
                if bool1 then
                    frame:Destroy()
                    connection2:Disconnect()
                end
            end)

            if self.StorageData.Storage.Parent.Name ~= "c" then
                frame.DeleteFrame.DeleteButton.MouseButton1Click:Connect(function()
                    local confirmFrame = ReplicatedStorage.Common:WaitForChild("Confirmation"):Clone()
                    confirmFrame.Parent = self.StorageData.Storage
                    confirmFrame.Position = UDim2.fromOffset(pos.x + 25, pos.y + 25)
                    confirmFrame.Confirmation.TextButton.MouseButton1Click:Connect(function()
                        connection2:Disconnect()
                        frame:Destroy()
                        confirmFrame:Destroy()
                        self:UnclaimCurrentTiles()
                        local claimedTiles = self:GetClaimedTiles()
                        InventoryActions:FireServer("updatedata", self.StorageData.Id, self.Id, claimedTiles)
                        InventoryActions:FireServer("removeitem", self.StorageData.Id, self.Id)
                        self.Item:Destroy()
                    end)
                end)
            else 
                frame.DeleteButton.Visible = false
            end
        end
    end)

    -- self.Item.MouseEnter:Connect(function()
    --     local Mouse = Players.LocalPlayer:GetMouse()
    --     UserInputService.MouseIconEnabled = false
    --     -- Mouse.
    --     local x = Mouse.X
    --     local y = Mouse.Y 
    --     local pos = Vector2.new(x, y) - self.Item.AbsolutePosition
    --     local frame = Instance.new("Frame")
    --     frame.Parent = self.StorageData.Storage
    --     frame.Position = UDim2.fromOffset(pos.x, pos.y)
    --     frame.Size = UDim2.fromOffset(100, 100)
    --     local connection1 = self.Item.MouseMoved:Connect(function() 
    --         x = Mouse.X
    --         y = Mouse.Y 
    --         pos = Vector2.new(x, y) - self.Item.AbsolutePosition
    --         frame.Position = UDim2.fromOffset(pos.x, pos.y)
    --     end)
    --     local connection2 = nil
    --     connection2 = self.Item.MouseLeave:Connect(function()
    --         UserInputService.MouseIconEnabled = true
    --         frame:Destroy()
    --         connection1:Disconnect()
    --         connection2:Disconnect()
    --     end)

    -- end)

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
                    lastStorageData.Tiles[X][Y]["TileFrame"].BackgroundTransparency = 0
                end 
            end
        end 

        local x, y, valid = self:CheckValidLocation(width, height)
        if x == -1 or y == -1 then
            return nil
        end

        local transparency = 0
        if not valid then 
            -- Color when item is impossible to palce 
            transparency = 0.5;
        end 
        for X = x, x + width - 1 do
            for Y = y, y + height - 1 do 
                StorageData.Tiles[X][Y]["TileFrame"].BackgroundTransparency = 0.5
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
                local x1 = height 
                local x2 = width
                self.Offset = UDim2.fromOffset((x1 - x2)/2 * TileSize, (x2-x1)/2 * TileSize) -- height - width because we switched them on the previous lines
                print(self.Offset)
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

    if tonumber(width) > tonumber(MaxTilesX)+1 or tonumber(height) > tonumber(MaxTilesY)+1 then
        return -1,-1, false
    end 

    local tiles = StorageData.Tiles

    local delta = StorageData.Storage.AbsolutePosition - StorageData.Storage.Parent.Parent.Parent.AbsolutePosition 
    local pos = ItemPosition - self.Offset - UDim2.fromOffset(delta.X, delta.Y)

    if self.PendingStorageData and not self.DragFrame.Dragging then 
        pos = ItemPosition - self.Offset 
    end

    local x = pos.X.Offset
    local y = pos.Y.Offset

    local translateX = math.floor(x/TileSize)
    local translateY = math.floor(y/TileSize)

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

    if StorageData.Type then
        if StorageData.Type ~= self.Type then
            return -1, -1, false
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
    -- self:HoverClear(tileX, tileY)
end

function InventoryItem:HoverClear(lastX, lastY)
    local width = self.Item:GetAttribute("Width")
	local height = self.Item:GetAttribute("Height")
    local StorageData = self.PendingStorageData or self.StorageData
    for X = lastX, lastX + width - 1 do
        for Y = lastY, lastY + height - 1 do 
            StorageData.Tiles[X][Y]["TileFrame"].BackgroundTransparency = 0
        end 
    end
end 

function InventoryItem:UnclaimCurrentTiles()
    local width = self.Item:GetAttribute("Width")
	local height = self.Item:GetAttribute("Height")

    self.StorageData.UnclaimTiles(self.TileX, self.TileY, width, height)
end 

function InventoryItem:GetClaimedTiles()
    local tiles = self.StorageData.Tiles
    local data = {}
    for x = 0, #tiles do
        local yTiles = tiles[x]
        for y = 0, #yTiles do
            local Data = yTiles[y]
            if Data["Claimed"] then
                if not data[tostring(x)] then
                    data[tostring(x)] = {}
                end
                table.insert(data[tostring(x)], y)
            end
        end
    end
    return data
end 


return InventoryItem
