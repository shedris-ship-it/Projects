return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rng = require(Shared.Lib.Rng)
	local Util = require(Shared.Lib.Util)
	local DriftModel = require(Shared.Logic.DriftModel)
	local SquadProfile = require(Shared.Logic.SquadProfile)
	local UtilityAI = require(Shared.Logic.UtilityAI)
	local Tactics = require(Shared.Data.Tactics)
	local ScareDeck = require(Shared.Logic.ScareDeck)
	local DirectorModel = require(Shared.Logic.DirectorModel)
	local Progression = require(Shared.Logic.Progression)

	test("rng: deterministic, in range, roughly uniform", function()
		local a, b = Rng.new(42), Rng.new(42)
		for _ = 1, 100 do
			check.equal(a:NextNumber(), b:NextNumber(), "same sequence")
		end
		local rng = Rng.new(7)
		local buckets = { 0, 0, 0, 0, 0, 0 }
		for _ = 1, 6000 do
			local v = rng:NextInteger(1, 6)
			check.truthy(v >= 1 and v <= 6, "out of range")
			buckets[v] += 1
		end
		for i, n in buckets do
			check.truthy(n > 850 and n < 1150, "bucket " .. i .. " has " .. n)
		end
		local f1, f2 = Rng.new(1):Fork("a"), Rng.new(1):Fork("b")
		check.truthy(f1:NextNumber() ~= f2:NextNumber(), "forks should differ")
	end)

	test("util: clock directions", function()
		check.equal(Util.clockDirection(0, -1, 0, -1), 12, "ahead")
		check.equal(Util.clockDirection(0, -1, 1, 0), 3, "right")
		check.equal(Util.clockDirection(0, -1, 0, 1), 6, "behind")
		check.equal(Util.clockDirection(0, -1, -1, 0), 9, "left")
		check.equal(Util.clockDirection(1, 0, 0, 1), 3, "right when facing east")
	end)

	test("drift: baseline alone collapses after about 40 minutes", function()
		local drift = DriftModel.new(Config.Drift)
		local seconds = 0
		while not drift:IsCollapsed() do
			drift:Tick(1, 0)
			seconds += 1
		end
		check.near(seconds / 60, 40, 0.1, "minutes to collapse")
	end)

	test("drift: isolation adds per isolated player", function()
		local drift = DriftModel.new(Config.Drift)
		drift:Tick(60, 2)
		check.near(drift.value, 2.5 + 2, 1e-6, "one minute with two isolated players")
	end)

	test("drift: events and the per-minute caps", function()
		local drift = DriftModel.new(Config.Drift)
		drift:Set(50)
		drift:Apply("PlayerDowned", 0)
		check.near(drift.value, 60, 1e-6, "a down")
		drift:Apply("LockOpened", 1)
		check.near(drift.value, 55, 1e-6, "a lock opened")
		local cap = Config.Drift.Caps.ItemFound
		local step = -Config.Drift.Events.ItemFound
		for i = 1, cap + 2 do
			drift:Apply("ItemFound", 10 + i)
		end
		check.near(drift.value, 55 - cap * step, 1e-6, "items found count only so often a minute")
		drift:Apply("ItemFound", 80)
		check.near(drift.value, 55 - (cap + 1) * step, 1e-6, "the cap frees up after a minute")
		check.equal((DriftModel.stateFor(Config.Drift, 61)), "Breaking", "state name")
		check.equal((DriftModel.stateFor(Config.Drift, 0)), "Calm", "state name")
	end)

	test("drift: hard difficulty speeds up the clock", function()
		local drift = DriftModel.new(Config.Drift, 1.25)
		drift:Tick(60, 0)
		check.near(drift.value, 2.5 * 1.25, 1e-6, "hard baseline")
	end)

	test("squad profile: counters decay with the half-life", function()
		local profile = SquadProfile.new(100)
		profile:Add("hides", 4, 0)
		check.near(profile:Get("hides", 100), 2, 1e-6, "half after one half-life")
		profile:AddTo("hide", "locker", 3, 0)
		profile:AddTo("hide", "bed", 1, 0)
		check.equal(profile:Ranked("hide", 10)[1].key, "locker", "favourite category")
		local signals = profile:Signals(0)
		check.near(signals.hideHabit, 1, 1e-6, "hide habit saturates")
		check.truthy(signals.cohesion >= 0 and signals.cohesion <= 1, "cohesion in range")
	end)

	test("utility AI: habits change the choice, cooldowns block it", function()
		local feasibility = {}
		for _, tactic in Tactics.List do
			feasibility[tactic.id] = 1
		end
		local hiders = { hideHabit = 1 }
		local counts = {}
		local rng = Rng.new(5)
		for _ = 1, 400 do
			local id = UtilityAI.choose(Tactics.List, hiders, feasibility, {}, 0, rng)
			counts[id] = (counts[id] or 0) + 1
		end
		check.truthy((counts.CheckHidingSpots or 0) > 60, "hiding-spot checks should be common against hiders")
		local id = UtilityAI.choose(Tactics.List, hiders, { CheckHidingSpots = 1 }, { CheckHidingSpots = 0 }, 1, rng)
		check.equal(id, nil, "cooldown blocks the only feasible tactic")
		check.atLeast(#Tactics.List, 12, "tactic menu size")
	end)

	test("scare deck: respects cooldowns and the big-scare gap", function()
		local deck = ScareDeck.new({
			{ id = "knock", weight = 2, cooldown = 10 },
			{ id = "figure", weight = 1, big = true, cooldown = 0 },
		}, Rng.new(1), 60)
		local lastBig = -math.huge
		for t = 0, 600, 5 do
			local card = deck:Draw(t, 50)
			if card and card.big then
				check.atLeast(t - lastBig, 60, "big scares too close")
				lastBig = t
			end
		end
	end)

	test("director: dormant early, no hunts before 3 minutes, hunts at Breaking", function()
		local base = { now = 0, drift = 70, runTime = 60, stationary = 0 }
		local r = DirectorModel.evaluate(base, Config)
		check.equal(r.tier, 0, "dormant in the first 90s")
		check.truthy(not r.huntDue, "no early hunt")
		base.runTime = 200
		base.now = 200
		r = DirectorModel.evaluate(base, Config)
		check.equal(r.tier, 3, "tier at 70 drift")
		check.truthy(r.huntDue, "first hunt at Breaking")
		base.lastHuntEnded = 150
		r = DirectorModel.evaluate(base, Config)
		check.truthy(not r.huntDue, "cooldown")
		base.squadInLantern = true
		base.forced = true
		r = DirectorModel.evaluate(base, Config)
		check.truthy(not r.huntDue, "lantern rooms block even forced hunts")
		base.squadInLantern = false
		base.lastRevive = 190
		r = DirectorModel.evaluate(base, Config)
		check.truthy(not r.huntDue, "no hunt within 20s of a revive")
		check.equal(DirectorModel.tierForDrift(30), 1, "tier 1")
		check.equal(DirectorModel.tierForDrift(45), 2, "tier 2")
	end)

	test("progression: failing forward still pays, levels cap at 50", function()
		check.truthy(Progression.marksForRun({ won = false, drift = 100 }) > 0, "a collapse still pays")
		check.truthy(
			Progression.marksForRun({ won = true, extracted = true, drift = 20 })
				> Progression.marksForRun({ won = true, drift = 80 }),
			"low drift pays more"
		)
		-- Progress pays, won or lost: +10 a region opened or a puzzle solved.
		local lost = { won = false, drift = 100 }
		local progressed = { won = false, drift = 100, regionsOpened = 2, puzzlesSolved = 1 }
		check.equal(
			Progression.marksForRun(progressed) - Progression.marksForRun(lost),
			30,
			"two regions and a puzzle are worth 30"
		)
		check.equal(
			Progression.marksForRun({ won = false, drift = 100, survivedHunts = 2 }) - Progression.marksForRun(lost),
			30,
			"two hunts survived are worth 30"
		)
		local level = Progression.levelFromXp(10 ^ 7)
		check.equal(level, 50, "max level")
		check.equal((Progression.levelFromXp(0)), 1, "start level")
	end)
end
