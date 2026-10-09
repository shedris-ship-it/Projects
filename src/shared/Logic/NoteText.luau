-- Writing the family's notes (Data/Notes, R2c "leads"): which drawer, which
-- room, said the way a person would, and never ambiguous. Pure (tests/specs/
-- NoteText.spec). The text is made on the server and sent only to a player
-- who reads the note (Services/ItemService), so nothing in the world gives
-- the answer away before then.

local Notes = require(script.Parent.Parent.Data.Notes)

local NoteText = {}

-- What a container is called, and how many drawers it has (bottom first,
-- as World/PropFactory numbers them).
NoteText.Furniture = {
	Dresser = { name = "dresser", drawers = 3 },
	Desk = { name = "desk", drawers = 2 },
	Wardrobe = { name = "wardrobe" },
	Cabinet = { name = "cabinet" },
	Locker = { name = "locker" },
	TallCupboard = { name = "tall cupboard" },
	Counter = { name = "counter" },
	Fridge = { name = "fridge" },
	Chest = { name = "chest" },
}

local DRAWER_WORDS = {
	[2] = { "bottom", "top" },
	[3] = { "bottom", "middle", "top" },
}

-- Which drawer or cupboard: `kind` is the furniture's Data/Props kind,
-- `group` the space's group (World/PropFactory: Drawer1, Main, Freezer...).
function NoteText.place(kind: string, group: string?): string
	local furniture = NoteText.Furniture[kind]
	if not furniture then
		return "plain sight"
	end
	local index = group and tonumber(string.match(group, "^Drawer(%d+)$"))
	if index and furniture.drawers then
		local words = DRAWER_WORDS[furniture.drawers]
		local word = words and words[index]
		return word and ("the " .. word .. " drawer of the " .. furniture.name)
			or ("a drawer of the " .. furniture.name)
	end
	if kind == "Counter" then
		return "a cupboard under the counter"
	elseif kind == "Fridge" then
		return group == "Freezer" and "the freezer" or "the fridge"
	end
	return "the " .. furniture.name
end

-- The rooms as notes name them: { [id] = { name, floor, neighbours } }.
function NoteText.rooms(layout, templatesById)
	local rooms = {}
	for _, room in layout.rooms do
		local template = templatesById[room.template]
		rooms[room.id] = {
			name = template and template.name or ("room " .. room.id),
			floor = room.floor or 0,
			area = (room.w or 40) * (room.d or 40),
			neighbours = {},
		}
	end
	for _, seam in layout.seams do
		if seam.connected and rooms[seam.a] and rooms[seam.b] then
			table.insert(rooms[seam.a].neighbours, seam.b)
			table.insert(rooms[seam.b].neighbours, seam.a)
		end
	end
	for _, room in rooms do
		table.sort(room.neighbours)
	end
	return rooms
end

local function count(rooms, test): number
	local n = 0
	for _, room in rooms do
		if test(room) then
			n += 1
		end
	end
	return n
end

-- "the Study"; with two of a name, "the upstairs Bathroom"; with two on one
-- floor, "the Bathroom by the Study" (a neighbour whose name is its own and
-- that its twin isn't next to). Also returns whether that picks out this
-- room alone: two guest rooms off the same bedroom can't be told apart in
-- words, and notes never point into those (Logic/Leads).
function NoteText.roomPhrase(rooms, id: number): (string, boolean)
	local room = rooms[id]
	local name = room.name
	if count(rooms, function(r)
		return r.name == name
	end) == 1 then
		return "the " .. name, true
	end
	local sameFloor = count(rooms, function(r)
		return r.name == name and r.floor == room.floor
	end)
	if sameFloor == 1 then
		return "the " .. (room.floor > 0 and "upstairs " or "downstairs ") .. name, true
	end
	-- Its neighbours with names of their own, and whether a twin of this room
	-- is next to the same one.
	local twins = {}
	for twinId, r in rooms do
		if r.name == name and twinId ~= id then
			table.insert(twins, r)
		end
	end
	local landmarks = {}
	for _, other in room.neighbours do
		local otherName = rooms[other].name
		if otherName ~= name and count(rooms, function(r)
			return r.name == otherName
		end) == 1 then
			table.insert(landmarks, other)
		end
	end
	local function shared(ids: { number }): boolean
		for _, twin in twins do
			local all = true
			for _, landmark in ids do
				all = all and table.find(twin.neighbours, landmark) ~= nil
			end
			if all then
				return true
			end
		end
		return false
	end
	for _, landmark in landmarks do
		if not shared({ landmark }) then
			return "the " .. name .. " by the " .. rooms[landmark].name, true
		end
	end
	for i = 1, #landmarks do
		for j = i + 1, #landmarks do
			if not shared({ landmarks[i], landmarks[j] }) then
				return "the "
					.. name
					.. " between the "
					.. rooms[landmarks[i]].name
					.. " and the "
					.. rooms[landmarks[j]].name,
					true
			end
		end
	end
	-- Two of them and nothing tells them apart but their size: "the larger".
	if #twins == 1 and room.area and twins[1].area then
		local ratio = room.area / twins[1].area
		if ratio >= 1.2 then
			return "the larger " .. name, true
		elseif ratio <= 1 / 1.2 then
			return "the smaller " .. name, true
		end
	end
	return "the " .. name, false
end

-- Fill a template's {fields}; {Item} is {item} with a capital.
function NoteText.write(template: string, fields): string
	local text = string.gsub(template, "{(%a+)}", function(key)
		local lower = string.lower(string.sub(key, 1, 1)) .. string.sub(key, 2)
		local value = fields[key] or fields[lower]
		if value == nil then
			return "{" .. key .. "}"
		end
		value = tostring(value)
		if key ~= lower then
			value = string.upper(string.sub(value, 1, 1)) .. string.sub(value, 2)
		end
		return value
	end)
	return text
end

-- A template for a token kind ("key" or "heirloom"), not one already used
-- this run while any are left. `used` is the run's set of used templates.
-- `voice`: written by one of the family (Data/Notes voices, Data/Family).
function NoteText.pick(rng, kind: string, used: { [string]: boolean }, voice: string?): string
	local voiced = voice and Notes.voices[voice]
	local list = (voiced and voiced[kind]) or Notes[kind] or Notes.key
	local fresh = {}
	for _, template in list do
		if not used[template] then
			table.insert(fresh, template)
		end
	end
	local template = rng:Pick(#fresh > 0 and fresh or list)
	used[template] = true
	return template
end

return NoteText
