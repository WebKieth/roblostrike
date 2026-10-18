--!strict
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Audio = require(script.Parent.AudioSettings)
local Settings = {}

function Settings.start(player: Player)
	Audio.start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlayerSettings") :: RemoteEvent
	local pending: { [string]: number } = {}
	local queued = false
	local function persist(channel: string, value: number)
		pending[channel] = value
		if queued then return end
		queued = true
		task.delay(0.3, function()
			queued = false
			for name, setting in pending do remote:FireServer(name, setting) end
			table.clear(pending)
		end)
	end
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.DisplayOrder = "AudioSettings", false, true, 50
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
	local shortcut = button(gui, "Настройки · F10", UDim2.fromOffset(160, 32), UDim2.new(1, -184, 0, 8))
	local shade = button(gui, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	shade.Name, shade.BackgroundColor3, shade.BackgroundTransparency = "SettingsModal", Color3.new(0, 0, 0), 0.3
	shade.AutoButtonColor, shade.Modal, shade.Visible = false, true, false
	local panel = Instance.new("Frame")
	panel.AnchorPoint, panel.Position, panel.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.92, 0.9)
	panel.BackgroundColor3, panel.BorderSizePixel, panel.Parent = Color3.fromRGB(18, 25, 36), 0, shade
	local size = Instance.new("UISizeConstraint")
	size.MaxSize, size.Parent = Vector2.new(500, 480), panel
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
	local note = label("Изменения применяются сразу и сохраняются между запусками игры.", UDim2.fromOffset(20, 46), 32)
	note.TextSize, note.TextWrapped = 12, true
	local open, native, openAfterNative = false, false, false
	local dragging: ((number) -> ())? = nil
	local touch: InputObject? = nil
	local function page(name: string): ScrollingFrame
		local result = Instance.new("ScrollingFrame")
		result.Name, result.Position, result.Size = name, UDim2.fromOffset(0, 124), UDim2.new(1, 0, 1, -192)
		result.BackgroundTransparency, result.BorderSizePixel = 1, 0
		result.CanvasSize, result.AutomaticCanvasSize = UDim2.new(), Enum.AutomaticSize.Y
		result.ScrollingDirection, result.ScrollBarThickness = Enum.ScrollingDirection.Y, 4
		result.ScrollBarImageColor3, result.Parent = Color3.fromRGB(82, 168, 240), panel
		return result
	end
	local general, controls = page("General"), page("Controls")
	local generalTab = button(panel, "Общие", UDim2.new(0.5, -24, 0, 32), UDim2.fromOffset(20, 84))
	local controlsTab = button(panel, "Управление", UDim2.new(0.5, -24, 0, 32), UDim2.new(0.5, 4, 0, 84))
	local generalNote = note.Text
	local function selectPage(showControls: boolean)
		dragging, touch = nil, nil
		general.Visible, controls.Visible = not showControls, showControls
		note.Text = if showControls then "Текущие привязки клавиш. Переназначение пока недоступно." else generalNote
		generalTab.BackgroundColor3 = if showControls then Color3.fromRGB(34, 46, 63) else Color3.fromRGB(42, 103, 159)
		controlsTab.BackgroundColor3 = if showControls then Color3.fromRGB(42, 103, 159) else Color3.fromRGB(34, 46, 63)
	end
	generalTab.Activated:Connect(function() selectPage(false) end)
	controlsTab.Activated:Connect(function() selectPage(true) end)
	selectPage(false)
	-- Read-only reference: this list does not register or change input bindings.
	local controlRows = {
		{ "ДВИЖЕНИЕ", "" },
		{ "Вперёд / назад", "W / S" },
		{ "Влево / вправо", "A / D" },
		{ "Прыжок / всплытие", "Space" },
		{ "Шаг (удерживать)", "Левый / правый Shift" },
		{ "Присесть (удерживать)", "Правый Ctrl" },
		{ "ОРУЖИЕ", "" },
		{ "Основное оружие", "1" },
		{ "Пистолет", "2" },
		{ "Нож", "3" },
		{ "Гранаты / сменить тип", "4 / повторное 4" },
		{ "Предыдущее / следующее", "Колёсико мыши" },
		{ "Огонь / режущий удар", "ЛКМ" },
		{ "Прицел / колющий удар", "ПКМ" },
		{ "Перезарядка", "R" },
		{ "Бросить автомат / пистолет", "G" },
		{ "Замах гранатой", "Удерживать ЛКМ" },
		{ "Бросить гранату", "Отпустить ЛКМ" },
		{ "Сменить режим броска", "ПКМ" },
		{ "МЕНЮ", "" },
		{ "Меню команды / сессии", "M" },
		{ "Настройки", "F10" },
		{ "Системное меню Roblox", "Escape" },
		{ "Освободить курсор", "Удерживать Alt / Option" },
	}
	local layout = Instance.new("UIListLayout")
	layout.SortOrder, layout.Padding, layout.Parent = Enum.SortOrder.LayoutOrder, UDim.new(0, 4), controls
	for index, row in controlRows do
		local heading = row[2] == ""
		local entry = Instance.new("Frame")
		entry.Name, entry.LayoutOrder, entry.Size = "Control" .. index, index, UDim2.new(1, 0, 0, 44)
		entry.BackgroundTransparency, entry.Parent = 1, controls
		local action = label(row[1], UDim2.fromOffset(20, 0), 44)
		action.Size, action.Parent = UDim2.new(if heading then 1 else 0.54, -24, 1, 0), entry
		action.TextSize, action.TextWrapped = if heading then 13 else 14, true
		if heading then action.TextColor3 = Color3.fromRGB(82, 168, 240) end
		if not heading then
			local keys = label(row[2], UDim2.new(0.54, 0, 0, 0), 44)
			keys.Size, keys.Parent = UDim2.new(0.46, -20, 1, 0), entry
			keys.TextSize, keys.TextWrapped, keys.TextXAlignment = 13, true, Enum.TextXAlignment.Right
		end
	end
	local function setOpen(value: boolean)
		open = value
		if not value then dragging, touch = nil, nil end
		shade.Visible = value and not native
		player:SetAttribute("SettingsOpen", value or native)
	end
	local sensitivity = 1
	local cursorFree = false
	local altKeys: { [Enum.KeyCode]: boolean } = {}
	local function setCursorFree(value: boolean)
		cursorFree = value
		-- A visible modal button releases Roblox's first-person mouse lock.
		shortcut.Modal = value
		-- Only mouse-look deltas are suppressed; the OS cursor still moves normally.
		UserInputService.MouseDeltaSensitivity = if value then 0 else sensitivity
		player:SetAttribute("HUDCursorFree", value)
	end
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt then
			altKeys[input.KeyCode] = true
			setCursorFree(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt then
			altKeys[input.KeyCode] = nil
			setCursorFree(next(altKeys) ~= nil)
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		table.clear(altKeys)
		setCursorFree(false)
	end)
	setCursorFree(false)
	local function get(channel: string): number
		return if channel == "Sensitivity" then sensitivity else Audio.get(channel)
	end
	for index, row in { { "Master", "Общая громкость" }, { "Characters", "Персонажи · шаги и смерть" }, { "Gunfire", "Стрельба" }, { "Sensitivity", "Чувствительность мыши" } } do
		local channel, title = row[1], row[2]
		local minimum, maximum = if channel == "Sensitivity" then 0.1 else 0, if channel == "Sensitivity" then 2 else 1
		local y = (index - 1) * 66
		local caption = label("", UDim2.fromOffset(20, y), 24)
		caption.Parent = general
		local minus = button(general, "−", UDim2.fromOffset(30, 28), UDim2.fromOffset(20, y + 26))
		local plus = button(general, "+", UDim2.fromOffset(30, 28), UDim2.new(1, -50, 0, y + 26))
		local track = button(general, "", UDim2.new(1, -124, 0, 20), UDim2.fromOffset(62, y + 30))
		track.Name, track.AutoButtonColor = channel .. "Slider", false
		local fill = Instance.new("Frame")
		fill.BackgroundColor3, fill.BorderSizePixel, fill.Parent = Color3.fromRGB(82, 168, 240), 0, track
		Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 8)
		local function update(value: number, save: boolean?)
			value = math.clamp(value, minimum, maximum)
			if channel == "Sensitivity" then
				sensitivity = value
				UserInputService.MouseDeltaSensitivity = if cursorFree then 0 else value
			else
				Audio.set(channel, value)
			end
			local volume = get(channel)
			fill.Size = UDim2.fromScale((volume - minimum) / (maximum - minimum), 1)
			caption.Text = string.format("%s  ·  %d%%", title, math.floor(volume * 100 + 0.5))
			if save then persist(channel, value) end
		end
		local function at(x: number)
			if track.AbsoluteSize.X > 0 then update(minimum + (maximum - minimum) * (x - track.AbsolutePosition.X) / track.AbsoluteSize.X, true) end
		end
		minus.Activated:Connect(function() update(get(channel) - 0.05, true) end)
		plus.Activated:Connect(function() update(get(channel) + 0.05, true) end)
		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging, touch = at, if input.UserInputType == Enum.UserInputType.Touch then input else nil
				at(input.Position.X)
			end
		end)
		local function applySaved()
			local value = player:GetAttribute("Setting" .. channel)
			if typeof(value) == "number" and pending[channel] == nil then update(value) end
		end
		player:GetAttributeChangedSignal("Setting" .. channel):Connect(applySaved)
		update(get(channel))
		applySaved()
	end
	UserInputService.InputChanged:Connect(function(input)
		if dragging and open and not native and (input == touch or (not touch and input.UserInputType == Enum.UserInputType.MouseMovement)) then
			dragging(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == touch or input.UserInputType == Enum.UserInputType.MouseButton1 then dragging, touch = nil, nil end
	end)
	button(panel, "ВЕРНУТЬСЯ В ИГРУ", UDim2.new(1, -40, 0, 36), UDim2.new(0, 20, 1, -56)).Activated:Connect(function() setOpen(false) end)
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
		if open or native or cursorFree then
			UserInputService.MouseIconEnabled = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end)
	setOpen(false)
end

return Settings
