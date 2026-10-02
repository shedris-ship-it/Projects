-- The stalker's model of the squad (doc section 5, "Adaptation: the squad
-- profile"). Counters decay exponentially so recent behaviour matters most.
-- Signals() turns them into 0..1 values the Tactician multiplies into its
-- tactic weights.

local SquadProfile = {}
SquadProfile.__index = SquadProfile

function SquadProfile.new(halfLife: number)
	return setmetatable({
		halfLife = halfLife,
		counters = {}, -- key -> { value, t }
		categories = {}, -- group -> key -> { value, t }
		averages = {}, -- key -> exponential moving average
		totals = {}, -- undecayed lifetime counts for the Dossier
	}, SquadProfile)
end

function SquadProfile:_decayed(entry, now: number): number
	if not entry then
		return 0
	end
	return entry.value * 0.5 ^ ((now - entry.t) / self.halfLife)
end

function SquadProfile:Add(key: string, amount: number, now: number)
	local value = self:_decayed(self.counters[key], now) + amount
	self.counters[key] = { value = value, t = now }
	self.totals[key] = (self.totals[key] or 0) + amount
end

function SquadProfile:Get(key: string, now: number): number
	return self:_decayed(self.counters[key], now)
end

function SquadProfile:AddTo(group: string, key: string, amount: number, now: number)
	self.categories[group] = self.categories[group] or {}
	local entries = self.categories[group]
	entries[key] = { value = self:_decayed(entries[key], now) + amount, t = now }
	local totalsKey = group .. ":" .. key
	self.totals[totalsKey] = (self.totals[totalsKey] or 0) + amount
end

-- Keys of a group sorted by decayed weight, heaviest first.
function SquadProfile:Ranked(group: string, now: number): { { key: string, weight: number } }
	local result = {}
	for key, entry in self.categories[group] or {} do
		table.insert(result, { key = key, weight = self:_decayed(entry, now) })
	end
	table.sort(result, function(a, b)
		if a.weight ~= b.weight then
			return a.weight > b.weight
		end
		return a.key < b.key
	end)
	return result
end

function SquadProfile:Weight(group: string, key: string, now: number): number
	local entries = self.categories[group]
	return entries and self:_decayed(entries[key], now) or 0
end

-- Exponential moving average with a time constant (seconds).
function SquadProfile:Sample(key: string, sample: number, dt: number, timeConstant: number)
	local current = self.averages[key]
	if current == nil then
		self.averages[key] = sample
		return
	end
	local alpha = 1 - math.exp(-dt / timeConstant)
	self.averages[key] = current + (sample - current) * alpha
end

function SquadProfile:Average(key: string, default: number?): number
	return self.averages[key] or default or 0
end

local function unit(value: number, scale: number): number
	return math.clamp(value / scale, 0, 1)
end

-- Normalised 0..1 habit signals, named to match Data/Tactics.
function SquadProfile:Signals(now: number)
	local topLoop = self:Ranked("loop", now)[1]
	local topRoute = self:Ranked("route", now)[1]
	return {
		hideHabit = unit(self:Get("hides", now), 4),
		loopHabit = unit(topLoop and topLoop.weight or 0, 4),
		routeHabit = unit(topRoute and topRoute.weight or 0, 8),
		-- High when the squad sticks together (small average spread).
		cohesion = 1 - unit(self:Average("spread", 30), 40),
		gazeHabit = unit(self:Get("gazeSeconds", now), 20),
		flashlightHabit = math.clamp(self:Average("flashlight", 0), 0, 1),
		anchorHabit = unit(self:Get("anchors", now), 5),
		pingHabit = unit(self:Get("pings", now), 8),
		stationary = unit(self:Get("stationarySeconds", now), 60),
	}
end

return SquadProfile
