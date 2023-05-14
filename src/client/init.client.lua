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

-- Client Side Inventory
local PlayerInventory = InventoryMod.new()

-- Inventory Ui functions 

local function OpenInventory()
	InventoryUi.MainFrame.Visible = true
end 

local function CloseInventory()
	InventoryUi.MainFrame.Visible = false
end 

local function TriggerInventory()
	InventoryUi.MainFrame.Visible = not InventoryUi.MainFrame.Visible
end 

-- sync Client Data with Server Data (replication)
Events.GetStorageData.OnClientEvent:Connect(function(ServerPlayerStorage, ServerPlayerUnitData) 

	if not PlayerInventory then return nil end

	if ServerPlayerStorage then
		PlayerInventory.Queue = ServerPlayerStorage.Queue
		PlayerInventory.RemovalQueue = ServerPlayerStorage.RemovalQueue
		PlayerInventory:GenerateQueue()
		PlayerInventory:EmptyRemovalQueue()
	end

	if ServerPlayerUnitData then
		-- check if it's queued for deauthorization
		if ServerPlayerUnitData.AuthorizationData == 'deauthorize' and PlayerInventory.StorageUnit then
			PlayerInventory.StorageUnit:Deauthorize()
			PlayerInventory.StorageUnit.AuthorizationData = nil
			PlayerInventory.StorageUnit = nil
			CloseInventory()
			return nil
		end

		local PlayerStorageUnit = StorageUnitMod.new(ServerPlayerUnitData) -- create a client side storage unit object from server passed data
		PlayerInventory.StorageUnit = PlayerStorageUnit
		PlayerInventory.StorageUnit:GenerateUI(PlayerInventory) -- build ui grid 
		if not InventoryUi.MainFrame.Visible then OpenInventory() end  -- if the inventory isnt visible open it
	end

end)


-- Inventory Ui Open Bind
UserInputService.InputBegan:Connect(function(input) 
	if input.KeyCode == Enum.KeyCode.Tab then
		TriggerInventory()	
		if not InventoryUi.MainFrame.Visible then
			if PlayerInventory.StorageUnit then
				PlayerInventory.StorageUnit:Deauthorize()
			end
		end 
	end
end)