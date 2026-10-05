-- Tuning numbers for the escape's lock planner (Logic/LockPlanner,
-- docs/plans/gameplay-rework.md section 5) over many houses. Run from the
-- repository root:
--
--     lune run tools/lockstats [count] [cells|mansion]
--
-- Prints how many regions the plans got, how often they needed fewer than
-- wanted and why, the gate kinds, backtracks, heirloom spread and attempts.

local process = require("@lune/process")

local Harness = require("../tests/harness")

local Shared = Harness.root("src/shared", "Shared")
local Config = Harness.require(Shared.Config)
local Rooms = Harness.require(Shared.Data.Rooms)
local Rng = Harness.require(Shared.Lib.Rng)
local LockPlanner = Harness.require(Shared.Logic.LockPlanner)

local count = tonumber(process.args[1]) or 100
local mode = process.args[2] or "mansion"

local generate, templates, config
if mode == "mansion" then
	local MansionGen = Harness.require(Shared.Logic.MansionGen)
	config, templates = Config.Mansion, Rooms.MansionById
	generate = function(seed)
		return MansionGen.generate(seed, Rooms.Mansion, config)
	end
else
	local LevelGraph = Harness.require(Shared.Logic.LevelGraph)
	config, templates = Config.Level, Rooms.ById
	generate = function(seed)
		return LevelGraph.generate(seed, Rooms.List, config)
	end
end

local regions, kinds, problems, short = {}, {}, {}, 0
local rejections = {}
local backtracks, attempts, puzzles, heirloomRegions, unsolved = 0, 0, 0, 0, 0
local regionSizes = {}
for seed = 1, count do
	local layout = generate(seed)
	local plan = LockPlanner.plan(layout, templates, Rng.new(seed):Fork("progression"), Config.Progression, config)
	local k = #plan.order
	regions[k] = (regions[k] or 0) + 1
	if k < LockPlanner.regionCount(#layout.rooms, Config.Progression) then
		short += 1
	end
	for _, lock in plan.locks do
		kinds[lock.kind] = (kinds[lock.kind] or 0) + 1
	end
	for _, problem in plan.stats.problems or {} do
		local key = string.gsub(problem, "%d+", "#")
		problems[key] = (problems[key] or 0) + 1
	end
	for key, n in plan.stats.rejected or {} do
		rejections[key] = (rejections[key] or 0) + n
	end
	backtracks += plan.stats.backtracks
	attempts += plan.stats.attempts
	puzzles += plan.stats.puzzles
	local seen = {}
	for _, id in plan.finale.heirlooms do
		seen[plan.roomRegion[plan.tokens[id].producer.room]] = true
	end
	for _ in seen do
		heirloomRegions += 1
	end
	for r = 0, k do
		table.insert(regionSizes, #plan.regions[r].rooms)
	end
	if not LockPlanner.solve(layout, plan, templates).solvable then
		unsolved += 1
	end
end

local function show(t)
	local keys = {}
	for key in t do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local out = {}
	for _, key in keys do
		table.insert(out, tostring(key) .. "=" .. t[key])
	end
	return table.concat(out, " ")
end

print(string.format("%d %s houses", count, mode))
print("regions: " .. show(regions) .. string.format("  (fewer than wanted: %d)", short))
print("locks: " .. show(kinds))
print(
	string.format(
		"backtracks %.2f a run, puzzles %.2f a run, attempts %.1f a run",
		backtracks / count,
		puzzles / count,
		attempts / count
	)
)
print(string.format("heirlooms spread over %.2f regions a run", heirloomRegions / count))
table.sort(regionSizes)
print(
	string.format(
		"region sizes: min %d, median %d, max %d",
		regionSizes[1],
		regionSizes[math.ceil(#regionSizes / 2)],
		regionSizes[#regionSizes]
	)
)
print("unsolvable: " .. unsolved)
print("last-resort plans' problems: " .. show(problems))
print("rejected attempts: " .. show(rejections))
