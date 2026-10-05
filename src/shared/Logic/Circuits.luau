-- The house's wiring (R2c, the breaker): which rooms each breaker feeds.
-- The hall and the dining room share one circuit of their own (the start
-- must stay readable); every other room is on one of the rest, grouped by
-- floor and by wing (rooms in a run round the house's middle), so a breaker
-- puts out a believable stretch of the house. Pure (tests/specs/
-- Circuits.spec), from its own fork of the run's rng ("circuits").
--
-- rooms: { { id, floor, x, z, name, corridor } } (x, z the room's middle).
-- Returns { circuits = { { rooms = { ids }, label } }, roomCircuit = { [id]
-- = index } }, the hall's circuit first.

local Circuits = {}

function Circuits.plan(rooms, start: number, dining: number?, rng, cfg)
	local count = rng:NextInteger(cfg.Count[1], cfg.Count[2])
	local hall, rest = {}, {}
	local cx, cz, n = 0, 0, 0
	for _, room in rooms do
		cx += room.x
		cz += room.z
		n += 1
	end
	cx, cz = cx / math.max(1, n), cz / math.max(1, n)
	for _, room in rooms do
		if room.id == start or room.id == dining then
			table.insert(hall, room)
		else
			table.insert(rest, room)
		end
	end
	-- Round the house, floor by floor: neighbours in this order are a wing.
	table.sort(rest, function(a, b)
		if (a.floor or 0) ~= (b.floor or 0) then
			return (a.floor or 0) < (b.floor or 0)
		end
		local ta, tb = math.atan2(a.z - cz, a.x - cx), math.atan2(b.z - cz, b.x - cx)
		if ta ~= tb then
			return ta < tb
		end
		return a.id < b.id
	end)
	-- Breakers shared out between the floors by how many rooms each has (at
	-- least one a floor), each floor's run of rooms cut into wings from a
	-- seeded starting point, so a circuit never spans floors.
	local floors, byFloor = {}, {}
	for _, room in rest do
		local f = room.floor or 0
		if not byFloor[f] then
			byFloor[f] = {}
			table.insert(floors, f)
		end
		table.insert(byFloor[f], room)
	end
	table.sort(floors)
	local groups = math.max(#floors, math.min(count - 1, #rest))
	local circuits = { { rooms = {}, label = "HALL" } }
	for _, room in hall do
		table.insert(circuits[1].rooms, room.id)
	end
	local left = groups
	for k, f in floors do
		local list = byFloor[f]
		local share = k == #floors and left
			or math.clamp(math.floor(groups * #list / #rest + 0.5), 1, left - (#floors - k))
		share = math.min(share, #list)
		left -= share
		local shift = rng:NextInteger(0, #list - 1)
		local first = #circuits + 1
		for g = 1, share do
			circuits[first + g - 1] = { rooms = {} }
		end
		for i = 1, #list do
			local room = list[((i - 1 + shift) % #list) + 1]
			local g = math.floor((i - 1) * share / #list)
			table.insert(circuits[first + g].rooms, room.id)
		end
	end
	-- A circuit is named for one of its rooms, the first that isn't a
	-- corridor (what the family would write on the panel).
	local byId = {}
	for _, room in rooms do
		byId[room.id] = room
	end
	for i = 2, #circuits do
		local circuit = circuits[i]
		table.sort(circuit.rooms)
		local name
		for _, id in circuit.rooms do
			if not byId[id].corridor then
				name = byId[id].name
				break
			end
		end
		circuit.label = string.upper(name or byId[circuit.rooms[1]].name)
	end
	local roomCircuit = {}
	for i, circuit in circuits do
		for _, id in circuit.rooms do
			roomCircuit[id] = i
		end
	end
	return { circuits = circuits, roomCircuit = roomCircuit }
end

return Circuits
