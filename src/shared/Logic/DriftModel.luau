-- Drift, the 0-100 pressure clock (doc section 2). Pure: the server's
-- DriftService owns one and feeds it time and events.

local DriftModel = {}
DriftModel.__index = DriftModel

function DriftModel.new(config, multiplier: number?)
	return setmetatable({
		config = config,
		multiplier = multiplier or 1,
		value = 0,
		anchorCredits = {}, -- timestamps of recent anchor rewards
		sources = {}, -- name -> net change, for the debug overlay
	}, DriftModel)
end

function DriftModel:_add(source: string, delta: number): number
	local before = self.value
	self.value = math.clamp(self.value + delta, 0, self.config.Max)
	local applied = self.value - before
	self.sources[source] = (self.sources[source] or 0) + applied
	return applied
end

-- Advance time. isolatedCount = players who have been >25 studs from every
-- teammate for 20+ seconds.
function DriftModel:Tick(dt: number, isolatedCount: number?): number
	local perMinute = self.config.BaselinePerMinute * self.multiplier
	local applied = self:_add("Baseline", perMinute * dt / 60)
	if isolatedCount and isolatedCount > 0 then
		applied += self:_add("Isolation", self.config.IsolationPerMinute * isolatedCount * dt / 60)
	end
	return applied
end

-- Apply a named event from config.Events. Anchor rewards are capped at
-- AnchorCreditsPerMinute so talking is rewarded but spam isn't.
function DriftModel:Apply(eventName: string, now: number): number
	local delta = self.config.Events[eventName]
	assert(delta ~= nil, "Unknown drift event " .. tostring(eventName))
	if eventName == "Anchor" then
		local recent = {}
		for _, t in self.anchorCredits do
			if now - t < 60 then
				table.insert(recent, t)
			end
		end
		self.anchorCredits = recent
		if #recent >= self.config.AnchorCreditsPerMinute then
			return 0
		end
		table.insert(self.anchorCredits, now)
	end
	if delta > 0 then
		delta *= self.multiplier
	end
	return self:_add(eventName, delta)
end

function DriftModel:Set(value: number)
	self:_add("Debug", value - self.value)
end

function DriftModel:IsCollapsed(): boolean
	return self.value >= self.config.Max
end

-- Name and index of the state band for a Drift value.
function DriftModel.stateFor(config, value: number): (string, number)
	local name, index = config.States[1].name, 1
	for i, state in config.States do
		if value >= state.min then
			name, index = state.name, i
		end
	end
	return name, index
end

function DriftModel:State(): (string, number)
	return DriftModel.stateFor(self.config, self.value)
end

-- Minutes until Collapse at the baseline rate from the current value.
function DriftModel:MinutesToCollapse(): number
	return (self.config.Max - self.value) / (self.config.BaselinePerMinute * self.multiplier)
end

return DriftModel
