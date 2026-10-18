--!strict
local Catalog = {}
export type Entry = { Id: string, Name: string }
local entries: { Entry } = {
	{ Id = "DeathmatchArena", Name = "Deathmatch Arena" },
	{ Id = "DesertCity", Name = "Desert City" },
}
table.sort(entries, function(a, b) return string.lower(a.Name) < string.lower(b.Name) end)
for _, entry in entries do table.freeze(entry) end
Catalog.Entries = table.freeze(entries)
Catalog.DefaultId = entries[1].Id

function Catalog.find(id: any): Entry?
	if typeof(id) ~= "string" then return nil end
	for _, entry in entries do if entry.Id == id then return entry end end
	return nil
end

return table.freeze(Catalog)
