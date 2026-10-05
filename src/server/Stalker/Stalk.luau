-- The Guest between hunts (owner, 2026-10-03). Runs at Config.Guest.BrainHz
-- for tiers 0-3, after he has arrived in the house. Layers:
--
--   reactions  every tick, whatever he's doing: yanked out of sight when a
--              tier-1 Witness has clearly seen him; holding and staring when
--              watched at tier 2; backing away when stared at up close; the
--              breath and creak warnings behind a turned back; the lunge
--   moves      what he's doing for a while (Data/StalkMoves): peek round a
--              door frame, stand in the doorway you just walked through,
--              creep up behind you, shadow a straggler, stare you down, walk
--              the far rooms. Chosen by utility (Logic/UtilityAI) from the
--              squad's habits and each Witness's gaze habits
--              (Logic/GazeHabits), at random among the best three
--
-- Rules and fairness gates are Logic/StalkRules. The body is Stalker/Body;
-- what the squad can see is Stalker/Sight. Every decision is logged with its
-- reasons for the debug overlay and the Dossier.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local GuestPose = require(Shared.Logic.GuestPose)
local BeliefMap = require(Shared.Logic.BeliefMap)
local GazeHabits = require(Shared.Logic.GazeHabits)
local Net = require(Shared.Net)
local SightMath = require(Shared.Logic.SightMath)
local PeekSpots = require(Shared.Logic.PeekSpots)
local StalkMoves = require(Shared.Data.StalkMoves)
local StalkRules = require(Shared.Logic.StalkRules)
local UtilityAI = require(Shared.Logic.UtilityAI)

local G = Config.Guest
local Poses = GuestPose.Poses

local Stalk = {}
Stalk.__index = Stalk

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function planar(a: Vector3, b: Vector3): number
	return (flat(a) - flat(b)).Magnitude
end

function Stalk.new(service)
	return setmetatable({
		service = service,
		services = service.services,
		body = service.bodyCtl,
		sight = service.sight,
		rng = service.rng:Fork("stalk"),
		move = nil,
		lastUsed = {},
		counts = {},
		log = {},
		target = nil,
		targetSince = 0,
		hiddenUntil = 0, -- tier 1: nobody sees him while he relocates
		seenFor = 0, -- seconds his target has been watching him
		watchedFor = 0, -- seconds anyone has been watching him
		warned = {}, -- player -> { since, last }: heard or saw him coming
		nextBreath = {},
		nextCreak = {},
		lastRoom = {}, -- player -> room id, for "the doorway you just walked through"
		doorwayPass = {}, -- player -> { from, to, t }
		peekCache = nil,
		peekCacheFor = nil,
		beliefs = {}, -- player -> BeliefMap: which room he thinks they're in
		beliefFor = nil, -- the world the maps were built for
		lastFed = {}, -- player -> memory time already folded into their map
		checkedAt = {}, -- player -> memory time he walked to and found empty
		priorAt = 0,
		contactLast = {}, -- player -> when he last lunged at them for getting too close
		withdrawUntil = 0,
		lostSince = nil,
		sensedPos = nil, -- where he believes the target is (nil = lost them)
		sensedSeen = false, -- ... and he can see them right now
	}, Stalk)
end

-- What he knows --------------------------------------------------------------------
-- Everything below the targeting layer works from sight, sound and the squad's
-- habits (doc section 5), not from reading players' positions.

-- Maps are per world; a new run starts with no beliefs.
function Stalk:_resetFor(world)
	if self.beliefFor ~= world then
		self.beliefFor = world
		self.beliefs = {}
		self.lastFed = {}
		self.checkedAt = {}
		self.lastRoom = {}
		self.doorwayPass = {}
		self.contactLast = {}
		self.withdrawUntil = 0
		self.lostSince = nil
	end
end

-- Habit weights: the rooms the squad uses most, most used first.
function Stalk:_prior(): { [number]: number }
	local prior = {}
	for rank, room in self.services.SquadProfileService:RoomsByUse() do
		prior[room] = 1 / rank
	end
	return prior
end

function Stalk:_belief(player: Player)
	local map = self.beliefs[player]
	if not map then
		map = BeliefMap.new(self.services.WorldService.adjacency, self:_prior())
		self.beliefs[player] = map
	end
	return map
end

-- Where he thinks `player` is, and whether he can see them right now. Seeing
-- them (or being stared at by them) gives the live position; otherwise it's
-- the last place he saw or heard them, until that's stale or he has been there
-- and found nobody. nil means he's lost them.
function Stalk:Known(player: Player): (Vector3?, boolean)
	local perception = self.service.perception
	local m = perception.memory[player]
	local watching = table.find(self.service.watchers or {}, player) ~= nil
	if watching or (m and m.seen and os.clock() - m.t <= G.SeenFreshSeconds) then
		return self.services.PlayerStateService:Position(player), true
	end
	if m and self.checkedAt[player] ~= m.t and perception:Confidence(player) >= G.TrackMinConfidence then
		return m.position, false
	end
	return nil, false
end

-- Fold new sightings and noises into each player's room belief, then let the
-- beliefs spread and relax towards the squad's habits.
function Stalk:_feed(dt: number)
	local worldService = self.services.WorldService
	self:_resetFor(worldService.World)
	local perception = self.service.perception
	local clock = os.clock()
	local refreshPrior = clock >= self.priorAt
	if refreshPrior then
		self.priorAt = clock + G.BeliefPriorRefresh
	end
	for _, player in self.services.PlayerStateService:LivingPlayers() do
		local map = self:_belief(player)
		if refreshPrior then
			map:SetPrior(self:_prior())
		end
		local m = perception.memory[player]
		if m and m.t > (self.lastFed[player] or 0) then
			self.lastFed[player] = m.t
			local room = worldService:RoomAt(m.position)
			if room then
				if m.seen then
					map:Observe(room)
				else
					map:Hear(room, G.BeliefHeardStrength, G.BeliefHeardSpread)
				end
			end
		end
		map:Step(dt, G.BeliefDiffuse, G.BeliefRelax)
	end
end

-- His best guess at a player's position for picking targets: what he knows,
-- else the middle of the room he thinks they're in.
function Stalk:_estimate(player: Player): Vector3?
	local pos = self:Known(player)
	if pos then
		return pos
	end
	local room = self.services.WorldService:Room((self:_belief(player):Best()))
	return room and room.center
end

-- Who he's after, and whether he's hidden from everyone right now.
function Stalk:Target(): Player?
	return self.target
end

