-- Owns the generated house: builds it from a layout, tears it down, and
-- answers spatial questions (which room is this, where is the doorway, is
-- this spot lit) for every other service.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Graph = require(Shared.Logic.Graph)
local Rooms = require(Shared.Data.Rooms)
local Net = require(Shared.Net)
local Signal = require(Shared.Lib.Signal)

local LevelBuilder = require(script.Parent.Parent.World.LevelBuilder)

local CELL = Config.Level.CellSize

local WorldService = {
	World = nil,
	Built = Signal.new(),
	Cleared = Signal.new(),
}

function WorldService:Init()
	self.folder = nil
	-- Collision groups (doc section 6: players pass through each other, so
	-- nobody can body-block a doorway).
	local PhysicsService = game:GetService("PhysicsService")
	local Groups = require(Shared.Constants).CollisionGroups
	for _, name in Groups do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(Groups.Players, Groups.Players, false)
	PhysicsService:CollisionGroupSetCollidable(Groups.Players, Groups.Stalker, false)
	PhysicsService:CollisionGroupSetCollidable(Groups.Players, Groups.Echo, false)
	PhysicsService:CollisionGroupSetCollidable(Groups.Echo, Groups.Echo, false)
	PhysicsService:CollisionGroupSetCollidable(Groups.Echo, Groups.Stalker, false)
	PhysicsService:CollisionGroupSetCollidable(Groups.Echo, Groups.Door, false)
	-- The stalker handles doors in code (it pauses to open them), so it never
	-- gets physically stuck on one.
	PhysicsService:CollisionGroupSetCollidable(Groups.Stalker, Groups.Door, false)
	PhysicsService:CollisionGroupSetCollidable(Groups.Phantom, "Default", false)
end

-- Phantom Architecture's stalker twist: it walks through solid seams.
function WorldService:SetStalkerUsesSeams(enabled: boolean)
	local PhysicsService = game:GetService("PhysicsService")
	local Groups = require(Shared.Constants).CollisionGroups
	PhysicsService:CollisionGroupSetCollidable(Groups.Stalker, Groups.Seam, not enabled)
	self.stalkerUsesSeams = enabled
end

function WorldService:Build(layout, rng)
	self:Clear()
	local started = os.clock()
	local folder = Instance.new("Folder")
	folder.Name = "ConsensusLevel"
	self.folder = folder
	-- Build the whole house unparented and parent it once: one replication
	-- burst instead of thousands of incremental ones.
	self.World = LevelBuilder.build(layout, Rooms.ById, folder, rng)
	folder.Parent = Workspace
	self.lastBuildSeconds = os.clock() - started
	print(
		string.format(
			"[Consensus] built %d rooms (seed %s, attempt %s) in %.2fs",
			#layout.rooms,
			tostring(layout.seed),
			tostring(layout.attempts),
			self.lastBuildSeconds
		)
	)
	local ids = {}
	for _, room in layout.rooms do
		table.insert(ids, room.id)
	end
	self.adjacency = Graph.adjacency(ids, layout.edges)
	self.Built:Fire(self.World)
	self:BroadcastLayout()
	return self.World
end

function WorldService:Clear()
	if self.folder then
		self.folder:Destroy()
		self.folder = nil
	end
	if self.World then
		self.World = nil
		self.adjacency = nil
		self.Cleared:Fire()
	end
end

-- Minimal map data for clients: rooms, names and roles. Doorways are left
-- out on purpose, so the map never settles an argument about a phantom door.
function WorldService:LayoutSnapshot()
	local world = self.World
	if not world then
		return nil
	end
	local rooms = {}
	for id, room in world.rooms do
		table.insert(rooms, {
			id = id,
			gx = room.gx,
			gz = room.gz,
			name = room.name,
			role = room.role,
			lantern = room.lantern,
			reverb = room.template.reverb,
			mood = room.mood,
		})
	end
	table.sort(rooms, function(a, b)
		return a.id < b.id
	end)
	local o = Config.Level.Origin
	return { rooms = rooms, cell = CELL, origin = { o.x, o.y, o.z }, seed = world.layout.seed }
