-- The music box and the piano (Logic/Puzzles/MusicBox): every tune keeps
-- the rules, the right notes in order solve it, any wrong note starts it
-- again.
return function(test, check, Shared, require)
	local Rng = require(Shared.Lib.Rng)
	local MusicBox = require(Shared.Logic.Puzzles.MusicBox)

	test("every tune: 4 to 7 notes on the keys, no key three times, and it turns", function()
		for seed = 1, 400 do
			local spec = MusicBox.generate(Rng.new(seed), {})
			check.truthy(spec.length >= 4 and spec.length <= 7, "length")
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

	test("played right it opens; one wrong note starts it again", function()
		local spec = MusicBox.generate(Rng.new(12), {})
		local state = MusicBox.start(spec)
		MusicBox.step(spec, state, { kind = "key", key = spec.notes[1] })
		check.equal(state.played, 1, "one right")
		local wrong = spec.notes[2] % MusicBox.Keys + 1
		local _, events = MusicBox.step(spec, state, { kind = "key", key = wrong })
		check.equal(events[1].kind, "discord", "a discord")
		check.equal(state.played, 0, "from the start")
		for _, k in spec.notes do
			MusicBox.step(spec, state, { kind = "key", key = k })
		end
		check.truthy(state.solved, "the whole tune")
	end)

	test("each key is higher than the one before", function()
		for k = 2, MusicBox.Keys do
			check.truthy(MusicBox.pitch(k) > MusicBox.pitch(k - 1), "key " .. k)
		end
	end)
end
