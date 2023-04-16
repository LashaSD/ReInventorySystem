-- print("Hello world, from client!")

local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

print("Character Loaded ".. Character.Name)