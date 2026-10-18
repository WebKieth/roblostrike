--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.ServerBrowser)
local Maps = require(ReplicatedStorage.Shared.MapCatalog)
local MapSelect = require(script.Parent.MapSelect)
local ServerBrowser = {}

function ServerBrowser.start(player: Player, remotes: Instance)
	local remote = remotes:WaitForChild("ServerDirectory") :: RemoteFunction
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.DisplayOrder = "ServerBrowser", false, true, 21
	gui.Parent = player:WaitForChild("PlayerGui")
	local overlay = Instance.new("Frame")
	overlay.Size, overlay.BackgroundColor3, overlay.Parent = UDim2.fromScale(1, 1), Color3.fromRGB(6, 10, 19), gui
	local panel = Instance.new("Frame")
	panel.AnchorPoint, panel.Position, panel.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.92, 0.86)
	panel.BackgroundColor3, panel.Parent = Color3.fromRGB(20, 27, 40), overlay
	local max = Instance.new("UISizeConstraint")
	max.MaxSize, max.Parent = Vector2.new(960, 800), panel
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
	local function text(parent: Instance, value: string, y: number, height: number): TextLabel
		local item = Instance.new("TextLabel")
		item.Text, item.Size, item.Position = value, UDim2.new(1, -32, 0, height), UDim2.fromOffset(16, y)
		item.BackgroundTransparency, item.Font, item.TextSize = 1, Enum.Font.GothamMedium, 18
		item.TextColor3, item.TextWrapped, item.Parent = Color3.fromRGB(238, 243, 250), true, parent
		return item
	end
	local function button(parent: Instance, value: string, position: UDim2, size: UDim2, callback: () -> ()): TextButton
		local item = Instance.new("TextButton")
		item.Text, item.Position, item.Size = value, position, size
		item.Font, item.TextSize, item.Modal = Enum.Font.GothamBold, 16, true
		item.BackgroundColor3, item.TextColor3, item.Parent = Color3.fromRGB(45, 92, 130), Color3.new(1, 1, 1), parent
		Instance.new("UICorner", item).CornerRadius = UDim.new(0, 8)
		item.Activated:Connect(callback)
		return item
	end
	local function input(parent: Instance, placeholder: string, y: number): TextBox
		local item = Instance.new("TextBox")
		item.Position, item.Size = UDim2.fromOffset(16, y), UDim2.new(1, -32, 0, 44)
		item.Text, item.PlaceholderText, item.ClearTextOnFocus = "", placeholder, false
		item.Font, item.TextSize = Enum.Font.GothamMedium, 18
		item.BackgroundColor3, item.TextColor3, item.Parent = Color3.fromRGB(34, 44, 60), Color3.new(1, 1, 1), parent
		return item
	end
	text(panel, "ROBOSTRIKE", 12, 44).Font = Enum.Font.GothamBold
	local status = text(panel, "", 0, 48)
	status.Position = UDim2.new(0, 16, 1, -52)
	local screens: { [string]: Frame } = {}
	for _, name in { "Home", "Create", "Find" } do
		local screen = Instance.new("Frame")
		screen.Size, screen.Position, screen.BackgroundTransparency = UDim2.new(1, 0, 1, -120), UDim2.fromOffset(0, 64), 1
		screen.Parent, screens[name] = panel, screen
	end
	local screenName, page, pageSize, pages = "Home", 1, Rules.DefaultPageSize, 1
	local pending, revision = false, 0
	local function show(name: string)
		screenName = name
		revision += 1
		status.Text = ""
		for id, screen in screens do screen.Visible = id == name end
	end
	local function request(command: string, value: any, requestedPage: any): any
		if pending then return nil end
		pending = true
		status.Text = if command == "List" then "Загрузка списка…" else "Подключение…"
		local ok, result = pcall(function() return remote:InvokeServer(command, value, requestedPage or page, pageSize) end)
		pending = false
		if not ok or typeof(result) ~= "table" then status.Text = "Нет связи с сервером. Попробуйте ещё раз."; return nil end
		status.Text = result.error or ""
		if result.error then return nil end
		if command ~= "List" and result.ok then status.Text = "Подключение к серверу…" end
		return result
	end
	button(screens.Home, "НОВЫЙ СЕРВЕР", UDim2.new(0.05, 0, 0.25, 0), UDim2.new(0.425, 0, 0, 90), function() show("Create") end)
	local create = screens.Create
	text(create, "Имя нового сервера (1–48 символов)", 44, 40)
	local name = input(create, "Введите имя сервера", 96)
	local selectedMap = Maps.DefaultId
	local mapSelect = MapSelect.new(create, UDim2.new(0.05, 0, 0, 154), function(id) selectedMap = id end)
	button(create, "ДАЛЕЕ — НАСТРОЙКИ", UDim2.new(0.05, 0, 0, 204), UDim2.new(0.9, 0, 0, 48), function()
		if not Rules.validName(name.Text) then status.Text = "Введите имя сервера: от 1 до 48 символов."; return end
		mapSelect.Close()
		request("Create", name.Text, selectedMap)
	end)
	local find = screens.Find
	local search = input(find, "Поиск по имени сессии", 0)
	local list = Instance.new("ScrollingFrame")
	list.Position, list.Size = UDim2.fromOffset(16, 106), UDim2.new(1, -32, 1, -158)
	list.BackgroundTransparency, list.ScrollBarThickness, list.Parent = 1, 6, find
	local layout = Instance.new("UIListLayout")
	layout.Padding, layout.Parent = UDim.new(0, 6), list
	local pager = text(find, "", 0, 36)
	pager.Position, pager.Size = UDim2.new(0.3, 0, 1, -42), UDim2.new(0.4, 0, 0, 36)
	local function refresh()
		if screenName ~= "Find" or pending then return end
		local token = revision
		local result = request("List", search.Text, page)
		if not result or token ~= revision or screenName ~= "Find" then return end
		page, pages = result.page, result.pages
		for _, item in list:GetChildren() do if item:IsA("TextButton") then item:Destroy() end end
		for index, entry in result.rows do
			local map = Maps.find(entry.mapId)
			local row = button(list, string.format("%s  ·  %s  ·  %d/%d  ·  %s", entry.name, if map then map.Name else "—", entry.players, entry.capacity, if entry.started then "В игре" else "Настройка"), UDim2.new(), UDim2.new(1, -8, 0, 46), function() request("Join", entry.id) end)
			row.LayoutOrder, row.TextTruncate = index, Enum.TextTruncate.AtEnd
			row.Interactable = entry.players < entry.capacity
		end
		list.CanvasSize, list.CanvasPosition = UDim2.fromOffset(0, #result.rows * 52), Vector2.zero
		pager.Text = string.format("%d / %d · всего %d", page, pages, result.total)
		status.Text = if result.total == 0 then "Серверы не найдены. Создайте новый или измените поиск." else ""
	end
	button(screens.Home, "НАЙТИ СЕРВЕР", UDim2.new(0.525, 0, 0.25, 0), UDim2.new(0.425, 0, 0, 90), function() show("Find"); refresh() end)
	for _, screen in { create, find } do
		button(screen, "← Назад", UDim2.new(0, 16, 1, -42), UDim2.fromOffset(110, 36), function() show("Home") end)
	end
	-- Navigation lives below the scroll area; the list itself may contain up to 50 rows.
	button(find, "‹", UDim2.new(0.25, 0, 1, -42), UDim2.new(0.07, 0, 0, 36), function() if not pending and page > 1 then page -= 1; refresh() end end)
	button(find, "›", UDim2.new(0.72, 0, 1, -42), UDim2.new(0.07, 0, 0, 36), function() if not pending and page < pages then page += 1; refresh() end end)
	button(find, "Обновить", UDim2.new(0.8, 0, 1, -42), UDim2.new(0.18, 0, 0, 36), refresh)
	local sizes: { [number]: TextButton } = {}
	for index, size in Rules.PageSizes do
		sizes[size] = button(find, tostring(size) .. " строк", UDim2.new((index - 1) * 0.17, 16, 0, 56), UDim2.new(0.15, 0, 0, 36), function()
			if pending then return end
			pageSize, page = size, 1
			for count, item in sizes do item.BackgroundColor3 = if count == size then Color3.fromRGB(49, 130, 93) else Color3.fromRGB(45, 92, 130) end
			refresh()
		end)
	end
	sizes[pageSize].BackgroundColor3 = Color3.fromRGB(49, 130, 93)
	button(find, "Искать", UDim2.new(0.7, 0, 0, 56), UDim2.new(0.28, -16, 0, 36), function() page = 1; refresh() end)
	search.FocusLost:Connect(function() page = 1; refresh() end)
	local function visibility()
		gui.Enabled = player:GetAttribute("InSession") ~= true
		if gui.Enabled then show("Home") end
	end
	player:GetAttributeChangedSignal("InSession"):Connect(visibility)
	player:GetAttributeChangedSignal("DirectoryError"):Connect(function() status.Text = player:GetAttribute("DirectoryError") or "" end)
	visibility()
end

return ServerBrowser
