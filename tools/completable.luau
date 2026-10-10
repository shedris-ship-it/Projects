-- Can every house the game might play be finished? (The progression audit,
-- 2026-10-10.) Builds houses exactly as a run does (Logic/HouseSize for the
-- squad, the difficulty and the night; every candidate Logic/HouseSearch
-- could pick), then walks each plan the way the bot does (Logic/BotPlan) from
-- the start to the table and out of the front door. Run from the repository
-- root:
--
--     lune run tools/completable [seeds] [candidates]
--
-- seeds: how many run seeds per squad, difficulty and night (default 6);
-- candidates: how many of each seed's candidates (default all 12). Prints
-- every house that can't be finished, and the gate kinds seen.

local process = require("@lune/process")

local Harness = require("../tests/harness")

local Shared = Harness.root("src/shared", "Shared")
local Config = Harness.require(Shared.Config)
local Rooms = Harness.require(Shared.Data.Rooms)
local BotPlan = Harness.require(Shared.Logic.BotPlan)
local HouseSearch = Harness.require(Shared.Logic.HouseSearch)
local HouseSize = Harness.require(Shared.Logic.HouseSize)
local NavGraph = Harness.require(Shared.Logic.NavGraph)

local seeds = tonumber(process.args[1]) or 6
local candidates = tonumber(process.args[2]) or Config.LevelDesign.Candidates

local total, failed = 0, 0
local kinds, puzzles = {}, {}
local started = os.clock()
for squad = 1, 4 do
	for _, hard in { false, true } do
		for _, night in { "full", "short" } do
			local mansion, progression = HouseSize.config(
				Config.Mansion,
				Config.Progression,
				squad,
				hard and 1 or 0,
				night ~= "full" and night or nil
			)
			local opts = {
				templates = Rooms.Mansion,
				templatesById = Rooms.MansionById,
				mansion = mansion,
				progression = progression,
				extra = hard and 1 or 0,
				leads = Config.Leads,
				nav = NavGraph.options(Config),
				targets = Config.LevelDesign.Targets,
				shortcut = Config.LevelDesign.ShortcutStuds,
				squad = squad,
				candidates = candidates,
			}
			for s = 1, seeds do
				local seed = s * 7919 + squad * 131 + (hard and 17 or 0) + (night == "short" and 5 or 0)
				for i = 1, candidates do
					local found = HouseSearch.candidate(seed, i, opts)
					local plan, layout = found.plan, found.layout
					local seams = {}
					for _, seam in layout.seams do
						seams[seam.id] = { a = seam.a, b = seam.b }
					end
					local start = plan.regions and plan.regions[0] and plan.regions[0].rooms or { layout.start }
					local steps, tableSet = BotPlan.walk(plan, seams, start, 200)
					local out = #steps > 0 and steps[#steps].kind == "extract"
					total += 1
					for _, lock in plan.locks do
						kinds[lock.kind] = (kinds[lock.kind] or 0) + 1
					end
					for _, puzzle in plan.puzzles or {} do
						puzzles[puzzle.kind] = (puzzles[puzzle.kind] or 0) + 1
					end
					if not tableSet or not out or not found.metrics.tableSet then
						failed += 1
						local last = steps[#steps]
						print(
							string.format(
								"CAN'T FINISH: squad %d %s %s seed %d candidate %d: table %s, out %s, metrics %s, %d steps, last %s",
								squad,
								hard and "Hard" or "Normal",
								night,
								seed,
								i,
								tostring(tableSet),
								tostring(out),
								tostring(found.metrics.tableSet),
								#steps,
								last and last.kind or "-"
							)
						)
					end
				end
			end
		end
	end
end

local function line(counts)
	local names = {}
	for name in counts do
		table.insert(names, name)
	end
	table.sort(names)
	local parts = {}
	for _, name in names do
		table.insert(parts, name .. "=" .. counts[name])
	end
	return table.concat(parts, " ")
end
print(string.format("%d houses, %d can't be finished (%.0f s)", total, failed, os.clock() - started))
print("locks: " .. line(kinds))
print("puzzles: " .. line(puzzles))
process.exit(failed == 0 and 0 or 1)
