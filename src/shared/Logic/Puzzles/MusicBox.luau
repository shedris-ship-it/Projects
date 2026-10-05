-- The music box and the piano (docs/plans/gameplay-rework.md section 7;
-- R2c): somewhere in the house a music box; wind it and it plays a short
-- tune, for everyone, wherever it's carried. Play that tune back on the
-- piano: a wrong note is a loud discord (heard by him) and you start again;
-- the whole tune opens the piano on an heirloom.
--
-- The tune: `length` notes (4 to 7) on 8 keys of a pentatonic scale, never
-- one key three times, and it changes direction at least once (so it's a
-- tune, not a run of steps). Pure (tests/specs/MusicBox.spec).

local MusicBox = {}

MusicBox.Keys = 8
-- Semitones above the lowest key: a major pentatonic across two octaves.
MusicBox.Semitones = { 0, 2, 4, 7, 9, 12, 14, 16 }

-- PlaybackSpeed for key `k`, from a sample whose own pitch is `base`.
function MusicBox.pitch(k: number, base: number?): number
	return (base or 1) * 2 ^ (MusicBox.Semitones[k] / 12)
end

local function changesDirection(notes): boolean
	local last = 0
	for i = 2, #notes do
		local step = notes[i] - notes[i - 1]
		if step ~= 0 then
			local sign = step > 0 and 1 or -1
			if last ~= 0 and sign ~= last then
				return true
			end
			last = sign
		end
	end
	return false
end

function MusicBox.valid(notes): boolean
	local counts = {}
	for _, k in notes do
		counts[k] = (counts[k] or 0) + 1
		if counts[k] >= 3 then
			return false
		end
	end
	return #notes >= 4 and changesDirection(notes)
end

function MusicBox.generate(rng, ctx)
	local length = (ctx and ctx.length) or rng:NextInteger(4, 7)
	local notes
	repeat
		notes = {}
		for i = 1, length do
			-- Mostly small steps, the way a tune moves.
			local from = notes[i - 1] or rng:NextInteger(2, 7)
			local step = rng:Pick({ -2, -1, -1, 1, 1, 2, 3, -3 })
			notes[i] = i == 1 and from or math.clamp(from + step, 1, MusicBox.Keys)
		end
	until MusicBox.valid(notes)
	return { length = length, notes = notes }
end

-- The screen gets how long the tune is, never the notes.
function MusicBox.view(spec)
	return { keys = MusicBox.Keys, length = spec.length }
end

function MusicBox.start(_spec)
	return { played = 0, solved = false }
end

-- input: { kind = "key", key }. Events: "note" (right), "discord" (wrong:
-- start again), "solved", "refused".
function MusicBox.step(spec, state, input)
	if state.solved then
		return state, {}
	end
	if input.kind ~= "key" or type(input.key) ~= "number" or input.key % 1 ~= 0 then
		return state, { { kind = "refused" } }
	end
	if input.key < 1 or input.key > MusicBox.Keys then
		return state, { { kind = "refused" } }
	end
	if input.key == spec.notes[state.played + 1] then
		state.played += 1
		local events = { { kind = "note", key = input.key } }
		if state.played >= spec.length then
			state.solved = true
			table.insert(events, { kind = "solved" })
		end
		return state, events
	end
	state.played = 0
	return state, { { kind = "discord", key = input.key } }
end

function MusicBox.solved(state): boolean
	return state.solved == true
end

function MusicBox.public(state, _now: number)
	return { played = state.played, solved = state.solved }
end

function MusicBox.parse(action: string, _word: string?, a: number?, _b: number?, _now: number)
	if action == "key" and type(a) == "number" then
		return { kind = "key", key = a }
	end
	return nil
end

function MusicBox.solve(spec, state, _now: number)
	state.played = spec.length
	state.solved = true
	return state, { { kind = "solved" } }
end

return MusicBox
