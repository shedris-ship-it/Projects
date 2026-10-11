-- The Director's "scare deck" (doc section 3: pacing, not randomness).
-- Scares are drawn from a shuffled deck with per-card cooldowns and a
-- minimum gap between big scares, which avoids both droughts and pile-ups.

local ScareDeck = {}
ScareDeck.__index = ScareDeck

-- The cards with their weights leaned by `multipliers` (id -> factor: the
-- night's temperament, Data/Temperaments `cards`), rounded to whole copies.
-- A card leaned to nothing stays at one copy unless its factor is 0: a
-- temperament makes a scare rarer, never gone by accident.
function ScareDeck.weighted(cards, multipliers)
	local out = {}
	for _, card in cards do
		local factor = multipliers and multipliers[card.id]
		if factor == nil then
			table.insert(out, card)
		elseif factor > 0 then
			local copy = table.clone(card)
			copy.weight = math.max(1, math.floor((card.weight or 1) * factor + 0.5))
			table.insert(out, copy)
		end
	end
	return out
end

-- cards: { { id, weight = n (copies in the deck), big = bool, cooldown = s,
--   minDrift = n (a Dread threshold since 2026-10-06), minAct = n, once = bool } }
function ScareDeck.new(cards, rng, bigGap: number)
	local self = setmetatable({
		cards = cards,
		rng = rng,
		bigGap = bigGap,
		deck = {},
		lastPlayed = {},
		lastBig = -math.huge,
	}, ScareDeck)
	self:_reshuffle()
	return self
end

function ScareDeck:_reshuffle()
	local deck = {}
	for _, card in self.cards do
		for _ = 1, card.weight or 1 do
			table.insert(deck, card)
		end
	end
	self.deck = self.rng:Shuffle(deck)
end

function ScareDeck:_playable(card, now: number, drift: number, act: number?, quiet: boolean?): boolean
	if drift < (card.minDrift or 0) then
		return false
	end
	if quiet and card.big then
		return false
	end
	if (act or 1) < (card.minAct or 1) then
		return false
	end
	if card.once and self.lastPlayed[card.id] then
		return false
	end
	local last = self.lastPlayed[card.id]
	if last and now - last < (card.cooldown or 0) then
		return false
	end
	if card.big and now - self.lastBig < self.bigGap then
		return false
	end
	return true
end

-- A card that couldn't be played after all (a house event with nothing near
-- to play it on): forget it was, so its cooldown doesn't run.
function ScareDeck:Unplay(card)
	self.lastPlayed[card.id] = nil
end

-- Draw the next playable card, or nil if nothing is playable right now.
-- Unplayable cards stay in the deck for later draws. `quiet`: no big ones
-- (the night's intro).
function ScareDeck:Draw(now: number, drift: number, act: number?, quiet: boolean?)
	if #self.deck == 0 then
		self:_reshuffle()
	end
	for i, card in self.deck do
		if self:_playable(card, now, drift, act, quiet) then
			table.remove(self.deck, i)
			self.lastPlayed[card.id] = now
			if card.big then
				self.lastBig = now
			end
			return card
		end
	end
	return nil
end

return ScareDeck
