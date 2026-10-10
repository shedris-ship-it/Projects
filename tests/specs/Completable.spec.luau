-- Every house the game might play can be finished (the progression audit,
-- 2026-10-10): built as a run builds it (Logic/HouseSize for each squad
-- size, Normal and Hard, the full and the short night; candidates Logic/
-- HouseSearch could pick) and walked as the bot walks it (Logic/BotPlan) to
-- the table and out of the front door. tools/completable sweeps thousands.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local BotPlan = require(Shared.Logic.BotPlan)
	local HouseSearch = require(Shared.Logic.HouseSearch)
	local HouseSize = require(Shared.Logic.HouseSize)
	local NavGraph = require(Shared.Logic.NavGraph)

	test("every squad, difficulty and night: the table set, then out", function()
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
					}
					for _, seed in { 101 + squad, 2203 + squad * 7 } do
						for _, i in { 1, 7 } do
							local found = HouseSearch.candidate(seed, i, opts)
							local seams = {}
							for _, seam in found.layout.seams do
								seams[seam.id] = { a = seam.a, b = seam.b }
							end
							local steps, tableSet = BotPlan.walk(found.plan, seams, found.plan.regions[0].rooms, 200)
							local name = string.format(
								"squad %d %s %s seed %d candidate %d",
								squad,
								hard and "Hard" or "Normal",
								night,
								seed,
								i
							)
							check.truthy(tableSet, name .. ": the table set")
							check.equal(steps[#steps].kind, "extract", name .. ": out of the house")
						end
					end
				end
			end
		end
	end)
end