-- At tier 1 nobody sees him while he walks to his next place: he shows
-- himself only once he's there (and never pops in while you're looking).
function Stalk:Hidden(now: number): boolean
	return now < self.hiddenUntil or self.transit == true
end

-- After downing someone alone he vanishes from everyone at any tier.
function Stalk:Withdrawn(now: number): boolean
	return now < self.withdrawUntil
end

-- Targets --------------------------------------------------------------------------

function Stalk:_valid(player: Player?): boolean
	return player ~= nil and player.Parent ~= nil and self.services.PlayerStateService:IsActive(player)
end

-- Whoever is most alone, weighted by how rarely they look behind them.
function Stalk:_pickTarget(now: number)
	local ps = self.services.PlayerStateService
	-- A target he can't find for a while is dropped for someone he can place.
	local lost = self.target ~= nil and self.sensedPos == nil
	self.lostSince = lost and (self.lostSince or now) or nil
	local giveUp = false
	if self.lostSince and now - self.lostSince >= G.TargetLostSeconds then
		for _, player in ps:ActivePlayers() do
			if player ~= self.target and self:Known(player) then
				giveUp = true
				break
			end
		end
	end
	if self:_valid(self.target) and now - self.targetSince < G.TargetStickSeconds and not giveUp then
		return
	end
	local profile = self.services.SquadProfileService
	local best, bestScore = nil, -math.huge
	for _, player in ps:ActivePlayers() do
		local pos = self:_estimate(player)
		if pos then
			-- Company counts only on the same floor (owner, 2026-10-04).
			local nearest = 40
			local worldService = self.services.WorldService
			for _, other in ps:LivingPlayers() do
				local otherPos = other ~= player and self:_estimate(other)
				if otherPos and worldService:Together(otherPos, pos, 40) then
					nearest = math.min(nearest, (otherPos - pos).Magnitude)
				end
			end
			local habits = profile:Gaze(player)
			local score = nearest / 40
				+ (habits and GazeHabits.blindBack(habits) or 0.5) * 0.8
				+ self.rng:NextNumber(0, 0.3)
			if score > bestScore then
				best, bestScore = player, score
			end
		end
	end
	if best ~= self.target then
		self.seenFor = 0
		self.lostSince = nil
		self.sensedPos, self.sensedSeen = nil, false
		if best then
			self.sensedPos, self.sensedSeen = self:Known(best)
		end
	end
	self.target = best
	self.targetSince = now
end

-- Geometry helpers --------------------------------------------------------------------

-- Where he believes the target is (set each tick; nil = he has lost them).
function Stalk:_targetPos(): Vector3?
	return self.sensedPos
end

-- The target's room, for choosing a search: his best guess, not the truth.
function Stalk:_targetRoom(): number?
	if self.sensedPos then
		return self.services.WorldService:RoomAt(self.sensedPos)
	end
	return self.target and (self:_belief(self.target):Best())
end

-- Doorway peek spots across the house, validated against furniture once
-- per world.
function Stalk:_peekSpots()
	local worldService = self.services.WorldService
	local world = worldService.World
	if self.peekCache and self.peekCacheFor == world then
		return self.peekCache
	end
	local divergent = self.services.DivergenceService:DivergentSeams()
	local cfg = {
		PeekLateral = G.PeekLateral,
		PeekWallClearance = G.PeekWallClearance,
		PeekHideLateral = G.PeekHideLateral,
		WallThickness = Config.Level.WallThickness,
	}
	local spots = {}
	for id, seam in world.seams do
		if seam.connected and not divergent[id] then
			-- The doorway itself (in the mansion, room centres don't line up
			-- with their doorways).
			local n = flat(seam.normal).Unit
			local c = seam.floorPosition
			for _, s in PeekSpots.forDoorway(c.X, c.Z, n.X, n.Z, cfg) do
				local position = Vector3.new(s.x, c.Y, s.z)
				local hide = Vector3.new(s.hideX, c.Y, s.hideZ)
				if self.body:Fits(position) and self.body:Fits(hide) then
					table.insert(spots, {
						position = position,
						hide = hide,
						face = Vector3.new(s.faceX, 0, s.faceZ),
						lean = s.lean,
						room = s.side > 0 and seam.b or seam.a, -- where he stands
						watches = s.side > 0 and seam.a or seam.b, -- the room he peeks into
						seam = id,
					})
				end
			end
		end
	end
	self.peekCache, self.peekCacheFor = spots, world
	return spots
end

-- Where his head is when he leans out from a peek spot (Logic/GuestPose).
function Stalk:_peekHead(spot): Vector3
	local head = GuestPose.exposed(Poses.Peek, spot.lean)
	local right = Vector3.new(-spot.face.Z, 0, spot.face.X)
	return spot.position + Vector3.new(0, GuestPose.Rig.rootY + head[2], 0) + right * head[1] - spot.face * head[3]
end

-- A peek spot for the target: in a doorway of the room they're in (or the
-- next one), at least the tier's minimum distance away, not in anyone's
-- view right now (he must be there before you turn).
function Stalk:_findPeek(tier: number, why)
	local targetPos = self:_targetPos()
	if not targetPos then
		return nil
	end
	why = why or {}
	local worldService = self.services.WorldService
	local room = worldService:RoomAt(targetPos)
	if not room then
		return nil
	end
	local near = { [room] = true }
	for _, n in worldService:Neighbours(room) do
		near[n] = true
	end
	local minDistance = G.PeekMinDistance[math.clamp(tier, 1, 3)]
	-- Where their head is: really, if he can see them; else about head height
	-- over where he thinks they are.
	local realHead = self.sensedSeen and self.target.Character and self.target.Character:FindFirstChild("Head")
	local head = realHead and { Position = realHead.Position } or { Position = targetPos + Vector3.new(0, 2.5, 0) }
	local candidates = {}
	local seams = worldService.World.seams
	for _, spot in self:_peekSpots() do
		why.spots = (why.spots or 0) + 1
		-- Only through an open doorway: a closed door would hide his head.
		local door = seams[spot.seam] and seams[spot.seam].door
		if near[spot.watches] and not (door and not door.open) then
			why.near = (why.near or 0) + 1
			local d = worldService:Separation(spot.position, targetPos)
			if d >= minDistance and d <= 60 then
				why.range = (why.range or 0) + 1
				-- The target must be able to see the peeking head from where
				-- they stand (through the doorway), just not right now.
				local view = head
					and self.services.WitnessService:ClearLine(head.Position, self:_peekHead(spot), { self.body.model })
				if view then
					why.line = (why.line or 0) + 1
				end
				if view and not self.sight:AnyoneSees(self.sight.BodyPoints(spot.position)) then
					table.insert(candidates, { spot = spot, weight = 1 + (60 - d) / 30 })
				end
			end
		end
	end
	if #candidates == 0 then
		return nil
	end
	return self.rng:WeightedPick(candidates, function(c)
		return c.weight
	end).spot
