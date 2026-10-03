-- Where the stalker thinks one player is: a probability per room (doc section 5,
-- "Memory": it searches by inference from habits, never by wallhack).
-- Pure maths over the room graph so it's testable; the server feeds it only what
-- the Guest saw or heard, plus a prior from the squad profile's room use.
--   observe: seen in a room, all the mass collapses there.
--   hear:    a noise; boosts that room and fades out over nearby rooms.
--   step:    mass drifts to neighbouring rooms and relaxes back to the prior.

local Graph = require(script.Parent.Graph)

local BeliefMap = {}
BeliefMap.__index = BeliefMap

local function normalize(mass, ids)
	local total = 0
	for _, id in ids do
		total += mass[id]
	end
	if total <= 0 then
		for _, id in ids do
			mass[id] = 1 / #ids
		end
		return
	end
	for _, id in ids do
		mass[id] /= total
	end
end

-- adj: room id -> neighbour list (Graph.adjacency). prior: room id -> weight.
function BeliefMap.new(adj: { [number]: { number } }, prior: { [number]: number }?)
	local ids = {}
	for id in adj do
		table.insert(ids, id)
	end
	table.sort(ids)
	local self = setmetatable({ adj = adj, ids = ids, mass = {}, prior = {} }, BeliefMap)
	self:SetPrior(prior)
	for _, id in ids do
		self.mass[id] = self.prior[id]
	end
	return self
end

-- Habit weights, such as SquadProfile room use. Missing rooms get a small floor
-- so he never rules a room out completely.
function BeliefMap:SetPrior(prior: { [number]: number }?)
	for _, id in self.ids do
		self.prior[id] = math.max(prior and prior[id] or 0, 0) + 0.05
	end
	normalize(self.prior, self.ids)
end

function BeliefMap:Observe(room: number)
	if self.mass[room] == nil then
		return
	end
	for _, id in self.ids do
		self.mass[id] = 0
	end
	self.mass[room] = 1
end

-- strength 0..1: how much of his belief this noise replaces. Mass spreads over
-- rooms within `spread` doors, halving each hop.
function BeliefMap:Hear(room: number, strength: number, spread: number?)
	if self.mass[room] == nil then
		return
	end
	local reach = spread or 1
	local dist = Graph.bfs(self.adj, room)
	local kernel, total = {}, 0
	for _, id in self.ids do
		local d = dist[id]
		local w = (d ~= nil and d <= reach) and 0.5 ^ d or 0
		kernel[id] = w
		total += w
	end
	local s = math.clamp(strength, 0, 1)
	for _, id in self.ids do
		self.mass[id] = self.mass[id] * (1 - s) + s * kernel[id] / total
	end
end

-- He looked in a room and she wasn't there: most of that room's mass goes
-- elsewhere (renormalised over the rest).
function BeliefMap:Clear(room: number, strength: number)
	if self.mass[room] == nil then
		return
	end
	self.mass[room] *= 1 - math.clamp(strength, 0, 1)
	normalize(self.mass, self.ids)
end

-- diffuse: fraction of mass per second that leaks to neighbours; relax: fraction
-- per second pulled back to the prior.
function BeliefMap:Step(dt: number, diffuse: number, relax: number)
	local leak = math.clamp(diffuse * dt, 0, 1)
	if leak > 0 then
		local nextMass = {}
		for _, id in self.ids do
			nextMass[id] = 0
		end
		for _, id in self.ids do
			local neighbours = self.adj[id]
			local m = self.mass[id]
			if #neighbours == 0 then
				nextMass[id] += m
			else
				nextMass[id] += m * (1 - leak)
				local share = m * leak / #neighbours
				for _, n in neighbours do
					nextMass[n] += share
				end
			end
		end
		self.mass = nextMass
	end
	local pull = math.clamp(relax * dt, 0, 1)
	if pull > 0 then
		for _, id in self.ids do
			self.mass[id] = self.mass[id] * (1 - pull) + self.prior[id] * pull
		end
	end
	normalize(self.mass, self.ids)
end

function BeliefMap:Get(room: number): number
	return self.mass[room] or 0
end

-- Most likely room (lowest id wins ties, so it's deterministic).
function BeliefMap:Best(): (number, number)
	local best, bestMass = self.ids[1], -1
	for _, id in self.ids do
		if self.mass[id] > bestMass + 1e-9 then
			best, bestMass = id, self.mass[id]
		end
	end
	return best, bestMass
end

-- The n likeliest rooms, most likely first.
function BeliefMap:Top(n: number): { { room: number, p: number } }
	local list = {}
	for _, id in self.ids do
		table.insert(list, { room = id, p = self.mass[id] })
	end
	table.sort(list, function(a, b)
		if math.abs(a.p - b.p) > 1e-9 then
			return a.p > b.p
		end
		return a.room < b.room
	end)
	while #list > n do
		table.remove(list)
	end
	return list
end

-- How sure he is: the top room's share of the belief (1 = certain).
function BeliefMap:Certainty(): number
	local _, mass = self:Best()
	return mass
end

-- A room drawn in proportion to the belief. rng needs NextNumber (Lib/Rng).
function BeliefMap:Sample(rng): number
	local roll = rng:NextNumber()
	local acc = 0
	for _, id in self.ids do
		acc += self.mass[id]
		if roll <= acc then
			return id
		end
	end
	return self.ids[#self.ids]
end

return BeliefMap
