--!strict
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Rules = require(game:GetService("ReplicatedStorage").Shared.SessionRules)

local MovementInput = {}

function MovementInput.start(player: Player)
	local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript)
	local controls = playerModule:GetControls()
	local nativeMenu = GuiService.MenuIsOpen
	local focused = true
	local blocked: boolean? = nil
	local function update()
		local nextBlocked = Rules.blocked(player) or nativeMenu or not focused
			or UserInputService:GetFocusedTextBox() ~= nil
		if nextBlocked == blocked then return end
		blocked = nextBlocked
		-- Disable resets the controller's held keys, jump and movement vector.
		-- Sinking WASD events instead can hide End from an already-held key.
		if nextBlocked then controls:Disable() else controls:Enable() end
	end
	for _, attribute in { "SessionBlocked", "TeamMenuOpen", "SettingsOpen" } do
		player:GetAttributeChangedSignal(attribute):Connect(update)
	end
	GuiService.MenuOpened:Connect(function() nativeMenu = true; update() end)
	GuiService.MenuClosed:Connect(function() nativeMenu = false; update() end)
	UserInputService.WindowFocusReleased:Connect(function() focused = false; update() end)
	UserInputService.WindowFocused:Connect(function() focused = true; update() end)
	UserInputService.TextBoxFocused:Connect(update)
	-- Defer until GetFocusedTextBox reflects the released text box.
	UserInputService.TextBoxFocusReleased:Connect(function() task.defer(update) end)
	player.CharacterAdded:Connect(function()
		blocked = nil
		update()
	end)
	update()
end

return MovementInput
