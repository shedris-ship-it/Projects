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
local MansionBuilder = require(script.Parent.Parent.World.MansionBuilder)
local FloorPlan = require(Shared.Logic.FloorPlan)
local NavGraph = require(Shared.Logic.NavGraph)
local RoomRects = require(Shared.Logic.RoomRects)
local Storeys = require(Shared.Logic.Storeys)

local CELL = Config.Level.CellSize
local PITCH = Config.Mansion.FloorPitch
-- The storeys the house being played has (docs/plans/level-design.md
-- section 10.1): the cellar is -1, the attic 2.
local lowStorey, highStorey = 0, 1

local WorldService = {
	World = nil,
	Built = Signal.new(),
	Cleared = Signal.new(),
	-- (seamId, why): who may pass a seam changed (a lock, a barricade, a
	-- door turned to wall). Doors opening and shutting don't count: they only
	-- cost time, which routes read when they're made.
	PassageChanged = Signal.new(),
	passageVersion = 0,
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
	-- Physical props (docs/plans/gameplay-rework.md section 4.2). Small things
	-- resting or thrown (Prop) and carried (Held) never touch players or The
	-- Guest: a carried thing can't fling its holder or shove a friend, and a
	-- throw's hit on him is decided in code. Heavy furniture you push collides
	-- with everyone but Echoes.
	for _, group in { Groups.Prop, Groups.Held } do
		PhysicsService:CollisionGroupSetCollidable(group, Groups.Players, false)
		PhysicsService:CollisionGroupSetCollidable(group, Groups.Echo, false)
		PhysicsService:CollisionGroupSetCollidable(group, Groups.Stalker, false)
		PhysicsService:CollisionGroupSetCollidable(group, Groups.Phantom, false)
	end
	PhysicsService:CollisionGroupSetCollidable(Groups.Held, Groups.Held, false)
	PhysicsService:CollisionGroupSetCollidable(Groups.Heavy, Groups.Echo, false)
	PhysicsService:CollisionGroupSetCollidable(Groups.Heavy, Groups.Phantom, false)
end

function WorldService:Build(layout, rng)
	self:Clear()
	local started = os.clock()
	local folder = Instance.new("Folder")
	folder.Name = "ConsensusLevel"
	self.folder = folder
	-- Build the whole house unparented and parent it once: one replication
	-- burst instead of thousands of incremental ones.
	-- The old house (40x40 cells) or the mansion (docs/plans/mansion-generation.md).
	if layout.mode == "Mansion" then
		self.World = MansionBuilder.build(layout, Rooms.MansionById, folder, rng)
	else
		self.World = LevelBuilder.build(layout, Rooms.ById, folder, rng)
	end
	-- What the run's services add to the house (decor, items, notes, puzzle
	-- stations, the dinner, tools lying about) goes in here, apart from what
	-- the builder made, so tools/studio/partdump.luau (Gate A) can measure the
	-- builder alone.
	local content = Instance.new("Folder")
	content.Name = "RunContent"
	content.Parent = folder
	self.content = content
	folder.Parent = Workspace
	self.lastBuildSeconds = os.clock() - started
	print(
		string.format(
			"[Consensus] built %d rooms (%s, seed %s, attempt %s, layout hash %d) in %.2fs",
			#layout.rooms,
			layout.mode or "Cells",
			tostring(layout.seed),
			tostring(layout.attempts),
			FloorPlan.hash(layout),
			self.lastBuildSeconds
		)
	)
	local ids = {}
	for _, room in layout.rooms do
		table.insert(ids, room.id)
	end
	self.adjacency = Graph.adjacency(ids, layout.edges)
	-- The graph The Guest and the Companion walk by (Logic/NavGraph).
	self.nav = NavGraph.build(layout, NavGraph.options(Config))
	self.passageChangedAt = {}
	self.debugBlocked = {}
	self.World.nav = self.nav
	lowStorey, highStorey = Storeys.range(layout)
	self.World.storeys = { low = lowStorey, high = highStorey }
	self.Built:Fire(self.World)
	self:BroadcastLayout()
	return self.World
end

