-- The dumbwaiter (R2c, the two-person locks): not a puzzle with a screen but
-- a mechanism (server/Puzzles/Dumbwaiter runs it: a crank downstairs, the
-- car, an open hatch upstairs). It keeps the registry's contract (Logic/
-- PuzzleKinds) so it's a station like the rest: on the map, in the
-- objective line, solved once its heirloom is taken. Nothing is hidden.

local Dumbwaiter = {}

function Dumbwaiter.generate(_rng, _ctx)
	return {}
end

function Dumbwaiter.view(_spec)
	return {}
end

function Dumbwaiter.start(_spec)
	return { solved = false }
end

function Dumbwaiter.step(_spec, state, _input)
	return state, { { kind = "refused" } }
end

function Dumbwaiter.solved(state): boolean
	return state.solved == true
end

function Dumbwaiter.public(state, _now: number)
	return { solved = state.solved }
end

function Dumbwaiter.parse(_action: string, _word: string?, _a: number?, _b: number?, _now: number)
	return nil
end

function Dumbwaiter.solve(_spec, state, _now: number)
	state.solved = true
	return state, { { kind = "solved" } }
end

return Dumbwaiter
