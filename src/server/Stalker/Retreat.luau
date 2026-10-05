-- Backing away, smartly (docs/plans/mansion-generation.md, M3; owner
-- 2026-10-04: "when the guest retreats he commonly backs up into a wall or
-- phase through the wall, I want him to feel smart and aware").
--
-- Logic/RetreatPlan picks where to go: a doorway, a stair or a gallery joint
-- within his back-away budget that leaves him furthest from everyone, that he
-- reaches before they could, that isn't a dead end and whose way out doesn't
-- pass anyone. He walks it backwards, still facing whoever drove him off,
-- round furniture and through doorways (Stalker/Walker), and re-plans when
-- someone closes in, someone else turns up, a wall comes up behind him or he
-- gets there. With nowhere better than where he stands he is cornered: he
-- stops and holds your stare instead of grinding into a wall.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local GuestPose = require(Shared.Logic.GuestPose)
local RetreatPlan = require(Shared.Logic.RetreatPlan)

local G = Config.Guest
local Poses = GuestPose.Poses

local REPLAN_SECONDS = 1.5
local CLOSING_STUDS = 4 -- someone this much nearer than at the last plan: plan again

local Retreat = {}
Retreat.__index = Retreat

function Retreat.new(service)
	return setmetatable({ service = service, plan = nil, plannedAt = 0, distances = {} }, Retreat)
end

-- A new retreat: forget the last one.
function Retreat:Reset()
	self.plan = nil
	self.plannedAt = 0
	self.distances = {}
end

function Retreat:Cornered(): boolean
	return self.plan ~= nil and self.plan.cornered == true
end

-- One tick: face `face` (or whoever is nearest) and back away. `stand`
-- replaces the players with fixed positions (F2 navtest retreat).
function Retreat:Step(face: Player?, stand: { Vector3 }?)
	local service = self.service
	local body = service.bodyCtl
	local ps = service.services.PlayerStateService
	local worldService = service.services.WorldService
	local here = body.root.Position
	if stand then
		body:FacePoint(stand[1])
	else
		local who = (face and face.Parent) and face or service:_nearestPlayer(here)
		if who then
			body:FacePlayer(who)
			body:SetGaze(who)
		end
	end
	local now = os.clock()
	local players = {}
	local closing = false
	local function consider(key, pos: Vector3)
		table.insert(players, pos)
		local d = worldService:Separation(pos, here)
		local before = self.distances[key]
		if before == nil or d < before - CLOSING_STUDS then
			closing = true
		end
	end
	if stand then
		for i, pos in stand do
			consider(i, pos)
		end
	else
		for _, player in ps:LivingPlayers() do
			local pos = ps:Position(player)
			if pos then
				consider(player, pos)
			end
		end
	end
	local due = not self.plan
		or now - self.plannedAt > REPLAN_SECONDS
		or closing
		or body.backBlockedAt > self.plannedAt
		or (not self.plan.cornered and body:Arrived())
	if due then
		self:_plan(players, here, now)
		self.distances = {}
		if stand then
			for i, pos in stand do
				self.distances[i] = worldService:Separation(pos, here)
			end
		else
			for _, player in ps:LivingPlayers() do
				local pos = ps:Position(player)
				if pos then
					self.distances[player] = worldService:Separation(pos, here)
				end
			end
		end
	end
	if self.plan and not self.plan.cornered then
		body:SetPose(Poses.BackAway)
		body:Go(self.plan.goal, G.BackAwaySpeed)
	else
		-- Nowhere better: he stops and stares.
		body:Hold()
		body:SetPose(Poses.Hold)
	end
end

function Retreat:_plan(players: { Vector3 }, here: Vector3, now: number)
	local service = self.service
	local worldService = service.services.WorldService
	local nav = worldService.nav
	self.plannedAt = now
	local feet = here - Vector3.new(0, service.body.groundOffset, 0)
	if not nav or #players == 0 then
		self.plan = { cornered = true }
		return
	end
	if self.doorwaysFor ~= nav then
		self.doorways, self.doorwaysFor = RetreatPlan.doorways(nav), nav
	end
	local dist, parent = worldService:NavDistances(feet)
	local me = { point = worldService.ToLayout(feet), room = worldService:RoomAt(feet), dist = dist, parent = parent }
	local them = {}
	for _, pos in players do
		table.insert(them, {
			point = worldService.ToLayout(pos),
			room = worldService:RoomAt(pos),
			dist = (worldService:NavDistances(pos)),
		})
	end
	local plan = RetreatPlan.choose(nav, me, them, {
		budget = G.BackAwaySpeed * G.BackAwayMaxSeconds,
		doorways = self.doorways,
		keep = self.plan and self.plan.node,
	})
	if not plan or plan.cornered then
		self.plan = { cornered = true }
		return
	end
	self.plan = { goal = worldService.FromLayout(nav.nodes[plan.node]), node = plan.node, cornered = false }
end

return Retreat
