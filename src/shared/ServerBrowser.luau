--!strict
local Browser = {}
Browser.PageSizes = { 10, 20, 50 }
Browser.DefaultPageSize = 50
Browser.NameLimit = 48

-- Lua's string.lower only handles ASCII; session names also commonly use Russian.
local function lower(value: string): string
	local characters = {}
	for _, code in utf8.codes(value) do
		if code >= 0x410 and code <= 0x42F then code += 32 elseif code == 0x401 then code = 0x451 end
		table.insert(characters, utf8.char(code))
	end
	return string.lower(table.concat(characters))
end

function Browser.validName(value: any): string?
	if typeof(value) ~= "string" or #value > 192 then return nil end
	local name = string.match(value, "^%s*(.-)%s*$") or ""
	local length = utf8.len(name)
	if not length or length < 1 or length > Browser.NameLimit or string.find(name, "%c") then return nil end
	return name
end

function Browser.page(entries: { any }, query: string, page: number, size: number): any
	size = if table.find(Browser.PageSizes, size) then size else Browser.DefaultPageSize
	local found = {}
	query = lower(query)
	for _, entry in entries do
		if string.find(lower(entry.name), query, 1, true) then table.insert(found, entry) end
	end
	table.sort(found, function(a, b)
		if a.name == b.name then return a.id < b.id end
		return a.name < b.name
	end)
	local pages = math.max(1, math.ceil(#found / size))
	page = math.clamp(math.floor(page), 1, pages)
	local rows = {}
	for index = (page - 1) * size + 1, math.min(page * size, #found) do table.insert(rows, found[index]) end
	return { rows = rows, page = page, pages = pages, total = #found, size = size }
end

return table.freeze(Browser)