function WorldService:Clear()
	if self.folder then
		self.folder:Destroy()
		self.folder = nil
		self.content = nil
	end
	if self.World then
		self.World = nil
		self.adjacency = nil
		self.nav = nil
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
	-- Every room as a rectangle (x, z its north-west corner from the origin;
	-- a 40x40 cell in the old house) on its floor; tall rooms stand on both.
	local rects = RoomRects.ofLayout(world.layout, Config.Level)
	local rooms = {}
	for _, rect in rects do
		local room = world.rooms[rect.id]
		table.insert(rooms, {
			id = rect.id,
			gx = room.gx,
			gz = room.gz,
			x = rect.x,
			z = rect.z,
			w = rect.w,
			d = rect.d,
			floor = rect.floor or 0,
			tall = rect.tall,
			top = rect.top,
			kind = room.kind,
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
	return {
		rooms = rooms,
		cell = CELL,
		pitch = PITCH,
		mode = world.layout.mode or "Cells",
		storeys = { lowStorey, highStorey },
		origin = { o.x, o.y, o.z },
		seed = world.layout.seed,
	}
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

-- Which storey of the mansion a point is on: a storey once it is near that
-- floor's level (stairs and the hall stand on several), within the storeys
-- the house has (Logic/Storeys).
local function floorAt(y: number): number
	return Storeys.of(y, PITCH, lowStorey, highStorey)
end
WorldService.FloorAt = floorAt

function WorldService:RoomAt(position: Vector3): number?
	local world = self.World
	if not world then
		return nil
	end
	local o = Config.Level.Origin
	if world.index then
		local y = position.Y - o.y
		if y < lowStorey * PITCH - 20 or y > (highStorey + 1) * PITCH + 20 then
			return nil
		end
		local index = world.index[floorAt(y)]
		return index and index:At(position.X - o.x, position.Z - o.z)
	end
	local gx = math.floor((position.X - o.x) / CELL + 0.5)
	local gz = math.floor((position.Z - o.z) / CELL + 0.5)
	if position.Y < o.y - 20 or position.Y > o.y + 40 then
		return nil
	end
	return world.layout.cells[gx .. "," .. gz]
end

-- How much further footsteps carry in the room a point is in: its template's
-- `creaks` (the attic's boards), else 1.
function WorldService:CreaksAt(position: Vector3): number
	local id = self:RoomAt(position)
	local room = id and self.World and self.World.rooms[id]
	return room and room.template.creaks or 1
end

-- Walking the house (Logic/NavGraph, docs/plans/mansion-generation.md M3) ----

local function toLayout(p: Vector3)
	local o = Config.Level.Origin
	return { x = p.X - o.x, y = p.Y - o.y, z = p.Z - o.z }
end
WorldService.ToLayout = toLayout

local function fromLayout(p): Vector3
	local o = Config.Level.Origin
	return Vector3.new(p.x + o.x, p.y + o.y, p.z + o.z)
end
WorldService.FromLayout = fromLayout

-- The floor height of the storey a point is on. A floor spot or a body's
-- root both work (anything below the upper floor's level is downstairs), so
-- in the old house it is always the ground.
function WorldService:FloorBase(y: number): number
	local o = Config.Level.Origin.y
	return o + floorAt(y - o) * PITCH
end

-- The passage model (docs/plans/gameplay-rework.md section 5.1): who may pass
-- a seam right now, and what it costs them in studs; nil means they can't.
-- Every route and distance the Guest, the Companion and the stalker's map of
-- the squad use comes through here, so locks (R2a), barricades (R1b) and
-- doors turned to walls (R3) only need adding in this one place. who:
--   "player"        players and the Companion
--   "guest"         The Guest between hunts
--   "guestHunt"     The Guest hunting
--   "guestRetreat"  distances while he backs away: how far, not how slow,
--                   so a shut door costs nothing
-- A shut door costs Config.Nav.DoorCost (opening it takes 1.5-3 s), one left
-- ajar half that. A barricade (Services/PushService) costs what getting past
-- it does: a squeeze for players, a shove for him (quicker hunting), and he
-- can't back away through one.
function WorldService:SeamCost(seamId: string, who: string?): number?
	local world = self.World
	local seam = world and world.seams[seamId]
	if not seam then
		return 0
	end
	if self.debugBlocked and self.debugBlocked[seamId] then
		return nil
	end
	local door = seam.door
	-- Locked (the escape, Services/LockService): a wall to everyone, him too.
	if door and door.locked then
		return nil
	end
	-- Something else shut across it (a crank door down: Services/CrankService).
	if seam.blocks and next(seam.blocks) then
		return nil
	end
	local cost = 0
	if door and not door.open and who ~= "guestRetreat" then
		local ajar = door.state and not door.state.latched
		cost = ajar and Config.Nav.DoorCost / 2 or Config.Nav.DoorCost
	end
	if seam.barricades and next(seam.barricades) then
		local B = Config.Barricade
		if who == "guestRetreat" then
			return nil
		end
		cost += (who == "player" and B.PlayerCost) or (who == "guestHunt" and B.GuestHuntCost) or B.GuestCost
	end
	return cost
end

-- What bars a doorway ({ [piece id] = { piece, side } }), or nil.
function WorldService:Barricades(seamId: string)
	local seam = self.World and self.World.seams[seamId]
	local list = seam and seam.barricades
	return (list and next(list)) and list or nil
end

-- Shut a doorway to everyone for a reason of its own (`cause`: a crank door
-- down), or open it again. Walkers re-route.
function WorldService:SetSeamBlocked(seamId: string, cause: string, blocked: boolean)
	local seam = self.World and self.World.seams[seamId]
	if not seam then
		return
	end
	seam.blocks = seam.blocks or {}
	if (seam.blocks[cause] == true) == blocked then
		return
	end
	seam.blocks[cause] = blocked or nil
	self:MarkPassageChanged(seamId, cause)
end

-- F2 `block <room> <room>`: shut a doorway to everyone, for testing what the
-- Guest and the Companion do with no way through. nil seam: open them all.
function WorldService:DebugBlock(seamId: string?, blocked: boolean)
	self.debugBlocked = self.debugBlocked or {}
	if seamId then
		self.debugBlocked[seamId] = blocked or nil
		self:MarkPassageChanged(seamId, "debug")
	else
		for id in self.debugBlocked do
			self.debugBlocked[id] = nil
			self:MarkPassageChanged(id, "debug")
		end
	end
end

-- Something changed who may pass a seam. Walkers whose way crosses it re-route
-- (Stalker/Walker reads passageVersion and PassageChangedSince).
function WorldService:MarkPassageChanged(seamId: string, why: string)
	self.passageVersion += 1
	if self.passageChangedAt then
		self.passageChangedAt[seamId] = self.passageVersion
	end
	self.PassageChanged:Fire(seamId, why)
end

function WorldService:PassageChangedSince(seamId: string, version: number): boolean
	local at = self.passageChangedAt and self.passageChangedAt[seamId]
	return at ~= nil and at > version
end

-- The way between two points (floor spots or roots): { steps = { { position,
-- node, kind, room, seam, stair, door } }, cost }, or nil. Steps are empty
-- when both are in the same room on the same level. opts as NavGraph.search
-- (avoid, extra), plus who (SeamCost; "guest" if not given).
function WorldService:Route(from: Vector3, to: Vector3, opts)
	local nav, world = self.nav, self.World
	if not nav or not world then
		return nil
	end
	opts = table.clone(opts or {})
	local who = opts.who or "guest"
	opts.doorCost = opts.doorCost or function(seamId: string): number?
		return self:SeamCost(seamId, who)
	end
	local route = NavGraph.route(nav, toLayout(from), self:RoomAt(from), toLayout(to), self:RoomAt(to), opts)
	if not route then
		return nil
	end
	for _, step in route.steps do
		local node = nav.nodes[step.node]
		step.position = fromLayout(node)
		step.kind = node.kind
		step.room = node.room
		local seam = step.seam and world.seams[step.seam]
		step.door = seam and seam.door or nil
	end
	return route
end

-- Every graph node's walking distance from a point (for weighing options).
-- opts as NavGraph.search, plus who: seams are charged by SeamCost when given.
function WorldService:NavDistances(from: Vector3, opts)
	if not self.nav then
		return nil
	end
	if opts and opts.who and not opts.doorCost then
		local who = opts.who
		opts = table.clone(opts)
		opts.doorCost = function(seamId: string): number?
			return self:SeamCost(seamId, who)
		end
	end
	return NavGraph.search(self.nav, NavGraph.attach(self.nav, toLayout(from), self:RoomAt(from)), opts)
end

-- How far apart two points are for someone walking: on the flat on one
-- storey, else by way of the nearest staircase.
function WorldService:Separation(a: Vector3, b: Vector3): number
	if not self.nav then
		return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
	end
	return NavGraph.separation(self.nav, toLayout(a), toLayout(b))
end

local function place(self, p: Vector3)
	local room = self:RoomAt(p)
	local record = room and self.World and self.World.rooms[room]
	local q = toLayout(p)
	q.room = room
	q.tall = record and record.tall or false
	q.storey = floorAt(q.y)
	return q
end

-- Whether two people count as together within `radius` (owner, 2026-10-04:
-- on different floors you're apart, unless you share the hall or a stairwell).
function WorldService:Together(a: Vector3, b: Vector3, radius: number): boolean
	return Storeys.together(place(self, a), place(self, b), radius, PITCH)
end

-- How far a noise made at `at` carries to a listener at `listener` (a floor
-- muffles it, Config.Stalker.FloorNoiseScale).
function WorldService:AudibleRadius(radius: number, at: Vector3, listener: Vector3): number
	return Storeys.audibleRadius(radius, place(self, at), place(self, listener), PITCH, Config.Stalker.FloorNoiseScale)
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
	if self.World.index then
		local seam = self:SeamBetween(a, b)
		if seam then
			return seam.floorPosition
		end
	end
	local ra, rb = self.World.rooms[a], self.World.rooms[b]
	return (ra.center + rb.center) / 2
end

-- A point just inside room `a`, in front of its doorway to `b`.
function WorldService:ApproachPoint(a: number, b: number, inset: number?): Vector3
	if self.World.index then
		local seam = self:SeamBetween(a, b)
		if seam then
			local into = seam.a == a and -seam.normal or seam.normal
			return seam.floorPosition + into * (inset or 3)
		end
	end
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

-- A room's lights (R2c "one light rule"): lit only while nothing keeps it
-- dark. Each thing that can is a cause, and this is the one place a room's
-- lights change, so none of them undoes another:
--   switch  its wall switch is off (Services/InteractService)
--   circuit its breaker is off; main: the main has tripped (the breaker)
--   killed  he put them out (StalkerService), for a while
--   dinner  every light dies when the dinner is served (FinaleService)
--   debug   F2 `light`
-- Moonlight through a window answers only to the dinner, him and F2: no
-- switch or breaker turns the moon off.
local ELECTRIC = { switch = true, circuit = true, main = true }

function WorldService:SetLightCause(id: number, cause: string, dark: boolean)
	local room = self:Room(id)
	if not room or not room.light then
		return
	end
	room.darkCauses = room.darkCauses or {}
	if (room.darkCauses[cause] == true) == dark then
		return
	end
	room.darkCauses[cause] = dark or nil
	self:_applyLight(room)
end

-- Every cause lifted at once (the way out after the dinner).
function WorldService:ClearLightCauses(id: number)
	local room = self:Room(id)
	if room and room.light then
		room.darkCauses = {}
		self:_applyLight(room)
	end
end

-- What keeps a room dark right now: { [cause] = true }.
function WorldService:LightCauses(id: number)
	local room = self:Room(id)
	return room and room.darkCauses or {}
end

function WorldService:_applyLight(room)
	local on = true
	for cause in room.darkCauses or {} do
		if not (ELECTRIC[cause] and room.lightKind == "window") then
			on = false
		end
	end
	room.lightOn = on
	room.light.Enabled = on
	if room.bounce then
		room.bounce.Enabled = on
	end
	for _, light in room.extraLights or {} do
		light.Enabled = on
	end
	room.lightPart:SetAttribute("Lit", on)
end

-- F2 `light`: on or off by hand.
function WorldService:SetRoomLight(id: number, on: boolean)
	self:SetLightCause(id, "debug", not on)
end

function WorldService:IsLanternRoom(id: number?): boolean
	if not id then
		return false
	end
	local room = self:Room(id)
	return room ~= nil and room.shrine ~= nil and room.shrine.lit
end

-- outside: only slots on an outer wall (LevelBuilder marks them), for tells
-- such as a window that would make no sense between two rooms.
function WorldService:TakeWallSlot(roomId: number, rng, outside: boolean?)
	local room = self:Room(roomId)
	if not room then
		return nil
	end
	local free = {}
	for _, slot in room.wallSlots do
		if not slot.used and (slot.outside or not outside) then
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

-- Random walkable point inside a room's clear centre area. In a corridor it
-- stays inside the junction or one open arm, clear of the closets and of
-- arms that were filled in.
function WorldService:RandomPointIn(roomId: number, rng): Vector3
	local room = self:Room(roomId)
	if room.rect then
		-- The mansion: inside the room's clear middle, away from the furniture
		-- along its walls. The hall's is in front of the staircase and a
		-- stairwell's at the foot of its stairs, round its walkable centre.
		if room.tall then
			-- A point of the hall's or the stairwell's walk shape, on either
			-- storey (the gallery, the upper landing): never over the void.
			local nav = self.nav and self.nav.rooms[roomId]
			local points = {}
			for _, id in nav and nav.nodes or {} do
				local node = self.nav.nodes[id]
				if node.kind == "tall" and node.region ~= "landing" then
					table.insert(points, node)
				end
			end
			if #points > 0 then
				local node = points[rng:NextInteger(1, #points)]
				return fromLayout(node) + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
			end
			return room.center + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		end
		local band = Config.Level.BandDepth
		local hx = math.max(1, room.rect.w / 2 - band)
		local hz = math.max(1, room.rect.d / 2 - band)
		return room.center + Vector3.new(rng:NextNumber(-hx, hx), 0, rng:NextNumber(-hz, hz))
	end
	local along = rng:NextNumber(-9, 9)
	if room.corridor then
		local inner = room.corridor - 1.5
		local across = rng:NextNumber(-inner, inner)
		local alongX = rng:Chance(0.5)
		local open = room.corridorOpen or {}
		if along < -inner and not open[alongX and "W" or "N"] then
			along = -inner
		elseif along > inner and not open[alongX and "E" or "S"] then
			along = inner
		end
		local offset = alongX and Vector3.new(along, 0, across) or Vector3.new(across, 0, along)
		return room.center + offset
	end
	return room.center + Vector3.new(along, 0, rng:NextNumber(-9, 9))
end

return WorldService