end

-- A point a few studs away that the target can't see: where he's yanked to
-- when you catch him without a door frame to hide behind. His whole body
-- must clear the way there (Stalker/Clearance), with floor under the end.
function Stalk:_escapePoint(from: Vector3): Vector3
	local best, bestScore = nil, -math.huge
	local targetPos = self:_targetPos() or from
	local worldService = self.services.WorldService
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		local point = from + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 9
		if self.body:Fits(point) and self.body.clearance:Clear(from, point) then
			local hidden = not self.sight:AnyoneSees(self.sight.BodyPoints(point))
			local score = (hidden and 100 or 0) + worldService:Separation(point, targetPos)
			if score > bestScore then
				best, bestScore = point, score
			end
		end
	end
	return best or from
end

-- Somewhere far from everyone, out of sight: for roaming the house.
function Stalk:_farPoint(): Vector3?
	local worldService = self.services.WorldService
	local best, bestScore = nil, -math.huge
	for _, id in worldService:RoomIds() do
		local point = worldService:RandomPointIn(id, self.rng)
		local d = self.service:_minPlayerDistance(point)
		if d >= 30 and self.body:Fits(point) then
			local score = -math.abs(d - 45) + self.rng:NextNumber(0, 15)
			if score > bestScore then
				best, bestScore = point, score
			end
		end
	end
	return best
end

-- Sneaking: a way someone is looking at costs him more (Config.Nav.SeenCost),
-- so he goes round the long way you won't see. Each graph point is checked
-- at most twice a second.
function Stalk:_unseenCost()
	local worldService = self.services.WorldService
	local nav = worldService.nav
	if not nav then
		return nil
	end
	if self.exposureFor ~= nav then
		self.exposure, self.exposureFor = {}, nav
	end
	local cache, sight = self.exposure, self.sight
	return function(nodeId: number): number
		local now = os.clock()
		local entry = cache[nodeId]
		if entry and now - entry.t < 0.5 then
			return entry.cost
		end
		local point = worldService.FromLayout(nav.nodes[nodeId]) + Vector3.new(0, 5.6, 0)
		local cost = sight:AnyoneSees({ point }) and Config.Nav.SeenCost or 0
		cache[nodeId] = { t = now, cost = cost }
		return cost
	end
end

-- Moves -----------------------------------------------------------------------------

local MOVES = {}

-- Walking somewhere out of everyone's sight (tier 0 and 1 he's invisible
-- anyway, and silent: steps are only heard by whoever can see him).
local function relocate(self, move, now)
	self.transit = true
	if not move.walking then
		move.walking = true
		self.body:FaceMovement()
		self.body:SetPose(Poses.Walk)
		self.body:SetGaze(nil)
		self.body:Go(move.goal, G.WalkSpeed, nil, self:_unseenCost())
	end
	if self.body:Arrived() or self.body:Unreachable() or now - move.started > 30 then
		move.walking = false
		self.transit = false
		return true
	end
	return false
end

MOVES.DistantRoam = {
	start = function(self, move)
		move.goal = self:_farPoint()
		return move.goal ~= nil
	end,
	update = function(self, move, now)
		if not move.pausing then
			if relocate(self, move, now) then
				-- Stand in the corner facing the wall for a while.
				move.pausing = now + self.rng:NextNumber(3, 7)
				self.body:Hold()
				self.body:SetPose(Poses.Idle)
			end
			return false
		end
		return now >= move.pausing
	end,
}

MOVES.Peek = {
	start = function(self, move, ctx)
		move.spot = self:_findPeek(ctx.tier)
		if not move.spot then
			return false
		end
		move.goal = move.spot.position
		move.holdFor = self.rng:NextNumber(G.PeekHoldSeconds[1], G.PeekHoldSeconds[2])
		return true
	end,
	update = function(self, move, now, ctx)
		local spot = move.spot
		if not move.peeking then
			if ctx.tier >= 2 and ctx.watchers > 0 then
				return self:_holdStare(ctx)
			end
			if relocate(self, move, now) then
				local feet = self.body.root.Position.Y - self.body.built.groundOffset
				if planar(self.body.root.Position, spot.position) > 2.5 or math.abs(feet - spot.position.Y) > 3 then
					return true -- couldn't get there
				end
				move.peeking = now
				self.body:Hold()
				self.body:FacePoint(spot.position + spot.face * 10)
				self.body:SetPose(Poses.Peek, spot.lean)
				self.body:SetGaze(self.target)
				self.service.yankTo = spot.hide
			end
			return false
		end
		-- Watching through the door frame (until someone shuts the door).
		local seam = self.services.WorldService.World.seams[spot.seam]
		local shut = seam and seam.door and not seam.door.open
		if shut or (now - move.peeking >= move.holdFor and ctx.watchers == 0) then
			-- Slip back behind the wall, unhurried, before anyone looks.
			self.body:SetPose(Poses.Idle)
			self.body:FaceMovement()
			self.body:Step(spot.hide, G.WalkSpeed)
			self.service.yankTo = nil
			return true
		end
		return false
	end,
	stop = function(self)
		self.service.yankTo = nil
	end,
}

-- "Standing in the doorway you just walked through."
MOVES.DoorwayStand = {
	start = function(self, move, ctx)
		local pass = self.target and self.doorwayPass[self.target]
		if not pass or ctx.now - pass.t > 10 or not StalkRules.mayBlockDoorway(ctx.tier) then
			return false
		end
		local worldService = self.services.WorldService
		local point = worldService:ApproachPoint(pass.from, pass.to, 1.5)
		local targetPos = self:_targetPos()
		if
			not targetPos
			or worldService:Separation(point, targetPos) < G.PeekMinDistance[math.clamp(ctx.tier, 1, 3)]
		then
			return false
		end
		if self.sight:AnyoneSees(self.sight.BodyPoints(point)) then
			return false
		end
		move.goal = point
		move.untilT = ctx.now + 25
		return true
	end,
	update = function(self, move, now, ctx)
		if not move.standing then
			if ctx.tier >= 2 and ctx.watchers > 0 then
				return self:_holdStare(ctx)
			end
			if relocate(self, move, now) then
				move.standing = now
				self.body:Hold()
				self.body:SetPose(Poses.Hold)
				self.body:FacePlayer(self.target)
				self.body:SetGaze(self.target)
			end
			return now > move.untilT
		end
		return now > move.untilT or (ctx.watchers == 0 and now - move.standing > 18)
	end,
}

