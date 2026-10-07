-- A hunt in phases (the Guest rework, 2026-10-07): before, he either ran at
-- you or followed a goto/wait plan, and you couldn't tell which by ear. Now:
--
--   prowl  nobody in sight: a fast walk, doors slammed open, a pause now
--          and then to listen (the Tactician's plans, at his kind's pace)
--   chase  he sees you: "spotted" (his head snaps round, a rasp for you),
--          then his full run at where you're going
--   lost   he's lost you: back to where he last saw you, still, listening,
--          a long sniff; then the hiding places nearest that spot. Hold
--          your breath. Then he prowls again.
--
-- The kind of hunt is drawn as it starts, by his mood (Logic/GuestMood
-- "hunt"): prowl, sweep (the rooms you use, the hiding places you like) or
-- silent (no slams, no listening pauses heard, a walk until he sees you).
-- Thirty seconds with nobody seen and he widens his options (KillLights,
-- MimicKnock). Pure: StalkerService keeps the state, the spec checks it. The
-- telegraph, the hunt's length, the hold chain and the catch rules are all
-- as they were.

local HuntPhases = {}

-- His pace while prowling, as a share of his run, by the kind of hunt.
HuntPhases.Prowl = { prowl = 0.6, sweep = 0.68, silent = 0.42 }

-- What each kind of hunt leans on (multiplies Data/Tactics weights).
HuntPhases.Tactics = {
	prowl = {},
	sweep = { SweepRooms = 2, CheckHidingSpots = 1.5 },
	silent = { Ambush = 1.5, ListenStill = 1.5, FlankBlindSpot = 1.3 },
}

-- ...and once he's seen nobody for a while.
HuntPhases.Widen = { KillLights = 1.6, MimicKnock = 1.6, FakePing = 1.3 }

function HuntPhases.new(kind: string?, now: number)
	return {
		kind = HuntPhases.Prowl[kind or ""] and kind or "prowl",
		phase = "prowl",
		since = now,
		started = now,
		lastSeen = nil,
		sightings = 0,
		losses = 0,
	}
end

-- One step. `seeing`: he sees someone he can chase this tick. Returns the
-- phase, and true when it was entered this step.
function HuntPhases.step(state, now: number, seeing: boolean, cfg): (string, boolean)
	if seeing then
		state.lastSeen = now
		if state.phase ~= "chase" then
			state.phase, state.since = "chase", now
			state.sightings += 1
			return "chase", true
		end
		return "chase", false
	end
	if state.phase == "chase" and now - (state.lastSeen or now) >= cfg.ChaseGrace then
		state.phase, state.since = "lost", now
		state.losses += 1
		return "lost", true
	end
	return state.phase, false
end

-- The lost spell is over (he listened, he looked): he prowls again.
function HuntPhases.done(state, now: number)
	if state.phase == "lost" then
		state.phase, state.since = "prowl", now
	end
end

-- His speed for the phase, as a share of his run: full in a chase, none
-- while he stands and listens, his kind's pace otherwise.
function HuntPhases.speed(state): number
	if state.phase == "chase" then
		return 1
	end
	return HuntPhases.Prowl[state.kind] or HuntPhases.Prowl.prowl
end

-- Has he gone long enough without seeing anyone to widen his options?
function HuntPhases.widened(state, now: number, cfg): boolean
	return now - (state.lastSeen or state.started) >= cfg.WidenAfter
end

-- Tactic weights for this hunt (kind, and widened), to fold with his mood's.
function HuntPhases.weights(state, now: number, cfg)
	local out = table.clone(HuntPhases.Tactics[state.kind] or {})
	if HuntPhases.widened(state, now, cfg) then
		for id, w in HuntPhases.Widen do
			out[id] = (out[id] or 1) * w
		end
	end
	return out
end

return HuntPhases
