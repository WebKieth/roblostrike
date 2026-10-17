--!strict
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.AudioSettings)
local Settings = {}

function Settings.start(player: Player)
	Audio.start()
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "AudioSettings", false, 50
	gui.Parent = player:WaitForChild("PlayerGui")
	local function button(parent: Instance, text: string, size: UDim2, position: UDim2): TextButton
		local b = Instance.new("TextButton")
		b.Text, b.Size, b.Position = text, size, position
		b.BackgroundColor3, b.TextColor3 = Color3.fromRGB(34, 46, 63), Color3.fromRGB(235, 242, 250)
		b.Font, b.TextSize, b.BorderSizePixel = Enum.Font.GothamMedium, 16, 0
		b.Parent = parent
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
		return b
	end
	local shortcut = button(gui, "Настройки · F10", UDim2.fromOffset(160, 32), UDim2.new(1, -180, 0, 8))
	local shade = button(gui, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	shade.Name, shade.BackgroundColor3, shade.BackgroundTransparency = "SettingsModal", Color3.new(0, 0, 0), 0.3
	shade.AutoButtonColor, shade.Modal, shade.Visible = false, true, false
	local panel = Instance.new("Frame")
	panel.AnchorPoint, panel.Position, panel.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.new(0.92, 0, 0, 416)
	panel.BackgroundColor3, panel.BorderSizePixel, panel.Parent = Color3.fromRGB(18, 25, 36), 0, shade
	local size = Instance.new("UISizeConstraint")
	size.MaxSize, size.Parent = Vector2.new(500, 416), panel
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
	local function label(text: string, position: UDim2, height: number): TextLabel
		local result = Instance.new("TextLabel")
		result.Text, result.Position, result.Size = text, position, UDim2.new(1, -40, 0, height)
		result.BackgroundTransparency, result.TextColor3 = 1, Color3.fromRGB(230, 238, 247)
		result.Font, result.TextSize, result.TextXAlignment = Enum.Font.GothamMedium, 16, Enum.TextXAlignment.Left
		result.Parent = panel
		return result
	end
	label("НАСТРОЙКИ", UDim2.fromOffset(20, 12), 30).TextSize = 22
	local note = label("Изменения применяются сразу и действуют до выхода из игры.", UDim2.fromOffset(20, 46), 32)
	note.TextSize, note.TextWrapped = 12, true
	local open, native, openAfterNative = false, false, false
	local dragging: ((number) -> ())? = nil
	local touch: InputObject? = nil
	local function setOpen(value: boolean)
		open = value
		if not value then dragging, touch = nil, nil end
		shade.Visible = value and not native
		player:SetAttribute("SettingsOpen", value or native)
	end
	local sensitivity = 1
	local function get(channel: string): number
		return if channel == "Sensitivity" then sensitivity else Audio.get(channel)
	end
	for index, row in { { "Master", "Общая громкость" }, { "Characters", "Персонажи · шаги и смерть" }, { "Gunfire", "Стрельба" }, { "Sensitivity", "Чувствительность мыши" } } do
		local channel, title = row[1], row[2]
		local minimum, maximum = if channel == "Sensitivity" then 0.1 else 0, if channel == "Sensitivity" then 2 else 1
		local y = 84 + (index - 1) * 66
		local caption = label("", UDim2.fromOffset(20, y), 24)
		local minus = button(panel, "−", UDim2.fromOffset(30, 28), UDim2.fromOffset(20, y + 26))
		local plus = button(panel, "+", UDim2.fromOffset(30, 28), UDim2.new(1, -50, 0, y + 26))
		local track = button(panel, "", UDim2.new(1, -124, 0, 20), UDim2.fromOffset(62, y + 30))
		track.Name, track.AutoButtonColor = channel .. "Slider", false
		local fill = Instance.new("Frame")
		fill.BackgroundColor3, fill.BorderSizePixel, fill.Parent = Color3.fromRGB(82, 168, 240), 0, track
		Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 8)
		local function update(value: number)
			value = math.clamp(value, minimum, maximum)
			if channel == "Sensitivity" then
				sensitivity = value
				UserInputService.MouseDeltaSensitivity = value
			else
				Audio.set(channel, value)
			end
			local volume = get(channel)
			fill.Size = UDim2.fromScale((volume - minimum) / (maximum - minimum), 1)
			caption.Text = string.format("%s  ·  %d%%", title, math.floor(volume * 100 + 0.5))
		end
		local function at(x: number)
			if track.AbsoluteSize.X > 0 then update(minimum + (maximum - minimum) * (x - track.AbsolutePosition.X) / track.AbsoluteSize.X) end
		end
		minus.Activated:Connect(function() update(get(channel) - 0.05) end)
		plus.Activated:Connect(function() update(get(channel) + 0.05) end)
		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging, touch = at, if input.UserInputType == Enum.UserInputType.Touch then input else nil
				at(input.Position.X)
			end
		end)
		update(get(channel))
	end
	UserInputService.InputChanged:Connect(function(input)
		if dragging and open and not native and (input == touch or (not touch and input.UserInputType == Enum.UserInputType.MouseMovement)) then
			dragging(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == touch or input.UserInputType == Enum.UserInputType.MouseButton1 then dragging, touch = nil, nil end
	end)
	button(panel, "ВЕРНУТЬСЯ В ИГРУ", UDim2.new(1, -40, 0, 36), UDim2.fromOffset(20, 360)).Activated:Connect(function() setOpen(false) end)
	shortcut.Activated:Connect(function() setOpen(not open) end)
	ContextActionService:BindActionAtPriority("RobostrikeSettings", function(_, state)
		if state == Enum.UserInputState.Begin and not native and not UserInputService:GetFocusedTextBox() then setOpen(not open) end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 30, Enum.KeyCode.F10)
	-- Roblox owns Escape/CoreGui; games cannot insert a custom settings tab there.
	-- Show our panel when it closes, without replacing or breaking the system menu.
	GuiService.MenuOpened:Connect(function()
		openAfterNative = not open
		native = true
		dragging, touch = nil, nil
		setOpen(false)
	end)
	GuiService.MenuClosed:Connect(function()
		native = false
		setOpen(openAfterNative)
	end)
	RunService:BindToRenderStep("RobostrikeSettingsMouse", Enum.RenderPriority.Camera.Value + 10, function()
		if open or native then
			UserInputService.MouseIconEnabled = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end)
	setOpen(false)
end

return Settings
