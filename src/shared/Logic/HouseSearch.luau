-- Pick the best house, not the first that works (docs/plans/level-design.md
-- section 5.5). A run builds several candidate mansions, each from its own
-- forks of the seed, with its escape plan and leads; each is walked and
-- measured (Logic/HouseMetrics: the walk, the backtracking, the shortcuts, a
-- loop and a hiding spot at every stage, every room's reason) and the one
-- nearest the targets is played. The pick depends only on the seed, the
-- squad size and the difficulty, so F2 `seed` and `squad` bring a house back.
-- Pure; `yield` (task.wait on the server) runs between candidates.

local Family = require(script.Parent.Family)
local HouseMetrics = require(script.Parent.HouseMetrics)
local HousePlans = require(script.Parent.HousePlans)
local Leads = require(script.Parent.Leads)
local LockPlanner = require(script.Parent.LockPlanner)
local MansionGen = require(script.Parent.MansionGen)
local RoomPurpose = require(script.Parent.RoomPurpose)
local Rng = require(script.Parent.Parent.Lib.Rng)

local HouseSearch = {}

-- The seed candidate `i` is generated from: the run's own for the first (the
-- house the generator alone would build), then draws from a fork of it.
-- (Not Fork("house " .. i): those salts hash one apart, so the next run's
-- seed would get most of the same houses.)
function HouseSearch.candidateSeed(seed: number, i: number): number
	if i == 1 then
		return seed
	end
	local rng = Rng.new(seed):Fork("houses")
	local value = seed
	for _ = 2, i do
		value = rng:NextInteger(1, 2147483646)
	end
	return value
end

-- One candidate: { layout, plan, leads, purposes, metrics, score, card }.
function HouseSearch.candidate(seed: number, i: number, opts)
	local houseSeed = HouseSearch.candidateSeed(seed, i)
	local layout = MansionGen.generate(houseSeed, opts.templates, opts.mansion)
	-- The run's seed names the house; the candidate is how it was found.
	layout.seed = seed
	layout.candidate = i
	layout.houseSeed = houseSeed
	local rng = Rng.new(houseSeed)
	local plan = LockPlanner.plan(
		layout,
		opts.templatesById,
		rng:Fork("progression"),
		opts.progression,
		opts.mansion,
		opts.extra
	)
	-- A servants' passage stays within one wing; if the planner drew its own
	-- regions instead of the wings', it could cross one, so it goes.
	if not plan.stats.wings then
		layout.passages = nil
	end
	local leads = Leads.plan(plan, Leads.rooms(layout, opts.templatesById), rng:Fork("leads"), opts.leads)
	-- The house plans on a desk somewhere open early (Logic/HousePlans).
	plan.housePlans = HousePlans.choose(layout, plan, opts.templatesById, rng:Fork("plans"))
	local purposes = RoomPurpose.of(layout, plan, opts.templatesById, leads)
	local metrics = HouseMetrics.measure(layout, plan, opts.templatesById, {
		nav = opts.nav,
		config = opts.mansion,
		shortcut = opts.shortcut,
		purposes = purposes,
	})
	local score, card = HouseMetrics.score(metrics, opts.targets, opts.squad)
	return {
		index = i,
		layout = layout,
		plan = plan,
		leads = leads,
		purposes = purposes,
		metrics = metrics,
		score = score,
		card = card,
	}
end

-- The best of opts.candidates houses (the lowest score; the earlier on a
-- tie). opts: templates, templatesById, mansion and progression (the run's,
-- Logic/HouseSize), leads (Config.Leads), nav (NavGraph.options), targets,
-- shortcut, squad, extra (Hard's regions), candidates. Returns the chosen
-- candidate with `scores` (every candidate's, in order).
function HouseSearch.run(seed: number, opts, yield: (() -> ())?)
	local best = nil
	local scores = {}
	for i = 1, math.max(1, opts.candidates) do
		local found = HouseSearch.candidate(seed, i, opts)
		scores[i] = found.score
		if best == nil or found.score < best.score then
			best = found
		end
		if yield and i < opts.candidates then
			yield()
		end
	end
	best.scores = scores
	-- The family who lived here (docs/plans/level-design.md section 11, L3.1),
	-- for the house that's played: who, whose rooms, and the charms on the
	-- doors.
	local family = Family.make(Rng.new(best.layout.houseSeed or seed):Fork("family"), best.layout)
	Family.markDoors(family, best.plan, LockPlanner.label)
	best.layout.family = family
	best.family = family
	return best
end

return HouseSearch
