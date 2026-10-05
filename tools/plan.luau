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
-- squad of `squad` (1-4, default 4; docs/plans/level-design.md section 5.2)
-- and is the best of several, as a run builds it (Logic/HouseSearch); add
-- `single` after the squad for the generator's first house alone.

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

local layout, config, found
local progression = Config.Progression
if mode == "mansion" then
	local HouseSearch = Harness.require(Shared.Logic.HouseSearch)
	local HouseSize = Harness.require(Shared.Logic.HouseSize)
	local NavGraph = Harness.require(Shared.Logic.NavGraph)
	config, progression = HouseSize.config(Config.Mansion, Config.Progression, squad)
	found = HouseSearch.run(seed, {
		templates = Rooms.Mansion,
		templatesById = Rooms.MansionById,
		mansion = config,
		progression = progression,
		leads = Config.Leads,
		nav = NavGraph.options(Config),
		targets = Config.LevelDesign.Targets,
		shortcut = Config.LevelDesign.ShortcutStuds,
		squad = squad,
		candidates = process.args[5] == "single" and 1 or Config.LevelDesign.Candidates,
	})
	layout = found.layout
	local scores = {}
	for _, score in found.scores do
		table.insert(scores, string.format("%.1f", score))
	end
	print(string.format("house %d of %d kept (scores %s)", found.index, #found.scores, table.concat(scores, " ")))
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
	-- The same fork RunOrchestrator gives it (the search planned a mansion's).
	local plan = found and found.plan
		or LockPlanner.plan(layout, templates, Rng.new(seed):Fork("progression"), progression, config)
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
				for _, need in lock.needs do
					for _, room in LockPlanner.producerRooms(plan, plan.tokens[need]) do
						table.insert(rooms, named(room))
					end
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
	-- The adventure the doors were laid for (Logic/Wings, docs/plans/level-design.md 5.3).
	local wings = layout.wings
	if wings and plan.stats.wings then
		local lines = {}
		local zero = wings.beats[0] or {}
		if zero.core then
			table.insert(lines, "region 0 built round a loop of " .. zero.core .. " rooms")
		end
		for _, r in wings.order do
			local beat = wings.beats[r]
			local parts = {}
			if beat.backtrack then
				table.insert(parts, "backtrack (its near door is bolted; in from another region)")
			end
			if beat.parallel then
				table.insert(parts, "opens side by side with the one before")
			end
			if beat.loop then
				table.insert(parts, "a loop inside (" .. beat.loop .. ")")
			end
			if beat.shortcut then
				table.insert(parts, "shortcut home " .. beat.shortcut)
			end
			table.insert(lines, "region " .. r .. ": " .. (#parts > 0 and table.concat(parts, "; ") or "plain"))
		end
		print("  the adventure: " .. table.concat(lines, "\n                 "))
	elseif layout.wings then
		print("  (planned as wings, but the planner grew its own regions)")
	end
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
	local Leads = Harness.require(Shared.Logic.Leads)
	local NavGraph = Harness.require(Shared.Logic.NavGraph)
	local RoomPurpose = Harness.require(Shared.Logic.RoomPurpose)
	-- The leads with the fork RunOrchestrator gives them.
	local leads = found and found.leads
		or Leads.plan(plan, Leads.rooms(layout, templates), Rng.new(seed):Fork("leads"), Config.Leads)
	local purposes = RoomPurpose.of(layout, plan, templates, leads)
	print("Every room's reasons (docs/plans/level-design.md section 4):")
	for _, room in layout.rooms do
		print(string.format("  %-22s %s", named(room.id), RoomPurpose.describe(purposes[room.id])))
	end
	local m = HouseMetrics.measure(layout, plan, templates, {
		nav = NavGraph.options(Config),
		config = config,
		shortcut = Config.LevelDesign.ShortcutStuds,
		purposes = purposes,
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
