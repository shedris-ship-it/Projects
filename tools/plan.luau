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

local fs = require("@lune/fs")
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
