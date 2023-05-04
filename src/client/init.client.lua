--- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

--- Libs
local InventoryMod = require(ReplicatedStorage.Common.Inventory)

--- Directories 
local Events = ReplicatedStorage.Common.Events

-- Vars
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

local InventoryUi = Player.PlayerGui:WaitForChild("Inventory")

-- Local Inventory Init
local PlayerInventory = InventoryMod.new()

Events.GetStorageData.OnClientEvent:Connect(function(ServerInventory)
	PlayerInventory.Queue = ServerInventory.Queue
	PlayerInventory.RemovalQueue = ServerInventory.RemovalQueue
	if PlayerInventory then
		PlayerInventory:GenerateQueue()
		PlayerInventory:EmptyRemovalQueue()
	end
end)


-- Inventory Open Bind

UserInputService.InputBegan:Connect(function(input) 
	if input.KeyCode == Enum.KeyCode.Tab then	
		InventoryUi.MainFrame.Visible = not InventoryUi.MainFrame.Visible 
	end
end)