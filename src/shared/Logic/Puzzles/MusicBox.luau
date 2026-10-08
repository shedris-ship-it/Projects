-- The music box and the piano (docs/plans/gameplay-rework.md section 7;
-- R2c): somewhere in the house a music box; wind it and it plays a short
-- tune, for everyone, wherever it's carried. Play that tune back on the
-- piano and it opens on an heirloom.
--
-- The squad playtest (2026-10-08) found it unreadable: "even for me who
-- knows it's there, I don't know how to do it". Now the box's comb and the
-- piano's keys wear the same eight colours (a child's practice stickers,
-- Config.MusicBox.Colors), the comb lights each note as it plays, and the
-- piano plays freely: no discord, no starting again. It opens the moment
-- its last notes played are the tune (each key is a little noise instead).
--
-- The tune: `length` notes (4 or 5) on 8 keys of a pentatonic scale, never
-- one key three times, and it changes direction at least once (so it's a
-- tune, not a run of steps). Pure (tests/specs/MusicBox.spec).

local MusicBox = {}

MusicBox.Keys = 8
MusicBox.Lengths = { 4, 5 } -- short enough to remember from one hearing
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
	local length = (ctx and ctx.length) or rng:NextInteger(MusicBox.Lengths[1], MusicBox.Lengths[2])
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
	return { played = 0, solved = false, recent = {} }
end

-- How much of the tune the keys played last spell out: the longest run at
-- the end of `recent` that is the start of the tune.
function MusicBox.matched(notes, recent): number
	for n = math.min(#notes, #recent), 1, -1 do
		local ok = true
		for i = 1, n do
			if recent[#recent - n + i] ~= notes[i] then
				ok = false
				break
			end
		end
		if ok then
			return n
		end
	end
	return 0
end

-- input: { kind = "key", key } or { kind = "listen" } (wind the box beside
-- the piano). Events: "note" (every key, with how much of the tune it now
-- matches), "listen", "solved", "refused".
function MusicBox.step(spec, state, input)
	if state.solved then
		return state, {}
	end
	if input.kind == "listen" then
		return state, { { kind = "listen" } }
	end
	if input.kind ~= "key" or type(input.key) ~= "number" or input.key % 1 ~= 0 then
		return state, { { kind = "refused" } }
	end
	if input.key < 1 or input.key > MusicBox.Keys then
		return state, { { kind = "refused" } }
	end
	state.recent = state.recent or {}
	table.insert(state.recent, input.key)
	while #state.recent > spec.length do
		table.remove(state.recent, 1)
	end
	state.played = MusicBox.matched(spec.notes, state.recent)
	local events = { { kind = "note", key = input.key, played = state.played } }
	if state.played >= spec.length then
		state.solved = true
		table.insert(events, { kind = "solved" })
	end
	return state, events
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
	elseif action == "listen" then
		return { kind = "listen" }
	end
	return nil
end

function MusicBox.solve(spec, state, _now: number)
	state.played = spec.length
	state.solved = true
	return state, { { kind = "solved" } }
end

return MusicBox
