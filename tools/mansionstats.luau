-- How the mansion generator behaves over many seeds, for tuning
-- Config.Mansion (docs/plans/mansion-generation.md). From the repository root:
--
--     lune run tools/mansionstats [seeds]
--
-- Prints the first-try pass rate, fallbacks, time per house, how many rooms
-- are corridors and stairwells against real rooms, and the room counts.

local process = require("@lune/process")

local Harness = require("../tests/harness")

local Shared = Harness.root("src/shared", "Shared")
local Config = Harness.require(Shared.Config)
local Rooms = Harness.require(Shared.Data.Rooms)
local MansionGen = Harness.require(Shared.Logic.MansionGen)

local n = tonumber(process.args[1]) or 300
local started = os.clock()
local attempts, fallbacks, firstTry = 0, 0, 0
local spine, general, upperGeneral, twoStairs = 0, 0, 0, 0
local counts, problems = {}, {}
for seed = 1, n do
	local layout = MansionGen.generate(seed, Rooms.Mansion, Config.Mansion)
	attempts += layout.attempts
	if layout.fallback then
		fallbacks += 1
		for _, problem in layout.lastProblems or {} do
			local kind = string.gsub(problem, "%d+", "#")
			problems[kind] = (problems[kind] or 0) + 1
		end
	end
	if layout.attempts == 1 then
		firstTry += 1
	end
	counts[#layout.rooms] = (counts[#layout.rooms] or 0) + 1
	local stairs = 0
	for _, room in layout.rooms do
		if room.corridor or room.kind == "stair" then
			spine += 1
		end
		if room.kind == "stair" then
			stairs += 1
		end
		if room.kind == nil then
			general += 1
			if room.floor == 1 then
				upperGeneral += 1
			end
		end
	end
	if stairs == 2 then
		twoStairs += 1
	end
end
local elapsed = os.clock() - started

print(
	("%d seeds: first try %.1f%%, mean attempts %.2f, fallbacks %d, %.1f ms per house"):format(
		n,
		firstTry / n * 100,
		attempts / n,
		fallbacks,
		elapsed / n * 1000
	)
)
print(
	("per house: %.1f corridors and stairwells, %.1f general rooms (%.1f upstairs); two stairwells in %d%%"):format(
		spine / n,
		general / n,
		upperGeneral / n,
		twoStairs * 100 // n
	)
)
local sizes = {}
for size in counts do
	table.insert(sizes, size)
end
table.sort(sizes)
local parts = {}
for _, size in sizes do
	table.insert(parts, size .. " rooms: " .. counts[size])
end
print(table.concat(parts, ", "))
for problem, count in problems do
	print(("  fallback reason x%d: %s"):format(count, problem))
end
