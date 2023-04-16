--- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--- Libs
local InventoryMod = require(ReplicatedStorage.Common.InventoryHandler)

--- Directories 
local Events = ReplicatedStorage.Common.Events


local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()


local ServerInventory = Events.GetStorageData:InvokeServer()
local PlayerInventory = InventoryMod.new()
PlayerInventory.StorageQueue = ServerInventory.StorageQueue

if PlayerInventory then
	print(PlayerInventory)
	PlayerInventory:GenerateStoragesQueue()
end 