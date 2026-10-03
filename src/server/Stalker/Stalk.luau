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
local GazeHabits = require(Shared.Logic.GazeHabits)
local Net = require(Shared.Net)
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
	}, Stalk)
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

-- Targets --------------------------------------------------------------------------

function Stalk:_valid(player: Player?): boolean
	return player ~= nil and player.Parent ~= nil and self.services.PlayerStateService:IsActive(player)
end

-- Whoever is most alone, weighted by how rarely they look behind them.
function Stalk:_pickTarget(now: number)
	if self:_valid(self.target) and now - self.targetSince < G.TargetStickSeconds then
		return
	end
	local ps = self.services.PlayerStateService
	local profile = self.services.SquadProfileService
	local best, bestScore = nil, -math.huge
	for _, player in ps:ActivePlayers() do
		local pos = ps:Position(player)
		if pos then
			local nearest = 40
			for _, other in ps:LivingPlayers() do
				local otherPos = other ~= player and ps:Position(other)
				if otherPos then
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
	end
	self.target = best
	self.targetSince = now
end

-- Geometry helpers --------------------------------------------------------------------

function Stalk:_targetPos(): Vector3?
	return self.target and self.services.PlayerStateService:Position(self.target)
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
			local a, b = world.rooms[seam.a], world.rooms[seam.b]
			local n = flat(b.center - a.center).Unit
			local c = (a.center + b.center) / 2
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
	local head = self.target.Character and self.target.Character:FindFirstChild("Head")
	local candidates = {}
	local seams = worldService.World.seams
	for _, spot in self:_peekSpots() do
		why.spots = (why.spots or 0) + 1
		-- Only through an open doorway: a closed door would hide his head.
		local door = seams[spot.seam] and seams[spot.seam].door
		if near[spot.watches] and not (door and not door.open) then
			why.near = (why.near or 0) + 1
			local d = planar(spot.position, targetPos)
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
-- when you catch him without a door frame to hide behind.
function Stalk:_escapePoint(from: Vector3): Vector3
	local best, bestScore = nil, -math.huge
	local targetPos = self:_targetPos() or from
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		local point = from + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 9
		if
			self.body:Fits(point)
			and self.services.WitnessService:ClearLine(from + Vector3.new(0, 2, 0), point + Vector3.new(0, 2, 0), {})
		then
			local hidden = not self.sight:AnyoneSees(self.sight.BodyPoints(point))
			local score = (hidden and 100 or 0) + planar(point, targetPos)
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

-- Moves -----------------------------------------------------------------------------

local MOVES = {}

-- Walking somewhere out of everyone's sight (tier 0 and 1 he's invisible
-- anyway; his footsteps aren't).
local function relocate(self, move, now)
	self.transit = true
	if not move.walking then
		move.walking = true
		self.body:FaceMovement()
		self.body:SetPose(Poses.Walk)
		self.body:SetGaze(nil)
		self.body:Go(move.goal, G.WalkSpeed)
	end
	if self.body:Arrived() or now - move.started > 30 then
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
				if planar(self.body.root.Position, spot.position) > 2.5 then
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
		if not targetPos or planar(point, targetPos) < G.PeekMinDistance[math.clamp(ctx.tier, 1, 3)] then
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
			self.body:Go(targetPos, ctx.tier >= 3 and G.WalkSpeed * 0.8 or G.WalkSpeed)
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
		local root = self.target.Character and self.target.Character:FindFirstChild("HumanoidRootPart")
		local speed = root and flat(root.AssemblyLinearVelocity).Magnitude or 0
		if ctx.distance > move.keep + 8 then
			-- Too far to follow: close in first, unhurried.
			self.body:FaceMovement()
			self.body:SetPose(Poses.Walk)
			self.body:Go(targetPos, G.WalkSpeed)
		elseif speed < 1 or ctx.distance < move.keep then
			-- You stopped; so did he.
			self.body:Hold()
			self.body:SetPose(Poses.Idle)
		else
			self.body:FaceMovement()
			self.body:SetPose(Poses.Walk)
			self.body:Go(targetPos, math.clamp(speed * 0.95, 3, G.WalkSpeed + 2))
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
		self.service.lungeLast[target] = ctx.now
		self.service.squadLungeLast = ctx.now
		Net.get("GuestEvent")
			:FireAllClients({ kind = "lunge", target = target.UserId, position = self.body.root.Position })
		self.services.Telemetry:Log("GuestLunge", { tier = ctx.tier, distance = ctx.distance }, target)
		self.body:Lunge(target, function(player)
			move.landed = true
			local pos = self.services.PlayerStateService:Position(player)
			local here = self.body.root.Position
			local hit = pos
				and StalkRules.lungeHits(planar(pos, here), math.abs(pos.Y - here.Y), G)
				and self.services.PlayerStateService:IsActive(player)
				and not self.services.HidingService:IsHidden(player)
			if hit then
				self.service:_catch(player, os.clock(), "lunge")
			end
			self.services.Telemetry:Log("GuestLungeLanded", { hit = hit == true }, player)
		end)
		return true
	end,
	update = function(self, _move)
		if self.body:Busy() then
			return false
		end
		-- Cancelled (two Witnesses) or landed: either way he backs off.
		self:_begin("BackAway", self:_ctxCache())
		return false
	end,
}

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
	if not self.target then
		for id in feasibility do
			if id ~= "DistantRoam" then
				feasibility[id] = 0
			end
		end
	end
	if ctx.tier == 0 then
		feasibility.DistantRoam = 1
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
		local pos = ps:Position(player)
		local room = pos and worldService:RoomAt(pos)
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
	if ctx.tier < 2 or ctx.distance > G.TellRadius or ctx.backAngle < 100 then
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
			if pos and (pos - foot).Magnitude < 40 then
				Net.get("GuestEvent"):FireClient(player, { kind = "creak", position = foot })
			end
		end
		warn()
	end
