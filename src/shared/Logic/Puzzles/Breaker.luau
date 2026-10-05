-- The breaker panel (docs/plans/gameplay-rework.md section 7; R2c): a row of
-- breakers that light real rooms, and a main that trips when more than the
-- panel's capacity are on at once (every light out, a loud clunk). A door
-- with an electric lock is on one of them: power it, and it opens for good.
--
-- At the start the panel is full (`capacity` on, the door's breaker off), so
-- to power the door you must first turn something else off. The labels are
-- the family's handwriting and not all true: the door's own breaker may have
-- lost its label, and another may wrongly carry the door's room. So the
-- door's breaker is one labelled with its room or with no label: never more
-- than three to try (`candidates`, tests/specs/Breaker.spec). A friend
-- watching the door's lamp, or the rooms going dark, tells you which.
--
-- Pure; the answer (`gate`) stays on the server.
--   generate(rng, ctx): ctx { labels = { names }, gate = index, gateName,
--     capacity?, smudge?, decoy? } (all optional: a plain six-breaker panel)

local Breaker = {}

local function countOn(on): number
	local n = 0
	for _, value in on do
		if value then
			n += 1
		end
	end
	return n
end

function Breaker.generate(rng, ctx)
	ctx = ctx or {}
	local labels = ctx.labels
	if not labels then
		labels = { "HALL" }
		for i = 2, 6 do
			labels[i] = "ROOM " .. i
		end
	end
	local count = #labels
	local gate = ctx.gate or rng:NextInteger(2, count)
	local capacity = math.clamp(ctx.capacity or rng:NextInteger(3, 4), 2, count - 1)
	-- On at the start: the hall, then others (never the door's) until full.
	local start = {}
	for i = 1, count do
		start[i] = false
	end
	start[1] = true
	local others = {}
	for i = 2, count do
		if i ~= gate then
			table.insert(others, i)
		end
	end
	rng:Shuffle(others)
	for k = 1, math.min(capacity - 1, #others) do
		start[others[k]] = true
	end
	-- What the panel says.
	local shown = table.clone(labels)
	local gateName = ctx.gateName or labels[gate]
	shown[gate] = gateName
	if rng:Chance(ctx.smudge or 0.35) then
		shown[gate] = "?"
	end
	if rng:Chance(ctx.decoy or 0.5) and #others > 0 then
		shown[rng:Pick(others)] = gateName
	end
	return {
		count = count,
		capacity = math.min(capacity, count),
		gate = gate,
		gateName = gateName,
		labels = shown,
		start = start,
	}
end

-- The breakers the door's could be, read off the panel: labelled with its
-- room, or with no label at all.
function Breaker.candidates(labels, gateName: string): { number }
	local list = {}
	for i, label in labels do
		if label == gateName or label == "?" then
			table.insert(list, i)
		end
	end
	return list
end

function Breaker.view(spec)
	return { count = spec.count, capacity = spec.capacity, labels = spec.labels, gateName = spec.gateName }
end

function Breaker.start(spec)
	return { on = table.clone(spec.start), tripped = false, solved = false }
end

-- Is breaker `i` giving power (on, and the main not tripped)?
function Breaker.powered(state, i: number): boolean
	return state.on[i] == true and not state.tripped
end

local function check(spec, state, events)
	if not state.tripped and state.on[spec.gate] and not state.solved then
		state.solved = true
		table.insert(events, { kind = "solved" })
	end
end

-- input: { kind = "flip", index } or { kind = "main" } (reset a tripped
-- main). Events: "flip", "trip", "reset", "solved", "refused".
function Breaker.step(spec, state, input)
	local events = {}
	if input.kind == "flip" then
		local i = input.index
		if type(i) ~= "number" or i % 1 ~= 0 or i < 1 or i > spec.count then
			return state, { { kind = "refused" } }
		end
		state.on[i] = not state.on[i]
		table.insert(events, { kind = "flip", index = i, on = state.on[i] })
		if not state.tripped and countOn(state.on) > spec.capacity then
			state.tripped = true
			table.insert(events, { kind = "trip" })
		end
		check(spec, state, events)
		return state, events
	elseif input.kind == "main" then
		if not state.tripped then
			return state, { { kind = "refused" } }
		end
		if countOn(state.on) > spec.capacity then
			-- Straight back off: too much is still on.
			table.insert(events, { kind = "trip" })
		else
			state.tripped = false
			table.insert(events, { kind = "reset" })
			check(spec, state, events)
		end
		return state, events
	end
	return state, { { kind = "refused" } }
end

function Breaker.solved(state): boolean
	return state.solved == true
end

function Breaker.public(state, _now: number)
	return { on = state.on, tripped = state.tripped, solved = state.solved }
end

function Breaker.parse(action: string, _word: string?, a: number?, _b: number?, _now: number)
	if action == "flip" and type(a) == "number" then
		return { kind = "flip", index = a }
	elseif action == "main" then
		return { kind = "main" }
	end
	return nil
end

-- F2 `solve`: one breaker off to make room, the door's on.
function Breaker.solve(spec, state, _now: number)
	state.tripped = false
	for i = spec.count, 2, -1 do
		if state.on[i] and i ~= spec.gate and countOn(state.on) >= spec.capacity then
			state.on[i] = false
		end
	end
	state.on[spec.gate] = true
	local events = {}
	check(spec, state, events)
	return state, events
end

return Breaker
