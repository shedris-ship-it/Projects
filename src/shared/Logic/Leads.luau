-- How each key and heirloom is found (docs/plans/gameplay-rework.md, R2c
-- "leads, not rummaging"): read the house, don't open every drawer. Each
-- token the lock planner keeps in a room (Logic/LockPlanner, a "container"
-- producer) gets a lead:
--
--   note      it's in a drawer or cupboard, and a note somewhere you can
--             already reach says which (Logic/NoteText writes it)
--   keepsake  in a small, distinctive box on a top in its room
--   display   behind the glass of a locked case on a top in its room: pick
--             the lock, or throw something through the glass
--   hook      a key on a key rack on a wall of its room
--   drawer    the old way: in a drawer, with nothing to point at it (off by
--             default)
--
-- A few decoys (an empty keepsake box, a case with nothing of his in it) keep
-- a box from always meaning a find. Pure (tests/specs/Leads.spec): where each
-- lead physically goes is Services/ItemService's job, which falls back to a
-- drawer when a room has no free top or wall.
--
-- Returns { tokens = { [token id] = { kind, noteRoom? } }, decoys = { { kind, room } } }.
-- Every token has a noteRoom when there's anywhere for one: a note's own, or
-- the fallback if its box, case or rack can't be placed.

local LockPlanner = require(script.Parent.LockPlanner)
local NoteText = require(script.Parent.NoteText)
local Props = require(script.Parent.Parent.Data.Props)

local Leads = {}

-- What each room offers a lead: tops to stand a box or case on, and whether
-- a note can name it so it's the only room it could mean (Logic/NoteText).
function Leads.rooms(layout, templatesById): { [number]: { tops: number, family: string?, nameable: boolean } }
	local rooms = {}
	local named = NoteText.rooms(layout, templatesById)
	for _, room in layout.rooms do
		local template = templatesById[room.template]
		local tops = 0
		for _, prop in template and template.props or {} do
			local kind = Props.Kinds[prop.kind]
			if kind and kind.top then
				tops += 1
			end
		end
		local _, nameable = NoteText.roomPhrase(named, room.id)
		rooms[room.id] = { tops = tops, family = template and template.family, nameable = nameable }
	end
	return rooms
end

local function sortedTokens(plan): { string }
	local ids = {}
	for id, token in plan.tokens do
		if token.producer.kind == "container" then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

-- The order regions open in: region -> 0 for the start, 1 for the first opened...
local function positions(plan): { [number]: number }
	local position = { [0] = 0 }
	for i, r in plan.order do
		position[r] = i
	end
	return position
end

function Leads.plan(plan, rooms, rng, cfg)
	local position = positions(plan)
	local regionOf = function(room)
		return position[plan.roomRegion[room]] or math.huge
	end
	local ids = {}
	for id in rooms do
		table.insert(ids, id)
	end
	table.sort(ids)
	local dining = plan.finale and plan.finale.table

	local out = { tokens = {}, decoys = {} }
	local used = {} -- lead kind -> times given, so one kind doesn't take every token
	local boxRooms, caseRooms, noteRooms = {}, {}, {}
	for _, id in sortedTokens(plan) do
		local token = plan.tokens[id]
		local room = LockPlanner.tokenRoom(plan, token)
		local info = rooms[room] or { tops = 0 }
		local weights = cfg.Weights[token.kind] or cfg.Weights.key
		local options = {}
		for _, kind in cfg.Kinds do
			local weight = weights[kind] or 0
			local fits = true
			if kind == "keepsake" then
				fits = info.tops > 0 and not boxRooms[room]
			elseif kind == "display" then
				fits = info.tops > 0 and not caseRooms[room]
			elseif kind == "hook" then
				fits = token.kind == "key"
			end
			if weight > 0 and fits then
				table.insert(options, { kind = kind, weight = weight * cfg.Repeat ^ (used[kind] or 0) })
			end
		end
		-- Somewhere for a note: open no later than the token's own room, and
		-- not that room (a note beside what it points at says nothing).
		local noteCandidates = {}
		for _, other in ids do
			if other ~= room and regionOf(other) <= regionOf(room) then
				local weight = regionOf(other) < regionOf(room) and 2 or 1
				weight /= 1 + (noteRooms[other] or 0)
				if other == dining then
					weight *= 0.5
				end
				table.insert(noteCandidates, { room = other, weight = weight })
			end
		end
		-- A note that can't name the room alone (two guest rooms off one
		-- bedroom) is a last resort: it still narrows it to two.
		local vague = nil
		if #noteCandidates == 0 or info.nameable == false then
			for i = #options, 1, -1 do
				if options[i].kind == "note" then
					vague = #noteCandidates > 0 and table.remove(options, i) or nil
					if not vague then
						table.remove(options, i)
					end
				end
			end
		end
		local lead
		if #options == 0 then
			lead = { kind = vague and "note" or "drawer" }
		else
			local pick = rng:WeightedPick(options, function(o)
				return o.weight
			end)
			lead = { kind = pick.kind }
		end
		-- Every token gets a note's room: its lead if it's a note, and the
		-- fallback should its box, case or rack find no place in the house.
		if #noteCandidates > 0 then
			local pick = rng:WeightedPick(noteCandidates, function(c)
				return c.weight
			end)
			lead.noteRoom = pick.room
			if lead.kind == "note" then
				noteRooms[pick.room] = (noteRooms[pick.room] or 0) + 1
			end
		end
		if lead.kind == "keepsake" then
			boxRooms[room] = true
		elseif lead.kind == "display" then
			caseRooms[room] = true
		end
		used[lead.kind] = (used[lead.kind] or 0) + 1
		out.tokens[id] = lead
	end

	-- Decoys: a box or a case holding nothing of his, in rooms without one.
	for _, entry in
		{
			{ kind = "keepsake", count = cfg.DecoyKeepsakes, taken = boxRooms },
			{
				kind = "display",
				count = cfg.DecoyDisplays,
				taken = caseRooms,
			},
		}
	do
		local want = rng:NextInteger(entry.count[1], entry.count[2])
		local free = {}
		for _, id in ids do
			if id ~= dining and (rooms[id].tops or 0) > 0 and not entry.taken[id] then
				table.insert(free, id)
			end
		end
		for _ = 1, want do
			if #free == 0 then
				break
			end
			local room = table.remove(free, rng:NextInteger(1, #free))
			entry.taken[room] = true
			table.insert(out.decoys, { kind = entry.kind, room = room })
		end
	end
	return out
end

return Leads
