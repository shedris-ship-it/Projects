-- The breaker panel (Logic/Puzzles/Breaker): the panel starts full, so the
-- door's breaker needs another off first; too many on trips the main; the
-- labels leave at most three breakers it could be, the right one among them.
return function(test, check, Shared, require)
	local Rng = require(Shared.Lib.Rng)
	local Breaker = require(Shared.Logic.Puzzles.Breaker)

	local LABELS = { "HALL", "STUDY", "KITCHEN", "NURSERY", "DEN", "GARAGE", "PANTRY" }

	local function generate(seed)
		local rng = Rng.new(seed)
		return Breaker.generate(rng, { labels = table.clone(LABELS), gate = rng:NextInteger(2, #LABELS) })
	end

	test("the panel starts full, the hall on, the door's breaker off", function()
		for seed = 1, 200 do
			local spec = generate(seed)
			local state = Breaker.start(spec)
			local on = 0
			for _, value in state.on do
				if value then
					on += 1
				end
			end
			check.equal(on, spec.capacity, "seed " .. seed .. ": full")
			check.truthy(state.on[1], "the hall")
			check.truthy(not state.on[spec.gate], "the door's off")
		end
	end)

	test("the door's breaker is always among at most three it could be", function()
		for seed = 1, 500 do
			local spec = generate(seed)
			local list = Breaker.candidates(spec.labels, spec.gateName)
			check.truthy(#list >= 1 and #list <= 3, "seed " .. seed .. ": " .. #list .. " candidates")
			check.truthy(table.find(list, spec.gate) ~= nil, "seed " .. seed .. ": the right one is among them")
		end
	end)

	test("one more on trips the main; the main won't stay up until something's off", function()
		local spec = generate(7)
		local state = Breaker.start(spec)
		local _, events = Breaker.step(spec, state, { kind = "flip", index = spec.gate })
		check.truthy(state.tripped, "tripped")
		check.truthy(not state.solved, "a tripped panel powers nothing")
		check.equal(events[#events].kind, "trip", "a clunk")
		Breaker.step(spec, state, { kind = "main" })
		check.truthy(state.tripped, "too much still on: straight back off")
		-- Turn something else off, then the main holds and the door has power.
		for i = 2, spec.count do
			if state.on[i] and i ~= spec.gate then
				Breaker.step(spec, state, { kind = "flip", index = i })
				break
			end
		end
		local _, after = Breaker.step(spec, state, { kind = "main" })
		check.truthy(not state.tripped, "the main holds")
		check.truthy(state.solved, "the door has power")
		check.equal(after[#after].kind, "solved", "and says so")
	end)

	test("the honest way: one off, the door's on, never tripping", function()
		for seed = 1, 100 do
			local spec = generate(seed)
			local state = Breaker.start(spec)
			for i = 2, spec.count do
				if state.on[i] and i ~= spec.gate then
					Breaker.step(spec, state, { kind = "flip", index = i })
					break
				end
			end
			Breaker.step(spec, state, { kind = "flip", index = spec.gate })
			check.truthy(state.solved and not state.tripped, "seed " .. seed)
		end
	end)

	test("powered means on and the main up", function()
		local spec = generate(3)
		local state = Breaker.start(spec)
		check.truthy(Breaker.powered(state, 1), "the hall")
		state.tripped = true
		check.truthy(not Breaker.powered(state, 1), "nothing, tripped")
	end)
end
