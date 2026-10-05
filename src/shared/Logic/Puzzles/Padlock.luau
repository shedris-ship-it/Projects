-- A combination padlock on a door (docs/plans/gameplay-rework.md section 7):
-- three or four wheels of digits, opened with a code found elsewhere (the
-- home computer prints it). Turning the wheels is quiet; pulling on a wrong
-- combination rattles the lock (noise with you as its source).
--
-- Pure (tests/specs/Terminal.spec); the answer stays on the server.

local Padlock = {}

-- ctx: { wheels? }. Returns the spec; `spec.answer` never leaves the server.
function Padlock.generate(rng, ctx)
	local wheels = (ctx and ctx.wheels) or rng:NextInteger(3, 4)
	local answer = {}
	for i = 1, wheels do
		answer[i] = rng:NextInteger(0, 9)
	end
	return { wheels = wheels, answer = answer }
end

-- The code as it's printed, "4 7 1 9".
function Padlock.code(spec): string
	local digits = {}
	for i, digit in spec.answer do
		digits[i] = tostring(digit)
	end
	return table.concat(digits, " ")
end

function Padlock.view(spec)
	return { wheels = spec.wheels }
end

function Padlock.start(spec)
	local digits = {}
	for i = 1, spec.wheels do
		digits[i] = 0
	end
	return { digits = digits, solved = false }
end

-- input: { kind = "turn", wheel, delta } or { kind = "pull" }. Changes
-- `state`, returns it and what happened: "turned", "rattle", "solved" or
-- "refused".
function Padlock.step(spec, state, input)
	if state.solved then
		return state, {}
	end
	if input.kind == "turn" then
		local wheel, delta = input.wheel, input.delta
		if type(wheel) ~= "number" or wheel % 1 ~= 0 or wheel < 1 or wheel > spec.wheels or type(delta) ~= "number" then
			return state, { { kind = "refused" } }
		end
		state.digits[wheel] = (state.digits[wheel] + math.sign(delta)) % 10
		return state, { { kind = "turned", wheel = wheel, digit = state.digits[wheel] } }
	elseif input.kind == "pull" then
		for i = 1, spec.wheels do
			if state.digits[i] ~= spec.answer[i] then
				return state, { { kind = "rattle" } }
			end
		end
		state.solved = true
		return state, { { kind = "solved" } }
	end
	return state, { { kind = "refused" } }
end

function Padlock.solved(state): boolean
	return state.solved == true
end

function Padlock.public(state, _now: number)
	return { digits = state.digits, solved = state.solved }
end

function Padlock.parse(action: string, _word: string?, a: number?, b: number?, _now: number)
	if action == "turn" and type(a) == "number" and type(b) == "number" then
		return { kind = "turn", wheel = a, delta = b }
	elseif action == "pull" then
		return { kind = "pull" }
	end
	return nil
end

function Padlock.solve(spec, state, _now: number)
	state.digits = table.clone(spec.answer)
	return Padlock.step(spec, state, { kind = "pull" })
end

return Padlock