-- Creep up behind the target, staying out of everyone's sight; faster the
-- more their back is turned; frozen in place while watched at tier 2.
MOVES.CreepBehind = {
	start = function(self, move, ctx)
		if ctx.tier < 2 or not self.target then
			return false
		end
		move.untilT = ctx.now + 45
		return true
	end,
	update = function(self, move, now, ctx)
		local targetPos = ctx.targetPos
		if not targetPos then
			return true
		end
		if not StalkRules.canCreep(ctx.tier, ctx.watchers) then
			return self:_holdStare(ctx) or now > move.untilT
		end
		local distance = ctx.distance
		self.body:SetGaze(self.target)
		self.body:FacePlayer(self.target)
		if distance > 22 then
			-- Far: walk the house towards them (unhurried, unseen).
			self.body:SetPose(Poses.Walk)
			self.body:Go(targetPos, ctx.tier >= 3 and G.WalkSpeed * 0.8 or G.WalkSpeed, nil, self:_unseenCost())
			return now > move.untilT
		end
		-- Near: sneak, step by step, to just behind their back.
		local look = ctx.targetLook or Vector3.new(0, 0, -1)
		local stop = ctx.tier >= 3 and 2 or G.CloseBehind
		local goal = targetPos - flat(look).Unit * stop
		if ctx.tier == 2 and distance <= G.CloseBehind + 0.8 then
			-- Right behind you. Breathing. Not touching you.
			self.body:Hold()
			self.body:SetPose(Poses.Hold)
			return now > move.untilT
		end
		local speed = StalkRules.creepSpeed(ctx.tier, ctx.backAngle, ctx.watchers, G)
		-- Move in short bursts (doc section 8): step, stop, step.
		local burst = (now * 1.4) % 1 < 0.65
		if not burst then
			self.body:Hold()
			self.body:SetPose(Poses.Creep)
			return false
		end
		local step = self.sight:StealthStep(goal)
		if step then
			self.body:SetPose(Poses.Creep)
			self.body:Step(step, speed)
		else
			self.body:Hold()
		end
		return now > move.untilT
	end,
}

-- Follow a straggler out of sight; his footsteps stop when theirs do.
MOVES.ShadowBehind = {
	start = function(self, move, ctx)
		if not self.target then
			return false
		end
		move.untilT = ctx.now + self.rng:NextNumber(18, 30)
		move.keep = ctx.tier <= 1 and 28 or self.rng:NextNumber(14, 22)
		return true
	end,
	update = function(self, move, now, ctx)
		local targetPos = ctx.targetPos
		if not targetPos then
			return true
		end
		if ctx.tier >= 2 and ctx.watchers > 0 then
			return self:_holdStare(ctx) or now > move.untilT
		end
		-- Only a target he can see gives away how fast they're moving.
		local root = ctx.seen and self.target.Character and self.target.Character:FindFirstChild("HumanoidRootPart")
		local speed = root and flat(root.AssemblyLinearVelocity).Magnitude or G.WalkSpeed
		if ctx.distance > move.keep + 8 then
			-- Too far to follow: close in first, unhurried.
			self.body:FaceMovement()
			self.body:SetPose(Poses.Walk)
			self.body:Go(targetPos, G.WalkSpeed, nil, self:_unseenCost())
		elseif speed < 1 or ctx.distance < move.keep then
			-- You stopped; so did he.
			self.body:Hold()
			self.body:SetPose(Poses.Idle)
		else
			self.body:FaceMovement()
			self.body:SetPose(Poses.Walk)
			self.body:Go(targetPos, math.clamp(speed * 0.95, 3, G.WalkSpeed + 2), nil, self:_unseenCost())
		end
		self.body:SetGaze(self.target)
		return now > move.untilT
	end,
}

-- Stand in plain sight, smiling, perfectly still, until you look away.
MOVES.StareDown = {
	start = function(self, move, ctx)
		if ctx.tier < 2 then
			return false
		end
		move.spot = self:_findPeek(ctx.tier)
		if not move.spot then
			return false
		end
		-- Not leaning round the frame: standing in the open beside it.
		move.goal = move.spot.position + Vector3.new(-move.spot.face.Z, 0, move.spot.face.X) * move.spot.lean * 1.2
		move.untilT = ctx.now + 30
		return true
	end,
	update = function(self, move, now, ctx)
		if not move.standing then
			if ctx.watchers > 0 then
				return self:_holdStare(ctx)
			end
			if relocate(self, move, now) then
				move.standing = now
				self.body:Hold()
				self.body:SetPose(Poses.Hold)
				self.body:FacePlayer(self.target)
				self.body:SetGaze(self.target)
			end
			return now > move.untilT
		end
		if ctx.watchers > 0 then
			move.seen = true
		elseif move.seen then
			return true -- you looked away: he moves on (closer, next)
		end
		return now > move.untilT
	end,
}

-- He's lost them: walk to the rooms he thinks they're in (the squad's habits,
-- narrowed by what he last saw or heard), look round, check the next one.
MOVES.Search = {
	start = function(self, move)
		if not self.target then
			return false
		end
		local worldService = self.services.WorldService
		local here = worldService:RoomAt(self.body.root.Position)
		local map = self:_belief(self.target)
		for _ = 1, 6 do
			local room = map:Sample(self.rng)
			if room ~= here then
				local point = worldService:RandomPointIn(room, self.rng)
				if self.body:Fits(point) then
					move.room, move.goal = room, point
					return true
				end
			end
		end
		return false
	end,
	update = function(self, move, now, ctx)
		if ctx.known then
			return true -- a clue: the moves that need a target take over
		end
		if ctx.tier >= 2 and ctx.watchers > 0 then
			return self:_holdStare(ctx)
		end
		if not move.pausing then
			if relocate(self, move, now) then
				move.pausing = now + self.rng:NextNumber(G.SearchPause[1], G.SearchPause[2])
				self.body:Hold()
				self.body:SetPose(Poses.Idle)
				self:_belief(self.target):Clear(move.room, G.BeliefClearStrength)
			end
			return false
		end
		return now >= move.pausing
	end,
}

