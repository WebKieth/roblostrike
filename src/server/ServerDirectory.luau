--!strict
-- Access codes and owner identities live only in MemoryStore, never in client data.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local TextService = game:GetService("TextService")
local Browser = require(ReplicatedStorage.Shared.ServerBrowser)
local Directory = {}
local TTL, REFRESH = 90, 20

function Directory.start(remotes: Folder, state: Folder, created: (Player, string) -> (), joined: (Player) -> (), leaving: (Player) -> ())
	local studio = RunService:IsStudio()
	local store = if not studio then MemoryStoreService:GetSortedMap("RobostrikeSessions_v1") else nil
	local remote = Instance.new("RemoteFunction")
	remote.Name, remote.Parent = "ServerDirectory", remotes
	local record: any = nil
	local closed = false
	local busy: { [Player]: boolean } = {}
	local last: { [Player]: number } = {}
	local traveling: { [Player]: number } = {}
	local cache: { any } = {}
	local cachedAt = -math.huge
	local loading = false

	local function close()
		closed = true
		local old = record
		record = nil
		cachedAt = -math.huge
		if old and store then task.spawn(function() pcall(function() store:RemoveAsync(old.id) end) end) end
	end
	local function teleport(player: Player, access: string?)
		local options = Instance.new("TeleportOptions")
		if access then options.ReservedServerAccessCode = access end
		player:SetAttribute("DirectoryError", nil)
		traveling[player] = os.clock()
		local ok, err = pcall(function() TeleportService:TeleportAsync(game.PlaceId, { player }, options) end)
		options:Destroy()
		if not ok then traveling[player] = nil; error(tostring(err)) end
	end
	TeleportService.TeleportInitFailed:Connect(function(player)
		traveling[player] = nil
		player:SetAttribute("DirectoryError", "Не удалось подключиться. Попробуйте ещё раз.")
	end)
	local function public(entry: any): any
		return { id = entry.id, name = entry.name, players = entry.players, capacity = entry.capacity, started = entry.started }
	end
	local function entries(): { any }
		if studio then return if record then { public(record) } else {} end
		if os.clock() - cachedAt < 10 then return cache end
		if loading then error("Каталог обновляется. Повторите запрос.") end
		loading = true
		local ok, result = pcall(function()
			local all, bound = {}, nil :: any
			repeat
				local batch = store:GetRangeAsync(Enum.SortDirection.Ascending, 200, bound)
				for _, item in batch do
					local value = item.value
					if value.ready and value.updated > os.time() - TTL then table.insert(all, public(value)) end
				end
				if #batch < 200 then break end
				local tail = batch[#batch]
				bound = { key = tail.key, sortKey = tail.sortKey }
			until false
			return all
		end)
		loading = false
		if not ok then error("Каталог временно недоступен. Попробуйте ещё раз.") end
		cache, cachedAt = result, os.clock()
		return cache
	end
	remote.OnServerInvoke = function(player: Player, command: any, value: any, page: any, size: any)
		local now = os.clock()
		if busy[player] or now - (last[player] or -math.huge) < 0.4 then return { error = "Подождите перед следующим запросом." } end
		if traveling[player] and now - traveling[player] < 30 then return { error = "Подключение к серверу…" } end
		busy[player], last[player] = true, now
		local ok, result = pcall(function()
			if command == "List" then
				if typeof(value) ~= "string" or #value > 192 or typeof(page) ~= "number" or page ~= page or math.abs(page) == math.huge then return { error = "Некорректный запрос." } end
				return Browser.page(entries(), value, page, size)
			elseif command == "Create" then
				if player:GetAttribute("InSession") then return { error = "Сначала выйдите из текущей сессии." } end
				local name = Browser.validName(value)
				if not name then return { error = "Введите имя сервера: от 1 до 48 символов." } end
				if not studio then
					local filtered = TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PublicChat)
					name = filtered:GetNonChatStringForBroadcastAsync()
					-- Never publish a censored title or fall back to unfiltered input.
					if not Browser.validName(name) or string.find(name, "#", 1, true) then
						return { error = "Roblox скрыл название сервера. Выберите другое имя без личных данных и запрещённых слов." }
					end
				end
				if player.Parent ~= Players then return { error = "Игрок отключился." } end
				if studio then
					if record then return { error = "В Studio доступна одна сессия. Найдите её в списке." } end
					record = { id = "studio", name = name, owner = player.UserId, players = 1, capacity = 6, started = false }
					closed = false
					created(player, name :: string)
				else
					local access, id = TeleportService:ReserveServerAsync(game.PlaceId)
					local entry = { id = id, access = access, name = name, owner = player.UserId, players = 0, capacity = 6, started = false, ready = false, updated = os.time() }
					store:SetAsync(id, entry, TTL, id)
					teleport(player, access)
				end
				return { ok = true }
			elseif command == "Join" then
				if player:GetAttribute("InSession") then return { error = "Вы уже в сессии." } end
				if typeof(value) ~= "string" or #value > 128 then return { error = "Некорректный сервер." } end
				local entry = if studio then record else store:GetAsync(value)
				if not entry or entry.id ~= value or (not studio and (not entry.ready or entry.updated <= os.time() - TTL)) then return { error = "Сервер уже закрыт. Обновите список." } end
				if entry.players >= entry.capacity then return { error = "Сервер заполнен." } end
				if studio then
					joined(player)
					if not player:GetAttribute("InSession") then return { error = "Сервер заполнен." } end
				else teleport(player, entry.access) end
				return { ok = true }
			elseif command == "Leave" then
				if studio then leaving(player) else teleport(player, nil) end
				return { ok = true }
			end
			return { error = "Неизвестная команда." }
		end)
		busy[player] = nil
		if not ok then
			warn("[ServerDirectory] " .. tostring(result))
			return { error = "Сервис серверов недоступен. Попробуйте ещё раз." }
		end
		return result
	end
	local function added(player: Player)
		if studio or game.PrivateServerId == "" or game.PrivateServerOwnerId ~= 0 then return end
		task.spawn(function()
			-- Resolve a reserved server from trusted storage, not TeleportData supplied by clients.
			local ok, entry = pcall(function() return store:GetAsync(game.PrivateServerId) end)
			if not ok or not entry or closed or player.Parent ~= Players then
				player:SetAttribute("DirectoryError", "Сессия закрыта или недоступна. Выберите другой сервер.")
				return
			end
			if not record then record = entry end
			if player.UserId == record.owner and not state:GetAttribute("OwnerUserId") then
				created(player, record.name)
				for _, other in Players:GetPlayers() do if other ~= player then joined(other) end end
			elseif state:GetAttribute("OwnerUserId") then
				joined(player)
			end
		end)
	end
	local elapsed, writing = REFRESH, false
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if not record or elapsed < REFRESH or writing or not state:GetAttribute("OwnerUserId") then return end
		elapsed = 0
		local entry = record
		entry.players = 0
		for _, player in Players:GetPlayers() do if player:GetAttribute("InSession") then entry.players += 1 end end
		entry.started, entry.ready, entry.updated = state:GetAttribute("Started") == true, true, os.time()
		if store then
			writing = true
			task.spawn(function()
				local ok, err = pcall(function() store:SetAsync(entry.id, entry, TTL, entry.id) end)
				if not ok then warn("[ServerDirectory] heartbeat: " .. tostring(err)) end
				-- close() may run while SetAsync is yielding.
				if record ~= entry then pcall(function() store:RemoveAsync(entry.id) end) end
				writing = false
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player) busy[player], last[player], traveling[player] = nil, nil, nil end)
	game:BindToClose(close)
	return { added = added, close = close }
end

return Directory
