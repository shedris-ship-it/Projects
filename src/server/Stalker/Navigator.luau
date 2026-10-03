-- The stalker's movement (doc section 7: "A* on the room graph for strategy").
-- Room templates keep the room centre and the doorway lanes clear of
-- furniture, so the route centre -> doorway -> centre is always walkable and
-- no navmesh is needed. Closed doors cost 1.5-3 seconds and make noise.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Graph = require(Shared.Logic.Graph)

local Navigator = {}
Navigator.__index = Navigator

local ARRIVE = 2.2
local BAND = 10.5

function Navigator.new(services, body, rng)
	return setmetatable({
		services = services,
		World = services.WorldService,
		Doors = services.DoorService,
		body = body,
		rng = rng,
		waypoints = {},
		index = 1,
		speed = 8,
		waitingUntil = 0,
		pendingDoor = nil,
		lastProgressCheck = 0,
		lastDistance = math.huge,
		destination = nil,
		canTeleport = nil, -- function() -> bool, set by the service
	}, Navigator)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Navigator:Position(): Vector3
	return self.body.root.Position
end

local function inBand(world, roomId, position: Vector3): boolean
	local room = world.rooms[roomId]
	local offset = position - room.center
	return math.max(math.abs(offset.X), math.abs(offset.Z)) > BAND
end

-- Room path, optionally through solid seams (Phantom Architecture twist)
-- and avoiding rooms (Lantern rooms during a hunt).
function Navigator:_roomPath(from: number, to: number, avoid)
	local worldService = self.World
	local adjacency = worldService.adjacency
	if worldService.stalkerUsesSeams then
		adjacency = self:_fullAdjacency()
	end
	return Graph.weightedPath(adjacency, from, to, function(a, b)
		if avoid and avoid[b] and b ~= to then
			return nil
		end
		local seam = worldService:SeamBetween(a, b)
		local cost = 1
		if seam and not seam.connected then
			cost = 1.6
		end
		return cost
	end)
end

function Navigator:_fullAdjacency()
	if self.fullAdjacency and self.fullAdjacencyFor == self.World.World then
		return self.fullAdjacency
	end
	local world = self.World.World
	local edges = {}
	for _, seam in world.seams do
		table.insert(edges, { seam.a, seam.b })
	end
	self.fullAdjacency = Graph.adjacency(self.World:RoomIds(), edges)
	self.fullAdjacencyFor = world
	return self.fullAdjacency
end

-- Plan a route to a world position. opts = { speed, avoid = { [roomId] = true } }
function Navigator:SetDestination(target: Vector3, opts)
	opts = opts or {}
	self.speed = opts.speed or self.speed
	self.body.humanoid.WalkSpeed = self.speed
	-- Same destination: keep the current route, including once it has
	-- arrived, so callers can re-issue a destination every tick and still
	-- see Arrived() become true.
	if self.destination and (flat(self.destination) - flat(target)).Magnitude < 1.5 then
		return
	end
	self.destination = target
	self.waypoints = {}
	self.index = 1
	self.pendingDoor = nil
	self.waitingUntil = 0
	local world = self.World.World
	local here = self:Position()
	local fromRoom = self.World:RoomAt(here)
	local toRoom = self.World:RoomAt(target)
	if not world or not fromRoom or not toRoom then
		table.insert(self.waypoints, { position = target })
		return
	end
	local path = self:_roomPath(fromRoom, toRoom, opts.avoid)
	if not path then
		table.insert(self.waypoints, { position = target })
		return
	end
	if inBand(world, fromRoom, here) and #path > 1 then
		table.insert(self.waypoints, { position = world.rooms[fromRoom].center })
	end
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local seam = self.World:SeamBetween(a, b)
		table.insert(
			self.waypoints,
			{ position = self.World:ApproachPoint(a, b, 3.5), doorBefore = seam and seam.door }
		)
		table.insert(self.waypoints, { position = self.World:DoorwayPoint(a, b) })
		table.insert(self.waypoints, { position = self.World:ApproachPoint(b, a, 3.5) })
	end
	if inBand(world, toRoom, target) then
		table.insert(self.waypoints, { position = world.rooms[toRoom].center })
	end
	table.insert(self.waypoints, { position = target })
end

function Navigator:Stop()
	self.waypoints = {}
	self.index = 1
	self.destination = nil
	self.pendingDoor = nil
	local root = self.body.root
	if not root.Anchored then
		self.body.humanoid:MoveTo(root.Position)
	end
end

function Navigator:Arrived(): boolean
	return self.index > #self.waypoints
end

function Navigator:Remaining(): number
	if self:Arrived() or not self.destination then
		return 0
	end
	return (flat(self.destination) - flat(self:Position())).Magnitude
end

-- Advance along the route. Returns true while still travelling.
function Navigator:Step(now: number): boolean
	local waypoint = self.waypoints[self.index]
	if not waypoint then
		return false
	end
	local humanoid = self.body.humanoid
	local root = self.body.root

	-- Waiting on a door.
	if self.pendingDoor then
		local door = self.pendingDoor
		if door.open then
			self.pendingDoor = nil
		elseif now >= self.waitingUntil then
			self.Doors:SetOpen(door, true, nil, self.Doors:IsBraced(door))
			self.pendingDoor = nil
		else
			if self.Doors:IsBraced(door) and now - (self.lastBang or 0) > 1.2 then
				self.lastBang = now
				self.Doors:Bang(door)
			end
			humanoid:MoveTo(root.Position)
			return true
		end
	end

	local distance = (flat(waypoint.position) - flat(root.Position)).Magnitude
	if distance <= ARRIVE then
		-- Reaching an approach point with a closed door ahead: open it first.
		local nextWaypoint = self.waypoints[self.index + 1]
		if waypoint.doorBefore and not waypoint.doorBefore.open and nextWaypoint then
			self.pendingDoor = waypoint.doorBefore
			self.waitingUntil = now + self.Doors:StalkerDelay(waypoint.doorBefore, self.rng)
		end
		self.index += 1
		self.lastDistance = math.huge
		self.lastProgressCheck = now
		return self.index <= #self.waypoints
	end

	humanoid.WalkSpeed = self.speed
	humanoid:MoveTo(waypoint.position)

	-- Stuck? Nudge him a little forward when nobody could see it (he's
	-- always physically somewhere: never more than a few studs), otherwise
	-- skip to the next waypoint.
	if now - self.lastProgressCheck > 1.5 then
		if distance > self.lastDistance - 0.6 then
			if self.canTeleport and self.canTeleport() then
				local toward = flat(waypoint.position) - flat(root.Position)
				local nudge = toward.Magnitude > 4 and toward.Unit * 4 or toward
				self.body.model:PivotTo(
					CFrame.new(flat(root.Position) + nudge + Vector3.new(0, self.body.groundOffset, 0))
						* root.CFrame.Rotation
				)
				local telemetry = self.services.Telemetry
				if telemetry then
					telemetry:Log("GuestNudge", { studs = math.floor(nudge.Magnitude * 10) / 10 })
				end
			end
			self.index += 1
		end
		self.lastDistance = distance
		self.lastProgressCheck = now
	end
	return true
end

return Navigator