-- A noise nobody made (a thing that fell, a flush, a radio left on): he goes
-- to look, unseen, stands a moment looking round, and moves on. Only while
-- he doesn't know where you are (docs/plans/gameplay-rework.md 4.9).
MOVES.Investigate = {
	start = function(self, move)
		local perception = self.service.perception
		local lure = perception:FreshLure(G.LureFreshSeconds)
		if not lure then
			return false
		end
		local spot = lure.position
		local floor = Vector3.new(spot.X, self.services.WorldService:FloorBase(spot.Y), spot.Z)
		-- As near the noise as he can stand.
		local goal = self.body:Fits(floor) and floor or nil
		for i = 1, 8 do
			if goal then
				break
			end
			local angle = i / 8 * math.pi * 2
			local point = floor + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 3
			if self.body:Fits(point) then
				goal = point
			end
		end
		if not goal then
			lure.checked = true
			return false
		end
		perception:FollowLure(lure, G.LureWaryWindow)
		move.goal = goal
		return true
	end,
	update = function(self, move, now, ctx)
		if ctx.known then
			return true -- someone to go after instead
		end
		if ctx.tier >= 2 and ctx.watchers > 0 then
			return self:_holdStare(ctx)
		end
		if not move.pausing then
			if relocate(self, move, now) then
				move.pausing = now + self.rng:NextNumber(G.LureLookSeconds[1], G.LureLookSeconds[2])
				self.body:Hold()
				self.body:SetPose(Poses.Idle)
			end
			return false
		end
		return now >= move.pausing
	end,
}

-- Worth going to look at a noise nobody made? A fresh one, he doesn't know
-- where you are, and less likely the more he's been fooled lately.
function Stalk:_lureTempts(ctx): boolean
	if ctx.known or ctx.tier < 1 then
		return false
	end
	local perception = self.service.perception
	if not perception:FreshLure(G.LureFreshSeconds) then
		return false
	end
	return self.rng:NextNumber() < perception:LureTrust(G.LureWaryWindow, G.LureWaryFactor)
end

-- Internal moves (not chosen by utility) -------------------------------------------

-- Tier 1: you've clearly seen him. Yanked out of sight in a blink, still
-- facing you; then he's gone (to everyone) while he finds a new place.
MOVES.Yank = {
	start = function(self, _move, ctx)
		local point = self.service.yankTo or self:_escapePoint(self.body.root.Position)
		self.body:FacePlayer(self.target or ctx.nearestWatcher)
		self.body:Zoom(point)
		self.services.SquadProfileService:RecordSighting(self.target, true)
		Net.get("GuestEvent"):FireAllClients({ kind = "yank", position = self.body.root.Position })
		return true
	end,
	update = function(self, move, now)
		if self.body:Busy() then
			return false
		end
		if not move.gone then
			move.gone = true
			self.hiddenUntil = now + self.rng:NextNumber(G.Tier1Cooldown[1], G.Tier1Cooldown[2])
			self.service.yankTo = nil
		end
		return true
	end,
}

-- Backing away slowly, never looking away, smile widening: after a lunge,
-- when stared at up close at tier 2, or when two Witnesses stare him down.
MOVES.BackAway = {
	start = function(self, move, ctx)
		self.service.retreat:Reset()
		move.untilT = ctx.now + G.BackAwayMaxSeconds
		move.face = ctx.nearestWatcher or self.target
		move.unseenFor = 0
		return true
	end,
	update = function(self, move, now, ctx)
		self.service:_backAwayStep(move.face)
		if ctx.watchers == 0 then
			move.unseenFor += ctx.dt
		else
			move.unseenFor = 0
		end
		return move.unseenFor > 1.5 or now > move.untilT
	end,
}

MOVES.Lunge = {
	start = function(self, move, ctx)
		local target = self.target
		move.contact = ctx.contact == true
		self.service.lungeLast[target] = ctx.now
		self.service.squadLungeLast = ctx.now
		Net.get("GuestEvent")
			:FireAllClients({ kind = "lunge", target = target.UserId, position = self.body.root.Position })
		self.services.Telemetry:Log(
			"GuestLunge",
			{ tier = ctx.tier, distance = ctx.distance, contact = move.contact },
			target
		)
		self.body:Lunge(target, function(player)
			move.landed = true
			local pos = self.services.PlayerStateService:Position(player)
			local here = self.body.root.Position
			local hit = pos
				and StalkRules.lungeHits(planar(pos, here), math.abs(pos.Y - here.Y), G)
				and self.services.PlayerStateService:IsActive(player)
				and not self.services.HidingService:IsHidden(player)
			if hit then
				-- Judged before the down: is anyone he knows of near enough to help?
				move.alone = move.contact and self:_alone(player)
				self.service:_catch(player, os.clock(), "lunge")
			end
			self.services.Telemetry:Log("GuestLungeLanded", { hit = hit == true }, player)
		end, move.contact and G.ContactWindup or nil)
		return true
	end,
	update = function(self, move)
		if self.body:Busy() then
			return false
		end
		-- Cancelled (two Witnesses) or landed. Having downed someone alone he
		-- slips away before their friends arrive; otherwise he backs off.
		local ctx = self:_ctxCache()
		self:_begin(move.alone and "Withdraw" or "BackAway", ctx)
		return false
	end,
}

-- Downed someone who was alone: out of sight at once, and gone while the
-- others come to help. Invisible to everyone (Stalk:Withdrawn), so no steps.
MOVES.Withdraw = {
	start = function(self, move, ctx)
		self.withdrawUntil = ctx.now + self.rng:NextNumber(G.WithdrawSeconds[1], G.WithdrawSeconds[2])
		move.goal = self:_farPoint()
		self.body:FacePlayer(self.target)
		self.body:Zoom(self:_escapePoint(self.body.root.Position))
		return true
	end,
	update = function(self, move, now)
		if self.body:Busy() then
			return false
		end
		if not move.walking then
			move.walking = true
			move.started = now
			self.body:FaceMovement()
			self.body:SetGaze(nil)
			self.body:SetPose(Poses.Run)
			if move.goal then
				self.body:Go(move.goal, G.WithdrawSpeed)
			end
		end
		if
			not move.still
			and (not move.goal or self.body:Arrived() or self.body:Unreachable() or now - move.started > 20)
		then
			move.still = true
			self.body:Hold()
			self.body:SetPose(Poses.Idle)
		end
		return now >= self.withdrawUntil
	end,
}

