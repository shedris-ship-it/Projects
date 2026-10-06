-- The house plans (docs/plans/level-design.md section 11, L3.5): a sheet of
-- blueprints left on a desk in the study, or the renovation plans on a
-- workbench, somewhere the squad gets to early. Reading them draws that
-- floor's rooms on everyone's map: rooms and their names only, no locks, no
-- contents, never a servants' passage. A reason to go into the room it's in
-- (Logic/RoomPurpose), and a reason to talk ("the plans say there's a room
-- behind the kitchen"). Pure.
--
--   plan.housePlans = { room = room id, storey = its floor }, or nil when no
--   room open early has anywhere to lay them

local LockPlanner = require(script.Parent.LockPlanner)

local HousePlans = {}

-- Where blueprints get left, best first (a top to lay them on).
HousePlans.Surfaces = { Desk = 6, Workbench = 3, Table = 2, Bench = 1, Counter = 1, Dresser = 1 }

-- The latest stage a room may open at and still hold them (0: open from the
-- start, 1: the first wing).
HousePlans.LatestStage = 1

function HousePlans.choose(layout, plan, templatesById, rng)
	if layout.mode ~= "Mansion" or not plan then
		return nil
	end
	-- Rooms already keeping something the run needs come after quiet ones.
	local keeping = {}
	for _, token in plan.tokens do
		for _, room in LockPlanner.producerRooms(plan, token) do
			keeping[room] = true
		end
	end
	for _, puzzle in plan.puzzles do
		keeping[puzzle.room] = true
	end
	local candidates = {}
	for _, room in layout.rooms do
		local template = templatesById[room.template]
		local shut = plan.pockets and plan.pockets[room.id]
		local open = room.id ~= layout.start
			and room.id ~= layout.deliberation
			and not room.corridor
			and room.kind ~= "stair"
			and room.kind ~= "passage"
			and not room.tall
			and not shut
			and template ~= nil
			and template.family ~= "corridor"
			and LockPlanner.stageOf(plan, room.id) <= HousePlans.LatestStage
		if open then
			local best = 0
			for _, prop in template.props or {} do
				best = math.max(best, HousePlans.Surfaces[prop.kind] or 0)
			end
			if best > 0 then
				table.insert(candidates, { room = room, weight = best * (keeping[room.id] and 1 or 2) })
			end
		end
	end
	if #candidates == 0 then
		return nil
	end
	table.sort(candidates, function(a, b)
		return a.room.id < b.room.id
	end)
	local pick = rng:WeightedPick(candidates, function(c)
		return c.weight
	end)
	return { room = pick.room.id, storey = pick.room.floor or 0 }
end

-- The rooms the plans for `storey` draw: every room on it (the servants'
-- passages are in `layout.passages`, not its rooms: a plan wouldn't show
-- them, they're found; UI/Map leaves them out the same way).
function HousePlans.rooms(layout, storey: number): { number }
	local out = {}
	for _, room in layout.rooms do
		local bottom = room.floor or 0
		local top = room.tall and (room.top or bottom + 1) or bottom
		if storey >= bottom and storey <= top and room.kind ~= "passage" then
			table.insert(out, room.id)
		end
	end
	table.sort(out)
	return out
end

return HousePlans
