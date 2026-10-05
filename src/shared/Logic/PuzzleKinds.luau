-- Every kind of puzzle (docs/plans/gameplay-rework.md section 7; R2c "the
-- puzzle registry"): the pure rules of each, by kind. A kind's module has
--   generate(rng, ctx) -> spec   (the answer stays on the server)
--   view(spec)                   what its screen is built from
--   start(spec) -> state
--   step(spec, state, input) -> (state, events)
--   solved(state) -> boolean
--   public(state, now)           what its operator's screen may show
--   parse(action, word?, a?, b?, now) -> input?   a click, checked
--   solve(spec, state, now)      F2 `solve`: as if done right
-- Services/PuzzleService runs them (with a station per kind, server/
-- Puzzles/*), UI/Puzzle draws them (UI/Puzzles/*). tests/specs/Puzzles.spec
-- holds every kind to this.

local Puzzles = script.Parent.Puzzles

return {
	terminal = require(Puzzles.Terminal),
	padlock = require(Puzzles.Padlock),
	breaker = require(Puzzles.Breaker),
	safe = require(Puzzles.Safe),
	musicbox = require(Puzzles.MusicBox),
	dumbwaiter = require(Puzzles.Dumbwaiter),
}
