-- His temperament for the night (Data/Temperaments; "a Guest you can read",
-- 2026-10-11): each strongly itself, readable from the first minutes, with a
-- sign and a counter for the Dossier; real moves, tactics, intro moves and
-- scare cards; numbers inside his fairness limits; and the voice trick only
-- where the owner allowed it.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local GuestMood = require(Shared.Logic.GuestMood)
	local ScareCards = require(Shared.Data.ScareCards)
	local ScareDeck = require(Shared.Logic.ScareDeck)
	local StalkMoves = require(Shared.Data.StalkMoves)
	local StalkRules = require(Shared.Logic.StalkRules)
	local Tactics = require(Shared.Data.Tactics)
	local Temperaments = require(Shared.Data.Temperaments)
	local Rng = require(Shared.Lib.Rng)
	local G = Config.Guest

	local cardIds = {}
	for _, card in ScareCards do
		cardIds[card.id] = true
	end

	-- Bounds on his numbers: a temperament leans him, it never makes him
	-- another creature (creep is clamped again with his mood: GuestMood).
	local BOUNDS = {
		creep = { 0.8, 1.2 },
		linger = { 0.4, 2 },
		peekHold = { 0.5, 1.6 },
		park = { 0.4, 1.2 },
		scent = { 0.4, 1 },
	}

	test("each is readable: a dominant mood, a sign and a counter, real names everywhere", function()
		check.equal(#Temperaments.List, 4, "four temperaments")
		for _, t in Temperaments.List do
			check.truthy(GuestMood.Moods[t.dominant], t.id .. ": a real dominant mood")
			check.truthy(type(t.sign) == "string" and #t.sign > 10, t.id .. " has a sign")
			check.truthy(type(t.counter) == "string" and #t.counter > 10, t.id .. " has a counter")
			for id, w in t.stalk do
				check.truthy(StalkMoves.ById[id], t.id .. ": no move " .. id)
				check.truthy(w > 0, t.id .. ": weight for " .. id)
			end
			for id, w in t.tactics do
				check.truthy(Tactics.ById[id], t.id .. ": no tactic " .. id)
				check.truthy(w > 0, t.id .. ": weight for " .. id)
			end
			for id, w in t.intro or {} do
				check.truthy(G.Intro.Moves[id], t.id .. ": " .. id .. " isn't an intro move")
				check.truthy(w > 0, t.id .. ": intro weight for " .. id)
			end
			for id, w in t.cards or {} do
				check.truthy(cardIds[id], t.id .. ": no scare card " .. id)
				check.truthy(w > 0, t.id .. ": a temperament makes a card rarer, never gone")
			end
			for key, value in t.numbers or {} do
				local b = BOUNDS[key]
				check.truthy(b, t.id .. ": unknown number " .. key)
				check.truthy(value >= b[1] and value <= b[2], t.id .. ": " .. key .. " within bounds")
			end
		end
	end)

	test("the night's own mood is most of the night, by time", function()
		for _, t in Temperaments.List do
			local time, total = {}, 0
			for seed = 1, 40 do
				local rng = Rng.new(seed)
				local state = GuestMood.new(t)
				local last, lastAt = nil, 0
				for now = 0, 1800, 5 do
					GuestMood.update(state, now, rng, G)
					if last then
						time[last] = (time[last] or 0) + (now - lastAt)
						total += now - lastAt
					end
					last, lastAt = state.mood, now
				end
			end
			local best, bestShare = nil, 0
			for id, seconds in time do
				if seconds / total > bestShare then
					best, bestShare = id, seconds / total
				end
			end
			check.equal(best, t.dominant, t.id .. ": the dominant mood holds the longest")
			check.atLeast((time[t.dominant] or 0) / total, 0.4, t.id .. ": at least 40% of the night")
		end
	end)

	test("the voice trick: a squad on Hard, or a playful Guest on any difficulty", function()
		local normal, hard = Config.Difficulty.Normal, Config.Difficulty.Hard
		local playful, patient = Temperaments.ById.Playful, Temperaments.ById.Patient
		check.truthy(not StalkRules.voiceAllowed(1, hard, playful), "never alone: it needs a friend's voice")
		check.truthy(StalkRules.voiceAllowed(2, normal, playful), "a playful Guest on Normal")
		check.truthy(not StalkRules.voiceAllowed(2, normal, patient), "not a patient one on Normal")
		for _, t in Temperaments.List do
			check.truthy(StalkRules.voiceAllowed(3, hard, t), "Hard, " .. t.id)
		end
		for _, t in Temperaments.List do
			if t.id ~= "Playful" then
				check.truthy(not t.voice, t.id .. " keeps the voice for Hard")
			end
		end
	end)

	test("the deck leans by the night: copies scaled and rounded, never lost by accident", function()
		local cards = {
			{ id = "a", weight = 2 },
			{ id = "b", weight = 3 },
			{ id = "c", weight = 1 },
			{ id = "d", weight = 2 },
		}
		local out = ScareDeck.weighted(cards, { a = 3, b = 0.1, d = 0 })
		local byId = {}
		for _, card in out do
			byId[card.id] = card
		end
		check.equal(byId.a.weight, 6, "three times as many")
		check.equal(byId.b.weight, 1, "rarer, but still in the deck")
		check.equal(byId.c.weight, 1, "untouched")
		check.equal(byId.d, nil, "a zero takes it out")
		check.equal(cards[1].weight, 2, "the cards themselves are untouched")
		check.equal(#ScareDeck.weighted(cards, nil), #cards, "no temperament, the plain deck")
	end)

	test("a restless Guest's presence budget runs out sooner", function()
		local function secondsBeside(scale)
			local state, t = {}, 0
			while not StalkRules.parkBudget(state, true, 0.1, G, scale) do
				t += 0.1
			end
			return t
		end
		local plain = secondsBeside(nil)
		local restless = secondsBeside(Temperaments.ById.Restless.numbers.park)
		check.atMost(restless, plain * 0.6, "he moves off sooner")
		check.atLeast(restless, 0.5, "but he does stand a moment")
	end)
end
