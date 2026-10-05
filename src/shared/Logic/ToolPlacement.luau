-- Where the house leaves its tools (owner, 2026-10-04: tools are found around
-- the house "in places that are both random and make sense", on a table for
-- instance, not picked in the hub). Pure and seeded, so the same seed puts the
-- same tools in the same places and the rules are tests
-- (tests/specs/ToolPlacement.spec.luau).
--
-- A surface is { key = "3:desk", room = 3, kind = "Desk", steps = 2, free = 4 }:
-- a furniture top with `free` places left on it, `steps` rooms from where the
-- squad starts.

local ToolPlacement = {}

-- The tools one house holds for a squad: one of each, plus the extras the
-- config gives bigger squads. The tool kept near the start (cfg.NearStart)
-- comes first so it gets the best pick.
function ToolPlacement.supply(squadSize: number, toolIds: { string }, cfg): { string }
	local list = {}
	for _, id in toolIds do
		table.insert(list, id)
	end
	if squadSize >= cfg.ExtraCopiesFromSquad then
		for id, extra in cfg.ExtraCopies do
			for _ = 1, extra do
				table.insert(list, id)
			end
		end
	end
	local first = cfg.NearStart
	table.sort(list, function(a, b)
		if (a == first) ~= (b == first) then
			return a == first
		end
		return a < b
	end)
	return list
end

local function setOf(list)
	local set = {}
	for _, v in list or {} do
		set[v] = true
	end
	return set
end

-- `homes` maps a tool id to the furniture kinds it makes sense on. `cfg` needs
-- NearStart and NearStartMaxSteps. Returns a list of { tool, surface } in
-- supply order; a tool with nowhere left to go is skipped.
function ToolPlacement.plan(rng, surfaces, supply: { string }, homes, cfg)
	local pool = {}
	for _, s in surfaces do
		if s.free > 0 then
			table.insert(pool, s)
		end
	end
	local usedSurface: { [string]: boolean } = {}
	local usedRoom: { [number]: boolean } = {}

	-- Best tier first: a sensible kind in a room that has no tool yet, then a
	-- sensible kind anywhere, then any top in a fresh room, then any top.
	local function pickFor(tool: string, maxSteps: number?)
		local fits = setOf(homes[tool])
		for tier = 1, 4 do
			local best = {}
			for _, s in pool do
				if not usedSurface[s.key] and (maxSteps == nil or s.steps <= maxSteps) then
					local home, fresh = fits[s.kind] == true, not usedRoom[s.room]
					if (tier == 1 and home and fresh) or (tier == 2 and home) or (tier == 3 and fresh) or tier == 4 then
						table.insert(best, s)
					end
				end
			end
			if #best > 0 then
				return rng:Pick(best)
			end
		end
		return nil
	end

	local placed = {}
	for _, tool in supply do
		local surface = pickFor(tool, tool == cfg.NearStart and cfg.NearStartMaxSteps or nil) or pickFor(tool, nil)
		if surface then
			usedSurface[surface.key] = true
			usedRoom[surface.room] = true
			table.insert(placed, { tool = tool, surface = surface })
		end
	end
	return placed
end

return ToolPlacement
