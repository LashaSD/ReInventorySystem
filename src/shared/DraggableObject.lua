local UDim2_new = UDim2.new

local UserInputService = game:GetService("UserInputService")

local DraggableObject 		= {}
DraggableObject.__index 	= DraggableObject

-- Sets up a new draggable object
function DraggableObject.new(Object)
	local self 			= setmetatable({}, DraggableObject)
	self.Object			= Object
	self.DragStarted	= nil
	self.DragEnded		= nil
	self.Dragged		= nil
	self.Dragging		= false
	
	return self
end

-- Enables dragging
function DraggableObject:Enable()
	local object			= self.Object
	local dragInput			= nil
	local startPos			= nil
	local preparingToDrag	= false
	
	-- Updates the element
	local function update(input)
		local delta 		= Vector2.new(input.Position.X, input.Position.Y) - object.AbsolutePosition - object.AbsoluteSize/2

		local newPosition	= UDim2_new(0, object.Position.X.Offset + delta.X, 0, object.Position.Y.Offset + delta.Y) 
		object.Position 	= newPosition

		return newPosition
	end
	
	self.InputBegan = object.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			preparingToDrag = true
			--[[if self.DragStarted then
				self.DragStarted()
			end
			
			dragging	 	= true
			dragStart 		= input.Position
			startPos 		= Element.Position
			--]]
			
			local connection 
			connection = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End and (self.Dragging or preparingToDrag) then
					self.Dragging = false
					connection:Disconnect()
					
					if self.DragEnded and not preparingToDrag then
						self.DragEnded()
					end
					
					preparingToDrag = false
				end
			end)
		end
	end)
	
	self.InputChanged = object.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)
	
	self.InputChanged2 = UserInputService.InputChanged:Connect(function(input)
		if object.Parent == nil then
			self:Disable()
			return
		end
		
		if preparingToDrag then
			preparingToDrag = false
			
			if self.DragStarted then
				self.DragStarted()
			end
			
			self.Dragging	= true
		end
		
		if input == dragInput and self.Dragging then
			local newPosition = update(input)
			
			if self.Dragged then
				self.Dragged(newPosition)
			end
		end
	end)

	self.ChangePosition = function(Pos) 
		startPos = Pos
	end
end

-- Disables dragging
function DraggableObject:Disable()
	self.InputBegan:Disconnect()
	self.InputChanged:Disconnect()
	self.InputChanged2:Disconnect()
	
	if self.Dragging then
		self.Dragging = false
		
		if self.DragEnded then
			self.DragEnded()
		end
	end
end

return DraggableObject
