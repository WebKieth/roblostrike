--!strict

-- Procedural circular mask: no external textures or asset permissions.
local Scope = {}

function Scope.start(gui: ScreenGui)
	local root = Instance.new("Frame")
	root.Name = "SniperScope"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = gui
	local function rectangle(): Frame
		local frame = Instance.new("Frame")
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.Parent = root
		return frame
	end
	local bands: { { Frame } } = {}
	for _ = 1, 128 do table.insert(bands, { rectangle(), rectangle() }) end
	local horizontal, vertical = rectangle(), rectangle()
	local marks: { Frame } = {}
	for _ = 1, 12 do table.insert(marks, rectangle()) end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.77)
	label.Size = UDim2.fromOffset(300, 30)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.TextSize = 17
	label.Parent = root
	local previous = Vector2.zero
	return function(visible: boolean, magnification: number, viewport: Vector2, point: Vector2)
		root.Visible = visible
		if not visible then return end
		local radius = math.min(viewport.X, viewport.Y) * 0.46
		local center = viewport * 0.5
		if viewport ~= previous then
			previous = viewport
			for i, pair in bands do
				local y0, y1 = (i - 1) / #bands * viewport.Y, i / #bands * viewport.Y
				local dy = math.max(math.abs(y0 - center.Y), math.abs(y1 - center.Y))
				local width = math.sqrt(math.max(0, radius * radius - dy * dy))
				pair[1].Position = UDim2.fromOffset(0, y0)
				pair[1].Size = UDim2.fromOffset(center.X - width, y1 - y0 + 1)
				pair[2].Position = UDim2.fromOffset(center.X + width, y0)
				pair[2].Size = UDim2.fromOffset(center.X - width + 1, y1 - y0 + 1)
			end
		end
		-- Reticle follows the real barrel ray, including sway and recoil.
		horizontal.Position = UDim2.fromOffset(center.X - radius, point.Y)
		horizontal.Size = UDim2.fromOffset(radius * 2, 1)
		vertical.Position = UDim2.fromOffset(point.X, center.Y - radius)
		vertical.Size = UDim2.fromOffset(1, radius * 2)
		for i, mark in marks do
			local step = math.ceil(i / 4)
			local sign = if i % 2 == 0 then 1 else -1
			local offset = radius * step * 0.12 * sign
			local alongX = i % 4 < 2
			mark.Position = UDim2.fromOffset(point.X + (if alongX then offset else -3), point.Y + (if alongX then -3 else offset))
			mark.Size = UDim2.fromOffset(if alongX then 1 else 7, if alongX then 7 else 1)
		end
		label.Text = string.format("×%g  ·  Нажатие колёсика — кратность", magnification)
	end
end

return Scope
