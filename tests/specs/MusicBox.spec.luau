-- The music box and the piano (Logic/Puzzles/MusicBox): every tune keeps
-- the rules, and the piano opens the moment the last notes played are the
-- tune. A wrong note costs nothing (the squad playtest, 2026-10-08: the
-- puzzle was unreadable, and every slip started it again).
return function(test, check, Shared, require)
	local Rng = require(Shared.Lib.Rng)
	local MusicBox = require(Shared.Logic.Puzzles.MusicBox)

	local function play(spec, state, keys)
		local events
		for _, k in keys do
			_, events = MusicBox.step(spec, state, { kind = "key", key = k })
		end
		return events
	end

	test("every tune: 4 or 5 notes on the keys, no key three times, and it turns", function()
		for seed = 1, 400 do
			local spec = MusicBox.generate(Rng.new(seed), {})
			check.truthy(spec.length >= 4 and spec.length <= 5, "length")
			check.equal(#spec.notes, spec.length, "as long as it says")
			for _, k in spec.notes do
				check.truthy(k >= 1 and k <= MusicBox.Keys, "on the keys")
			end
			check.truthy(MusicBox.valid(spec.notes), "seed " .. seed .. ": keeps the rules")
		end
	end)

	test("the rules turn away a run of steps and a key three times", function()
		check.truthy(not MusicBox.valid({ 1, 2, 3, 4, 5 }), "only up")
		check.truthy(not MusicBox.valid({ 3, 3, 4, 3, 2 }), "3 three times")
		check.truthy(MusicBox.valid({ 3, 5, 4, 6 }), "up, down, up")
	end)

	test("played right it opens", function()
		local spec = MusicBox.generate(Rng.new(12), {})
		local state = MusicBox.start(spec)
		local events = play(spec, state, spec.notes)
		check.truthy(state.solved, "the whole tune")
		check.equal(events[#events].kind, "solved", "and says so")
	end)

	test("a wrong note costs nothing: the tune counts from wherever it starts", function()
		local spec = { length = 4, notes = { 3, 5, 4, 6 } }
		local state = MusicBox.start(spec)
		local events = play(spec, state, { 3, 5 })
		check.equal(state.played, 2, "two right")
		check.equal(events[1].kind, "note", "every key is a note")
		play(spec, state, { 1 })
		check.equal(state.played, 0, "a slip: nothing matched")
		play(spec, state, { 8, 2, 3, 5, 4 })
		check.equal(state.played, 3, "noodling, then three right")
		check.truthy(not state.solved, "not yet")
		play(spec, state, { 6 })
		check.truthy(state.solved, "the last four were the tune")
	end)

	test("a slip that is itself the tune's start keeps that much", function()
		local spec = { length = 4, notes = { 3, 5, 3, 6 } }
		local state = MusicBox.start(spec)
		play(spec, state, { 3, 5, 3, 5 })
		check.equal(state.played, 2, "3, 5 again: two of the tune")
		play(spec, state, { 3, 6 })
		check.truthy(state.solved, "then the rest")
	end)

	test("listening changes nothing, and solved is solved", function()
		local spec = { length = 4, notes = { 3, 5, 4, 6 } }
		local state = MusicBox.start(spec)
		play(spec, state, { 3, 5 })
		local _, events = MusicBox.step(spec, state, { kind = "listen" })
		check.equal(events[1].kind, "listen", "a listen event")
		check.equal(state.played, 2, "nothing lost")
		check.equal(MusicBox.parse("listen", nil, nil, nil, 0).kind, "listen", "parsed")
		play(spec, state, { 4, 6 })
		local _, after = MusicBox.step(spec, state, { kind = "key", key = 1 })
		check.equal(#after, 0, "a solved piano takes no more")
	end)

	test("keys outside the eight are refused", function()
		local spec = { length = 4, notes = { 3, 5, 4, 6 } }
		local state = MusicBox.start(spec)
		local _, events = MusicBox.step(spec, state, { kind = "key", key = 9 })
		check.equal(events[1].kind, "refused", "nine")
		local _, half = MusicBox.step(spec, state, { kind = "key", key = 2.5 })
		check.equal(half[1].kind, "refused", "a half key")
	end)

	test("each key is higher than the one before", function()
		for k = 2, MusicBox.Keys do
			check.truthy(MusicBox.pitch(k) > MusicBox.pitch(k - 1), "key " .. k)
		end
	end)
end