end

function WorldService:BroadcastLayout(player: Player?)
	local snapshot = self:LayoutSnapshot()
	if not snapshot then
		return
	end
	if player then
		Net.get("Layout"):FireClient(player, snapshot)
	else
		Net.get("Layout"):FireAllClients(snapshot)
	end
end

-- Queries ------------------------------------------------------------------

function WorldService:RoomAt(position: Vector3): number?
	local world = self.World
	if not world then
		return nil
	end
	local o = Config.Level.Origin
	local gx = math.floor((position.X - o.x) / CELL + 0.5)
	local gz = math.floor((position.Z - o.z) / CELL + 0.5)
	if position.Y < o.y - 20 or position.Y > o.y + 40 then
		return nil
	end
	return world.layout.cells[gx .. "," .. gz]
end

function WorldService:Room(id: number)
	return self.World and self.World.rooms[id]
end

function WorldService:Neighbours(id: number): { number }
	return self.adjacency and self.adjacency[id] or {}
end

function WorldService:Path(a: number, b: number): { number }?
	if not self.adjacency then
		return nil
	end
	return Graph.path(self.adjacency, a, b)
end

function WorldService:Distances(from: number)
	return Graph.bfs(self.adjacency, from)
end

function WorldService:SeamBetween(a: number, b: number)
	if a > b then
		a, b = b, a
	end
	return self.World and self.World.seams["seam:" .. a .. "-" .. b]
end

-- Centre of the doorway between two neighbouring rooms, at floor level.
function WorldService:DoorwayPoint(a: number, b: number): Vector3
	local ra, rb = self.World.rooms[a], self.World.rooms[b]
	return (ra.center + rb.center) / 2
end

-- A point just inside room `a`, in front of its doorway to `b`.
function WorldService:ApproachPoint(a: number, b: number, inset: number?): Vector3
	local ra, rb = self.World.rooms[a], self.World.rooms[b]
	local dir = (rb.center - ra.center).Unit
	return ra.center + dir * (CELL / 2 - (inset or 3))
end

function WorldService:IsLit(position: Vector3): boolean
	local id = self:RoomAt(position)
	if not id then
		return false
	end
	local room = self.World.rooms[id]
	if room.shrine and room.shrine.lit then
		return true
	end
	return room.lightOn and room.light ~= nil and room.light.Enabled
end

function WorldService:SetRoomLight(id: number, on: boolean)
	local room = self:Room(id)
	if not room or not room.light then
		return
	end
	room.lightOn = on
	room.light.Enabled = on
	if room.bounce then
		room.bounce.Enabled = on
	end
	room.lightPart:SetAttribute("Lit", on)
end

function WorldService:IsLanternRoom(id: number?): boolean
	if not id then
		return false
	end
	local room = self:Room(id)
	return room ~= nil and room.shrine ~= nil and room.shrine.lit
end

function WorldService:TakeWallSlot(roomId: number, rng)
	local room = self:Room(roomId)
	if not room then
		return nil
	end
	local free = {}
	for _, slot in room.wallSlots do
		if not slot.used then
			table.insert(free, slot)
		end
	end
	local slot = rng:Pick(free)
	if slot then
		slot.used = true
	end
	return slot
end

function WorldService:TakeFloorSlot(roomId: number, rng)
	local room = self:Room(roomId)
	if not room then
		return nil
	end
	local free = {}
	for _, slot in room.floorSlots do
		if not slot.used then
			table.insert(free, slot)
		end
	end
	local slot = rng:Pick(free)
	if slot then
		slot.used = true
	end
	return slot
end

function WorldService:RoomIds(): { number }
	local ids = {}
	if self.World then
		for id in self.World.rooms do
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

-- Random walkable point inside a room's clear centre area.
function WorldService:RandomPointIn(roomId: number, rng): Vector3
	local room = self:Room(roomId)
	return room.center + Vector3.new(rng:NextNumber(-9, 9), 0, rng:NextNumber(-9, 9))
end

return WorldService
