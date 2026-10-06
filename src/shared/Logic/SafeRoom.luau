-- The safe room's contents (docs/plans/level-design.md section 11.12): a roll
-- from Data/SafeRoom with the run's seed, each entry at most once, how many by
-- squad (Config.Progression.SafeRoom.Count). The house plans go in only when
-- there's a floor they could show that the house's own plans don't
-- (`plansStorey`, Services/SafeRoomService). Pure.

local Loot = require(script.Parent.Parent.Data.SafeRoom)

local SafeRoom = {}

-- How many things for a squad of `squad` (1-4).
function SafeRoom.count(squad: number?, cfg): number
	local counts = cfg.Count
	local i = math.clamp(math.floor(squad or #counts), 1, #counts)
	return counts[i]
end

-- The roll: a list of Data/SafeRoom entries.
function SafeRoom.roll(rng, squad: number?, cfg, plansStorey: number?)
	local pool = {}
	for _, entry in Loot do
		if entry.kind ~= "plans" or plansStorey ~= nil then
			table.insert(pool, entry)
		end
	end
	local out = {}
	for _ = 1, math.min(SafeRoom.count(squad, cfg), #pool) do
		local pick = rng:WeightedPick(pool, function(entry)
			return entry.weight
		end)
		table.insert(out, pick)
		table.remove(pool, table.find(pool, pick))
	end
	return out
end

return SafeRoom
