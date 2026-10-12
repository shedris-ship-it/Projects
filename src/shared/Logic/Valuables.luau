-- Where the family's valuables are kept ("reasons to play again", the owner's
-- choice of 2026-10-11: push your luck). Optional loot, worth Marks for the
-- whole squad only if someone carries it out of the front door, so the real
-- choice comes in the final hunt: go back for the carriage clock, or run.
-- Carried in your hands like an heirloom, it gives you away the same way
-- (Logic/Scent), and he puts back one left lying (Services/ItemService).
--
-- The rooms that keep them are the ones off the way: side rooms first (the
-- plan's pockets), then the cellar and the attic, then the rooms farthest
-- from the hall by doorways, one a room, spread across the wings. Never the
-- hall, the dining room, the way out, a corridor, a stair, a lantern room or
-- the safe room. Pure (tests/specs/Valuables.spec).

local Graph = require(script.Parent.Graph)

local Valuables = {}

-- How each candidate room ranks: higher is further off the way.
local POCKET, STOREY = 3, 2

-- Rooms that may keep a valuable, each with its score and region.
function Valuables.candidates(layout, plan)
	local ids = {}
	for _, room in layout.rooms do
		table.insert(ids, room.id)
	end
	local dist = Graph.bfs(Graph.adjacency(ids, layout.edges or {}), layout.start)
	local far = 1
	for _, d in dist do
		far = math.max(far, d)
	end
	local safe = plan and plan.safeRoom and plan.safeRoom.room
	local out = {}
	for _, room in layout.rooms do
		local id = room.id
		local excluded = id == layout.start
			or id == layout.deliberation
			or id == layout.exit
			or id == safe
			or room.corridor
			or room.kind == "stair"
			or room.lantern
			or dist[id] == nil
		if not excluded then
			local score = (dist[id] or 0) / far
			if plan and plan.pockets and plan.pockets[id] then
				score += POCKET
			elseif room.floor and (room.floor < 0 or room.floor > 1) then
				score += STOREY
			end
			table.insert(out, {
				room = id,
				score = score,
				region = plan and plan.roomRegion and plan.roomRegion[id] or 0,
			})
		end
	end
	return out
end

-- `count` rooms, best first, one a room, a different region each while there
-- are regions left. Ties are broken by the seeded rng, so the same seed keeps
-- them in the same rooms.
function Valuables.pick(layout, plan, rng, count: number): { number }
	local options = Valuables.candidates(layout, plan)
	local jitter = {}
	for _, option in options do
		jitter[option.room] = rng:NextNumber() * 0.05
	end
	table.sort(options, function(a, b)
		local sa, sb = a.score + jitter[a.room], b.score + jitter[b.room]
		if sa ~= sb then
			return sa > sb
		end
		return a.room < b.room
	end)
	local picked, usedRegion, taken = {}, {}, {}
	for pass = 1, 2 do
		for _, option in options do
			if #picked >= count then
				return picked
			end
			if not taken[option.room] and (pass == 2 or not usedRegion[option.region]) then
				taken[option.room] = true
				usedRegion[option.region] = true
				table.insert(picked, option.room)
			end
		end
	end
	return picked
end

return Valuables
