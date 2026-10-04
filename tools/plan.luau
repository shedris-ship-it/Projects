-- Prints a layout as an ASCII floor plan, with a legend and its fingerprint
-- hash. Run from the repository root:
--
--     lune run tools/plan <seed> [cells|mansion]
--
-- "cells" is the old generator (Logic/LevelGraph); "mansion" is the mansion
-- generator (docs/plans/mansion-generation.md).

local process = require("@lune/process")

local Harness = require("../tests/harness")

local Shared = Harness.root("src/shared", "Shared")
local Config = Harness.require(Shared.Config)
local Rooms = Harness.require(Shared.Data.Rooms)
local FloorPlan = Harness.require(Shared.Logic.FloorPlan)

local seed = tonumber(process.args[1]) or 1800820264
local mode = process.args[2] or "cells"

local layout, config
if mode == "mansion" then
	local MansionGen = Harness.require(Shared.Logic.MansionGen)
	config = Config.Mansion
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
