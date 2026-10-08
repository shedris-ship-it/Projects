return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Feel = require(Shared.Logic.Feel)
	local Rng = require(Shared.Lib.Rng)

	local P, F = Config.Player, Config.Feel
	local crawl = Config.Run.DownedCrawlSpeed

	local function speedFor(overrides)
		local ctx = { downed = false, hidden = false, hub = false, sprinting = false, exhausted = false }
		for k, v in overrides or {} do
			ctx[k] = v
		end
		return Feel.targetSpeed(ctx, P, crawl)
	end

	test("walking is slow, sprinting stays fast, the hub stays brisk", function()
		check.equal(speedFor(), 8, "a slow horror walk")
		check.equal(speedFor({ sprinting = true }), P.SprintSpeed, "sprint is unchanged")
		check.equal(speedFor({ hub = true }), P.LobbyWalkSpeed, "hub")
		check.truthy(P.WalkSpeed < P.LobbyWalkSpeed, "the run is slower than the hub")
	end)

	test("out of stamina you stagger faster than a walk but far slower than a sprint", function()
		local winded = speedFor({ sprinting = true, exhausted = true })
		check.equal(winded, P.WindedSpeed)
		check.truthy(winded > P.WalkSpeed and winded < P.SprintSpeed, "between walk and sprint")
	end)

	test("crawling and hiding override everything", function()
		check.equal(speedFor({ downed = true, sprinting = true }), crawl, "downed crawl")
		check.equal(speedFor({ hidden = true, sprinting = true }), 0, "hidden")
	end)

	test("the speeds keep the server's noise bands valid", function()
		-- Walk noise needs walking above the creep threshold; sprint noise
		-- needs sprinting above its own, with walking safely below it.
		check.truthy(P.WalkSpeed > P.WalkSpeedThreshold, "walking is heard")
		check.truthy(P.WalkSpeed < P.SprintSpeedThreshold, "walking is not sprint noise")
		check.truthy(P.WindedSpeed < P.SprintSpeedThreshold, "a stagger is not sprint noise")
		check.truthy(P.SprintSpeed > P.SprintSpeedThreshold, "sprinting is sprint noise")
	end)

	-- The squad playtest (2026-10-08): no way to sneak. A crouch creeps under
	-- the noise threshold: no footsteps, no noise he hears.
	test("crouched: a silent creep, and nothing faster is mistaken for one", function()
		check.equal(speedFor({ crouched = true }), P.CrouchSpeed, "a creep")
		check.truthy(P.CrouchSpeed < P.WalkSpeedThreshold, "under the walk noise")
		check.truthy(P.CrouchSpeed < Config.Feel.FootstepMinSpeed, "no footsteps")
		check.truthy(P.CrouchSpeed > 2, "but still getting somewhere")
		check.equal(speedFor({ crouched = true, downed = true }), crawl, "down beats a crouch")
		check.equal(speedFor({ crouched = true, hub = true }), P.LobbyWalkSpeed, "no creeping in the hub")
	end)

	test("steps are slower walking than sprinting, with longer strides when running", function()
		check.truthy(Feel.stride(P.SprintSpeed, P, F) > Feel.stride(P.WalkSpeed, P, F), "longer stride")
		local walk = Feel.stepsPerSecond(P.WalkSpeed, P, F)
		local run = Feel.stepsPerSecond(P.SprintSpeed, P, F)
		check.truthy(walk < run, "sprinting steps come faster")
		check.atMost(walk, 2, "a walk is under two steps a second")
	end)

	test("creeping is silent and sprint steps are louder than walking steps", function()
		check.equal(Feel.stepVolume(2, P, F), 0, "creep")
		check.truthy(Feel.stepVolume(P.SprintSpeed, P, F) > Feel.stepVolume(P.WalkSpeed, P, F), "sprint louder")
	end)

	-- Owner, 2026-10-04: footsteps were "not even audible" at 0.3. A walk has to
	-- stay clearly audible on the quietest floor, and never louder than a sprint.
	test("a walking step stays audible on every floor", function()
		local Footsteps = require(Shared.Data.Footsteps)
		local walk = Feel.stepVolume(P.WalkSpeed, P, F)
		for name, set in Footsteps.Surfaces do
			check.truthy(walk * set.volume >= 0.6, name .. " walking step audible")
		end
	end)

	test("bob is light at a walk and intense at a sprint", function()
		local wv, wl, wr = Feel.bobAmplitude(P.WalkSpeed, true, 1, P, F)
		local sv, sl, sr = Feel.bobAmplitude(P.SprintSpeed, true, 1, P, F)
		check.truthy(sv > wv * 2 and sl > wl and sr > wr, "sprint is much stronger")
		check.near(wv, F.BobWalk[1], 1e-9, "walk vertical")
		check.near(sv, F.BobSprint[1], 1e-9, "sprint vertical")
	end)

	test("no bob at rest, in the air, or with the setting at 0; the setting scales it", function()
		local function total(speed, grounded, intensity)
			local v, l, r = Feel.bobAmplitude(speed, grounded, intensity, P, F)
			return v + l + r
		end
		check.equal(total(0, true, 1), 0, "standing still")
		check.equal(total(P.SprintSpeed, false, 1), 0, "airborne")
		check.equal(total(P.SprintSpeed, true, 0), 0, "camera motion off")
		check.near(total(P.SprintSpeed, true, 0.5), total(P.SprintSpeed, true, 1) / 2, 1e-9, "half strength")
	end)

	test("one bounce a step, one sway every two steps, and it stays within its amplitude", function()
		local y0 = Feel.bobAt(0.25, 1, 1, 1)
		local y1 = Feel.bobAt(1.25, 1, 1, 1)
		check.near(y0, y1, 1e-9, "same bounce every step")
		local _, x0 = Feel.bobAt(0.5, 1, 1, 1)
		local _, x2 = Feel.bobAt(2.5, 1, 1, 1)
		local _, x1 = Feel.bobAt(1.5, 1, 1, 1)
		check.near(x0, x2, 1e-9, "sway repeats every two steps")
		check.truthy(math.abs(x0 + x1) < 1e-9, "and swings the other way on the next step")
		for i = 0, 40 do
			local y, x, r = Feel.bobAt(i * 0.13, 0.2, 0.1, 1)
			check.atMost(math.abs(y), 0.2 + 1e-9, "vertical")
			check.atMost(math.abs(x), 0.1 + 1e-9, "lateral")
			check.atMost(math.abs(r), 1 + 1e-9, "roll")
		end
	end)

	test("landings dip harder from higher falls and not at all from a hop", function()
		check.equal(Feel.landingDip(F.LandMinSpeed - 1, 1, F), 0, "a hop")
		check.truthy(Feel.landingDip(50, 1, F) > Feel.landingDip(30, 1, F), "higher is harder")
		check.near(Feel.landingDip(500, 1, F), F.LandDip, 1e-9, "capped")
		check.equal(Feel.landingDip(50, 0, F), 0, "camera motion off")
	end)

	test("the sprint FOV kick only comes when running and respects the setting", function()
		check.equal(Feel.fovKick(P.WalkSpeed, 1, P, F), 0, "walking")
		check.near(Feel.fovKick(P.SprintSpeed, 1, P, F), F.FovKick, 1e-9, "full sprint")
		check.equal(Feel.fovKick(P.SprintSpeed, 0, P, F), 0, "camera motion off")
		check.truthy(Feel.fovKick(P.WindedSpeed, 1, P, F) < F.FovKick / 2, "a stagger barely widens")
	end)

	test("turning leans the camera the other way, capped", function()
		check.truthy(Feel.turnLean(200, 1, F) < 0, "right turn leans one way")
		check.truthy(Feel.turnLean(-200, 1, F) > 0, "left turn the other")
		check.atMost(math.abs(Feel.turnLean(1e6, 1, F)), F.TurnLeanMax, "capped")
		check.equal(Feel.turnLean(200, 0, F), 0, "camera motion off")
	end)

	test("exhausted breathing is faster but never higher pitched, and the gasp is low", function()
		local fresh = Feel.breathTempo(1, F)
		local spent = Feel.breathTempo(0, F)
		check.near(fresh, F.BreathSpeedMin, 1e-9, "fresh tempo")
		check.near(spent, F.BreathSpeedMax, 1e-9, "spent tempo")
		check.truthy(spent > fresh, "faster when spent")
		-- Playback speed raises pitch by `speed`; the shift cancels it down to BreathPitch.
		for _, stamina in { 1, 0.6, 0.3, 0 } do
			local speed = Feel.breathTempo(stamina, F)
			check.near(speed * Feel.breathOctave(speed, F), F.BreathPitch, 1e-9, "pitch held")
		end
		check.atMost(F.BreathPitch, 1, "the voice isn't pitched up")
		check.atMost(F.BreathGasp.pitch, 0.9, "a low gasp")
		check.truthy(Feel.breathOctave(F.BreathSpeedMax, F) >= 0.5, "within the effect's range")
	end)

	test("the sample bag never repeats back to back and plays everything each round", function()
		local rng = Rng.new(3)
		local bag = Feel.newBag(5)
		local last = nil
		for _ = 1, 20 do
			local seen = {}
			for _ = 1, 5 do
				local pick = Feel.draw(bag, rng)
				check.truthy(pick ~= last, "no immediate repeat")
				check.equal(seen[pick], nil, "once a round")
				seen[pick] = true
				last = pick
			end
		end
		check.equal(Feel.draw(Feel.newBag(1), rng), 1, "a single sample")
	end)

	test("pitch and volume jitter stay within the spread", function()
		local rng = Rng.new(11)
		for _ = 1, 100 do
			local j = Feel.jitter(rng, F.FootstepPitchSpread)
			check.truthy(j >= 1 - F.FootstepPitchSpread - 1e-9 and j <= 1 + F.FootstepPitchSpread + 1e-9, "inside")
		end
	end)
end
