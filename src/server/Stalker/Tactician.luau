-- The Tactician (doc section 5): scores the tactic menu against the squad
-- profile, picks among the top three, and turns the pick into a plan of
-- simple actions for the body to execute. Every decision is logged with
-- the profile values behind it, for the debug overlay and the Dossier.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Tactics = require(Shared.Data.Tactics)
local UtilityAI = require(Shared.Logic.UtilityAI)

local S = Config.Stalker
local G = Config.Guest

local Tactician = {}
Tactician.__index = Tactician

function Tactician.new(services, perception, archetype, rng)
	return setmetatable({
		services = services,
		perception = perception,
		archetype = archetype,
		rng = rng,
		lastUsed = {},
		log = {},
		counts = {},
	}, Tactician)
end

function Tactician:Reset()
	self.lastUsed = {}
	self.log = {}
	self.counts = {}
end

local function roomCenter(world, id)
	return world.rooms[id].center
end

-- Hiding spots near a position, weighted by learned preference and heat.
function Tactician:_spotsNear(position: Vector3, count: number)
	local services = self.services
	local worldService = services.WorldService
	local world = worldService.World
	local roomId = worldService:RoomAt(position)
	if not roomId then
		return {}
	end
	local nearby = { [roomId] = true }
	for _, n in worldService:Neighbours(roomId) do
		nearby[n] = true
	end
	local favourite = services.SquadProfileService:FavouriteHideCategory()
	local candidates = {}
	for _, spot in world.hidingSpots do
		if nearby[spot.roomId] then
			table.insert(candidates, spot)
		end
	end
	table.sort(candidates, function(a, b)
		return a.id < b.id
	end)
	local chosen = {}
	for _ = 1, count do
		if #candidates == 0 then
			break
		end
		local pick = self.rng:WeightedPick(candidates, function(spot)
			local w = 1 + spot.heat * 0.8
			if spot.category == favourite then
				w *= 2.5
			end
			if spot.roomId == roomId then
				w *= 1.5
			end
			return w
		end)
		table.insert(chosen, pick)
		table.remove(candidates, table.find(candidates, pick))
	end
	return chosen
end

local function nearestClosedDoor(services, position: Vector3, maxDistance: number)
	local best, bestDistance = nil, maxDistance
	for _, door in services.WorldService.World.doors do
		-- On the same floor: a door under your feet isn't near you.
		if not door.open and math.abs(door.position.Y - position.Y) < 6 then
			local d = (door.position - position).Magnitude
			if d < bestDistance then
				best, bestDistance = door, d
			end
		end
	end
	return best
end

function Tactician:_feasibility(ctx)
	local f = {}
	local hasMemory = ctx.memory ~= nil
	f.SearchLastKnown = hasMemory and 1 or 0
	f.SweepRooms = 0.6
	f.CheckHidingSpots = hasMemory and 1 or 0.5
	f.FakeLeaveReturn = hasMemory and 0.8 or 0
	f.CutOffLoop = (ctx.loop and hasMemory) and 1 or 0
	f.TargetStraggler = (ctx.squadSize >= 2 and ctx.straggler) and 1 or 0
	f.FlankBlindSpot = (hasMemory and ctx.memory.facing) and 1 or 0
	f.KillLights = (hasMemory and ctx.memoryRoomLit) and 0.8 or 0
	f.FakePing = (ctx.squadSize >= 2 and hasMemory) and 0.8 or 0
	f.Ambush = hasMemory and 0.8 or 0
	f.ListenStill = 0.6
	f.MimicKnock = (hasMemory and ctx.doorNearMemory) and 0.9 or 0
	-- A noise nobody made, newer than anything he knows: worth a look.
	local lure = ctx.lure
	f.Investigate = (lure and (not hasMemory or lure.t > ctx.memory.t)) and ctx.lureTrust or 0
	-- The final hunt during a ritual leans on flanking: the squad is busy.
	if ctx.final then
		f.FlankBlindSpot = hasMemory and 1.4 or 0
		f.FakeLeaveReturn = 0
	end
	return f
end