end

-- Should he lunge at the target now?
function Stalk:_lungeCheck(now: number, ctx): boolean
	if ctx.tier < 3 or not self.target or ctx.distance > G.LungeRadius then
		return false
	end
	local service, services = self.service, self.services
	local target = self.target
	local pos = ctx.targetPos
	local here = self.body.root.Position
	local sinceDown = math.huge
	for _, down in service.recentDowns do
		if (down.position - pos).Magnitude <= G.NoLungeNearDownRadius then
			sinceDown = math.min(sinceDown, now - down.t)
		end
	end
	local warned = self.warned[target]
	local head = target.Character and target.Character:FindFirstChild("Head")
	local ok = StalkRules.canLunge({
		tier = ctx.tier,
		-- The debug tier override skips the early-run gate, for testing.
		runTime = service.tierOverride and math.huge or (now - service.runStart),
		watchers = ctx.watchers,
		anchored = now < (service.frozenUntil or 0),
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
	self:_pickTarget(now)
	self:_trackDoorways(now)
	local ps = self.services.PlayerStateService
	local playerWatchers = {}
	for _, w in watchers do
		if typeof(w) == "Instance" then
			table.insert(playerWatchers, w)
		end
	end
	local targetPos = self:_targetPos()
	local here = self.body.root.Position
	local view = self.target and self.sight:View(self.target)
	local nearest, nearestDistance = nil, math.huge
	for _, w in playerWatchers do
		local pos = ps:Position(w)
		if pos and planar(pos, here) < nearestDistance then
			nearest, nearestDistance = w, planar(pos, here)
		end
	end
	local ctx = {
		now = now,
		dt = dt,
		tier = tier,
		watchers = #watchers,
		nearestWatcher = nearest,
		targetPos = targetPos,
		targetLook = view and view.LookVector or nil,
		distance = targetPos and planar(targetPos, here) or math.huge,
		backAngle = (self.target and targetPos) and self.sight:Angle(self.target, here + Vector3.new(0, 5, 0)) or 0,
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
	local busy = moveId == "Yank" or moveId == "Lunge" or moveId == "BackAway"

	-- Reactions --------------------------------------------------------------------
	if not busy then
		if StalkRules.flees(tier, self.seenFor, G) and not self:Hidden(now) then
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
			-- Unseen between appearances: walk somewhere new.
			self:_begin("DistantRoam", ctx)
		elseif self.forceMove then
			-- Debug console: "guest move <name>".
			local id = self.forceMove
			self.forceMove = nil
			self:_begin(id, ctx)
		else
			local id, scored = self:_choose(ctx)
			if not self:_begin(id, ctx, scored) and id ~= "DistantRoam" then
				self:_begin("DistantRoam", ctx)
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

function Stalk:DebugLines(): { string }
	local last = self.log[#self.log]
	return {
		string.format(
			"move %s · target %s",
			self.move and self.move.id or "-",
			self.target and self.target.DisplayName or "-"
		),
		last and ("top " .. table.concat(last.top, ", ")) or "",
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
