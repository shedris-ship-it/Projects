-- The Guest's moods and temperaments (Logic/GuestMood, Data/Temperaments):
-- seeded, legible (every mood has a tell and a counter), shifted by what the
-- squad does, and never outside his fairness limits.
return function(test, check, Shared, require)
	local GuestMood = require(Shared.Logic.GuestMood)
	local Temperaments = require(Shared.Data.Temperaments)
	local StalkMoves = require(Shared.Data.StalkMoves)
	local Tactics = require(Shared.Data.Tactics)
	local Rng = require(Shared.Lib.Rng)
	local cfg = { MoodSeconds = { 60, 180 } }

	local function run(seed: number, temperament)
		local rng = Rng.new(seed)
		local state = GuestMood.new(temperament)
		local moods = {}
		for t = 0, 1800, 5 do
			local id = GuestMood.update(state, t, rng, cfg)
			if id then
				table.insert(moods, id)
			end
		end
		return moods
	end

	test("the same seed meets the same moods; a new mood is never the one he was in", function()
		local a = run(7, Temperaments.ById.Patient)
		local b = run(7, Temperaments.ById.Patient)
		check.equal(table.concat(a, ","), table.concat(b, ","), "same seed, same moods")
		check.atLeast(#a, 10, "half an hour holds ten or more moods")
		for i = 2, #a do
			check.truthy(a[i] ~= a[i - 1], "no mood twice in a row")
		end
		local c = run(8, Temperaments.ById.Patient)
		check.truthy(table.concat(a, ",") ~= table.concat(c, ","), "another seed, other moods")
	end)

	test("a temperament leans the night: a patient Guest is patient more often than a hungry one", function()
		local function share(temperament, mood)
			local count, total = 0, 0
			for seed = 1, 30 do
				for _, id in run(seed, temperament) do
					total += 1
					if id == mood then
						count += 1
					end
				end
			end
			return count / total
		end
		check.truthy(
			share(Temperaments.ById.Patient, "Patient") > share(Temperaments.ById.Hungry, "Patient"),
			"patient more often when patient"
		)
		check.truthy(
			share(Temperaments.ById.Hungry, "Stalking") > share(Temperaments.ById.Playful, "Stalking"),
			"stalking more often when hungry"
		)
	end)

	test("every mood is legible and names real moves and tactics; every weight is positive", function()
		for _, id in GuestMood.Order do
			local mood = GuestMood.Moods[id]
			check.truthy(mood, id .. " is defined")
			check.truthy(type(mood.tell) == "string" and #mood.tell > 0, id .. " has a tell")
			check.truthy(type(mood.counter) == "string" and #mood.counter > 0, id .. " has a counter")
			for move, w in mood.stalk do
				check.truthy(StalkMoves.ById[move], id .. ": no move " .. move)
				check.truthy(w > 0, id .. ": weight for " .. move)
			end
			for tactic, w in mood.tactics do
				check.truthy(Tactics.ById[tactic], id .. ": no tactic " .. tactic)
				check.truthy(w > 0, id .. ": weight for " .. tactic)
			end
			for _, key in { "seen", "hunt" } do
				local total = 0
				for _, w in mood[key] do
					check.truthy(w > 0, id .. ": " .. key .. " weight")
					total += w
				end
				check.truthy(total > 0, id .. " has " .. key .. " options")
			end
		end
		for _, t in Temperaments.List do
			check.truthy(type(t.line) == "string" and #t.line > 0, t.id .. " has a Dossier line")
			for mood, w in t.moodOdds do
				check.truthy(GuestMood.Moods[mood], t.id .. ": no mood " .. mood)
				check.truthy(w > 0, t.id .. ": odds for " .. mood)
			end
			for move in t.stalk do
				check.truthy(StalkMoves.ById[move], t.id .. ": no move " .. move)
			end
			for tactic in t.tactics do
				check.truthy(Tactics.ById[tactic], t.id .. ": no tactic " .. tactic)
			end
		end
	end)

	test(
		"what happens shifts him: a stun irritates, a taken heirloom sets him stalking, a catch makes him the host",
		function()
			local rng = Rng.new(3)
			local state = GuestMood.new(Temperaments.ById.Playful)
			GuestMood.update(state, 0, rng, cfg)
			state.mood = "Curious"
			check.equal(GuestMood.event(state, "stunned", 10, rng, cfg), "Irritated", "a stun irritates him")
			local untilT = state.untilT
			check.equal(GuestMood.event(state, "stunned", 50, rng, cfg), nil, "already irritated: no change")
			check.atLeast(state.untilT, math.max(untilT, 50 + 60), "...but it lasts longer")
			check.equal(GuestMood.event(state, "heirloomTaken", 60, rng, cfg), "Stalking", "after the carrier")
			check.equal(GuestMood.event(state, "huntCaught", 70, rng, cfg), "Host", "a catch: the host again")
			check.equal(GuestMood.event(state, "nonsense", 80, rng, cfg), nil, "an unknown event changes nothing")
			local lonely = GuestMood.event(state, "lonely", 90, rng, cfg)
			check.truthy(lonely == "Curious" or lonely == "Playful", "lonely: curious or playful")
		end
	)

	test("weights fold the archetype, the temperament and the mood together", function()
		local state = GuestMood.new(Temperaments.ById.Patient)
		state.mood = "Patient"
		local w = GuestMood.weights(state, { DoorwayStand = 1.3, Peek = 1.4 }, "stalk")
		local expected = 1.3 * Temperaments.ById.Patient.stalk.DoorwayStand * GuestMood.Moods.Patient.stalk.DoorwayStand
		check.near(w.DoorwayStand, expected, 1e-9, "three weights multiplied")
		check.near(w.Peek, 1.4, 1e-9, "only the archetype weighs Peek")
		local t = GuestMood.weights(state, nil, "tactics")
		check.near(
			t.Ambush,
			Temperaments.ById.Patient.tactics.Ambush * GuestMood.Moods.Patient.tactics.Ambush,
			1e-9,
			"tactics"
		)
	end)

	test("his creep stays within 0.8-1.2 of itself, whatever the night and the mood", function()
		for _, t in Temperaments.List do
			for _, id in GuestMood.Order do
				local state = GuestMood.new(t)
				state.mood = id
				local scale = GuestMood.creepScale(state)
				check.truthy(scale >= 0.8 and scale <= 1.2, t.id .. "/" .. id .. " creep " .. scale)
			end
		end
	end)

	test("each night draws a temperament from the seed, and all four come up", function()
		local seen = {}
		for seed = 1, 60 do
			seen[GuestMood.temperament(Temperaments.List, Rng.new(seed)).id] = true
		end
		for _, t in Temperaments.List do
			check.truthy(seen[t.id], t.id .. " drawn on some night")
		end
		local rng = Rng.new(5)
		local state = GuestMood.new(Temperaments.ById.Restless)
		state.mood = "Curious"
		local picks = {}
		for _ = 1, 50 do
			picks[GuestMood.choose(state, "seen", rng)] = true
		end
		check.truthy(picks.Yank and picks.Withdraw and picks.Duck, "all three tier-1 reactions come up")
	end)
end