-- Build the context the tactics need, from memory and public state only.
function Tactician:Context(final: boolean)
	local services = self.services
	local worldService = services.WorldService
	local world = worldService.World
	local player, memory = self.perception:BestMemory()
	local ctx = {
		final = final,
		player = player,
		memory = memory,
		squadSize = #services.PlayerStateService:LivingPlayers(),
		signals = services.SquadProfileService:Signals(),
		loop = services.SquadProfileService:FavouriteLoop(),
	}
	if memory then
		local roomId = worldService:RoomAt(memory.position)
		ctx.memoryRoom = roomId
		ctx.memoryRoomLit = roomId ~= nil and world.rooms[roomId].lightOn
		ctx.doorNearMemory = nearestClosedDoor(services, memory.position, 30)
	end
	-- Straggler: the remembered Witness farthest from the others' memories.
	local mem = self.perception.memory
	local bestGap, straggler = 25, nil
	for p, m in mem do
		if p.Parent and self.perception:Confidence(p) > 0.1 then
			local nearest = math.huge
			for q, n in mem do
				if q ~= p and q.Parent then
					nearest = math.min(nearest, (n.position - m.position).Magnitude)
				end
			end
			if nearest ~= math.huge and nearest > bestGap then
				bestGap, straggler = nearest, p
			end
		end
	end
	ctx.straggler = straggler
	ctx.lure = self.perception:FreshLure(G.LureFreshSeconds)
	ctx.lureTrust = self.perception:LureTrust(G.LureWaryWindow, G.LureWaryFactor)
	return ctx
end