-- Nobody he knows of is near enough to help this player.
function Stalk:_alone(victim: Player): boolean
	local ps = self.services.PlayerStateService
	local victimPos = ps:Position(victim)
	if not victimPos then
		return true
	end
	for _, other in ps:LivingPlayers() do
		if other ~= victim and ps:IsActive(other) then
			local pos = self:Known(other)
			if pos and self.services.WorldService:Together(pos, victimPos, G.ContactAloneRadius) then
				return false
			end
		end
	end
	return true
end

-- Seconds since anyone went down within the no-lunge radius of a position.
function Stalk:_sinceDownNear(pos: Vector3, now: number): number
	local since = math.huge
	for _, down in self.service.recentDowns do
		if (down.position - pos).Magnitude <= G.NoLungeNearDownRadius then
			since = math.min(since, now - down.t)
		end
	end
	return since
end

-- Anyone he can see who has walked right up to him (Logic/StalkRules.contact).
-- Not only his target: whoever rushes him gets the lunge.
function Stalk:_contactVictim(now: number, ctx): (Player?, number?)
	local service, services = self.service, self.services
	local here = self.body.root.Position
	for _, entry in service.perception.visibleList do
		local player = entry.player
		local pos = services.PlayerStateService:Position(player)
		local head = player.Character and player.Character:FindFirstChild("Head")
		if pos then
			local distance = planar(pos, here)
			local ok = StalkRules.contact({
				tier = ctx.tier,
				visibleToVictim = service.visibleTo[player] == true,
				distance = distance,
				verticalGap = math.abs(pos.Y - here.Y),
				lineOfSight = head ~= nil
					and services.WitnessService:ClearLine(self.body:EyePosition(), head.Position, { self.body.model }),
				watchers = ctx.watchers,
				anchored = now < (service.frozenUntil or 0),
				stunned = now < (service.stunnedUntil or 0),
				hidden = services.HidingService:IsHidden(player),
				downed = not services.PlayerStateService:IsActive(player),
				safeRoom = service.perception:InSafeRoom(player),
				sinceDownNearby = self:_sinceDownNear(pos, now),
				sinceContact = now - (self.contactLast[player] or -math.huge),
			}, G)
			if ok then
				return player, distance
			end
		end
	end
	return nil, nil
end

-- Hold still and stare at whoever is watching (tier 2+). Returns false so
-- the move carries on when they look away.
function Stalk:_holdStare(ctx): boolean
	self.body:Hold()
	self.body:SetPose(Poses.Hold)
	local watcher = ctx.nearestWatcher or self.target
	if watcher then
		self.body:FacePlayer(watcher)
		self.body:SetGaze(watcher)
	end
	return false
end

-- Choosing ---------------------------------------------------------------------------------

function Stalk:_signals()
	local signals = self.services.SquadProfileService:Signals()
	return signals
end

