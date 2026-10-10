-- Twin levers (the squad playtest, 2026-10-10: "no reason to need your team";
-- the owner's choice, solo-safe team puzzles): a door that opens only while
-- its two levers are down together, one beside the door and its twin in
-- another room, out of sight of it. Not a puzzle with a screen but a
-- mechanism (server/Puzzles/Levers runs it), keeping the registry's contract
-- (Logic/PuzzleKinds) so it's a station like the rest. Nothing is hidden.
--
-- A lever is down while someone holds it, and for a moment after: a squad's
-- moment (Grace) is short, so it's "now!" over voice, one at each. With one
-- player left (alone, or the rest down or lost), a released lever stays down
-- on a clockwork catch long enough to walk to its twin, ticking loud enough
-- for him to hear: slower and riskier, never impossible.
--
-- Pure (tests/specs/Levers.spec).

local Levers = {}

function Levers.generate(_rng, _ctx)
	return {}
end

function Levers.view(_spec)
	return {}
end

function Levers.start(_spec)
	return { solved = false }
end

function Levers.step(_spec, state, _input)
	return state, { { kind = "refused" } }
end

function Levers.solved(state): boolean
	return state.solved == true
end

function Levers.public(state, _now: number)
	return { solved = state.solved }
end

function Levers.parse(_action: string, _word: string?, _a: number?, _b: number?, _now: number)
	return nil
end

function Levers.solve(_spec, state, _now: number)
	state.solved = true
	return state, { { kind = "solved" } }
end

-- How long a lever let go stays down: the squad's moment, or (one player
-- left) the walk to its twin at `cfg.SoloWalkSpeed`, plus `cfg.SoloMargin`.
-- cfg: { Grace, SoloWalkSpeed, SoloMargin }.
function Levers.window(players: number, walkStuds: number, cfg): number
	if players >= 2 then
		return cfg.Grace
	end
	return walkStuds / cfg.SoloWalkSpeed + cfg.SoloMargin
end

-- Is a lever down? lever: { held (anyone on it now), releasedAt?, window }.
function Levers.down(lever, now: number): boolean
	if lever.held then
		return true
	end
	return lever.releasedAt ~= nil and now - lever.releasedAt < lever.window
end

-- Only on its catch (let go, still down): the ticking.
function Levers.ticking(lever, now: number): boolean
	return not lever.held and Levers.down(lever, now)
end

-- Both down at once: the door opens.
function Levers.together(a, b, now: number): boolean
	return Levers.down(a, now) and Levers.down(b, now)
end

return Levers