-- Choose a tactic and produce its plan: a list of actions.
function Tactician:Decide(final: boolean)
	local ctx = self:Context(final)
	local feasibility = self:_feasibility(ctx)
	local now = os.clock()
	local id, scored = UtilityAI.choose(
		Tactics.List,
		ctx.signals,
		feasibility,
		self.lastUsed,
		now,
		self.rng,
		self.archetype.tacticWeights
	)
	if not id then
		id = "SweepRooms"
	end
	self.lastUsed[id] = now
	self.counts[id] = (self.counts[id] or 0) + 1
	local top = {}
	for i = 1, math.min(3, #scored) do
		table.insert(top, string.format("%s %.2f", scored[i].id, scored[i].score))
	end
	local entry = {
		t = now,
		tactic = id,
		top = top,
		signals = ctx.signals,
		target = ctx.player and ctx.player.DisplayName or nil,
	}
	table.insert(self.log, entry)
	if #self.log > 40 then
		table.remove(self.log, 1)
	end
	if Config.Debug.LogTactics then
		print(string.format("[Stalker] %s (top: %s)", id, table.concat(top, ", ")))
	end
	return id, self:_plan(id, ctx), ctx
end

function Tactician:_plan(id: string, ctx)
	local services = self.services
	local worldService = services.WorldService
	local world = worldService.World
	local run = S.SprintSpeedRatio * Config.Player.SprintSpeed
	local walk = S.WalkSpeed
	local stalk = S.StalkSpeed
	local here = services.StalkerService:GetPosition() or Vector3.zero
	local plan = {}
	local function moveTo(pos, speed)
		table.insert(plan, { type = "goto", position = pos, speed = speed })
	end
	local function wait(seconds, listen)
		table.insert(plan, { type = "wait", seconds = seconds, listen = listen })
	end
	local memoryPos = ctx.memory and ctx.memory.position

	if id == "SearchLastKnown" and memoryPos then
		moveTo(memoryPos, run)
		wait(S.SearchLookSeconds)
		for _, spot in self:_spotsNear(memoryPos, 1) do
			moveTo(spot.frontPosition, walk)
			table.insert(plan, { type = "inspect", spot = spot })
		end
	elseif id == "SweepRooms" then
		local rooms = services.SquadProfileService:RoomsByUse()
		local current = worldService:RoomAt(here)
		local count = 0
		for _, roomId in rooms do
			if roomId ~= current and world.rooms[roomId] then
				moveTo(roomCenter(world, roomId), run)
				wait(1)
				count += 1
				if count >= 2 then
					break
				end
			end
		end
		if count == 0 then
			local ids = worldService:RoomIds()
			moveTo(roomCenter(world, self.rng:Pick(ids)), walk)
		end
	elseif id == "CheckHidingSpots" then
		for _, spot in self:_spotsNear(memoryPos or here, 2) do
			moveTo(spot.frontPosition, run)
			table.insert(plan, { type = "inspect", spot = spot })
		end
	elseif id == "FakeLeaveReturn" and memoryPos then
		local roomId = worldService:RoomAt(memoryPos)
		local farthest, best = nil, -1
		if roomId then
			local distances = worldService:Distances(roomId)
			for rid, d in distances do
				if d > best and d <= 3 then
					farthest, best = rid, d
				end
			end
		end
		if farthest then
			moveTo(roomCenter(world, farthest), walk)
			table.insert(plan, { type = "noise", radius = 0, sound = "Footsteps" })
		end
		wait(6)
		moveTo(memoryPos, stalk)
		for _, spot in self:_spotsNear(memoryPos, 2) do
			moveTo(spot.frontPosition, stalk)
			table.insert(plan, { type = "inspect", spot = spot })
		end
	elseif id == "CutOffLoop" and ctx.loop and memoryPos then
		local targetRoom = worldService:RoomAt(memoryPos)
		local index = table.find(ctx.loop, targetRoom) or 1
		local opposite = ctx.loop[((index - 1 + math.floor(#ctx.loop / 2)) % #ctx.loop) + 1]
		moveTo(roomCenter(world, opposite), run)
		wait(5, true)
	elseif id == "TargetStraggler" and ctx.straggler then
		local m = self.perception.memory[ctx.straggler]
		moveTo(m.position, run)
		wait(1.5)
	elseif id == "FlankBlindSpot" and memoryPos then
		local facing = ctx.memory.facing or Vector3.new(0, 0, -1)
		local behind = memoryPos - Vector3.new(facing.X, 0, facing.Z).Unit * 10
		local behindRoom = worldService:RoomAt(behind)
		-- Somewhere he can stand: not inside furniture, not over the hall.
		if behindRoom and services.StalkerService.bodyCtl:Fits(behind) then
			moveTo(behind, stalk)
		end
		moveTo(memoryPos, run)
	elseif id == "KillLights" and ctx.memoryRoom then
		moveTo(
			worldService:ApproachPoint(ctx.memoryRoom, worldService:Neighbours(ctx.memoryRoom)[1] or ctx.memoryRoom, 6),
			walk
		)
		local rooms = { ctx.memoryRoom }
		for _, n in worldService:Neighbours(ctx.memoryRoom) do
			table.insert(rooms, n)
		end
		table.insert(plan, { type = "lights", rooms = rooms })
		moveTo(memoryPos, stalk)
		wait(2)
	elseif id == "FakePing" and memoryPos then
		local roomId = worldService:RoomAt(memoryPos)
		local neighbour = roomId and self.rng:Pick(worldService:Neighbours(roomId))
		if neighbour then
			local spot = roomCenter(world, neighbour)
			table.insert(plan, { type = "fakePing", position = spot + Vector3.new(0, 2, 0) })
			moveTo(worldService:ApproachPoint(neighbour, roomId, 4), stalk)
			wait(8, true)
		end
	elseif id == "Ambush" and memoryPos then
		local roomId = worldService:RoomAt(memoryPos)
		local neighbours = roomId and worldService:Neighbours(roomId) or {}
		local neighbour = self.rng:Pick(neighbours)
		if neighbour then
			moveTo(worldService:ApproachPoint(neighbour, roomId, 4), walk)
			wait(8, true)
		end
	elseif id == "ListenStill" then
		wait(4, true)
	elseif id == "Investigate" and ctx.lure then
		self.perception:FollowLure(ctx.lure, G.LureWaryWindow)
		local spot = ctx.lure.position
		moveTo(Vector3.new(spot.X, worldService:FloorBase(spot.Y), spot.Z), run)
		wait(self.rng:NextNumber(G.LureLookSeconds[1], G.LureLookSeconds[2]), true)
	elseif id == "MimicKnock" and ctx.doorNearMemory then
		local door = ctx.doorNearMemory
		local roomId = worldService:RoomAt(memoryPos)
		local farSide = door.a == roomId and door.b or door.a
		moveTo(worldService:ApproachPoint(farSide, farSide == door.a and door.b or door.a, 2.5), stalk)
		table.insert(plan, { type = "knock", door = door })
		wait(8, true)
	end
	if #plan == 0 then
		wait(2, true)
	end
	return plan
end

function Tactician:Summary()
	local list = {}
	for id, count in self.counts do
		table.insert(
			list,
			{ tactic = id, count = count, description = Tactics.ById[id] and Tactics.ById[id].description or id }
		)
	end
	table.sort(list, function(a, b)
		return a.count > b.count
	end)
	return list
end

return Tactician
