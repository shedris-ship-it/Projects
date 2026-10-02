-- Deterministic seeded random number generator (Park-Miller minimal standard).
--
-- Roblox's Random is fine in-engine, but the design calls for every random
-- choice to be reproducible from a logged seed, and the generator/validator
-- are unit-tested outside the engine. This RNG gives identical sequences in
-- Studio, live servers and the Lune test runner. All products stay below 2^53,
-- so the arithmetic is exact in doubles.

local MODULUS = 2147483647
local MULTIPLIER = 48271

local Rng = {}
Rng.__index = Rng

local function normaliseSeed(seed: number): number
	local s = math.floor(math.abs(seed or 1)) % MODULUS
	if s == 0 then
		s = 1
	end
	return s
end

function Rng.new(seed: number)
	local self = setmetatable({ Seed = seed, _state = normaliseSeed(seed) }, Rng)
	-- Discard a few values so nearby seeds diverge quickly.
	for _ = 1, 4 do
		self:_next()
	end
	return self
end

-- Hash a string or number into a seed-sized integer (djb2 variant).
function Rng.hash(value: any): number
	local text = tostring(value)
	local h = 5381
	for i = 1, #text do
		h = (h * 33 + string.byte(text, i)) % MODULUS
	end
	return h
end

function Rng:_next(): number
	self._state = (self._state * MULTIPLIER) % MODULUS
	return self._state
end

-- Uniform number in [0, 1), or [min, max) when bounds are given.
function Rng:NextNumber(min: number?, max: number?): number
	local unit = (self:_next() - 1) / (MODULUS - 1)
	if min == nil then
		return unit
	end
	return min + (max - min) * unit
end

-- Uniform integer in [min, max] inclusive.
function Rng:NextInteger(min: number, max: number): number
	if max < min then
		min, max = max, min
	end
	local value = min + math.floor(self:NextNumber() * (max - min + 1))
	return math.min(value, max)
end

function Rng:Chance(probability: number): boolean
	return self:NextNumber() < probability
end

function Rng:Pick(list: { any }): any
	if #list == 0 then
		return nil
	end
	return list[self:NextInteger(1, #list)]
end

-- Fisher-Yates shuffle in place. Returns the same table for chaining.
function Rng:Shuffle(list: { any }): { any }
	for i = #list, 2, -1 do
		local j = self:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Pick an element with probability proportional to weightFn(element).
function Rng:WeightedPick(list: { any }, weightFn: (any) -> number): any
	local total = 0
	local weights = table.create(#list)
	for i, item in list do
		local w = math.max(0, weightFn(item))
		weights[i] = w
		total += w
	end
	if total <= 0 then
		return self:Pick(list)
	end
	local roll = self:NextNumber() * total
	for i, item in list do
		roll -= weights[i]
		if roll < 0 then
			return item
		end
	end
	return list[#list]
end

-- Pick up to `count` distinct elements, preserving no particular order.
function Rng:Sample(list: { any }, count: number): { any }
	local copy = table.clone(list)
	self:Shuffle(copy)
	local result = {}
	for i = 1, math.min(count, #copy) do
		result[i] = copy[i]
	end
	return result
end

-- Independent child stream. Lets subsystems draw numbers without disturbing
-- each other's sequences, so adding a feature doesn't change existing layouts.
function Rng:Fork(salt: any)
	return Rng.new((self.Seed + Rng.hash(salt)) % MODULUS)
end

return Rng
