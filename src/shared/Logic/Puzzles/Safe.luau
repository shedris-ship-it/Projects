-- The wall safe, cracked by ear (docs/plans/gameplay-rework.md section 7;
-- R2c): a dial of `size` numbers and a combination of three. Turn it one
-- notch at a time; when it sits on the next number of the combination, the
-- operator (and only the operator) hears a click. Set it there and go on;
-- set it anywhere else and it starts again. Spin it fast and the dial
-- rattles, loud enough for him to hear. Holds an heirloom.
--
-- Pure (tests/specs/Safe.spec); the combination stays on the server.

local Safe = {}

Safe.Size = 40
Safe.Stages = 3
Safe.FastTurns = 8 -- more notches than this within FastWindow rattles
Safe.FastWindow = 1

function Safe.generate(rng, _ctx)
	local combo = {}
	local last = 0
	for i = 1, Safe.Stages do
		local n
		repeat
			n = rng:NextInteger(1, Safe.Size - 1)
		until math.abs(n - last) >= 5 and math.abs(n - last) <= Safe.Size - 5
		combo[i] = n
		last = n
	end
	return { size = Safe.Size, combo = combo }
end

function Safe.view(spec)
	return { size = spec.size, stages = #spec.combo }
end

function Safe.start(_spec)
	return { dial = 0, stage = 1, solved = false, recent = {} }
end

-- input: { kind = "turn", delta = -1 | 1, now } or { kind = "set" }.
-- Events: "turned", "click" (on the number: for the operator alone),
-- "rattle" (spun too fast), "set", "wrong", "solved", "refused".
function Safe.step(spec, state, input)
	if state.solved then
		return state, {}
	end
	local events = {}
	if input.kind == "turn" then
		local delta = input.delta
		if delta ~= 1 and delta ~= -1 then
			return state, { { kind = "refused" } }
		end
		state.dial = (state.dial + delta) % spec.size
		table.insert(events, { kind = "turned", dial = state.dial })
		if state.dial == spec.combo[state.stage] then
			table.insert(events, { kind = "click" })
		end
		-- Spun too fast: the mechanism rattles.
		local now = input.now or 0
		table.insert(state.recent, now)
		while #state.recent > 0 and now - state.recent[1] > Safe.FastWindow do
			table.remove(state.recent, 1)
		end
		if #state.recent > Safe.FastTurns then
			table.insert(events, { kind = "rattle" })
			table.clear(state.recent)
		end
		return state, events
	elseif input.kind == "set" then
		if state.dial == spec.combo[state.stage] then
			state.stage += 1
			if state.stage > #spec.combo then
				state.solved = true
				return state, { { kind = "solved" } }
			end
			return state, { { kind = "set", stage = state.stage } }
		end
		state.stage = 1
		return state, { { kind = "wrong" } }
	end
	return state, { { kind = "refused" } }
end

function Safe.solved(state): boolean
	return state.solved == true
end

function Safe.public(state, _now: number)
	return { dial = state.dial, stage = state.stage, solved = state.solved }
end

function Safe.parse(action: string, _word: string?, a: number?, _b: number?, now: number)
	if action == "turn" and (a == 1 or a == -1) then
		return { kind = "turn", delta = a, now = now }
	elseif action == "set" then
		return { kind = "set" }
	end
	return nil
end

function Safe.solve(spec, state, _now: number)
	state.dial = spec.combo[#spec.combo]
	state.stage = #spec.combo + 1
	state.solved = true
	return state, { { kind = "solved" } }
end

return Safe
