-- Prints a layout as an ASCII floor plan, with a legend and its fingerprint
-- hash. Run from the repository root:
--
--     lune run tools/plan <seed> [cells|mansion]
--
-- "cells" is the old generator (Logic/LevelGraph); "mansion" is the mansion
-- generator (docs/plans/mansion-generation.md).
--
--     lune run tools/plan <seed> mansion freeze
--
-- also writes that mansion to src/shared/Data/MansionFallback.luau, the
-- authored house used when every attempt fails (then run stylua on it).
--
--     lune run tools/plan <seed> [cells|mansion] locks [squad]
--
-- adds the escape's plan for that house (Logic/LockPlanner): its regions,
-- what locks each, where the keys, the computer and the heirlooms are, and
-- how it measures as a level (Logic/HouseMetrics). A mansion is sized for a
-- squad of `squad` (1-4, default 4; docs/plans/level-design.md section 5.2).

local fs = require("@lune/fs")
local process = require("@lune/process")

local Harness = require("../tests/harness")

local Shared = Harness.root("src/shared", "Shared")
local Config = Harness.require(Shared.Config)
local Rooms = Harness.require(Shared.Data.Rooms)
local FloorPlan = Harness.require(Shared.Logic.FloorPlan)

local seed = tonumber(process.args[1]) or 1800820264
local mode = process.args[2] or "cells"
local squad = tonumber(process.args[4]) or 4

local layout, config
local progression = Config.Progression
if mode == "mansion" then
	local HouseSize = Harness.require(Shared.Logic.HouseSize)
	local MansionGen = Harness.require(Shared.Logic.MansionGen)
	config, progression = HouseSize.config(Config.Mansion, Config.Progression, squad)
	layout = MansionGen.generate(seed, Rooms.Mansion, config)
else
	local LevelGraph = Harness.require(Shared.Logic.LevelGraph)
	config = Config.Level
	layout = LevelGraph.generate(seed, Rooms.List, config)
end

print(FloorPlan.render(layout, config))
if layout.lastProblems then
	print("last problems: " .. table.concat(layout.lastProblems, "; "))
end

-- A Luau literal for a plain table: keys sorted, lists as lists.
local function literal(value): string
	local kind = type(value)
	if kind == "string" then
		return string.format("%q", value)
	elseif kind ~= "table" then
		return tostring(value)
	end
	local n = #value
	local isList = true
	for key in value do
		if type(key) ~= "number" or key < 1 or key > n or key % 1 ~= 0 then
			isList = false
		end
	end
	local parts = {}
	if isList then
		for i = 1, n do
			parts[i] = literal(value[i])
		end
	else
		local keys = {}
		for key in value do
			table.insert(keys, key)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		for _, key in keys do
			local name = if type(key) == "string" and string.match(key, "^[%a_][%w_]*$")
				then key
				else "[" .. literal(key) .. "]"
			table.insert(parts, name .. " = " .. literal(value[key]))
		end
	end
	return "{ " .. table.concat(parts, ", ") .. " }"
end

if process.args[3] == "locks" then
	local Rng = Harness.require(Shared.Lib.Rng)
	local LockPlanner = Harness.require(Shared.Logic.LockPlanner)
	local templates = mode == "mansion" and Rooms.MansionById or Rooms.ById
	-- The same fork RunOrchestrator gives it.
	local plan = LockPlanner.plan(layout, templates, Rng.new(seed):Fork("progression"), progression, config)
	local function named(id)
		local room
		for _, r in layout.rooms do
			if r.id == id then
				room = r
			end
		end
		local template = room and templates[room.template]
		return id .. " " .. (template and template.name or "?")
	end
	print("Escape plan (" .. #plan.order .. " regions after the first, " .. plan.stats.attempts .. " attempts)")
	for r = 0, #plan.order do
		local region = plan.regions[r]
		local rooms = {}
		for _, id in region.rooms do
			table.insert(rooms, tostring(id))
		end
		local how = ""
		if region.gate then
			local lock = plan.locks[region.gate]
			local token = lock.needs and plan.tokens[lock.needs[1]]
			local from
			if not token then
				from = "worked from " .. named(lock.side)
			elseif token.producer.kind == "puzzle" then
				local puzzle = plan.puzzles[token.producer.id]
				from = "from the " .. puzzle.kind .. " in " .. named(puzzle.room)
			else
				local rooms = {}
				for _, room in LockPlanner.producerRooms(plan, token) do
					table.insert(rooms, named(room))
				end
				from = "kept in " .. table.concat(rooms, " and ")
			end
			how = string.format("  <- %s %s (%s)", lock.kind, region.gate, from)
		end
		local position = r == 0 and "open" or ("opens " .. (table.find(plan.order, r) or "?"))
		print(string.format("  region %d (%s): rooms %s%s", r, position, table.concat(rooms, " "), how))
	end
	local bolts = {}
	for id, lock in plan.locks do
		if lock.kind == "bolt" then
			table.insert(bolts, id .. " from " .. lock.side)
		end
	end
	table.sort(bolts)
	print("  bolts (shortcuts, opened from inside): " .. (#bolts > 0 and table.concat(bolts, ", ") or "none"))
	local heirlooms = {}
	for _, id in plan.finale.heirlooms do
		table.insert(heirlooms, id .. " in " .. named(LockPlanner.tokenRoom(plan, plan.tokens[id])))
	end
	print("  heirlooms: " .. table.concat(heirlooms, ", "))
	print(
		"  the dinner seals: "
			.. (#plan.finale.cut > 0 and table.concat(plan.finale.cut, ", ") or "nothing")
			.. "; out by "
			.. named(plan.finale.goal)
	)
	-- How it measures as a level (Logic/HouseMetrics, docs/plans/level-design.md).
	local HouseMetrics = Harness.require(Shared.Logic.HouseMetrics)
	local NavGraph = Harness.require(Shared.Logic.NavGraph)
	local m = HouseMetrics.measure(layout, plan, templates, {
		nav = NavGraph.options(Config),
		config = config,
		shortcut = Config.LevelDesign.ShortcutStuds,
	})
	local score, card = HouseMetrics.score(m, Config.LevelDesign.Targets, squad)
	print(string.format("Level score %.1f (lower is better; squad %d's bands)", score, squad))
	for _, line in HouseMetrics.describe(card) do
		print("  " .. line)
	end
end

if mode == "mansion" and process.args[3] == "freeze" then
	if layout.fallback then
		error("seed " .. seed .. " fell back; freeze a seed that generates")
	end
	local frozen = {}
	for _, key in
		{
			"mode",
			"rooms",
			"edges",
			"seams",
			"start",
			"exit",
			"deliberation",
			"criticalPath",
			"lanterns",
			"extraEdges",
			"frontDoor",
			"exitDoor",
		}
	do
		frozen[key] = layout[key]
	end
	local source = table.concat({
		"-- The authored mansion: used when every generation attempt fails",
		"-- (Logic/MansionGen.fallback). Frozen from seed "
			.. seed
			.. " with `lune run tools/plan "
			.. seed
			.. " mansion freeze`;",
		"-- tests/specs/Mansion.spec checks it still passes the validator.",
		"",
		"return " .. literal(frozen),
		"",
	}, string.char(10))
	fs.writeFile("src/shared/Data/MansionFallback.luau", source)
	print("froze seed " .. seed .. " into src/shared/Data/MansionFallback.luau")
end
