-- The Guest's moods (the Guest rework, 2026-10-07): what he is about for a
-- while, so the same squad meets a different Guest from one minute to the
-- next. Pure: StalkerService owns a state and feeds it events; Stalk and the
-- Tactician read the weights; the server publishes the mood as an attribute
-- so every client draws its body language and plays its sound (legible:
-- you can tell what he's about by looking and listening).
--
-- A mood lasts a drawn while (Config.Guest.MoodSeconds), then he takes on a
-- new one by his temperament's odds (Data/Temperaments). Things that happen
-- shift it sooner: a stun or a lure that came to nothing irritates him, a
-- stare-down makes him patient or irritated, an heirloom taken sets him
-- stalking its carrier, a catch makes him the host again, a long while
-- seeing nobody makes him curious or playful.
--
-- A mood never shortens a tell, a cooldown or a fairness gate
-- (Logic/StalkRules); `creep` scales his creeping speed within 0.8-1.2 with
-- the temperament's.

local GuestMood = {}

GuestMood.Moods = {
	Curious = {
		tell = "His head tilts one way, then the other.",
		counter = "He's looking, not hunting: stay out of his way and keep quiet.",
		sound = nil,
		stalk = {
			Search = 1.3,
			Investigate = 1.4,
			Peek = 1.2,
			DistantRoam = 1.1,
			CreepBehind = 0.8,
			FingersPeek = 1.4,
			HallwayStand = 1.2,
		},
		tactics = { SweepRooms = 1.3, Investigate = 1.3, CheckHidingSpots = 1.1 },
		-- When a Witness catches him peeking at tier 1 (Stalk's tier-1 reactions).
		seen = { Yank = 1, Withdraw = 1.4, Duck = 1 },
		hunt = { prowl = 1, sweep = 1.5, silent = 0.5 },
		creep = 1,
	},
	Stalking = {
		tell = "Low and loose, hands hanging, fingers spread.",
		counter = "He's after one of you: keep together and look behind you.",
		sound = nil,
		stalk = {
			CreepBehind = 1.5,
			ShadowBehind = 1.5,
			DoorwayStand = 1.2,
			Peek = 0.8,
			DistantRoam = 0.5,
			BehindTheDoor = 1.3,
			HallwayStand = 1.1,
		},
		tactics = { TargetStraggler = 1.4, FlankBlindSpot = 1.4, SearchLastKnown = 1.2 },
		seen = { Yank = 1.4, Withdraw = 1, Duck = 0.6 },
		hunt = { prowl = 1, sweep = 0.6, silent = 1.6 },
		creep = 1.1,
	},
	Host = {
		tell = "Hands clasped in front of him, humming.",
		counter = "The hum carries: you can hear where he is.",
		sound = "Hum",
		stalk = { DoorwayStand = 1.1, DistantRoam = 1.2, CreepBehind = 0.7, StareDown = 1.1, HostAction = 2.2 },
		tactics = { MimicKnock = 1.4, Ambush = 1.2 },
		seen = { Yank = 0.8, Withdraw = 1.5, Duck = 0.7 },
		hunt = { prowl = 1.5, sweep = 0.8, silent = 0.5 },
		creep = 0.9,
	},
	Playful = {
		tell = "Fingertips tapping, head bobbing to a tune only he hears.",
		counter = "His games are noisy: don't follow every sound.",
		sound = "Tap",
		stalk = {
			Peek = 1.3,
			Investigate = 1.2,
			ShadowBehind = 1.1,
			CreepBehind = 0.8,
			HostAction = 1.6,
			FingersPeek = 1.4,
			BehindTheDoor = 1.4,
			MimicVoice = 1.6,
		},
		tactics = { FakePing = 1.5, MimicKnock = 1.5, FakeLeaveReturn = 1.3 },
		seen = { Yank = 0.8, Withdraw = 1, Duck = 1.6 },
		hunt = { prowl = 1.4, sweep = 1, silent = 0.6 },
		creep = 1,
	},
	Patient = {
		tell = "Dead still, not even breathing.",
		counter = "He waits where you're going: take the other door.",
		sound = nil,
		stalk = {
			DoorwayStand = 1.5,
			StareDown = 1.3,
			CreepBehind = 0.8,
			ShadowBehind = 0.8,
			BehindTheDoor = 1.5,
			HallwayStand = 1.5,
		},
		tactics = { Ambush = 1.6, ListenStill = 1.5, CutOffLoop = 1.3 },
		seen = { Yank = 1, Withdraw = 1.6, Duck = 0.6 },
		hunt = { prowl = 0.7, sweep = 0.6, silent = 1.8 },
		creep = 0.85,
	},
	Irritated = {
		tell = "His knuckles crack and his head jerks.",
		counter = "Something you did annoyed him: stop doing it for a while.",
		sound = "Crack",
		stalk = {
			CreepBehind = 1.4,
			StareDown = 1.4,
			ShadowBehind = 1.2,
			Peek = 0.6,
			Investigate = 0.6,
			HostAction = 0.4,
			MimicVoice = 1.2,
		},
		tactics = { KillLights = 1.6, CheckHidingSpots = 1.4, SearchLastKnown = 1.3 },
		seen = { Yank = 1.6, Withdraw = 0.8, Duck = 0.6 },
		hunt = { prowl = 1, sweep = 1.6, silent = 0.6 },
		creep = 1.15,
	},
}

GuestMood.Order = { "Curious", "Stalking", "Host", "Playful", "Patient", "Irritated" }

-- Events that shift his mood, and what they lean him towards.
GuestMood.Events = {
	stunned = { Irritated = 1 },
	barricade = { Irritated = 1 },
	luresEmpty = { Irritated = 1 },
	staredDown = { Patient = 1, Irritated = 1 },
	heirloomTaken = { Stalking = 1 },
	huntCaught = { Host = 1 },
	huntSurvived = { Irritated = 1, Patient = 0.6 },
	lonely = { Curious = 1, Playful = 1 },
}

-- temperament: a Data/Temperaments entry (or nil for even odds).
function GuestMood.new(temperament)
	return { mood = nil, untilT = 0, temperament = temperament, changes = 0, reason = nil }
end

local function odds(state, id: string): number
	local t = state.temperament
	return (t and t.moodOdds and t.moodOdds[id]) or 1
end

-- Draw among `weights` (id -> weight) by the temperament's odds, never the
-- mood he's in unless it's the only one.
local function draw(state, weights, rng): string?
	local list = {}
	for _, id in GuestMood.Order do
		local w = weights[id]
		if w and w > 0 and id ~= state.mood then
			table.insert(list, { id = id, w = w * odds(state, id) })
		end
	end
	if #list == 0 then
		return nil
	end
	return rng:WeightedPick(list, function(entry)
		return entry.w
	end).id
end

local function set(state, id: string, now: number, rng, cfg, reason: string): boolean
	local seconds = cfg and cfg.MoodSeconds or { 60, 180 }
	state.untilT = now + rng:NextNumber(seconds[1], seconds[2])
	state.reason = reason
	if state.mood == id then
		return false
	end
	state.mood = id
	state.changes += 1
	return true
end

-- Time passing: a new mood when this one has run its course (the first
-- call picks his first). Returns the new mood's id when it changed.
function GuestMood.update(state, now: number, rng, cfg): string?
	if state.mood and now < state.untilT then
		return nil
	end
	local all = {}
	for _, id in GuestMood.Order do
		all[id] = 1
	end
	local id = draw(state, all, rng) or state.mood or "Curious"
	if set(state, id, now, rng, cfg, "time") then
		return id
	end
	return nil
end

-- Something happened (a key of GuestMood.Events). Already in one of the
-- moods it leans to, he stays in it a while longer. Returns the new mood's
-- id when it changed.
function GuestMood.event(state, kind: string, now: number, rng, cfg): string?
	local leans = GuestMood.Events[kind]
	if not leans then
		return nil
	end
	if state.mood and leans[state.mood] then
		local seconds = cfg and cfg.MoodSeconds or { 60, 180 }
		state.untilT = math.max(state.untilT, now + seconds[1])
		return nil
	end
	local id = draw(state, leans, rng)
	if id and set(state, id, now, rng, cfg, kind) then
		return id
	end
	return nil
end

-- Weights for UtilityAI.choose: the archetype's, times the temperament's,
-- times the mood's. kind: "stalk" (Data/StalkMoves) or "tactics".
function GuestMood.weights(state, archetypeWeights, kind: string)
	local out = {}
	local function fold(source)
		for id, w in source or {} do
			out[id] = (out[id] or 1) * w
		end
	end
	fold(archetypeWeights)
	fold(state.temperament and state.temperament[kind])
	local mood = state.mood and GuestMood.Moods[state.mood]
	fold(mood and mood[kind])
	return out
end

-- His creeping speed scale for the temperament and mood, within 0.8-1.2.
function GuestMood.creepScale(state): number
	local t = state.temperament
	local mood = state.mood and GuestMood.Moods[state.mood]
	local scale = ((t and t.numbers and t.numbers.creep) or 1) * ((mood and mood.creep) or 1)
	return math.clamp(scale, 0.8, 1.2)
end

-- A number from the temperament (linger, peekHold), 1 when it has none.
function GuestMood.number(state, key: string): number
	local t = state.temperament
	return (t and t.numbers and t.numbers[key]) or 1
end

-- Pick among a mood's weighted options (`seen` for tier-1 reactions, `hunt`
-- for the kind of hunt). Returns the id.
function GuestMood.choose(state, key: string, rng): string?
	local mood = GuestMood.Moods[state.mood or "Curious"]
	local options = mood and mood[key]
	if not options then
		return nil
	end
	local list = {}
	for id, w in options do
		table.insert(list, { id = id, w = w })
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return rng:WeightedPick(list, function(entry)
		return entry.w
	end).id
end

-- The night's temperament from a seeded rng (Data/Temperaments' weights).
function GuestMood.temperament(list, rng)
	return rng:WeightedPick(list, function(t)
		return t.weight or 1
	end)
end

return GuestMood
