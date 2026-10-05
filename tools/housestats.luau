-- The level-design numbers (Logic/HouseMetrics, docs/plans/level-design.md
-- section 5.1) over many houses: the spread of every metric and of the score
-- against Config.LevelDesign.Targets. Run from the repository root:
--
--     lune run tools/housestats [count] [squad] [single]
--
-- The squad size (1-4, default 4) sizes the house (Config.Mansion.BySquad)
-- and picks the targets' bands. Each house is the best of several, as a run
-- builds it (Logic/HouseSearch); `single` measures the generator's first
-- house alone.

local process = require("@lune/process")

local Harness = require("../tests/harness")

local Shared = Harness.root("src/shared", "Shared")
local Config = Harness.require(Shared.Config)
local Rooms = Harness.require(Shared.Data.Rooms)
local HouseMetrics = Harness.require(Shared.Logic.HouseMetrics)
local HouseSearch = Harness.require(Shared.Logic.HouseSearch)
local HouseSize = Harness.require(Shared.Logic.HouseSize)
local NavGraph = Harness.require(Shared.Logic.NavGraph)

local count = tonumber(process.args[1]) or 50
local squad = tonumber(process.args[2]) or 4
local single = process.args[3] == "single"
local design = Config.LevelDesign
local nav = NavGraph.options(Config)
local config, progression = HouseSize.config(Config.Mansion, Config.Progression, squad)

local values = {} -- metric -> { values }
local scores = {}
local misses = {} -- metric -> houses outside the band
local started = os.clock()
for seed = 1, count do
	local found = HouseSearch.run(seed, {
		templates = Rooms.Mansion,
		templatesById = Rooms.MansionById,
		mansion = config,
		progression = progression,
		leads = Config.Leads,
		nav = nav,
		targets = design.Targets,
		shortcut = design.ShortcutStuds,
		squad = squad,
		candidates = single and 1 or design.Candidates,
	})
	local layout, plan, m = found.layout, found.plan, found.metrics
	-- How many houses were planned as wings (Logic/Wings) and kept them.
	m.wingsPlanned = layout.wings and 1 or 0
	m.wingsKept = plan.stats.wings and 1 or 0
	for key, value in m do
		if type(value) == "number" then
			values[key] = values[key] or {}
			table.insert(values[key], value)
		end
	end
	local score, card = HouseMetrics.score(m, design.Targets, squad)
	table.insert(scores, score)
	for _, line in card do
		if line.penalty > 0 then
			misses[line.name] = (misses[line.name] or 0) + 1
		end
	end
end
local elapsed = os.clock() - started

local function spread(list)
	table.sort(list)
	local function at(q)
		return list[math.clamp(math.ceil(#list * q), 1, #list)]
	end
	local function show(v)
		if v == math.huge then
			return "inf"
		end
		return math.floor(v) == v and tostring(v) or string.format("%.2f", v)
	end
	return string.format("min %8s  p25 %8s  median %8s  p75 %8s  max %8s", show(list[1]), show(at(0.25)), show(at(0.5)), show(at(0.75)), show(list[#list]))
end

print(string.format("%d mansions, squad %d (%.0f ms a house)", count, squad, elapsed * 1000 / count))
local keys = {}
for key in values do
	table.insert(keys, key)
end
table.sort(keys)
for _, key in keys do
	local target = design.Targets[key]
	local band = target and ((target.bySquad and target.bySquad[squad]) or target.band)
	print(
		string.format(
			"%-17s %s%s",
			key,
			spread(values[key]),
			band and string.format("   band %s-%s, missed by %d", tostring(band[1]), tostring(band[2]), misses[key] or 0)
				or ""
		)
	)
end
print(string.format("%-17s %s", "SCORE", spread(scores)))
