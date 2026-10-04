-- Records what the old generator (Logic/LevelGraph) builds for a fixed set of
-- seeds, as one fingerprint hash per seed, in tests/golden/LevelGraph.txt.
-- tests/specs/Golden.spec.luau fails if any of them ever changes, so work on
-- the mansion can't quietly change the houses players get today.
--
-- Only rerun this when a change to the old layouts is intended and approved:
--
--     lune run tools/golden

local fs = require("@lune/fs")

local Harness = require("../tests/harness")

local Shared = Harness.root("src/shared", "Shared")
local Config = Harness.require(Shared.Config)
local Rooms = Harness.require(Shared.Data.Rooms)
local LevelGraph = Harness.require(Shared.Logic.LevelGraph)
local FloorPlan = Harness.require(Shared.Logic.FloorPlan)

local seeds = {}
for seed = 1, 1000 do
	table.insert(seeds, seed)
end
-- The debug seed the baseline screenshots use, and the specs' favourites.
for _, seed in { 1800820264, 12345, 4242 } do
	table.insert(seeds, seed)
end

local lines = { "# seed hash: LevelGraph fingerprints (lune run tools/golden)" }
for _, seed in seeds do
	local layout = LevelGraph.generate(seed, Rooms.List, Config.Level)
	table.insert(lines, seed .. " " .. FloorPlan.hash(layout))
end
fs.writeFile("tests/golden/LevelGraph.txt", table.concat(lines, "\n") .. "\n")
print("wrote " .. #seeds .. " fingerprints to tests/golden/LevelGraph.txt")