function Stalk:_choose(ctx)
	local feasibility = {}
	for _, move in StalkMoves.List do
		feasibility[move.id] = table.find(move.tiers, ctx.tier) and 1 or 0
	end
	-- Moves that need a target he can place are off while he's lost them;
	-- then he searches by habit instead (tier 0 just wanders far away).
	local aimed = { Peek = true, DoorwayStand = true, CreepBehind = true, ShadowBehind = true, StareDown = true }
	for id in feasibility do
		if (not self.target or not ctx.known) and aimed[id] then
			feasibility[id] = 0
		end
	end
	if not self.target then
		feasibility.Search = 0
	end
	if ctx.tier == 0 then
		feasibility.DistantRoam = 1
	elseif self.target and not ctx.known then
		feasibility.DistantRoam = 0
	end
	if ctx.known then
		feasibility.Search = 0
	end
	-- A noise nobody made: worth a look while he's lost you, less so each
	-- time he's been fooled lately.
	if feasibility.Investigate > 0 then
		local perception = self.service.perception
		local lure = not ctx.known and perception:FreshLure(G.LureFreshSeconds)
		feasibility.Investigate = lure and perception:LureTrust(G.LureWaryWindow, G.LureWaryFactor) or 0
	end
	local pass = self.target and self.doorwayPass[self.target]
	if not pass or ctx.now - pass.t > 10 then
		feasibility.DoorwayStand = 0
	end
	-- Peeking is the early game; creeping takes over as he gets bolder,
	-- above all behind a turned back, and just after you've checked behind
	-- you (your gaze habits say you won't look again for a while).
	feasibility.Peek *= ({ [1] = 1, [2] = 0.55, [3] = 0.35 })[ctx.tier] or 1
	if feasibility.CreepBehind > 0 then
		local habits = self.target and self.services.SquadProfileService:Gaze(self.target)
		local window = habits and GazeHabits.creepWindow(habits, ctx.now) or 0.5
		local back = ctx.backAngle > G.BackTurnedDegrees and 1 or 0
		feasibility.CreepBehind = 0.6 + 0.8 * back + 0.5 * window
	end
	local id, scored = UtilityAI.choose(
		StalkMoves.List,
		self:_signals(),
		feasibility,
		self.lastUsed,
		ctx.now,
		self.rng,
		self.service.archetype.stalkWeights
	)
	return id or "DistantRoam", scored
end

function Stalk:_begin(id: string, ctx, scored)
	if self.move and MOVES[self.move.id] and MOVES[self.move.id].stop then
		MOVES[self.move.id].stop(self, self.move)
	end
	self.transit = false
	local move = { id = id, started = ctx.now }
	local ok = MOVES[id].start(self, move, ctx)
	if not ok then
		self.move = nil
		self.lastFailed = id
		return false
	end
	self.move = move
	self.lastUsed[id] = ctx.now
	self.counts[id] = (self.counts[id] or 0) + 1
	local top = {}
	for i = 1, math.min(3, scored and #scored or 0) do
		table.insert(top, string.format("%s %.2f", scored[i].id, scored[i].score))
	end
	table.insert(self.log, {
		t = ctx.now,
		move = id,
		top = top,
		target = self.target and self.target.DisplayName or "-",
		tier = ctx.tier,
	})
	if #self.log > 40 then
		table.remove(self.log, 1)
	end
	if Config.Debug.LogTactics then
		print(string.format("[Guest] %s -> %s (tier %d)", id, self.target and self.target.Name or "-", ctx.tier))
	end
	return true
end

-- Per tick --------------------------------------------------------------------------------

function Stalk:_ctxCache()
	return self.ctx
end

-- Notice when the target walks through a doorway (for DoorwayStand).
function Stalk:_trackDoorways(now: number)
	local ps = self.services.PlayerStateService
	local worldService = self.services.WorldService
	for _, player in ps:ActivePlayers() do
		-- Only a doorway he actually saw them use counts.
		local pos, seen = self:Known(player)
		local room = seen and pos and worldService:RoomAt(pos) or nil
		local last = self.lastRoom[player]
		if room and last and room ~= last then
			self.doorwayPass[player] = { from = last, to = room, t = now }
		end
		self.lastRoom[player] = room or last
	end
end

-- The warnings before a back attack (owner: subtle tells). A breath only
-- the target hears, close behind them; a floorboard creak anyone near can
-- hear, from where he really is. Both count as a warning for the lunge,
-- as does simply watching him come.
function Stalk:_tells(now: number, ctx)
	local target = self.target
	if not target then
		return
	end
	local warned = self.warned[target]
	if warned and now - warned.last > G.WarningMemorySeconds then
		self.warned[target] = nil
		warned = nil
	end
	local function warn()
		if not self.warned[target] then
			self.warned[target] = { since = now, last = now }
		else
			self.warned[target].last = now
		end
	end
	if ctx.targetWatching then
		warn()
	end
	if ctx.tier < 2 or not ctx.seen or ctx.distance > G.TellRadius or ctx.backAngle < 100 then
		return
	end
	local head = self.body:ExposedPoints()[1]
	if now >= (self.nextBreath[target] or 0) then
		self.nextBreath[target] = now + self.rng:NextNumber(G.BreathInterval[1], G.BreathInterval[2])
		Net.get("GuestEvent"):FireClient(target, { kind = "breath", position = head })
		warn()
	end
	if now >= (self.nextCreak[target] or 0) and self.body.root.AssemblyLinearVelocity.Magnitude > 0.3 then
		self.nextCreak[target] = now + self.rng:NextNumber(G.CreakInterval[1], G.CreakInterval[2])
		local foot = self.body.root.Position - Vector3.new(0, self.body.built.groundOffset, 0)
		for _, player in self.services.PlayerStateService:RunPlayers() do
			local pos = self.services.PlayerStateService:Position(player)
			if pos and (pos - foot).Magnitude < self.services.WorldService:AudibleRadius(40, foot, pos) then
				Net.get("GuestEvent"):FireClient(player, { kind = "creak", position = foot })
			end
		end
		warn()
	end
end

-- Should he lunge at the target now?
function Stalk:_lungeCheck(now: number, ctx): boolean
	if ctx.tier < 3 or not self.target or not ctx.seen or ctx.distance > G.LungeRadius then
		return false
	end
	local service, services = self.service, self.services
	local target = self.target
	local pos = ctx.targetPos
	local here = self.body.root.Position
	local sinceDown = self:_sinceDownNear(pos, now)
	local warned = self.warned[target]
	local head = target.Character and target.Character:FindFirstChild("Head")
	local ok = StalkRules.canLunge({
		tier = ctx.tier,
		-- The debug tier override skips the early-run gate, for testing.
		runTime = service.tierOverride and math.huge or (now - service.runStart),
		watchers = ctx.watchers,
		anchored = now < (service.frozenUntil or 0),
		stunned = now < (service.stunnedUntil or 0),
		distance = ctx.distance,
		verticalGap = math.abs(pos.Y - here.Y),
		lineOfSight = head ~= nil
			and services.WitnessService:ClearLine(self.body:EyePosition(), head.Position, { self.body.model }),
		hidden = services.HidingService:IsHidden(target),
		downed = not services.PlayerStateService:IsActive(target),
		safeRoom = service.perception:InSafeRoom(target),
		sinceDownNearby = sinceDown,
		sincePlayerLunge = now - (service.lungeLast[target] or -math.huge),
		sinceSquadLunge = now - (service.squadLungeLast or -math.huge),
		warnedFor = warned and (now - warned.since) or 0,
		sinceWarned = warned and (now - warned.last) or math.huge,
	}, G)
	return ok
end

-- watchers: players (and "companion") watching him this tick.
function Stalk:Update(now: number, dt: number, watchers, tier: number)
	self:_feed(dt)
	self:_pickTarget(now)
	self:_trackDoorways(now)
	local ps = self.services.PlayerStateService
	local playerWatchers = {}
	for _, w in watchers do
		if typeof(w) == "Instance" then
			table.insert(playerWatchers, w)
		end
	end
	local here = self.body.root.Position
	self.sensedPos, self.sensedSeen = nil, false
	if self.target then
		self.sensedPos, self.sensedSeen = self:Known(self.target)
		-- He's walked to where he last saw or heard them and they aren't
		-- there: that clue is spent, and so is that room.
		if
			self.sensedPos
			and not self.sensedSeen
			and planar(self.sensedPos, here) <= G.CheckedRadius
			and math.abs(self.sensedPos.Y - here.Y) < 6
		then
			local m = self.service.perception.memory[self.target]
			self.checkedAt[self.target] = m and m.t
			local room = self.services.WorldService:RoomAt(self.sensedPos)
			if room then
				self:_belief(self.target):Clear(room, G.BeliefClearStrength)
			end
			self.sensedPos = nil
		end
	end
	local targetPos = self.sensedPos
	-- Their camera only counts while he can see them; otherwise the way they
	-- were facing when he last did.
	local memory = self.target and self.service.perception.memory[self.target]
	local view = self.target and self.sensedSeen and self.sight:View(self.target)
	local look = view and view.LookVector or (targetPos and memory and memory.facing) or nil
	local backAngle = 0
	if targetPos then
		if self.sensedSeen then
			backAngle = self.sight:Angle(self.target, here + Vector3.new(0, 5, 0))
		elseif look then
			local d = here - targetPos
			backAngle = SightMath.angle(look.X, look.Z, d.X, d.Z)
		end
	end
	-- Walking distances: someone on the other floor is a staircase away.
	local worldService = self.services.WorldService
	local nearest, nearestDistance = nil, math.huge
	for _, w in playerWatchers do
		local pos = ps:Position(w)
		local d = pos and worldService:Separation(pos, here)
		if d and d < nearestDistance then
			nearest, nearestDistance = w, d
		end
	end
	local ctx = {
		now = now,
		dt = dt,
		tier = tier,
		watchers = #watchers,
		nearestWatcher = nearest,
		targetPos = targetPos,
		known = targetPos ~= nil,
		seen = self.sensedSeen,
		targetLook = look,
		distance = targetPos and worldService:Separation(targetPos, here) or math.huge,
		backAngle = backAngle,
		targetWatching = self.target ~= nil and table.find(playerWatchers, self.target) ~= nil,
	}
	self.ctx = ctx
	if #watchers > 0 then
		self.watchedFor += dt
	else
		self.watchedFor = 0
	end
	self.seenFor = ctx.targetWatching and self.seenFor + dt or 0

	local moveId = self.move and self.move.id
	local busy = moveId == "Yank" or moveId == "Lunge" or moveId == "BackAway" or moveId == "Withdraw"

	-- Reactions --------------------------------------------------------------------
	if not busy then
		-- Walk right up to him and he lunges (before he can flee or hold).
		local victim, victimDistance = self:_contactVictim(now, ctx)
		if victim then
			self.contactLast[victim] = now
			self.target, self.targetSince = victim, now
			self.sensedPos, self.sensedSeen = self:Known(victim)
			ctx.contact, ctx.distance = true, victimDistance
			self:_begin("Lunge", ctx)
		elseif StalkRules.flees(tier, self.seenFor, G) and not self:Hidden(now) then
			self:_begin("Yank", ctx)
		elseif StalkRules.backsOff(tier, self.watchedFor, nearestDistance, G) then
			self:_begin("BackAway", ctx)
		elseif self:_lungeCheck(now, ctx) then
			self:_begin("Lunge", ctx)
		end
	end
	self:_tells(now, ctx)
	self:_provocation(dt, ctx)

	-- Moves ----------------------------------------------------------------------------
	-- A fresh noise nobody made cuts a walk by habit short: he goes to look.
	if
		self.move
		and (self.move.id == "Search" or self.move.id == "DistantRoam")
		and now - self.move.started > 0.5
		and self.service.perception:FreshLure(G.LureFreshSeconds)
		and self:_lureTempts(ctx)
	then
		if MOVES[self.move.id].stop then
			MOVES[self.move.id].stop(self, self.move)
		end
		self.move = nil
		self.nextChoice = 0
		self:_begin("Investigate", ctx)
	end
	local move = self.move
	if move then
		local done = MOVES[move.id].update(self, move, now, ctx)
		if done and self.move == move then
			if MOVES[move.id].stop then
				MOVES[move.id].stop(self, move)
			end
			self.move = nil
		end
	end
	if not self.move and now >= (self.nextChoice or 0) then
		self.nextChoice = now + 1 / G.BrainHz
		if tier <= 1 and now < self.hiddenUntil then
			-- Unseen between appearances: walk somewhere new, by habit.
			if self:_lureTempts(ctx) and self:_begin("Investigate", ctx) then
				-- A noise nobody made: he goes to look first.
				return
			elseif tier == 0 or not self:_begin("Search", ctx) then
				self:_begin("DistantRoam", ctx)
			end
		elseif self.forceMove then
			-- Debug console: "guest move <name>".
			local id = self.forceMove
			self.forceMove = nil
			self:_begin(id, ctx)
		else
			local id, scored = self:_choose(ctx)
			if not self:_begin(id, ctx, scored) and id ~= "DistantRoam" then
				-- Couldn't do it (no peek spot...): look for them by habit.
				if id == "Search" or tier == 0 or not self:_begin("Search", ctx) then
					self:_begin("DistantRoam", ctx)
				end
			end
		end
		if not self.move then
			-- Nothing to do: stand still where he is, facing the room.
			self.body:Hold()
			self.body:SetPose(Poses.Idle)
		end
	end
end

-- Shining a torch in his face up close, at tiers 2-3, provokes a hunt
-- (doc section 5, kept from the old intrusions).
function Stalk:_provocation(dt: number, ctx)
	local target = self.target
	if ctx.tier < 2 or not target or not ctx.targetWatching or ctx.distance > 10 then
		self.provoke = 0
		return
	end
	if self.services.PlayerStateService:FlashlightOn(target) then
		self.provoke = (self.provoke or 0) + dt
		if self.provoke >= Config.Stalker.ProvokeFlashlightSeconds then
			self.provoke = 0
			Net.get("Notify"):FireClient(target, "You provoked it.", "danger")
			self.service:ForceHunt("provoked")
		end
	end
end

-- Debug console: end the current move and start this one next.
function Stalk:DebugMove(name: string?): string
	for id in MOVES do
		if string.lower(id) == string.lower(name or "") then
			if self.move and MOVES[self.move.id].stop then
				MOVES[self.move.id].stop(self, self.move)
			end
			self.move = nil
			self.hiddenUntil = 0
			self.nextChoice = 0
			self.forceMove = id
			return "next move " .. id
		end
	end
	local names = {}
	for id in MOVES do
		table.insert(names, id)
	end
	table.sort(names)
	return "moves: " .. table.concat(names, ", ")
end

-- Debug console: how many doorway peek spots pass each filter right now.
function Stalk:DebugPeeks(tier: number): string
	self:_pickTarget(os.clock())
	local why = {}
	local spot = self:_findPeek(math.max(tier, 1), why)
	return string.format(
		"target %s · spots %d · near %d · in range %d · line %d · picked %s",
		self.target and self.target.DisplayName or "-",
		why.spots or 0,
		why.near or 0,
		why.range or 0,
		why.line or 0,
		spot and string.format("(%.0f, %.0f)", spot.position.X, spot.position.Z) or "none"
	)
end

-- For the debug overlay and the Dossier.
function Stalk:Summary()
	local list = {}
	for id, count in self.counts do
		local move = StalkMoves.ById[id]
		if move then
			table.insert(list, { move = id, count = count, description = move.description })
		end
	end
	table.sort(list, function(a, b)
		return a.count > b.count
	end)
	return list
end

-- Debug console: what he believes about his target (rooms, most likely first).
function Stalk:_beliefLine(): string
	local target = self.target
	if not target then
		return "belief: no target"
	end
	local parts = {}
	for _, entry in self:_belief(target):Top(3) do
		table.insert(parts, string.format("room %d %.0f%%", entry.room, entry.p * 100))
	end
	return string.format(
		"belief: %s · %s",
		self.sensedPos and (self.sensedSeen and "sees them" or "last known") or "LOST",
		table.concat(parts, ", ")
	)
end

function Stalk:DebugLines(): { string }
	local last = self.log[#self.log]
	return {
		string.format(
			"move %s · target %s",
			self.move and self.move.id or "-",
			self.target and self.target.DisplayName or "-"
		),
		last and ("top " .. table.concat(last.top, ", ")) or "",
		self:_beliefLine(),
		string.format(
			"seen %.1fs · watched %.1fs · hidden %s · last failed %s",
			self.seenFor,
			self.watchedFor,
			tostring(self:Hidden(os.clock())),
			tostring(self.lastFailed or "-")
		),
	}
end

return Stalk
