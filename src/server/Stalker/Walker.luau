-- Walking the house, for The Guest and the Companion (docs/plans/
-- mansion-generation.md, M3; owner 2026-10-04: "I want his pathfinding in
-- general to be very advanced and dynamic"). Three layers:
--   1. strategy: WorldService:Route on the house's graph (Logic/NavGraph)
--      picks the doorways, stairs and gallery to go by, in studs, round
--      closed doors and lit Lanterns and (when sneaking) out of sight;
--   2. footwork: each stretch inside a room is planned on Roblox's navmesh
--      (PathfindingService), which sees every piece of furniture, the stair
--      ramps and the railings, and anything moved since. It re-plans when
--      the way is blocked;
--   3. steering: MoveTo between those points, cutting corners only where a
--      body-sized sweep is clear (Stalker/Clearance), slowing for turns and
--      stairs, and a stuck ladder that never moves him through anything.
-- Doorways are straight walks (approach, doorway, approach), so a closed
-- door never spoils a plan and still costs time to open. The old house
-- works the same way on its graph of rooms.
--
-- A barricade across a doorway ahead (Services/PushService): The Guest stops
-- at it, bangs, and shoves it clear within a few seconds (never more than
-- Config.Barricade.ShoveMax); if nothing will let it move, he slips past
-- once nobody can see. The Companion squeezes past, like a player.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Barricade = require(Shared.Logic.Barricade)
local Config = require(Shared.Config)
local Sfx = require(Shared.Lib.Sfx)

local Clearance = require(script.Parent.Clearance)

local B = Config.Barricade

local Walker = {}
Walker.__index = Walker

local ARRIVE = 2.2 -- at a graph point (doorways, the goal)
local ARRIVE_FINE = 1.3 -- at a navmesh point (they're close together)
local RISE = 4 -- a point above or below by more than this isn't reached yet
local STUCK_SECONDS = 1.2
local REPLAN_SECONDS = 0.25 -- a moving target re-routes at most this often
local RELEG_SECONDS = 0.5 -- and re-plans its last leg on the navmesh at most this often
local LOOKAHEAD_SECONDS = 0.3
local PLAN_TIMEOUT = 1.5 -- a navmesh plan slower than this is abandoned for the graph's own way
local UNREACHABLE_RETRY = 1 -- with no way there, try the graph again this often

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- agent = {
--   model, humanoid, root, groundOffset,
--   group       collision group (for sweeps),
--   halfWidth   how far the body reaches sideways,
--   path        PathfindingService agent parameters,
--   opensDoors  "stalker" (waits, bangs braced doors) or "companion",

--   who         who he walks as, for WorldService:SeamCost (a string, or a
--               function returning one; "guest" if not given)
-- }
function Walker.new(services, agent, rng)
	return setmetatable({
		services = services,
		World = services.WorldService,
		Doors = services.DoorService,
		agent = agent,
		body = agent, -- Stalker code reads navigator.body.root
		humanoid = agent.humanoid,
		root = agent.root,
		rng = rng,
		clearance = Clearance.new({ model = agent.model, group = agent.group, halfWidth = agent.halfWidth }),
		goals = {},
		index = 1,
		speed = 8,
		destination = nil,
		options = nil,
		routedAt = 0,
		leg = nil, -- { goal, points, index, token, computing, blocked }
		token = 0,
		pendingDoor = nil,
		waitingUntil = 0,
		pendingBarricade = nil, -- { seam, untilT, door }
		progressAt = 0,
		bestDistance = math.huge,
		stage = 0, -- the stuck ladder's rung
		sidestepUntil = 0,
		lookaheadAt = 0,
		canTeleport = nil, -- function() -> bool: nobody could see a nudge
		allowNudge = true,
		unreachable = false, -- the last route found no way there
		routeVersion = 0, -- WorldService.passageVersion when the route was made
		stats = { routes = 0, legs = 0, replans = 0, fallbacks = 0, stuck = 0, sidesteps = 0, nudges = 0, skipped = 0 },
	}, Walker)
end

function Walker:Position(): Vector3
	return self.root.Position
end

-- Where his feet are.
function Walker:Feet(): Vector3
	return self.root.Position - Vector3.new(0, self.agent.groundOffset, 0)
end

local function reached(feet: Vector3, point: Vector3, radius: number): boolean
	return (flat(point) - flat(feet)).Magnitude <= radius and math.abs(point.Y - feet.Y) <= RISE
end

-- Planning ------------------------------------------------------------------------

-- Turn a route's steps into goals: legs (inside a room, on the navmesh) that
-- end at the approach before a doorway, and the straight crossings through.
local function goalsOf(route, target: Vector3)
	local goals = {}
	local fallback = {}
	local steps = route and route.steps or {}
	for i, step in steps do
		local nextStep = steps[i + 1]
		local previous = steps[i - 1]
		local crossing = step.kind == "doorway"
			or (step.kind == "approach" and previous ~= nil and previous.kind == "doorway")
		if crossing then
			-- Through a doorway and out the other side: straight.
			table.insert(goals, { kind = "cross", position = step.position, seam = step.seam })
		elseif step.kind == "approach" and nextStep and nextStep.kind == "doorway" then
			table.insert(goals, {
				kind = "leg",
				position = step.position,
				door = nextStep.door,
				seam = nextStep.seam,
				fallback = fallback,
			})
			fallback = {}
		else
			table.insert(fallback, step.position)
		end
	end
	table.insert(goals, { kind = "leg", position = target, fallback = fallback, final = true })
	return goals
end

-- Plan a route to a world position. opts = { speed, avoid = { [roomId] =
-- true }, extra = function(node) -> studs (prefer unseen ways), force }.
function Walker:SetDestination(target: Vector3, opts)
	opts = opts or {}
	self.speed = opts.speed or self.speed
	self.humanoid.WalkSpeed = self.speed
	local now = os.clock()
	-- With no way there last time, look again now and then (a door may have
	-- been unlocked), however often the caller asks.
	local retry = self.unreachable and now - self.routedAt >= UNREACHABLE_RETRY
	if self.destination and not opts.force and not retry then
		local moved = (self.destination - target).Magnitude
		-- Same destination: keep the route, including once it has arrived,
		-- so callers can re-issue it every tick and still see Arrived().
		if moved < 1.5 then
			return
		end
		-- A target that moves (a chase): follow it on the last leg, and
		-- re-plan the whole way only every so often.
		local last = self.goals[#self.goals]
		local sameRoom = self.World:RoomAt(target) == self.World:RoomAt(self.destination)
		if last and last.final and (sameRoom or now - self.routedAt < REPLAN_SECONDS) and moved < 6 then
			self.destination = target
			last.position = target
			local leg = self.leg
			if self.index == #self.goals and leg and not leg.computing and now - leg.plannedAt > RELEG_SECONDS then
				self:_planLeg(last)
			end
			return
		end
	end
	self.destination = target
	self.options = opts
	self.routedAt = now
	self.stats.routes += 1
	local feet = self:Feet()
	local who = self.agent.who
	if type(who) == "function" then
		who = who()
	end
	self.routeVersion = self.World.passageVersion
	local route = self.World:Route(feet, target, {
		avoid = opts.avoid,
		extra = opts.extra,

		who = who,
	})
	-- No way there from inside the house (every way is locked or blocked):
	-- stand and wait to be given somewhere else, rather than walk a straight
	-- line at a wall. Outside the house (arriving from the porch) there is no
	-- graph to ask, so the straight walk stays.
	local fromRoom, toRoom = self.World:RoomAt(feet), self.World:RoomAt(target)
	self.unreachable = route == nil and fromRoom ~= nil and toRoom ~= nil and fromRoom ~= toRoom
	if self.unreachable then
		self.stats.unreachable = (self.stats.unreachable or 0) + 1
		self.goals = {}
		self.index = 1
		self.pendingDoor = nil
		self.pendingBarricade = nil
		if self.leg and self.leg.connection then
			self.leg.connection:Disconnect()
		end
		self.leg = nil
		self.token += 1
		if not self.root.Anchored then
			self.humanoid:MoveTo(self.root.Position)
		end
		return
	end
	self.goals = goalsOf(route, target)
	self.index = 1
	self.pendingDoor = nil
	self.pendingBarricade = nil
	self.waitingUntil = 0
	self.leg = nil
	self:_resetProgress(now)
	self:_startGoal()
end

function Walker:_resetProgress(now: number)
	self.progressAt = now
	self.bestDistance = math.huge
	self.stage = 0
end

-- Not moving on purpose (waiting on a door or a plan): don't count it as stuck.
function Walker:_pause(now: number)
	self.progressAt = now
end

-- Begin the current goal: a leg gets a navmesh plan; a crossing is straight.
function Walker:_startGoal()
	local goal = self.goals[self.index]
	self.leg = nil
	if goal and goal.kind == "leg" then
		self:_planLeg(goal)
	end
end

-- Plan one leg on the navmesh, in the background; until it's ready he keeps
-- going if the straight way is clear.
function Walker:_planLeg(goal)
	self.token += 1
	local token = self.token
	local leg = { goal = goal, points = nil, index = 1, token = token, computing = true, plannedAt = os.clock() }
	if self.leg and self.leg.connection then
		self.leg.connection:Disconnect()
	end
	self.leg = leg
	self.stats.legs += 1
	local start = self:Feet()
	local finish = goal.position
	task.spawn(function()
		local path = PathfindingService:CreatePath(self.agent.path)
		local ok = pcall(function()
			path:ComputeAsync(start, finish)
		end)
		if self.leg ~= leg or token ~= self.token then
			return
		end
		leg.computing = false
		if ok and path.Status == Enum.PathStatus.Success then
			local points = {}
			for _, waypoint in path:GetWaypoints() do
				table.insert(points, waypoint.Position)
			end
			-- The last point is the goal itself, exactly.
			points[#points] = finish
			leg.points = points
			leg.index = math.min(2, #points)
			leg.connection = path.Blocked:Connect(function(blockedIndex: number)
				if self.leg == leg and blockedIndex >= leg.index then
					self.stats.replans += 1
					self:_planLeg(goal)
				end
			end)
		else
			-- The graph's own way through the room (the doorway lanes and the
			-- clear middle: Logic/NavGraph keeps furniture off them).
			self.stats.fallbacks += 1
			local points = table.clone(goal.fallback or {})
			table.insert(points, finish)
			leg.points = points
			leg.index = 1
		end
	end)
end

function Walker:Stop()
	self.goals = {}
	self.index = 1
	self.destination = nil
	self.unreachable = false
	self.pendingDoor = nil
	self.pendingBarricade = nil
	if self.leg and self.leg.connection then
		self.leg.connection:Disconnect()
	end
	self.leg = nil
	self.token += 1
	if not self.root.Anchored then
		self.humanoid:MoveTo(self.root.Position)
	end
end

function Walker:Arrived(): boolean
	return not self.unreachable and self.index > #self.goals
end

-- The last route found no way to the destination (locked or blocked doors):
-- he is standing still. Callers should pick somewhere else.
function Walker:Unreachable(): boolean
	return self.unreachable
end

-- Whether a seam this route still has to cross has changed who may pass it
-- since the route was made.
function Walker:_routeCrossesChanged(): boolean
	for i = self.index, #self.goals do
		local seam = self.goals[i].seam
		if seam and self.World:PassageChangedSince(seam, self.routeVersion) then
			return true
		end
	end
	return false
end

function Walker:Remaining(): number
	if self:Arrived() or not self.destination then
		return 0
	end
	return (flat(self.destination) - flat(self:Position())).Magnitude
end

-- The point he's walking to right now.
function Walker:CurrentPoint(): Vector3?
	local goal = self.goals[self.index]
	if not goal then
		return nil
	end
	local leg = self.leg
	if goal.kind == "leg" and leg and leg.points then
		return leg.points[leg.index] or goal.position
	end
	return goal.position
end

-- What he's doing, for F2 navtest and the overlay.
function Walker:Describe(): string
	local goal = self.goals[self.index]
	local leg = self.leg
	local point = self:CurrentPoint()
	local feet = self:Feet()
	return string.format(
		"goal %d/%d %s%s · %s · stage %d%s · feet (%.0f, %.0f, %.0f) to (%s)",
		self.index,
		#self.goals,
		goal and goal.kind or "-",
		goal and goal.door and (goal.door.open and " (door open)" or " (door shut)") or "",
		leg
				and (leg.computing and "planning" or string.format(
					"point %d/%d%s",
					leg.index,
					leg.points and #leg.points or 0,
					leg.timedOut and " (timed out)" or ""
				))
			or "no leg",
		self.stage,
		(self.pendingDoor and " · at a door" or "")
			.. (self.pendingBarricade and " · at a barricade" or "")
			.. (self.unreachable and " · no way there" or ""),
		feet.X,
		feet.Y,
		feet.Z,
		point and string.format("%.0f, %.0f, %.0f", point.X, point.Y, point.Z) or "-"
	)
end

-- Following ------------------------------------------------------------------------

function Walker:_advanceGoal(now: number)
	local goal = self.goals[self.index]
	-- A closed door ahead: open it first.
	local door = goal and goal.door
	if door and not door.open and self.goals[self.index + 1] then
		self.pendingDoor = door
		if door.state and door.state.target >= Config.Doors.PassAngle then
			-- Already swinging open (after a barricade): a moment.
			self.waitingUntil = now + 0.4
		elseif self.agent.opensDoors == "stalker" then
			self.waitingUntil = now + self.Doors:StalkerDelay(door, self.rng)
		else
			self.waitingUntil = now + 0.6
		end
	end
	self.index += 1
	self:_resetProgress(now)
	self:_startGoal()
end

-- Barricades ------------------------------------------------------------------------

-- At the barricade across the doorway ahead: he starts on it (or the
-- Companion starts squeezing past).
function Walker:_beginBarricade(goal, entries, now: number)
	local who = self.agent.who
	if type(who) == "function" then
		who = who()
	end
	local seconds = B.SqueezeSeconds
	if self.agent.opensDoors == "stalker" then
		local weight = 0
		for _, entry in entries do
			weight = math.max(weight, entry.piece.weight)
		end
		seconds = Barricade.shoveSeconds(weight, who == "guestHunt", B)
		-- A shut door in the way: he opens it, as far as the piece lets it.
		local door = goal.door
		if door and not door.open and not door.locked then
			self.Doors:SetOpen(door, true)
		end
	end
	self.pendingBarricade = { seam = goal.seam, untilT = now + seconds, door = goal.door }
	self.humanoid:MoveTo(self.root.Position)
	self:_pause(now)
end

-- Past it: through the doorway, then on from there.
function Walker:_slipPast(seamId: string): boolean
	local push = self.services.PushService
	local seam = self.World.World and self.World.World.seams[seamId]
	local spot = push and seam and push:SqueezeSpot(seam, self:Feet())
	if not spot then
		return false
	end
	self.agent.model:PivotTo(CFrame.new(spot + Vector3.new(0, self.agent.groundOffset, 0)) * self.root.CFrame.Rotation)
	self.stats.slips = (self.stats.slips or 0) + 1
	return true
end

-- Waiting at a barricade. Returns true while still at it.
function Walker:_atBarricade(now: number): boolean
	local pending = self.pendingBarricade
	local entries = self.World:Barricades(pending.seam)
	local goal = self.goals[self.index]
	if not entries then
		-- Cleared (pushed away, or he shoved it): on through.
		self.pendingBarricade = nil
		local door = pending.door
		if door and not door.open and not door.locked then
			self.Doors:SetOpen(door, true)
		end
		if goal and goal.kind == "leg" then
			self:_planLeg(goal)
		end
		return false
	end
	self.humanoid:MoveTo(self.root.Position)
	self:_pause(now)
	if now < pending.untilT then
		if self.agent.opensDoors == "stalker" and now - (self.lastBang or 0) > B.BangEvery then
			self.lastBang = now
			local _, entry = next(entries)
			local at = entry.piece.prop.frame.Position + Vector3.new(0, 3, 0)
			Sfx.play("DoorBang", at, 0.9, 0.75)
			local noise = self.services.NoiseService
			if noise then
				noise:Emit(at, B.BangNoise, nil, "slam")
			end
		end
		return true
	end
	if self.agent.opensDoors == "stalker" then
		local push = self.services.PushService
		local seam = self.World.World.seams[pending.seam]
		local moved = true
		for _, entry in entries do
			moved = push:Shove(entry.piece, seam, self:Feet()) and moved
		end
		if moved then
			self.stats.shoves = (self.stats.shoves or 0) + 1
			pending.untilT = now + B.ShoveTime + 0.2 -- the heave, then on
			-- A door the piece held part-open swings the rest of the way.
			local door = pending.door
			if door then
				task.delay(B.ShoveTime + 0.05, function()
					if not door.open and not door.locked then
						self.Doors:SetOpen(door, true)
					end
				end)
			end
			return true
		end
		-- Nothing lets it move: past it once nobody can see, else bang on.
		if self.canTeleport and self.canTeleport() and self:_slipPast(pending.seam) then
			self.pendingBarricade = nil
			self:_reroute()
			return false
		end
		pending.untilT = now + 1
		return true
	end
	-- The Companion squeezes past.
	self.pendingBarricade = nil
	if self:_slipPast(pending.seam) then
		self:_reroute()
	end
	return false
end

-- Route again from wherever he is to the same destination.
function Walker:_reroute()
	local destination, options = self.destination, self.options
	if destination then
		self:SetDestination(destination, {
			speed = options and options.speed,
			avoid = options and options.avoid,
			extra = options and options.extra,
			force = true,
		})
	end
end

-- Advance along the route. Returns true while still travelling.
function Walker:Step(now: number): boolean
	-- A doorway ahead was locked or blocked since the route was made; or he
	-- had no way at all and something opened.
	if self.routeVersion ~= self.World.passageVersion then
		local changed = self.unreachable or self:_routeCrossesChanged()
		self.routeVersion = self.World.passageVersion
		if changed then
			self:_reroute()
		end
	end
	local goal = self.goals[self.index]
	if not goal then
		return false
	end
	local humanoid = self.humanoid

	-- Waiting on a door.
	if self.pendingDoor then
		local door = self.pendingDoor
		if door.open then
			self.pendingDoor = nil
		elseif now >= self.waitingUntil then
			local braced = self.agent.opensDoors == "stalker" and self.Doors:IsBraced(door)
			-- (A player's body walked by the server, F2 `botrun`: the door
			-- swings away from them like one opened with E, or it stops on them.)
			self.Doors:SetOpen(door, true, self.agent.player, braced)
			self.pendingDoor = nil
		else
			if
				self.agent.opensDoors == "stalker"
				and self.Doors:IsBraced(door)
				and now - (self.lastBang or 0) > 1.2
			then
				self.lastBang = now
				self.Doors:Bang(door)
			end
			humanoid:MoveTo(self.root.Position)
			self:_pause(now)
			return true
		end
	end

	-- A barricade across the doorway ahead.
	if self.pendingBarricade then
		if self:_atBarricade(now) then
			return true
		end
		goal = self.goals[self.index]
		if not goal then
			return false
		end
	end
	local feet = self:Feet()
	if goal.kind == "leg" and goal.seam then
		local entries = self.World:Barricades(goal.seam)
		if entries then
			-- At the doorway, or right up against what bars his own side.
			local near = (flat(goal.position) - flat(feet)).Magnitude <= ARRIVE + 1
			local push = self.services.PushService
			local seam = self.World.World.seams[goal.seam]
			local mine = (feet - seam.floorPosition):Dot(flat(seam.normal).Unit) >= 0 and 1 or -1
			for _, entry in entries do
				near = near or (entry.side == mine and push and push:Gap(entry.piece, feet) <= B.Reach)
			end
			if near then
				self:_beginBarricade(goal, entries, now)
				return true
			end
		end
	end

	local point = goal.position
	local radius = ARRIVE
	local leg = self.leg
	if goal.kind == "leg" then
		if leg and leg.computing and not leg.points and now - leg.plannedAt > PLAN_TIMEOUT then
			-- Too slow: the graph's own way through the room instead.
			self.stats.fallbacks += 1
			leg.computing = false
			leg.timedOut = true
			local points = table.clone(goal.fallback or {})
			table.insert(points, goal.position)
			leg.points = points
			leg.index = 1
		end
		if not leg or (leg.computing and not leg.points) then
			-- The navmesh plan is on its way: keep going if the straight way
			-- is clear, else wait a moment for it.
			if self.clearance:Clear(self.root.Position, goal.position + Vector3.new(0, self.agent.groundOffset, 0)) then
				humanoid.WalkSpeed = self.speed
				humanoid:MoveTo(goal.position)
			else
				humanoid:MoveTo(self.root.Position)
			end
			self:_pause(now)
			return true
		end
		-- The last point is the goal itself, which moves with a chased target.
		point = leg.index < #leg.points and leg.points[leg.index] or goal.position
		radius = leg.index < #leg.points and ARRIVE_FINE or ARRIVE
		-- Cut ahead to a later point when the body fits the straight way.
		if now - self.lookaheadAt > LOOKAHEAD_SECONDS and leg.index < #leg.points then
			self.lookaheadAt = now
			for k = math.min(#leg.points, leg.index + 3), leg.index + 1, -1 do
				local candidate = k == #leg.points and goal.position or leg.points[k]
				if
					math.abs(candidate.Y - feet.Y) < 1
					and self.clearance:Clear(self.root.Position, candidate + Vector3.new(0, self.agent.groundOffset, 0))
				then
					leg.index = k
					point = candidate
					break
				end
			end
		end
	end

	if reached(feet, point, radius) then
		if goal.kind == "leg" and leg and leg.points and leg.index < #leg.points then
			leg.index += 1
			self:_resetProgress(now)
			return true
		end
		self:_advanceGoal(now)
		return self.index <= #self.goals
	end

	-- Speed: slower on stairs and into sharp turns.
	local speed = self.speed
	if math.abs(point.Y - feet.Y) > 1 then
		speed *= 0.8
	end
	if goal.kind == "leg" and leg and leg.points then
		local after = leg.points[leg.index + 1]
		if after then
			local a, b = flat(point - feet), flat(after - point)
			if a.Magnitude > 0.1 and b.Magnitude > 0.1 and a.Magnitude < 4 and a.Unit:Dot(b.Unit) < 0.35 then
				speed *= 0.75
			end
		end
	end
	humanoid.WalkSpeed = speed

	if now < self.sidestepUntil then
		return true
	end
	humanoid:MoveTo(point)
	self:_checkStuck(now, feet, point)
	return true
end

-- The stuck ladder: re-plan the leg, side-step, nudge (only unseen, only into
-- clear space), then give the goal up and route again. Never through walls.
function Walker:_checkStuck(now: number, feet: Vector3, point: Vector3)
	local distance = (flat(point) - flat(feet)).Magnitude + math.abs(point.Y - feet.Y)
	if distance < self.bestDistance - 0.5 then
		self.bestDistance = distance
		self.progressAt = now
		self.stage = 0
		return
	end
	if now - self.progressAt < STUCK_SECONDS then
		return
	end
	self.progressAt = now
	self.stage += 1
	self.stats.stuck += 1
	local goal = self.goals[self.index]
	local rootPoint = point + Vector3.new(0, self.agent.groundOffset, 0)
	if self.stage == 1 and goal.kind == "leg" then
		self.stats.replans += 1
		self:_planLeg(goal)
	elseif self.stage <= 2 then
		-- Side-step: the clear short move that best closes on the point.
		local here = self.root.Position
		local best, bestScore = nil, -math.huge
		for i = 0, 7 do
			local angle = i / 8 * math.pi * 2
			local candidate = here + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 2.5
			if self.clearance:Clear(here, candidate) then
				local score = -(flat(rootPoint) - flat(candidate)).Magnitude + self.rng:NextNumber(0, 0.3)
				if score > bestScore then
					best, bestScore = candidate, score
				end
			end
		end
		if best then
			self.stats.sidesteps += 1
			self.humanoid:MoveTo(best - Vector3.new(0, self.agent.groundOffset, 0))
			self.sidestepUntil = now + 0.6
		end
	elseif self.stage == 3 and self.allowNudge and self.canTeleport and self.canTeleport() then
		-- Nobody could see: a short shift into clear space toward the point.
		local here = self.root.Position
		local toward = rootPoint - here
		if toward.Magnitude > 0.1 then
			local reach = self.clearance:Reach(here, here + toward.Unit * math.min(3, toward.Magnitude))
			if (reach - here).Magnitude > 0.5 and self.clearance:Grounded(reach, self.agent.groundOffset) then
				self.stats.nudges += 1
				self.agent.model:PivotTo(CFrame.new(reach) * self.root.CFrame.Rotation)
				local telemetry = self.services.Telemetry
				if telemetry then
					telemetry:Log("GuestNudge", {
						studs = math.floor((reach - here).Magnitude * 10) / 10,
						room = self.World:RoomAt(here),
					})
				end
			end
		end
	elseif self.stage >= 4 then
		-- Give this goal up and route again from wherever he is.
		self.stats.skipped += 1
		if self.destination then
			self:_reroute()
			self.stage = 0
		end
	end
end

-- The Guest's navmesh agent: his body collides with a 1.6 x 1.0 box at the
-- hips and stoops through doorways (8 high), so it plans with a slim, short
-- agent and never jumps.
Walker.GuestPath = {
	AgentRadius = 1.4,
	AgentHeight = 6,
	AgentCanJump = false,
	AgentCanClimb = false,
	WaypointSpacing = 3,
}

Walker.CompanionPath = {
	AgentRadius = 1.2,
	AgentHeight = 5,
	AgentCanJump = false,
	AgentCanClimb = false,
	WaypointSpacing = 3,
}

-- The arrival radius, for callers that test closeness themselves.
Walker.Arrive = ARRIVE

return Walker
