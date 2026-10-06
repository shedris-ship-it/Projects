-- Pacing over a whole run (docs/plans/gameplay-rework.md, R2c; the owner's
-- audit of 2026-10-06): Drift, Dread, the Director and the acts, simulated
-- second by second. A squad that keeps making progress meets a few hunts,
-- meets his tier 3 in the second half of its run, and never collapses; a
-- squad that stalls is hunted more and more until the house comes apart.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Acts = require(Shared.Logic.Acts)
	local DirectorModel = require(Shared.Logic.DirectorModel)
	local Dread = require(Shared.Logic.Dread)
	local DriftModel = require(Shared.Logic.DriftModel)

	local TELEGRAPH = 4

	-- events: { t (seconds), kind = "gate" | "found" | "place" }. Returns a
	-- record: hunt start times, the highest Drift, when it collapsed (or
	-- nil), the tier each second and the Dread each second. The gap after a
	-- hunt is the middle roll, and no false alarms or returns are drawn, so
	-- the run is the same every time.
	local function simulate(shape, events, seconds, difficulty)
		difficulty = difficulty or Config.Difficulty.Normal
		local drift = DriftModel.new(Config.Drift, difficulty.DriftMultiplier)
		local facts = { gates = shape.gates, heirlooms = shape.heirlooms, places = shape.heirlooms }
		facts.gatesOpened, facts.heirloomsFound, facts.placesSet = 0, 0, 0
		local act, actSince, armedAt, lastHuntEnded, retreatUntil, huntEnds = 1, 0, nil, nil, nil, nil
		local lastProgress, foundAny = 0, false
		local record = { hunts = {}, peak = 0, collapsed = nil, tiers = {}, dreads = {} }
		local delay = (Config.Pacing.ArmDelay[1] + Config.Pacing.ArmDelay[2]) / 2
		local gap = DirectorModel.huntGap(0.5, Config)
		local function arm(t)
			if armedAt == nil or t + delay < armedAt then
				armedAt = t + delay
			end
		end
		for t = 0, seconds do
			for _, e in events do
				if e.t == t then
					lastProgress = t
					if e.kind == "gate" then
						facts.gatesOpened += 1
						drift:Apply("LockOpened", t)
						drift:Apply("RegionEntered", t)
						arm(t)
					elseif e.kind == "found" then
						facts.heirloomsFound += 1
						drift:Apply("ItemFound", t)
						if not foundAny then
							foundAny = true
							arm(t)
						end
					else
						facts.placesSet += 1
						drift:Apply("ItemFound", t)
					end
				end
			end
			local now = Acts.of(facts, Config.Pacing)
			if now > act then
				act, actSince = now, t
				arm(t)
			end
			drift:Tick(1, 0, t - lastProgress >= Config.Drift.StallGraceSeconds)
			record.peak = math.max(record.peak, drift.value)
			local dread = Dread.value(drift.value, act, t - actSince, Config.Pacing, difficulty)
			record.dreads[t] = dread
			if huntEnds then
				record.tiers[t] = 4
				if t >= huntEnds then
					huntEnds = nil
					lastHuntEnded = t
					retreatUntil = t + Config.Stalker.RetreatTierSeconds
					drift:Apply("HuntSurvived", t)
				end
			else
				local decision = DirectorModel.evaluate({
					now = t,
					runTime = t,
					drift = drift.value,
					dread = dread,
					act = act,
					armedAt = armedAt,
					minGap = gap,
					lastHuntEnded = lastHuntEnded,
					retreatUntil = retreatUntil,
					stationary = 0,
					difficulty = difficulty,
				}, Config)
				record.tiers[t] = decision.tier
				if decision.huntDue then
					table.insert(record.hunts, t)
					armedAt = nil
					huntEnds = t + TELEGRAPH + DirectorModel.huntDuration(dread, 0, Config)
				end
			end
			if drift:IsCollapsed() then
				record.collapsed = t
				return record
			end
		end
		return record
	end

	local function minutes(n)
		return n * 60
	end

	-- The first second a tier was reached outside a hunt, or nil.
	local function firstAt(record, tier)
		for t = 0, #record.tiers do
			if record.tiers[t] == tier then
				return t
			end
		end
		return nil
	end

	local steadyEvents = {
		{ t = minutes(4), kind = "gate" },
		{ t = minutes(7), kind = "found" },
		{ t = minutes(10), kind = "gate" },
		{ t = minutes(12), kind = "place" },
		{ t = minutes(15), kind = "found" },
		{ t = minutes(16), kind = "gate" },
		{ t = minutes(18), kind = "place" },
		{ t = minutes(21), kind = "found" },
		{ t = minutes(23), kind = "place" },
	}

	test("a steady squad in a three-region house meets 2-5 hunts and never comes near collapse", function()
		local r = simulate({ gates = 3, heirlooms = 3 }, steadyEvents, minutes(23))
		local at = {}
		for _, t in r.hunts do
			table.insert(at, string.format("%.1f", t / 60))
		end
		print(string.format("      steady: hunts at minutes %s; peak Drift %.0f", table.concat(at, ", "), r.peak))
		check.truthy(r.collapsed == nil, "no collapse")
		check.atLeast(#r.hunts, 2, "hunts before the dinner")
		check.atMost(#r.hunts, 5, "not a hunt every minute")
		check.atMost(r.peak, 85, "Drift stays under 85")
		check.atLeast(r.hunts[1], Config.Run.NoHuntBeforeSeconds, "no hunt in the first minutes")
	end)

	test(
		"fear follows progress: a clean run meets tier 2 after its first door and tier 3 in its second half",
		function()
			local r = simulate({ gates = 3, heirlooms = 3 }, steadyEvents, minutes(23))
			local tier2, tier3 = firstAt(r, 2), firstAt(r, 3)
			print(
				string.format(
					"      steady: tier 2 at minute %.1f, tier 3 at minute %.1f, Dread at the dinner %.0f",
					(tier2 or 0) / 60,
					(tier3 or 0) / 60,
					r.dreads[minutes(23)]
				)
			)
			check.truthy(tier2 ~= nil, "tier 2 comes")
			check.atLeast(tier2, minutes(4), "not before the first door")
			check.atMost(tier2, minutes(7), "but soon after it")
			check.truthy(tier3 ~= nil, "tier 3 comes to a clean run")
			check.atLeast(tier3, minutes(11), "in the second half")
			check.atMost(tier3, minutes(20), "before the dinner")
			check.atLeast(r.dreads[minutes(23)], 60, "the house is Breaking by the dinner")
			check.atMost(r.peak, 30, "though Drift, the failure clock, stayed low")
			-- Before the first door, nothing has changed: Dread is only Drift.
			check.atMost(r.dreads[minutes(3)], 15, "calm before the first door")
		end
	)

	test("dread's floor eases in over the ramp and only rises through the acts", function()
		local P = Config.Pacing
		check.equal(Dread.floor(1, 1000, P), 0, "act 1 has no floor")
		check.equal(Dread.floor(2, 0, P), 0, "act 2 starts from act 1's floor")
		check.near(Dread.floor(2, P.DreadRamp / 2, P), P.ActDread[2] / 2, 1e-6, "half way up at half the ramp")
		check.equal(Dread.floor(2, P.DreadRamp, P), P.ActDread[2], "and there at the ramp's end")
		check.equal(Dread.floor(3, 0, P), P.ActDread[2], "act 3 starts where act 2 ended")
		check.equal(Dread.floor(4, 1000, P), P.ActDread[4], "the dinner")
		check.equal(Dread.value(70, 2, 1000, P), 70, "Drift above the floor is what counts")
		check.equal(Dread.value(10, 3, 1000, P), P.ActDread[3], "the floor above Drift is what counts")
		check.atLeast(
			Dread.value(0, 1, 0, P, Config.Difficulty.Hard),
			Config.Difficulty.Hard.DreadFloor,
			"Hard starts uneasy"
		)
		check.equal(
			DirectorModel.tierFor(Config.Difficulty.Hard.DreadFloor),
			1,
			"so he's at tier 1 from the start on Hard"
		)
	end)

	test("the gap after a hunt is drawn afresh, never a clock", function()
		local P = Config.Pacing
		check.near(DirectorModel.huntGap(0.5, Config), P.MinHuntGap, 1e-6, "the middle roll is the gap itself")
		check.near(DirectorModel.huntGap(0, Config), P.MinHuntGap * (1 - P.HuntGapJitter), 1e-6, "the shortest")
		check.near(DirectorModel.huntGap(1, Config), P.MinHuntGap * (1 + P.HuntGapJitter), 1e-6, "the longest")
		-- A false alarm is a decision of its own; a return waits for no gap.
		local base = {
			now = 1000,
			runTime = 1000,
			drift = 10,
			dread = 10,
			act = 2,
			armedAt = 900,
			lastHuntEnded = 950,
			minGap = 180,
			difficulty = Config.Difficulty.Normal,
		}
		check.equal(DirectorModel.evaluate(base, Config).huntDue, false, "waiting out the gap")
		local urgent = table.clone(base)
		urgent.armedUrgent = true
		check.truthy(DirectorModel.evaluate(urgent, Config).huntDue, "he comes straight back")
		local alarm = table.clone(base)
		alarm.lastHuntEnded = nil
		alarm.armedFalse = true
		local d = DirectorModel.evaluate(alarm, Config)
		check.truthy(d.huntDue and d.falseAlarm, "a false alarm is due like a hunt")
		check.equal(d.reason, "false alarm", "and says so")
	end)

	test("a house with nothing locked still has hunts at the moments that matter", function()
		local events = {
			{ t = minutes(5), kind = "found" },
			{ t = minutes(8), kind = "place" },
			{ t = minutes(12), kind = "found" },
			{ t = minutes(15), kind = "place" },
		}
		local r = simulate({ gates = 0, heirlooms = 2 }, events, minutes(15))
		check.atLeast(#r.hunts, 2, "the old house meets him too")
	end)

	test("a squad that stalls is hunted more and more, and the house collapses before 45 minutes", function()
		local r = simulate({ gates = 3, heirlooms = 3 }, {}, minutes(45))
		print(string.format("      stalled: %d hunts, collapse at minute %.1f", #r.hunts, (r.collapsed or 0) / 60))
		check.truthy(r.collapsed ~= nil, "it collapses")
		check.atMost(r.collapsed or math.huge, minutes(45), "within 45 minutes")
		check.atLeast(#r.hunts, 3, "hunted on the way down")
	end)

	test("no hunt ever starts in the first three minutes, whatever wakes one", function()
		local events = { { t = 10, kind = "gate" }, { t = 20, kind = "found" } }
		local r = simulate({ gates = 3, heirlooms = 3 }, events, minutes(5))
		for _, t in r.hunts do
			check.atLeast(t, Config.Run.NoHuntBeforeSeconds, "too early")
		end
	end)
end
