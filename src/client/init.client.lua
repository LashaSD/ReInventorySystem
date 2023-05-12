--- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

--- Libs
local InventoryMod = require(ReplicatedStorage.Common:WaitForChild("Inventory"))
local StorageUnitMod = require(ReplicatedStorage.Common:WaitForChild("StorageUnit"))

--- Directories 
local Events = ReplicatedStorage.Common.Events

-- Vars
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

local InventoryUi = Player.PlayerGui:WaitForChild("Inventory")

-- Local Inventory Init
local PlayerInventory = InventoryMod.new()
local PlayerStorageUnit = nil

Events.GetStorageData.OnClientEvent:Connect(function(ServerData) -- sync Client Data with Server Data (replication)
	local ServerPlayerStorage = ServerData["MainStorage"]
	local ServerPlayerUnitData = ServerData["StorageUnit"]

	if PlayerInventory and ServerPlayerStorage then
		PlayerInventory.Queue = ServerPlayerStorage.Queue
		PlayerInventory.RemovalQueue = ServerPlayerStorage.RemovalQueue
		PlayerInventory:GenerateQueue()
		PlayerInventory:EmptyRemovalQueue()
	end

	print(ServerData)

	if ServerPlayerUnitData then
		PlayerStorageUnit = StorageUnitMod.new(ServerPlayerUnitData) 
		PlayerStorageUnit:GenerateUi()
	end

end)


-- Inventory Open Bind

UserInputService.InputBegan:Connect(function(input) 
	if input.KeyCode == Enum.KeyCode.Tab then	
		InventoryUi.MainFrame.Visible = not InventoryUi.MainFrame.Visible 
	end
end)