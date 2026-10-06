-- The best of several houses (Logic/HouseSearch, docs/plans/level-design.md
-- section 5.5): a seed and squad always give the same house, the pick is
-- never worse than the generator's first, candidates differ from run to run,
-- and the kept houses meet the structural targets.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local FloorPlan = require(Shared.Logic.FloorPlan)
	local HouseSearch = require(Shared.Logic.HouseSearch)
	local HouseSize = require(Shared.Logic.HouseSize)
	local NavGraph = require(Shared.Logic.NavGraph)

	-- Fewer candidates than a run, to keep the suite quick.
	local CANDIDATES = 5

	local function options(squad: number, candidates: number, profile: string?)
		local mansion, progression = HouseSize.config(Config.Mansion, Config.Progression, squad, 0, profile)
		return {
			templates = Rooms.Mansion,
			templatesById = Rooms.MansionById,
			mansion = mansion,
			progression = progression,
			leads = Config.Leads,
			nav = NavGraph.options(Config),
			targets = Config.LevelDesign.Targets,
			shortcut = Config.LevelDesign.ShortcutStuds,
			squad = squad,
			candidates = candidates,
		}
	end

	test("the short night (WP8): a small house, one locked wing, two heirlooms, found every time", function()
		local fallbacks = 0
		for seed = 1, 20 do
			local found = HouseSearch.run(seed * 7 + 3, options(1, CANDIDATES, "short"))
			local layout, plan = found.layout, found.plan
			check.truthy(layout ~= nil and plan ~= nil, "seed " .. seed .. ": a house and a plan")
			if layout.fallback then
				fallbacks += 1 -- (the frozen fallback is the full house: not short)
			else
				check.atMost(#layout.rooms, 16, "seed " .. seed .. ": a short house (" .. #layout.rooms .. " rooms)")
			end
			check.equal(#plan.finale.heirlooms, 2, "two heirlooms")
			local regions = 0
			for id in plan.regions do
				if id ~= 0 then
					regions += 1
				end
			end
			check.atMost(regions, 1, "one locked wing after the first")
			check.equal(plan.stats.pockets or 0, 0, "no pockets")
		end
		check.atMost(fallbacks, 2, "fallbacks: " .. fallbacks .. " of 20")
	end)

	test("the same seed and squad keep the same house, plan and leads", function()
		local a = HouseSearch.run(4242, options(4, 3))
		local b = HouseSearch.run(4242, options(4, 3))
		check.equal(a.index, b.index)
		check.equal(FloorPlan.hash(a.layout), FloorPlan.hash(b.layout))
		check.equal(table.concat(a.plan.order, ","), table.concat(b.plan.order, ","))
		check.equal(a.score, b.score)
		check.equal(a.layout.seed, 4242, "the house goes by the run's seed")
	end)

	test("the pick is never worse than the first, and the yield runs between candidates", function()
		local yields = 0
		local found = HouseSearch.run(99, options(1, 4), function()
			yields += 1
		end)
		check.equal(#found.scores, 4)
		check.truthy(found.score <= found.scores[1], "no worse than the generator's own house")
		for _, score in found.scores do
			check.truthy(found.score <= score, "the lowest score is kept")
		end
		check.equal(yields, 3)
	end)

	test("next seeds get different candidates", function()
		local seen = {}
		local shared = 0
		for seed = 1, 3 do
			for i = 2, 6 do
				local s = HouseSearch.candidateSeed(seed, i)
				if seen[s] then
					shared += 1
				end
				seen[s] = true
			end
		end
		check.equal(shared, 0)
	end)

	test("kept houses: the squad's regions, none under three rooms, no heirloom in a corridor", function()
		for _, squad in { 1, 4 } do
			local short, small = 0, 0
			local seeds = 6
			for seed = 1, seeds do
				local found = HouseSearch.run(seed * 1009, options(squad, CANDIDATES))
				local m = found.metrics
				local wanted = Config.Mansion.BySquad[squad].regions
				if m.regions < wanted then
					short += 1
				end
				if (m.minRegion or 99) < 3 then
					small += 1
				end
				check.equal(m.corridorHeirlooms, 0, ("squad %d seed %d"):format(squad, seed))
				check.truthy(m.tableSet, ("squad %d seed %d: the table is set"):format(squad, seed))
			end
			check.truthy(short <= 1, ("squad %d: %d of %d houses short of regions"):format(squad, short, seeds))
			check.truthy(small <= 1, ("squad %d: %d of %d houses with a tiny region"):format(squad, small, seeds))
		end
	end)
end
