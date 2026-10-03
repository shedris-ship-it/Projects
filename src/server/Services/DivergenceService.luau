-- Divergence (doc sections 1 and 7): the server sends each Witness a list of
-- perception rules, never world state. Clients apply their own rules to their
-- own copy of the house. Anchoring (WitnessService) collapses a target's rules
-- for everyone by broadcasting PerceptionAnchor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Tells = require(Shared.Data.Tells)
local Net = require(Shared.Net)
local PerceptionPlanner = require(Shared.Logic.PerceptionPlanner)

local DivergenceService = {}

function DivergenceService:Init(services)
	self.services = services
	self.Witness = services.WitnessService
	self.World = services.WorldService
	self.profiles = {}
end

function DivergenceService:Start()
	self.World.Cleared:Connect(function()
		self.profiles = {}
		Net.get("PerceptionProfile"):FireAllClients({ rules = {} })
	end)
end

local function toTable(v: Vector3)
	return { x = v.X, y = v.Y, z = v.Z }
end
DivergenceService.toTable = toTable

local function toVector(t): Vector3
	return Vector3.new(t.x, t.y, t.z)
end
DivergenceService.toVector = toVector

-- sites: AnomalyService tell sites. Returns the planner result.
function DivergenceService:Plan(players: { Player }, sites, rng)
	local world = self.World.World
	local ids, names = {}, {}
	for _, player in players do
		local id = tostring(player.UserId)
		table.insert(ids, id)
		names[id] = player.DisplayName
	end
	table.sort(ids)

	local plannerSites = {}
	local usedSeams = {}
	for _, site in sites do
		table.insert(plannerSites, {
			id = site.id,
			tellId = site.tellId,
			position = toTable(site.position),
			normal = site.cframe and toTable(site.cframe.LookVector) or nil,
			seamId = site.seamId,
			connected = site.connected,
			roomId = site.roomId,
		})
		if site.seamId then
			usedSeams[site.seamId] = true
		end
	end
	for _, seamId in self.reservedSeams or {} do
		usedSeams[seamId] = true
	end

	-- Real furniture safe to recolour, and free floor spots for harmless
	-- phantoms, never in the start room's centre where everyone spawns.
	local calibrationProps, floorSpots = {}, {}
	for _, prop in world.props do
		local kind = prop.kind
		if kind ~= "Rug" and kind ~= "Chair" and prop.model.Parent then
			local pivot = prop.model:GetPivot()
			table.insert(calibrationProps, { id = prop.id, position = toTable(pivot.Position + Vector3.new(0, 2, 0)) })
		end
	end
	table.sort(calibrationProps, function(a, b)
		return a.id < b.id
	end)
	for _, roomId in self.World:RoomIds() do
		local room = world.rooms[roomId]
		for _, slot in room.floorSlots do
			if not slot.used then
				table.insert(floorSpots, { position = toTable(slot.position), roomId = roomId })
			end
		end
	end
	local seams = {}
	for id, seam in world.seams do
		if not usedSeams[id] then
			table.insert(seams, { id = id, connected = seam.connected })
		end
	end
	table.sort(seams, function(a, b)
		return a.id < b.id
	end)

	local result = PerceptionPlanner.plan({
		players = ids,
		names = names,
		sites = plannerSites,
		calibrationProps = calibrationProps,
		floorSpots = floorSpots,
		seams = seams,
		tells = Tells,
		config = Config.Divergence,
		rng = rng,
	})
	if not PerceptionPlanner.everyoneDisprovable(result, ids) then
		warn("[Consensus] perception plan has a Witness with nothing to disprove")
	end

	-- Register every divergent target so Witnessing it can anchor it.
	for target, info in result.targets do
		self.Witness:Register(target, {
			kind = "divergence",
			position = toVector(info.position) + Vector3.new(0, 2, 0),
			label = info.label,
			divergent = true,
		})
	end
	for _, rules in result.profiles do
		for _, rule in rules do
			local entry = self.Witness:Entry(rule.target)
			if entry then
				entry.divergent = true
			elseif rule.kind == "Recolor" then
				for _, prop in calibrationProps do
					if prop.id == rule.target then
						self.Witness:Register(rule.target, {
							kind = "divergence",
							position = toVector(prop.position),
							label = "Furniture",
							divergent = true,
						})
					end
				end
			elseif rule.kind == "PhantomSound" and rule.params.ambient then
				self.Witness:Register(rule.target, {
					kind = "divergence",
					position = toVector(rule.params.position) + Vector3.new(0, 2, 0),
					label = "Where the sound was",
					divergent = true,
					radius = 8,
				})
			end
		end
	end

	self.profiles = result.profiles
	for _, player in players do
		self:SendProfile(player)
	end
	return result
end

-- Seams that look different to someone (a doorway for one Witness, a wall
-- for another). The Guest doesn't peek round these: a head poking out of
-- what you see as a wall would give the divergence away.
function DivergenceService:DivergentSeams(): { [string]: boolean }
	local set = {}
	for _, rules in self.profiles or {} do
		for _, rule in rules do
			if rule.kind == "SeamFlip" then
				set[rule.target] = true
			end
		end
	end
	for _, id in self.reservedSeams or {} do
		set[id] = true
	end
	return set
end

-- Seams the anomaly needs for itself (e.g. Phantom Architecture's Sources).
function DivergenceService:ReserveSeams(seamIds: { string })
	self.reservedSeams = seamIds
end

function DivergenceService:SendProfile(player: Player)
	local rules = self.profiles[tostring(player.UserId)] or {}
	Net.get("PerceptionProfile"):FireClient(player, { rules = rules })
end

-- Add rules mid-run (rituals use this for per-player flickers).
function DivergenceService:AddRules(player: Player, rules)
	local id = tostring(player.UserId)
	self.profiles[id] = self.profiles[id] or {}
	for _, rule in rules do
		table.insert(self.profiles[id], rule)
	end
	self:SendProfile(player)
end

function DivergenceService:RemoveRules(player: Player, predicate: (any) -> boolean)
	local id = tostring(player.UserId)
	local kept = {}
	for _, rule in self.profiles[id] or {} do
		if not predicate(rule) then
			table.insert(kept, rule)
		end
	end
	self.profiles[id] = kept
	self:SendProfile(player)
end

-- One-off local scare for a single Witness (a knock only they hear, a
-- figure only they see). Absent from server state by design.
function DivergenceService:Scare(player: Player, payload)
	Net.get("Scare"):FireClient(player, payload)
end

function DivergenceService:Reset()
	self.profiles = {}
	self.reservedSeams = nil
end

return DivergenceService
