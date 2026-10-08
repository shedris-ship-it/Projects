return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local StalkRules = require(Shared.Logic.StalkRules)
	local SightMath = require(Shared.Logic.SightMath)
	local PeekSpots = require(Shared.Logic.PeekSpots)
	local GazeHabits = require(Shared.Logic.GazeHabits)
	local GuestPose = require(Shared.Logic.GuestPose)
	local StalkMoves = require(Shared.Data.StalkMoves)

	local G = Config.Guest

	-- A lunge context where everything allows it; tests switch one thing off.
	local function ready(overrides)
		local ctx = {
			tier = 3,
			runTime = 600,
			watchers = 1,
			distance = 4,
			verticalGap = 0,
			lineOfSight = true,
			hidden = false,
			downed = false,
			safeRoom = false,
			sinceDownNearby = math.huge,
			sincePlayerLunge = math.huge,
			sinceSquadLunge = math.huge,
			warnedFor = 3,
			sinceWarned = 0.5,
		}
		for k, v in overrides or {} do
			ctx[k] = v
		end
		return ctx
	end

	test("visibility: nobody at tier 0, only the target at tier 1, everyone after", function()
		check.equal(StalkRules.visibleTo(0, true), false, "tier 0 target")
		check.equal(StalkRules.visibleTo(1, true), true, "tier 1 target")
		check.equal(StalkRules.visibleTo(1, false), false, "tier 1 others")
		check.equal(StalkRules.visibleTo(2, false), true, "tier 2 everyone")
		check.equal(StalkRules.visibleTo(4, false), true, "hunting everyone")
	end)

	test("two watchers freeze him; one doesn't at tier 3", function()
		check.truthy(StalkRules.frozen(2), "two watchers")
		check.equal(StalkRules.frozen(1), false, "one watcher alone")
		check.truthy(StalkRules.canCreep(3, 1), "tier 3 creeps while one watches")
		check.equal(StalkRules.canCreep(3, 2), false, "but not while two do")
	end)

	test("tier 2 creeps only while unwatched and never attacks", function()
		check.truthy(StalkRules.canCreep(2, 0), "unwatched")
		check.equal(StalkRules.canCreep(2, 1), false, "watched by one")
		check.equal(StalkRules.canLunge(ready({ tier = 2 }), G), false, "no lunge at tier 2")
		check.equal(StalkRules.canCreep(1, 0), false, "tier 1 never approaches")
	end)

	test("creeping is faster behind your back and slowest while stared at", function()
		local side = StalkRules.creepSpeed(3, 90, 0, G)
		local behind = StalkRules.creepSpeed(3, 180, 0, G)
		local watched = StalkRules.creepSpeed(3, 0, 1, G)
		check.truthy(behind > side, "back turned is faster")
		check.truthy(watched <= side, "stared at is slowest")
		check.atMost(behind, 2, "tier 3 is really slow")
		check.truthy(StalkRules.creepSpeed(2, 180, 0, G) > behind, "tier 2 is quicker than tier 3")
	end)

	test("his mood leans his creep, never past the tier's fastest nor the watched pace", function()
		local side = StalkRules.creepSpeed(2, 120, 0, G)
		check.truthy(StalkRules.creepSpeed(2, 120, 0, G, 1.2) > side, "an irritated Guest creeps faster")
		check.truthy(StalkRules.creepSpeed(2, 120, 0, G, 0.8) < side, "a patient one slower")
		check.equal(StalkRules.creepSpeed(2, 180, 0, G, 1.2), G.CreepSpeedTier2[2], "never past the tier's fastest")
		check.equal(StalkRules.creepSpeed(3, 180, 0, G, 1.2), G.CreepSpeedTier3[2], "nor at tier 3")
		check.equal(StalkRules.creepSpeed(3, 0, 1, G, 1.2), G.CreepSpeedWatched, "watched: the watched pace")
	end)

	test("tier 1 flees once spotted; tier 2 backs off when stared at up close", function()
		check.equal(StalkRules.flees(1, 0.1, G), false, "a glance isn't enough")
		check.truthy(StalkRules.flees(1, G.SpottedFleeSeconds, G), "clearly seen")
		check.equal(StalkRules.flees(2, 5, G), false, "tier 2 doesn't flee")
		check.truthy(StalkRules.backsOff(2, G.StareBackAwaySeconds, 8, G), "stared at up close")
		check.equal(StalkRules.backsOff(2, G.StareBackAwaySeconds, 30, G), false, "far away he just holds")
	end)

	test("no lunge without a warning first", function()
		check.truthy(StalkRules.canLunge(ready(), G), "all clear")
		local ok, why = StalkRules.canLunge(ready({ warnedFor = 0.5 }), G)
		check.equal(ok, false, "warned too recently")
		check.equal(why, "no warning yet", "reason")
		check.equal(StalkRules.canLunge(ready({ sinceWarned = 30 }), G), false, "warning long gone")
	end)

	test("no lunge at hidden, downed, safe-room or just-revived players", function()
		check.equal(StalkRules.canLunge(ready({ hidden = true }), G), false, "hidden")
		check.equal(StalkRules.canLunge(ready({ downed = true }), G), false, "downed")
		check.equal(StalkRules.canLunge(ready({ safeRoom = true }), G), false, "safe room")
		check.equal(StalkRules.canLunge(ready({ sinceDownNearby = 5 }), G), false, "someone just went down")
		check.equal(StalkRules.canLunge(ready({ lineOfSight = false }), G), false, "through a wall")
		check.equal(StalkRules.canLunge(ready({ watchers = 2 }), G), false, "two watchers")
	end)

	test("per-player and squad lunge cooldowns", function()
		check.equal(StalkRules.canLunge(ready({ sincePlayerLunge = 30 }), G), false, "same player")
		check.equal(StalkRules.canLunge(ready({ sinceSquadLunge = 10 }), G), false, "anyone recently")
		check.truthy(StalkRules.canLunge(ready({ sincePlayerLunge = 200, sinceSquadLunge = 90 }), G), "later")
	end)

	test("no lunge early in the run; the lunge only lands within reach", function()
		check.equal(StalkRules.canLunge(ready({ runTime = 100 }), G), false, "early run")
		check.equal(StalkRules.canLunge(ready({ distance = G.LungeRadius + 1 }), G), false, "too far")
		check.truthy(StalkRules.lungeHits(G.LungeReach - 0.5, 0, G), "still close")
		check.equal(StalkRules.lungeHits(G.LungeReach + 1, 0, G), false, "a sprinter at the edge escapes")
	end)

	-- A close-contact context where everything allows it; tests switch one thing off.
	local function touching(overrides)
		local ctx = {
			tier = 2,
			visibleToVictim = true,
			distance = 3,
			verticalGap = 0,
			lineOfSight = true,
			watchers = 1,
			hidden = false,
			downed = false,
			safeRoom = false,
			sinceDownNearby = math.huge,
			sinceContact = math.huge,
			approaching = true,
			-- A run at him: the live caller always fills this in (Stalk:_contactVictim).
			approachSpeed = 15,
			graced = false,
		}
		for k, v in overrides or {} do
			ctx[k] = v
		end
		return ctx
	end

	test("close contact: only for whoever walks into him, never for his own approach", function()
		local ok, why = StalkRules.contact(touching({ approaching = false }), G)
		check.equal(ok, false, "he crept up to someone standing still")
		check.equal(why, "not coming at him", "reason")
		check.truthy(StalkRules.contact(touching({ approaching = true }), G), "they came at him")
		check.truthy(G.CloseBehind > G.ContactRadius, "tier 2 stops outside the contact radius")
	end)

	test("close contact: running at him is a contact; walking his way he makes way instead", function()
		check.truthy(StalkRules.contact(touching({ approachSpeed = 19 }), G), "a sprint at him")
		local ok, why = StalkRules.contact(touching({ approachSpeed = 8 }), G)
		check.equal(ok, false, "a walk is not rushing him")
		check.equal(why, "only walking", "reason")
		check.equal(
			StalkRules.contact(touching({ approachSpeed = 19, makingWay = true }), G),
			false,
			"never while he makes way"
		)
		check.equal(StalkRules.canLunge(ready({ makingWay = true }), G), false, "nor the lunge")
	end)

	-- A making-way context: a player walking his way, close, between hunts.
	local function passing(overrides)
		local ctx = {
			hunting = false,
			seated = false,
			tier = 2,
			visibleToThem = true,
			active = true,
			distance = 7,
			verticalGap = 0,
			nearFor = 0,
			approachSpeed = 8,
		}
		for k, v in overrides or {} do
			ctx[k] = v
		end
		return ctx
	end

	test("after you: he steps aside for a player walking his way, or one he has stood beside too long", function()
		check.truthy(StalkRules.makesWay(passing(), G), "walking his way")
		check.truthy(
			StalkRules.makesWay(passing({ approachSpeed = 0, distance = 5, nearFor = G.ParkSeconds }), G),
			"standing beside them too long"
		)
		check.equal(StalkRules.makesWay(passing({ approachSpeed = 0, nearFor = 1 }), G), false, "not yet")
		check.equal(StalkRules.makesWay(passing({ approachSpeed = 19 }), G), false, "running at him is a contact")
		check.equal(StalkRules.makesWay(passing({ distance = G.MakeWayRange + 2 }), G), false, "still far off")
		check.equal(StalkRules.makesWay(passing({ hunting = true }), G), false, "never in a hunt")
		check.equal(StalkRules.makesWay(passing({ seated = true }), G), false, "not from his place at the table")
		check.equal(
			StalkRules.makesWay(passing({ visibleToThem = false }), G),
			false,
			"not for someone who can't see him"
		)
		check.equal(StalkRules.makesWay(passing({ verticalGap = 8 }), G), false, "not for the floor above")
		check.truthy(G.MakeWayMaxSpeed >= Config.Player.WindedSpeed, "a winded stagger is still walking")
		check.truthy(G.MakeWayMaxSpeed < Config.Player.SprintSpeed, "a sprint is not")
	end)

	test("the presence budget: twelve seconds beside one player in a minute, then he moves off", function()
		local state = {}
		local spent = false
		local t = 0
		while not spent and t < 60 do
			spent = StalkRules.parkBudget(state, true, 0.25, G)
			t += 0.25
		end
		check.truthy(spent, "spent standing beside them")
		check.atLeast(t, G.ParkBudget, "not before the budget")
		check.atMost(t, G.ParkBudget * 1.6, "not much after it either")
		-- Away from them it drains; spent until it's down by half.
		local away = 0
		while StalkRules.parkBudget(state, false, 0.5, G) do
			away += 0.5
		end
		check.atLeast(away, (G.ParkBudget / 2) / (G.ParkBudget / G.ParkWindow) - 1, "it drains by half first")
		check.equal(StalkRules.parkBudget(state, false, 0.5, G), false, "free again")
	end)

	test("a player just pulled up can't be caught again for a moment (revive grace)", function()
		local ok, why = StalkRules.contact(touching({ graced = true }), G)
		check.equal(ok, false, "no contact lunge in the grace")
		check.equal(why, "just back up", "reason")
		check.equal(StalkRules.canLunge(ready({ graced = true }), G), false, "no lunge in the grace")
	end)

	test("a Guest stunned by a throw can't lunge or lunge on contact", function()
		local ok, why = StalkRules.canLunge(ready({ stunned = true }), G)
		check.equal(ok, false, "no lunge while stunned")
		check.equal(why, "stunned", "and says why")
		local touched, reason = StalkRules.contact(touching({ stunned = true }), G)
		check.equal(touched, false, "no contact lunge while stunned")
		check.equal(reason, "stunned", "and says why")
		check.truthy(StalkRules.canLunge(ready({ stunned = false }), G), "fine once it wears off")
	end)

	test("walking at him is not a contact: he makes way for a walk, and lunges at a run", function()
		local ok, why = StalkRules.contact(touching({ approachSpeed = 8 }), G)
		check.equal(ok, false, "a walk at 8")
		check.equal(why, "only walking", "reason")
		check.truthy(StalkRules.contact(touching({ approachSpeed = 15 }), G), "a run at 15")
	end)

	test("run at a Guest you can see and he lunges, from tier 1, with no warning or wait", function()
		for tier = 1, 3 do
			check.truthy(StalkRules.contact(touching({ tier = tier }), G), "tier " .. tier)
		end
		-- The normal lunge still refuses the same situation at tier 2.
		check.equal(
			StalkRules.canLunge(ready({ tier = 2, distance = 3 }), G),
			false,
			"tier 2 still never lunges unprovoked"
		)
	end)

	test("close contact: not at tier 0, not if he's unseen by them, not out of reach", function()
		check.equal(StalkRules.contact(touching({ tier = 0 }), G), false, "tier 0")
		check.equal(StalkRules.contact(touching({ visibleToVictim = false }), G), false, "he is invisible to them")
		check.equal(StalkRules.contact(touching({ distance = G.ContactRadius + 1 }), G), false, "too far")
		check.equal(StalkRules.contact(touching({ verticalGap = 6 }), G), false, "another floor")
		check.equal(StalkRules.contact(touching({ lineOfSight = false }), G), false, "through a wall")
	end)

	test("close contact: two watchers freeze him, and the protected stay protected", function()
		check.equal(StalkRules.contact(touching({ watchers = 2 }), G), false, "a buddy staring too")
		check.equal(StalkRules.contact(touching({ hidden = true }), G), false, "hidden")
		check.equal(StalkRules.contact(touching({ downed = true }), G), false, "downed")
		check.equal(StalkRules.contact(touching({ safeRoom = true }), G), false, "safe room")
	end)

	test("close contact: no revive camping, and a short cooldown after a miss", function()
		check.equal(StalkRules.contact(touching({ sinceDownNearby = 5 }), G), false, "someone just went down")
		local ok, why = StalkRules.contact(touching({ sinceContact = 2 }), G)
		check.equal(ok, false, "too soon")
		check.equal(why, "cooldown", "reason")
		check.truthy(StalkRules.contact(touching({ sinceContact = G.ContactCooldownPerPlayer + 1 }), G), "later")
	end)

	test(
		"the stare counts only in the light: the room, the beam, the clip light, a lantern, or arm's length",
		function()
			local cfg = Config.Stare
			local function lit(overrides)
				local ctx = {
					distance = 20,
					roomLit = false,
					beamOn = false,
					beamAngle = 90,
					clipOn = false,
					clipAngle = 90,
					lanternOn = false,
				}
				for k, v in overrides or {} do
					ctx[k] = v
				end
				return StalkRules.litFor(ctx, cfg)
			end
			check.equal(lit(), false, "a dark room, no light on him")
			check.truthy(lit({ roomLit = true }), "a lit room")
			check.truthy(lit({ beamOn = true, beamAngle = 10 }), "in the beam")
			check.equal(lit({ beamOn = true, beamAngle = 60 }), false, "the beam points elsewhere")
			check.equal(lit({ beamOn = true, beamAngle = 10, distance = cfg.BeamRange + 5 }), false, "beyond the beam")
			check.truthy(lit({ clipOn = true, clipAngle = 20, distance = 10 }), "the clip light, close")
			check.equal(lit({ clipOn = true, clipAngle = 20, distance = 30 }), false, "the clip light is short")
			check.truthy(lit({ lanternOn = true, distance = 12 }), "a lit lantern in hand")
			check.truthy(lit({ distance = 3 }), "arm's length in the dark")
			check.truthy(
				StalkRules.litFor({ distance = 60 }, { LitOnly = false }),
				"the old rule when the light is off"
			)
		end
	)

	-- The squad playtest (2026-10-08): a wider, shorter torch. What lights him
	-- for the stare is the beam players see, never a second set of numbers.
	test("the stare's beam is the torch's beam", function()
		local T, S = Config.Torch, Config.Stare
		check.equal(S.BeamRange, T.Range, "reach")
		check.equal(S.BeamHalfAngle, T.Angle / 2, "cone")
		check.equal(S.ClipRange, T.Clip.Range, "clip reach")
		check.equal(S.ClipHalfAngle, T.Clip.Angle / 2, "clip cone")
		check.equal(Config.Hands.ClipLight, T.Clip, "the clip light itself")
		check.atMost(G.EyeShineRange, T.Range, "his eyes shine only in your beam's reach")
		check.atMost(G.EyeShineCone, T.Angle / 2, "and inside its cone")
	end)

	test("in a hunt two watchers hold him a few seconds at a time, then he comes on until they lose him", function()
		local cfg = Config.Stare
		local state = { held = 0, spent = false, unwatched = 0, holds = 0 }
		local heldFor = 0
		for _ = 1, 100 do
			if StalkRules.huntHold(state, true, 0.1, cfg) then
				heldFor += 0.1
			end
		end
		check.near(heldFor, cfg.HuntHoldSeconds, 0.15, "held for the hold time only")
		check.truthy(state.spent, "then the hold is spent")
		check.equal(StalkRules.huntHold(state, true, 0.1, cfg), false, "staring on does nothing more")
		-- A short break doesn't reset it; losing him for HoldResetSeconds does.
		StalkRules.huntHold(state, false, cfg.HoldResetSeconds / 2, cfg)
		check.truthy(state.spent, "a glance away isn't enough")
		StalkRules.huntHold(state, false, cfg.HoldResetSeconds, cfg)
		check.equal(state.spent, false, "lost for long enough: they can hold him again")
		check.truthy(StalkRules.huntHold(state, true, 0.1, cfg), "and do")
	end)

	test("holds shrink within one hunt, so two torches can't blink him all the way to the door", function()
		local cfg = Config.Stare
		local state = { held = 0, spent = false, unwatched = 0, holds = 0 }
		local function hold()
			local heldFor = 0
			for _ = 1, 200 do
				if StalkRules.huntHold(state, true, 0.05, cfg) then
					heldFor += 0.05
				end
			end
			return heldFor
		end
		local function blink()
			StalkRules.huntHold(state, false, cfg.HoldResetSeconds + 0.1, cfg)
		end
		local first = hold()
		blink()
		local second = hold()
		blink()
		local third = hold()
		blink()
		local fourth = hold()
		check.near(first, cfg.HuntHoldSeconds, 0.1, "the first hold is full")
		check.near(second, cfg.HuntHoldSeconds * cfg.HoldDecay, 0.1, "the second is half")
		check.near(third, cfg.HuntHoldSeconds * cfg.HoldDecay ^ 2, 0.1, "the third a quarter")
		check.near(fourth, math.max(cfg.HoldMin, cfg.HuntHoldSeconds * cfg.HoldDecay ^ 3), 0.1, "then the floor")
		-- A hold let go early still counts for its share.
		local fresh = { held = 0, spent = false, unwatched = 0, holds = 0 }
		for _ = 1, 20 do
			StalkRules.huntHold(fresh, true, 0.1, cfg) -- 2 s of a 4 s hold
		end
		StalkRules.huntHold(fresh, false, cfg.HoldResetSeconds + 0.1, cfg)
		check.near(fresh.holds, 0.5, 0.05, "half a hold used")
		check.near(
			StalkRules.holdCap(fresh, cfg),
			cfg.HuntHoldSeconds * cfg.HoldDecay ^ 0.5,
			0.05,
			"the next is shorter"
		)
	end)

	test("doorway stand only while he can't attack", function()
		check.truthy(StalkRules.mayBlockDoorway(2), "tier 2")
		check.equal(StalkRules.mayBlockDoorway(3), false, "tier 3")
	end)

	test("sight: back turned beyond 110 degrees, sides, cones", function()
		-- Looking along -Z.
		check.near(SightMath.angle(0, -1, 0, -5), 0, 1e-6, "ahead")
		check.near(SightMath.angle(0, -1, 0, 5), 180, 1e-6, "behind")
		check.truthy(SightMath.backTurned(0, -1, 0, 5, 110), "behind counts")
		check.equal(SightMath.backTurned(0, -1, 5, 0, 110), false, "the side is peripheral, not behind")
		check.equal(SightMath.side(0, -1, -3, 0), 1, "left")
		check.equal(SightMath.side(0, -1, 3, 0), -1, "right")
		check.truthy(SightMath.inCone(0, -1, 1, -3, 110), "inside the view cone")
		check.equal(SightMath.inCone(0, -1, 5, 0.5, 110), false, "outside it")
	end)

	test("stealth: a seen step loses to a hidden one, a blocked step never wins", function()
		local hidden = SightMath.stealthScore(1.0, 0, false)
		local seen = SightMath.stealthScore(2.5, 1, false)
		check.truthy(hidden > seen, "stays out of sight even if it's slower")
		check.truthy(SightMath.stealthScore(0.2, 0, false) > SightMath.stealthScore(5, 0, true), "walls")
		check.truthy(SightMath.stealthScore(2, 0, false) > SightMath.stealthScore(1, 0, false), "progress")
	end)

	test("peek spots: beside the jamb, behind the wall, outside the lane, leaning in", function()
		local cfg = {
			PeekLateral = G.PeekLateral,
			PeekWallClearance = G.PeekWallClearance,
			PeekHideLateral = G.PeekHideLateral,
			WallThickness = Config.Level.WallThickness,
		}
		-- A doorway at the origin in a wall facing +Z (room a at -Z, b at +Z).
		local spots = PeekSpots.forDoorway(0, 0, 0, 1, cfg)
		check.equal(#spots, 4, "two per side")
		for _, spot in spots do
			check.truthy(math.abs(spot.x) > Config.Level.LaneHalfWidth, "outside the doorway lane")
			check.truthy(math.abs(spot.x) > Config.Level.DoorWidth / 2, "behind the jamb")
			check.truthy(spot.z * spot.side > Config.Level.WallThickness, "behind the wall, on its side")
			check.near(spot.faceZ, -spot.side, 1e-9, "faces through the wall")
			-- Leaning: his right is (-faceZ, faceX); the doorway is at x = 0.
			local rightX = -spot.faceZ
			local towardDoor = -spot.x
			check.truthy(rightX * towardDoor * spot.lean > 0, "leans towards the opening")
			check.truthy(math.abs(spot.hideX) > math.abs(spot.x), "the hide point is further along the wall")
			check.near(spot.hideZ, spot.z, 1e-9, "and just as far behind it")
		end
	end)

	test("peeking puts his head in the doorway; hiding doesn't", function()
		local head = GuestPose.exposed("Peek", 1)
		local still = GuestPose.exposed("Idle", 0)
		check.truthy(head[1] > 2, "leaning right moves his head over 2 studs right")
		check.near(still[1], 0, 0.3, "standing, his head is over his feet")
		check.truthy(still[2] > 3 and still[2] < 3.6, "head height above the root")
		local left = GuestPose.exposed("Peek", -1)
		check.truthy(left[1] < -2, "and the other way")
	end)

	test("gaze habits: rear checks, their rhythm and the shoulder", function()
		local h = GazeHabits.new()
		local t = 0
		-- Walking along -Z, looking back over the left shoulder every 10 s.
		for _ = 1, 6 do
			for _ = 1, 100 do
				t += 0.1
				GazeHabits.sample(h, t, 0, 0, 0.1)
			end
			GazeHabits.sample(h, t, math.rad(150), 0, 0.1)
			t += 0.1
			GazeHabits.sample(h, t, 0, 0, 0.1)
		end
		check.equal(h.checks, 6, "every look back counted once")
		check.near(h.interval, 10.1, 2, "the rhythm converges")
		check.truthy(GazeHabits.sideBias(h) > 0.5, "always over the left shoulder")
		check.truthy(GazeHabits.creepWindow(h, h.lastCheck + 0.5) > 0.8, "safe to move just after a check")
		check.truthy(GazeHabits.creepWindow(h, h.lastCheck + 9.5) < 0.2, "not when one is due")
	end)

	test("gaze habits: rarely looking back means a blind back; staring vs running", function()
		local careful, careless = GazeHabits.new(), GazeHabits.new()
		careful.checks, careful.interval = 5, 6
		careless.checks, careless.interval = 5, 40
		check.truthy(GazeHabits.blindBack(careless) > GazeHabits.blindBack(careful) + 0.5, "blind back")
		GazeHabits.recordSighting(careful, true)
		GazeHabits.recordSighting(careful, true)
		GazeHabits.recordSighting(careless, false)
		check.truthy(GazeHabits.stareHabit(careful) > GazeHabits.stareHabit(careless), "stares")
	end)

	test("every stalk move has tiers, a description and a counter", function()
		check.atLeast(#StalkMoves.List, 6, "at least six moves")
		for _, move in StalkMoves.List do
			check.truthy(move.description ~= "", move.id .. " description")
			check.truthy(move.counter ~= "", move.id .. " counter")
			if move.errand then
				-- Errands (R2c) are never picked by habit: no tiers, no weight.
				check.equal(#move.tiers, 0, move.id .. " is never chosen by habit")
			else
				check.truthy(#move.tiers > 0, move.id .. " tiers")
				check.truthy(move.base > 0 and move.cooldown >= 0, move.id .. " numbers")
			end
		end
	end)
end
