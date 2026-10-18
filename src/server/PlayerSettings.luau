--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Settings = {}
local ranges = { Master = { 0, 1 }, Characters = { 0, 1 }, Gunfire = { 0, 1 }, Sensitivity = { 0.1, 2 } }
type Entry = { values: { [string]: number }, changed: { [string]: boolean }, loaded: boolean, revision: number, saved: number, saving: boolean }

local function valid(channel: any, value: any): boolean
	local range = if typeof(channel) == "string" then ranges[channel] else nil
	return range ~= nil and typeof(value) == "number" and value == value and value >= range[1] and value <= range[2]
end

function Settings.start(remotes: Folder)
	-- Local, unpublished places cannot even obtain a DataStore handle.
	-- Preferences must not prevent the rest of the game from starting.
	local store: GlobalDataStore? = nil
	local available, result = pcall(function()
		return DataStoreService:GetDataStore("PlayerSettings_v1")
	end)
	if available then
		store = result
	else
		warn("[Settings] Persistence unavailable; settings apply only to this session: " .. tostring(result))
	end
	local entries: { [Player]: Entry } = {}
	local remote = Instance.new("RemoteEvent")
	remote.Name, remote.Parent = "PlayerSettings", remotes
	local function save(player: Player)
		if not store then return end
		local entry = entries[player]
		if not entry then return end
		while entry.saving do task.wait(0.1) end
		if not entry.loaded or entry.saved == entry.revision then return end
		entry.saving = true
		local revision, values = entry.revision, table.clone(entry.values)
		local ok, err = pcall(function()
			store:UpdateAsync(tostring(player.UserId), function() return values end)
		end)
		if ok then entry.saved = revision else warn("[Settings] Save failed: " .. tostring(err)) end
		entry.saving = false
	end
	local function added(player: Player)
		local entry: Entry = { values = {}, changed = {}, loaded = false, revision = 0, saved = 0, saving = false }
		entries[player] = entry
		for channel in ranges do
			entry.values[channel] = 1
			player:SetAttribute("Setting" .. channel, 1)
		end
		if not store then return end
		task.spawn(function()
			for attempt = 1, 3 do
				local ok, data = pcall(function() return store:GetAsync(tostring(player.UserId)) end)
				if ok then
					if entries[player] ~= entry then return end
					for channel in ranges do
						if not entry.changed[channel] and typeof(data) == "table" and valid(channel, data[channel]) then
							entry.values[channel] = data[channel]
							player:SetAttribute("Setting" .. channel, data[channel])
						end
					end
					entry.loaded = true
					return
				end
				warn("[Settings] Load failed: " .. tostring(data))
				task.wait(attempt * 2)
			end
			-- Never overwrite existing settings after a failed read.
		end)
	end
	remote.OnServerEvent:Connect(function(player, channel, value)
		local entry = entries[player]
		if not entry or not valid(channel, value) then return end
		entry.changed[channel] = true
		if entry.loaded and entry.values[channel] == value then return end
		entry.values[channel] = value
		entry.revision += 1
		player:SetAttribute("Setting" .. channel, value)
	end)
	Players.PlayerAdded:Connect(added)
	Players.PlayerRemoving:Connect(function(player)
		local entry = entries[player]
		-- A quick disconnect may race the initial DataStore read.
		local deadline = os.clock() + 10
		while store and entry and not entry.loaded and os.clock() < deadline do task.wait(0.1) end
		save(player)
		entries[player] = nil
	end)
	for _, player in Players:GetPlayers() do added(player) end
	task.spawn(function()
		while true do
			task.wait(15)
			for player in entries do task.spawn(save, player) end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player in entries do
			pending += 1
			task.spawn(function() save(player); pending -= 1 end)
		end
		while pending > 0 do task.wait(0.1) end
	end)
end

return Settings
