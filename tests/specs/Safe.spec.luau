-- The wall safe (Logic/Puzzles/Safe): a click on the right number, three
-- set in turn opens it, a wrong set starts again, and spinning it fast
-- rattles.
return function(test, check, Shared, require)
	local Rng = require(Shared.Lib.Rng)
	local Safe = require(Shared.Logic.Puzzles.Safe)

	local function turnTo(spec, state, target, now)
		local events = {}
		local guard = 0
		while state.dial ~= target and guard < spec.size do
			guard += 1
			now += 0.2 -- slowly: never a rattle
			local _, e = Safe.step(spec, state, { kind = "turn", delta = 1, now = now })
			for _, event in e do
				table.insert(events, event)
			end
		end
		return events, now
	end

	test("the combination is three numbers, far enough apart to tell", function()
		for seed = 1, 200 do
			local spec = Safe.generate(Rng.new(seed), {})
			check.equal(#spec.combo, 3, "three")
			local last = 0
			for _, n in spec.combo do
				check.truthy(n >= 1 and n < spec.size, "on the dial")
				check.truthy(math.abs(n - last) >= 5, "seed " .. seed .. ": apart")
				last = n
			end
		end
	end)

	test("a click sounds on the next number and nowhere else", function()
		local spec = Safe.generate(Rng.new(4), {})
		local state = Safe.start(spec)
		local clicks, now = 0, 0
		for _ = 1, spec.size do
			now += 0.2
			local _, events = Safe.step(spec, state, { kind = "turn", delta = 1, now = now })
			for _, event in events do
				if event.kind == "click" then
					clicks += 1
					check.equal(state.dial, spec.combo[1], "on the first number")
				end
			end
		end
		check.equal(clicks, 1, "once round the dial, one click")
	end)

	test("set on each number in turn and it opens; a wrong set starts again", function()
		local spec = Safe.generate(Rng.new(9), {})
		local state = Safe.start(spec)
		local now = 0
		_, now = turnTo(spec, state, spec.combo[1], now)
		Safe.step(spec, state, { kind = "set" })
		check.equal(state.stage, 2, "the first number set")
		-- A wrong set: back to the start.
		Safe.step(spec, state, { kind = "turn", delta = 1, now = now + 0.2 })
		local _, events = Safe.step(spec, state, { kind = "set" })
		check.equal(events[1].kind, "wrong", "wrong")
		check.equal(state.stage, 1, "from the start again")
		for stage = 1, 3 do
			_, now = turnTo(spec, state, spec.combo[stage], now)
			Safe.step(spec, state, { kind = "set" })
		end
		check.truthy(state.solved, "open")
	end)

	test("spinning it fast rattles; slowly never does", function()
		local spec = Safe.generate(Rng.new(2), {})
		local state = Safe.start(spec)
		local rattles = 0
		for i = 1, 30 do
			local _, events = Safe.step(spec, state, { kind = "turn", delta = 1, now = i * 0.05 })
			for _, event in events do
				if event.kind == "rattle" then
					rattles += 1
				end
			end
		end
		check.truthy(rattles >= 1, "fast: rattles")
		local slow = Safe.start(spec)
		local events = turnTo(spec, slow, (spec.combo[1] + 20) % spec.size, 0)
		for _, event in events do
			check.truthy(event.kind ~= "rattle", "slow: never")
		end
	end)
end
