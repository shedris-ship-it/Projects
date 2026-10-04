-- The leaves of a potted plant (owner, 2026-10-04: the old plant was a few huge
-- balls of foliage that clipped walls and furniture). Pure and seeded, so the
-- rule "no leaf reaches past the plant's footprint" is a test
-- (tests/specs/PlantLeaves.spec.luau), not a hope.
--
-- A leaf is a thin blade standing out of the soil: `azimuth` is the way it faces
-- round the plant (radians), `tilt` how far it leans out from straight up
-- (radians), `baseRadius` where it leaves the soil, measured from the middle.

local PlantLeaves = {}

-- The farthest any corner of the leaf is from the plant's upright axis (studs).
function PlantLeaves.extent(leaf): number
	local tip = leaf.baseRadius + leaf.length * math.sin(leaf.tilt)
	return math.sqrt(tip * tip + (leaf.width / 2) * (leaf.width / 2))
end

-- cfg is Config.Plant; `reach` is Props.Kinds.Plant.reach. A leaf that would
-- lean too far for its length is made to stand straighter, never shortened.
function PlantLeaves.layout(rng, cfg, reach: number)
	local count = rng:NextInteger(cfg.Count[1], cfg.Count[2])
	local limit = reach - cfg.Margin
	local turn = rng:NextNumber(0, math.pi * 2)
	local leaves = {}
	for i = 1, count do
		local length = rng:NextNumber(cfg.Length[1], cfg.Length[2])
		local width = rng:NextNumber(cfg.Width[1], cfg.Width[2])
		local base = rng:NextNumber(cfg.BaseRadius[1], cfg.BaseRadius[2])
		local wanted = math.rad(rng:NextNumber(cfg.Tilt[1], cfg.Tilt[2]))
		-- How far out the tip may go before a corner passes the limit.
		local room = math.sqrt(math.max(0, limit * limit - (width / 2) * (width / 2))) - base
		local cap = math.asin(math.clamp(room / length, 0, 1))
		table.insert(leaves, {
			azimuth = turn + (i - 1) * (2 * math.pi / count) + rng:NextNumber(-0.25, 0.25),
			tilt = math.min(wanted, cap),
			length = length,
			width = width,
			baseRadius = base,
			shade = rng:NextNumber(0.78, 1.15),
		})
	end
	return leaves
end

return PlantLeaves
