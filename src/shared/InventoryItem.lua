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

local TileSize = ReplicatedStorage.Common.UiFrames.Tile.Size.X.Offset

local InventoryItem = {}
InventoryItem.__index = InventoryItem

function InventoryItem.new(ItemData)
	local self = setmetatable(ItemData, InventoryItem)

    local x, y = InventoryHandler.CheckFreeSpace(self.StorageData, tonumber(self.Item:GetAttribute("Width")), tonumber(self.Item:GetAttribute("Height")))

	self.TileX = ItemData.TileX or x
	self.TileY = ItemData.TileY or y

    if not self.TileX or not self.TileY then return nil end

    self.Equipped = self.Type and false or nil

    self.DragFrame = DragabbleItem.new(self.Item)

    self.Offset = ItemData.Offset or UDim2.fromOffset(0,0)

    self.OriginPosition = nil

    self.Item.Rotation = ItemData.Rotation or 0

    self.OriginOrientation = self.Item.Rotation
    self.CurrentOrientation = self.Item.Rotation

    self.PendingStorage = nil

	return self
end

function InventoryItem:Init()
    TileSize = math.floor(Players.LocalPlayer.PlayerGui.Inventory.AbsoluteSize.X * 30 / 1280)
    self.Connections = {}

	local width = self.Item:GetAttribute("Width")
	local height = self.Item:GetAttribute("Height")

    self.Item.Parent = self.StorageData.Storage
    self.Item.Size = UDim2.new(0, TileSize * width, 0, TileSize * height)

	self:ChangeLocationWithinStorage(self.TileX, self.TileY)
    self:UpdateServer()

    if self.StorageData.Storage.Parent.Name == 'c' then
        local parsedData = {["TileX"] = self.TileX, ["TileY"] = self.TileY, 
            ["Name"] = self.Item.Name, 
            ["Offset"] = self.Offset, ["Rotation"] = self.CurrentOrientation, 
            ["Width"] = self.Item:GetAttribute("Width"), ["Height"] = self.Item:GetAttribute("Height"),
            ["Type"] = self.Type}
        StorageUnitActions:FireServer("updatedata", self.StorageData.Id, self.Id, parsedData)
    end

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
            local parsedData = {["TileX"] = x, ["TileY"] = y, 
            ["Name"] = self.Item.Name, 
            ["Offset"] = self.Offset, ["Rotation"] = self.CurrentOrientation, 
            ["Width"] = self.Item:GetAttribute("Width"), ["Height"] = self.Item:GetAttribute("Height"),
            ["Type"] = self.Type}

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
                        BaseComp.Equipped(self.Type, self.Item, self.Id, self.PendingStorageData.Id)
                    end
                elseif self.PendingStorageData and not self.PendingStorageData.Type then
                    if self.Equipped then
                        self.Equipped = false
                        BaseComp.Unequipped(self.Type, self.Item, self.Id, self.StorageData.Id)
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
            local x1 = width
            local x2 = height
            if self.Item.Rotation ~= self.CurrentOrientation then
                self.Item:SetAttribute("Width", height)
                self.Item:SetAttribute("Height", width)
                x1 = height
                x2 = width
            end
            if self.CurrentOrientation % 180 ~= 0 and width ~= height then 
                self.Offset = UDim2.fromOffset((x1 - x2)/2 * TileSize, (x2-x1)/2 * TileSize) 
            elseif width ~= height then
                self.Offset = UDim2.fromOffset(0,0)
            end 
            self.Item.Rotation = self.CurrentOrientation
        end 
        self:ChangeLocationWithinStorage(tileX, tileY)
        self:UpdateServer()
        if self.PendingStorageData then
            self.StorageData = self.PendingStorageData
            self.PendingStorageData = nil
            self:UpdateServer()
        end
        self.OriginPosition = self.Item.Position
    end


    -- [[ STORAGE CHANGE EVENT ]] --
    local StorageEnter = Events:WaitForChild("StorageEnter").Event:Connect(function(Inventory, Storage) 
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

    table.insert(self.Connections, StorageEnter)
    local InfoBoxFrame = nil
    local connection1 = nil
    local connection2 = nil

    local rarityColors = {
        ["common"] = Color3.fromRGB(148, 148, 148),
        ["uncommon"] = Color3.fromRGB(104, 216, 24),
        ["rare"] = Color3.fromRGB(0, 123, 255),
        ["epic"] = Color3.fromRGB(221, 0, 255),
        ["exotic"] = Color3.fromRGB(255, 234, 9),
    }


    local infoOnHover = self.Item.MouseEnter:Connect(function()
        local plr = Players.LocalPlayer
        local ItemInfoFound = plr.PlayerGui.Inventory.MainFrame.GridMainFrame:FindFirstChild("ItemInfo")
        if plr.PlayerGui.Inventory.MainFrame.GridMainFrame:FindFirstChild("DeleteFrame") or self.DragFrame.Dragging then
            if InfoBoxFrame then InfoBoxFrame:Destroy() end
            if connection1 then connection1:Disconnect() end
            if connection2 then connection2:Disconnect() end 
            return nil
        end

        if ItemInfoFound then
            ItemInfoFound:Destroy()
        end
        if InfoBoxFrame then InfoBoxFrame:Destroy() end

        local invWidth = self.Item:GetAttribute("InventoryWidth")
        local invHeight = self.Item:GetAttribute("InventoryHeight")

        InfoBoxFrame = ReplicatedStorage.Common.UiFrames:WaitForChild("ItemInfo"):Clone()
        InfoBoxFrame.Name = "ItemInfo"
        InfoBoxFrame.ItemFrame.ItemName.Text = self.Item.Name

        local rarity = self.Item:GetAttribute("Rarity")
        local rarityColor = rarityColors[rarity]
        if rarity and rarityColor then
            InfoBoxFrame.ItemFrame.ItemName.TextColor3 = rarityColor
        end

        InfoBoxFrame.StorageInfo.Info.Text = invWidth and "Storage: ".. invWidth.. "x".. invHeight or "Storage: 0x0"

        InfoBoxFrame.RarityInfo.Info.Text = rarityColor and "Rarity: ".. string.upper(rarity) or "Rarity: NONE"
        InfoBoxFrame.RarityInfo.Info.TextColor3 = rarityColor or InfoBoxFrame.RarityInfo.Info.TextColor3

        InfoBoxFrame.TypeInfo.Info.Text = self.Type and "Type: "..string.upper(self.Type) or "Type: NONE"

        local Mouse = plr:GetMouse()
        local x = Mouse.X
        local y = Mouse.Y 
        local pos = Vector2.new(x, y) - self.Item.Parent.Parent.Parent.Parent.AbsolutePosition

        InfoBoxFrame.Parent = self.StorageData.Storage.Parent.Parent.Parent
        InfoBoxFrame.Position = UDim2.fromOffset(pos.x  + 25, pos.y - 25)

        connection1 = self.Item.MouseMoved:Connect(function()
            if self.DragFrame.Dragging then return nil end
            x = Mouse.X
            y = Mouse.Y 
            pos = Vector2.new(x, y) - self.Item.Parent.Parent.Parent.Parent.AbsolutePosition
            InfoBoxFrame.Position = UDim2.fromOffset(pos.x + 25, pos.y - 25)
        end)
        connection2 = self.Item.MouseLeave:Connect(function()
            if InfoBoxFrame then
                InfoBoxFrame:Destroy()
            end
            connection1:Disconnect()
            connection2:Disconnect()
        end)
    end)

    table.insert(self.Connections, infoOnHover)

    local ItemOptions = nil
    local confirmText = "Are You Sure?"
    local Options = self.Item.InputBegan:Connect(function(InputObject)
        if InputObject.UserInputType == Enum.UserInputType.MouseButton2 then
            if InfoBoxFrame then InfoBoxFrame:Destroy(); if connection1  then connection1:Disconnect() end end

            ItemOptions = ReplicatedStorage.Common.UiFrames:WaitForChild("ItemOptions"):Clone()
            local DeleteFrame = ItemOptions.DeleteFrame
            local DropFrame = ItemOptions.DropFrame

            if self.StorageData.Storage.Parent.Name ~= "b" then DeleteFrame.Visible = false end

            local Mouse = Players.LocalPlayer:GetMouse()
            local x = Mouse.X
            local y = Mouse.Y 
            local pos = Vector2.new(x, y) - self.Item.Parent.Parent.Parent.Parent.AbsolutePosition
            local YOffset = self.StorageData.Storage.Parent.CanvasPosition.Y

            ItemOptions.Position = UDim2.fromOffset(pos.x, pos.y + YOffset)
            ItemOptions.Parent = self.StorageData.Storage.Parent.Parent.Parent

            local connection3 = nil
            local connection4 = nil
            local connection5 = nil

            connection3 = DeleteFrame.ItemFrame.TextButton.MouseButton1Click:Connect(function()
                if DeleteFrame.ItemFrame.TextButton.Text == confirmText then
                    if connection2 then connection2:Disconnect() end
                    if connection4 then connection4:Disconnect() end
                    ItemOptions:Destroy()
                    self:Destroy()
                    return
                else
                    DeleteFrame.ItemFrame.TextButton.Text = confirmText
                end
            end)

            connection4 = DropFrame.ItemFrame.TextButton.MouseButton1Click:Connect(function()
                if connection2 then connection2:Disconnect() end
                if connection3 then connection3:Disconnect() end
                connection4:Disconnect()
                ItemOptions:Destroy()
                self:Drop()
                return
            end)

            local bool = true
            local bool1 = true

            connection5 = self.Item.MouseLeave:Connect(function()
                bool1 = true
                if bool then
                    ItemOptions:Destroy()
                    connection2:Disconnect()
                end
            end)
            ItemOptions.MouseEnter:Connect(function() bool = false end)
            ItemOptions.MouseLeave:Connect(function()
                bool = true 
                if bool1 then
                    ItemOptions:Destroy()
                    if connection5 then connection5:Disconnect() end
                end
            end)
        elseif InputObject.UserInputType == Enum.UserInputType.MouseButton1 then
            if InfoBoxFrame then InfoBoxFrame:Destroy() end
            if connection1 then connection1:Disconnect() end
            if connection2 then connection2:Disconnect() end 
        end
    end)

    table.insert(self.Connections, Options)

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
                -- height - width because we switched them on the previous lines so the original equation is width - height
                self.Offset = UDim2.fromOffset((x1 - x2)/2 * TileSize, (x2-x1)/2 * TileSize) 
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

function InventoryItem:UpdateServer()
    if self.StorageData.Storage.Parent.Name == "b" then
        local ClaimedTiles = self:GetClaimedTiles()
        InventoryActions:FireServer('updatedata', self.StorageData.Id, self.Id, ClaimedTiles)
    end
end     

function InventoryItem:Destroy()
    for _, v in ipairs(self.Connections) do
        if v then
            v:Disconnect()
        end
    end
    self.DragFrame:Disable()
    self.Item:Destroy()
    self:UnclaimCurrentTiles()
    local claimedTiles = self:GetClaimedTiles()
    InventoryActions:FireServer("updatedata", self.StorageData.Id, self.Id, claimedTiles)
    InventoryActions:FireServer("removeitem", self.StorageData.Id, self.Id)
end 

function InventoryItem:Drop()
    self.Item:Destroy()
    self:UnclaimCurrentTiles()
    local claimedTiles = self:GetClaimedTiles()
    InventoryActions:FireServer("updatedata", self.StorageData.Id, self.Id, claimedTiles)
    local parsedData = {}
    parsedData.Rarity = self.Item:GetAttribute("Rarity")
    if self.StorageData.Storage.Parent.Name == "a" and self.Equipped then
        local BaseComp = require(script.Parent:FindFirstChild("Component"))
        self.Equipped = false
        BaseComp.Unequipped(self.Type, self.Item, self.Id, self.StorageData.Id)
    end
    InventoryActions:FireServer("dropitem", self.StorageData.Id, self.Id, parsedData)
end 


return InventoryItem
