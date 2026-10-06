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

	test(
		"the labels at the door (plate): numbers on the panel, the names on the plate, revealed for a while",
		function()
			for seed = 1, 100 do
				local rng = Rng.new(seed)
				local spec = Breaker.generate(
					rng,
					{ labels = table.clone(LABELS), gate = rng:NextInteger(2, #LABELS), plate = true }
				)
				for i, label in spec.labels do
					check.equal(label, tostring(i), "seed " .. seed .. ": a number on the panel")
				end
				check.equal(#spec.plate, #LABELS, "every breaker on the plate")
				local candidates = Breaker.candidates(spec.plate, spec.gateName)
				check.atMost(#candidates, 3, "at most three to try from the plate")
				check.truthy(table.find(candidates, spec.gate) ~= nil, "the door's among them")
				local text = Breaker.plateText(spec)
				check.truthy(string.find(text, "1  HALL", 1, true) ~= nil, "the plate reads line by line")
				local state = Breaker.start(spec)
				check.equal(Breaker.public(state, 0).labels, nil, "the panel keeps its numbers")
				check.truthy(Breaker.reveal(spec, state, 100, 20), "traced")
				check.equal(Breaker.public(state, 110).labels, spec.plate, "the labels show while traced")
				check.equal(Breaker.public(state, 121).labels, nil, "and fade")
			end
			local plain = Breaker.generate(Rng.new(1), { labels = table.clone(LABELS), gate = 3 })
			check.equal(plain.plate, nil, "no plate unless asked")
			check.equal(Breaker.reveal(plain, Breaker.start(plain), 0, 20), false, "nothing to trace without one")
		end
	)

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
	test(
		"a second door on the panel (the safe room): truly labelled, off at first, open for good once powered",
		function()
			for seed = 1, 100 do
				local rng = Rng.new(seed)
				local gate = rng:NextInteger(2, #LABELS)
				local extraIndex = gate == #LABELS and 2 or #LABELS
				local spec = Breaker.generate(rng, {
					labels = table.clone(LABELS),
					gate = gate,
					extra = { index = extraIndex, name = "SAFE ROOM" },
				})
				check.equal(spec.extra, extraIndex, "seed " .. seed .. ": on the panel")
				check.equal(spec.labels[extraIndex], "SAFE ROOM", "seed " .. seed .. ": labelled as it is")
				for i, label in spec.labels do
					if i ~= extraIndex then
						check.truthy(label ~= "SAFE ROOM", "seed " .. seed .. ": no other breaker says so")
					end
				end
				local state = Breaker.start(spec)
				check.truthy(not state.on[extraIndex], "seed " .. seed .. ": off at the start")
				-- Make room, then power it: open, and the main door's puzzle isn't.
				for i = 2, spec.count do
					if state.on[i] and i ~= spec.gate then
						Breaker.step(spec, state, { kind = "flip", index = i })
						break
					end
				end
				local _, events = Breaker.step(spec, state, { kind = "flip", index = extraIndex })
				check.truthy(state.extraOpen, "seed " .. seed .. ": open")
				check.equal(events[#events].kind, "extra", "seed " .. seed .. ": says so")
				check.truthy(not state.solved, "seed " .. seed .. ": the door's puzzle still to do")
				-- Off again, it stays open.
				Breaker.step(spec, state, { kind = "flip", index = extraIndex })
				check.truthy(state.extraOpen, "seed " .. seed .. ": for good")
			end
		end
	)
end
