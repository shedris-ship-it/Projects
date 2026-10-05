-- Pacing over a whole run (docs/plans/gameplay-rework.md, R2c): Drift,
-- the Director and the acts, simulated second by second. A squad that keeps
-- making progress meets a few hunts and never collapses; a squad that stalls
-- is hunted more and more until the house comes apart.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Acts = require(Shared.Logic.Acts)
	local DirectorModel = require(Shared.Logic.DirectorModel)
	local DriftModel = require(Shared.Logic.DriftModel)

	local TELEGRAPH = 4

	-- events: { t (seconds), kind = "gate" | "found" | "place" }. Returns the
	-- hunt start times, the highest Drift, and when it collapsed (or nil).
	local function simulate(shape, events, seconds)
		local drift = DriftModel.new(Config.Drift)
		local facts = { gates = shape.gates, heirlooms = shape.heirlooms, places = shape.heirlooms }
		facts.gatesOpened, facts.heirloomsFound, facts.placesSet = 0, 0, 0
		local act, armedAt, lastHuntEnded, retreatUntil, huntEnds = 1, nil, nil, nil, nil
		local lastProgress, foundAny = 0, false
		local hunts, peak = {}, 0
		local delay = (Config.Pacing.ArmDelay[1] + Config.Pacing.ArmDelay[2]) / 2
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
				act = now
				arm(t)
			end
			drift:Tick(1, 0, t - lastProgress >= Config.Drift.StallGraceSeconds)
			peak = math.max(peak, drift.value)
			if huntEnds then
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
					act = act,
					armedAt = armedAt,
					lastHuntEnded = lastHuntEnded,
					retreatUntil = retreatUntil,
					stationary = 0,
					difficulty = Config.Difficulty.Normal,
				}, Config)
				if decision.huntDue then
					table.insert(hunts, t)
					armedAt = nil
					huntEnds = t + TELEGRAPH + DirectorModel.huntDuration(drift.value, 0, Config)
				end
			end
			if drift:IsCollapsed() then
				return hunts, peak, t
			end
		end
		return hunts, peak, nil
	end

	local function minutes(n)
		return n * 60
	end

	test("a steady squad in a three-region house meets 2-4 hunts and never comes near collapse", function()
		local events = {
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
		local hunts, peak, collapsed = simulate({ gates = 3, heirlooms = 3 }, events, minutes(23))
		local at = {}
		for _, t in hunts do
			table.insert(at, string.format("%.1f", t / 60))
		end
		print(string.format("      steady: hunts at minutes %s; peak Drift %.0f", table.concat(at, ", "), peak))
		check.truthy(collapsed == nil, "no collapse")
		check.atLeast(#hunts, 2, "hunts before the dinner")
		check.atMost(#hunts, 4, "not a hunt every minute")
		check.atMost(peak, 85, "Drift stays under 85")
		check.atLeast(hunts[1], Config.Run.NoHuntBeforeSeconds, "no hunt in the first minutes")
	end)

	test("a house with nothing locked still has hunts at the moments that matter", function()
		local events = {
			{ t = minutes(5), kind = "found" },
			{ t = minutes(8), kind = "place" },
			{ t = minutes(12), kind = "found" },
			{ t = minutes(15), kind = "place" },
		}
		local hunts = simulate({ gates = 0, heirlooms = 2 }, events, minutes(15))
		check.atLeast(#hunts, 2, "the old house meets him too")
	end)

	test("a squad that stalls is hunted more and more, and the house collapses before 45 minutes", function()
		local hunts, _, collapsed = simulate({ gates = 3, heirlooms = 3 }, {}, minutes(45))
		print(string.format("      stalled: %d hunts, collapse at minute %.1f", #hunts, (collapsed or 0) / 60))
		check.truthy(collapsed ~= nil, "it collapses")
		check.atMost(collapsed or math.huge, minutes(45), "within 45 minutes")
		check.atLeast(#hunts, 3, "hunted on the way down")
	end)

	test("no hunt ever starts in the first three minutes, whatever wakes one", function()
		local events = { { t = 10, kind = "gate" }, { t = 20, kind = "found" } }
		local hunts = simulate({ gates = 3, heirlooms = 3 }, events, minutes(5))
		for _, t in hunts do
			check.atLeast(t, Config.Run.NoHuntBeforeSeconds, "too early")
		end
	end)
end
