local function signal()
	local callbacks = {}
	return {Connect = function(_, callback) table.insert(callbacks, callback) end,
		Fire = function(_, ...) for _, callback in callbacks do callback(...) end end}
end
local attributes, signals = {}, {}
local controller = {enabled = true, held = false, moving = false, resets = 0}
function controller:Disable()
	self.enabled, self.held, self.moving = false, false, false
	self.resets += 1
end
function controller:Enable() self.enabled = true end
function controller:keyDown() if self.enabled then self.held, self.moving = true, true end end
function controller:keyUp() if self.enabled then self.held, self.moving = false, false end end
local player = {CharacterAdded = signal()}
function player:GetAttribute(name) return attributes[name] end
function player:GetAttributeChangedSignal(name)
	if not signals[name] then signals[name] = signal() end
	return signals[name]
end
function player:SetAttribute(name, value)
	attributes[name] = value
	self:GetAttributeChangedSignal(name):Fire()
end
function player:WaitForChild() return {WaitForChild = function() return "playerModule" end} end
local gui = {MenuIsOpen = false, MenuOpened = signal(), MenuClosed = signal()}
local input = {WindowFocusReleased = signal(), WindowFocused = signal(),
	TextBoxFocused = signal(), TextBoxFocusReleased = signal()}
local textBox = nil
function input:GetFocusedTextBox() return textBox end
local services = {GuiService = gui, UserInputService = input,
	ReplicatedStorage = {Shared = {SessionRules = "rules"}}}
local game = {GetService = function(_, name) return assert(services[name]) end}
local require = function(name)
	if name == "playerModule" then return {GetControls = function() return controller end} end
	return {blocked = function()
		return attributes.SessionBlocked == true or attributes.TeamMenuOpen == true or attributes.SettingsOpen == true
	end}
end
local task = {defer = function(callback) callback() end}
local movement = (function()
-- MOVEMENT_INPUT_MODULE_HERE
end)()
movement.start(player)
assert(controller.enabled)
for _, attribute in {"SessionBlocked", "TeamMenuOpen", "SettingsOpen"} do
	controller:keyDown()
	player:SetAttribute(attribute, true)
	assert(not controller.enabled and not controller.held and not controller.moving)
	controller:keyUp() -- release during the freeze/menu cannot leave stale input
	player:SetAttribute(attribute, false)
	assert(controller.enabled and not controller.moving)
	player:SetAttribute(attribute, true)
	controller:keyDown() -- a press during freeze must not leak into combat
	player:SetAttribute(attribute, false)
	assert(not controller.held and not controller.moving)
	controller:keyDown(); assert(controller.moving)
	controller:keyUp(); assert(not controller.moving)
end
player:SetAttribute("SessionBlocked", true)
player:SetAttribute("SettingsOpen", true)
player:SetAttribute("SessionBlocked", false)
assert(not controller.enabled, "ending freeze cannot bypass settings")
player:SetAttribute("SettingsOpen", false)
controller:keyDown(); input.WindowFocusReleased:Fire()
assert(not controller.enabled and not controller.moving)
input.WindowFocused:Fire(); assert(controller.enabled and not controller.moving)
gui.MenuOpened:Fire(); assert(not controller.enabled)
gui.MenuClosed:Fire(); assert(controller.enabled)
textBox = {}; input.TextBoxFocused:Fire(); assert(not controller.enabled)
textBox = nil; input.TextBoxFocusReleased:Fire(); assert(controller.enabled)
player:SetAttribute("SessionBlocked", true)
local resets = controller.resets
player.CharacterAdded:Fire()
assert(not controller.enabled and controller.resets == resets + 1, "respawn reapplies freeze")
print("Movement: freeze/menu/focus resets held input and restores controls without drift OK")
