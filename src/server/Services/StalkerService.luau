-- The stalker (doc section 5). Three layers:
--   Director  (Stalker/Director)  pacing: target tier, hunts, scares
--   Tactician (Stalker/Tactician) decisions during hunts, from the squad profile
--   Body      (this service, Stalker/Perception, Stalker/Navigator)
--
-- The observation rule:
--   watched by nobody     -> it repositions freely
--   watched by one player -> it holds still, then edges closer
--   watched by two or more-> it is frozen; hold the stare ~3 s with Focus
--                            and it retreats
--
-- Tiers: 0 Dormant, 1 Watching, 2 Closing, 3 Intruding, 4 Hunting.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Assets = require(Shared.Assets)
local Archetypes = require(Shared.Data.Archetypes)
local Net = require(Shared.Net)

local StalkerFolder = script.Parent.Parent:WaitForChild("Stalker")
local StalkerModel = require(StalkerFolder.StalkerModel)
local Navigator = require(StalkerFolder.Navigator)
local Perception = require(StalkerFolder.Perception)
local Tactician = require(StalkerFolder.Tactician)
local Director = require(StalkerFolder.Director)

local S = Config.Stalker
local Modes = Constants.StalkerModes
local RS = Constants.RunState

local TIER_MODES = { [0] = Modes.Dormant, [1] = Modes.Watching, [2] = Modes.Closing, [3] = Modes.Intruding }

local StalkerService = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function StalkerService:Init(services)
	self.services = services
	self.active = false
	self.body = nil
	self.mode = Modes.Dormant
	self.tier = 0
	self.visibleTo = {}
end

function StalkerService:Start()
	self.runState = ReplicatedStorage:WaitForChild("RunState")
	self.services.WorldService.Cleared:Connect(function()
		self:Stop()
	end)
	self.services.WitnessService.Anchored:Connect(function(id)
		if id == "stalker" and self.active then
			self.frozenUntil = os.clock() + Config.Witness.StalkerAnchorSeconds
		end
	end)
	local bodyAccumulator, directorAccumulator = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		if not self.active or not self.body then
			return
		end
		bodyAccumulator += dt
		directorAccumulator += dt
		if bodyAccumulator >= 1 / S.BodyHz then
			local step = bodyAccumulator
			bodyAccumulator = 0
			local ok, err = pcall(self._update, self, step)
			if not ok then
				warn("[Consensus] stalker update failed: " .. tostring(err))
			end
		end
		if directorAccumulator >= 1 then
			directorAccumulator = 0
			local ok, err = pcall(self._direct, self)
			if not ok then
				warn("[Consensus] director failed: " .. tostring(err))
			end
		end
	end)
end

-- Lifecycle -----------------------------------------------------------------

-- ctx = { archetype = id, rng, difficulty, anomalyId, runStart }
function StalkerService:Begin(ctx)
	self:Stop()
	local archetype = Archetypes[ctx.archetype] or Archetypes.TheGuest
	self.archetype = archetype
	self.rng = ctx.rng
	self.difficulty = ctx.difficulty
	self.twist = ctx.anomalyId
	self.runStart = ctx.runStart
	self.body = StalkerModel.build(archetype, self.services.WorldService.folder)
	self.perception = Perception.new(self.services, self.body)
	self.perception.hearingMultiplier = archetype.hearingMultiplier or 1
	self.navigator = Navigator.new(self.services, self.body, self.rng:Fork("nav"))
	self.navigator.canTeleport = function()
		return not self.perception:AnyoneLookingAt(self.body.root.Position)
	end
	self.tactician = Tactician.new(self.services, self.perception, archetype, self.rng:Fork("tactics"))
	self.director = Director.new(self.services, self.rng:Fork("director"), ctx.difficulty)
	self.mode = Modes.Dormant
	self.tier = 0
	self.final = false
	self.resolved = false
	self.frozenUntil = 0
	self.coStare = 0
	self.intrusionLast = {}
	self.visibleTo = {}
	self.parked = true
	self.data = {}
	self.huntCount = 0
	self.active = true
	self.services.WitnessService:Register("stalker", {
		kind = "stalker",
		position = function()
			return self.parked and Vector3.new(0, -1e4, 0) or (self.body.root.Position + Vector3.new(0, 1.5, 0))
		end,
		label = "Figure",
		radius = 6,
		anchorSeconds = Config.Witness.StalkerAnchorSeconds,
		ignore = { self.body.model },
	})
	self:_publish()
end

function StalkerService:Stop()
	self.active = false
	if self.body and self.body.model then
		self.body.model:Destroy()
	end
	self.body = nil
	self.visibleTo = {}
	self.services.WitnessService:Unregister("stalker")
	if self.runState then
		self.runState:SetAttribute(RS.Hunting, false)
		self.runState:SetAttribute(RS.StalkerMode, Modes.Dormant)
		self.runState:SetAttribute(RS.Tier, 0)
	end
end

function StalkerService:_publish()
	self.runState:SetAttribute(RS.StalkerMode, self.mode)
	self.runState:SetAttribute(RS.Tier, self.mode == Modes.Hunting and 4 or self.tier)
	self.runState:SetAttribute(RS.Hunting, self.mode == Modes.Hunting or self.mode == Modes.Telegraph)
end

-- Public queries ----------------------------------------------------------------

function StalkerService:GetPosition(): Vector3?
	if not self.active or not self.body or self.parked then
		return nil
	end
	return self.body.root.Position
end

function StalkerService:CanSeePlayer(player: Player): boolean
	if not self.active or self.parked or not self.perception then
		return false
	end
	return self.perception:CanSee(player)
end

function StalkerService:IsHunting(): boolean
	return self.active and (self.mode == Modes.Hunting or self.mode == Modes.Telegraph)
end

function StalkerService:ForceHunt(reason: string?)
	if not self.active or self.resolved then
		return
	end
	self.director:ForceHunt()
	self.forceReason = reason
end

function StalkerService:StartFinalHunt()
	if not self.active then
		return
	end
	self.final = true
	self:_beginTelegraph(5)
end

function StalkerService:EndFinalHunt()
	if not self.active then
		return
	end
	self.final = false
	self.resolved = true
	self:_retreat("resolved")
end

function StalkerService:SetTierOverride(tier: number?)
	self.tierOverride = tier
end

function StalkerService:TacticsSummary()
	return self.tactician and self.tactician:Summary() or {}
end

function StalkerService:DebugState()
	if not self.active then
		return nil
	end
	local memories = {}
	for player in self.perception.memory do
		if player.Parent then
			table.insert(memories, string.format("%s %.2f", player.DisplayName, self.perception:Confidence(player)))
		end
	end
	local last = self.tactician.log[#self.tactician.log]
	return {
		mode = self.mode,
		tier = self.tier,
		final = self.final,
		watchers = self.watchers and #self.watchers or 0,
		coStare = self.coStare,
		memories = memories,
		tactic = last and last.tactic or "-",
		top = last and last.top or {},
		target = self.data.target and self.data.target.DisplayName or (last and last.target) or "-",
		director = self.director.lastDecision and self.director.lastDecision.reason or "-",
	}
end

-- Visibility ---------------------------------------------------------------------

function StalkerService:_setVisible(set)
	local resolved = {}
	for _, player in self.services.PlayerStateService:RunPlayers() do
		local visible = set == "all" or (type(set) == "table" and set[player] == true)
		resolved[player] = visible
		if (self.visibleTo[player] == true) ~= visible then
			Net.get("StalkerVisibility"):FireClient(player, visible)
		end
	end
	self.visibleTo = resolved
end

function StalkerService:SyncPlayer(player: Player)
	Net.get("StalkerVisibility"):FireClient(player, self.visibleTo[player] == true)
end

-- Body helpers ------------------------------------------------------------------

function StalkerService:_place(position: Vector3, lookAt: Vector3?)
	local body = self.body
	local base = Vector3.new(position.X, self:_floorY(position) + body.groundOffset, position.Z)
	local target = lookAt and (flat(lookAt) + Vector3.new(0, base.Y, 0)) or (base + Vector3.new(0, 0, -1))
	if (target - base).Magnitude < 0.1 then
		target = base + Vector3.new(0, 0, -1)
	end
	body.root.Anchored = true
	body.model:PivotTo(CFrame.lookAt(base, target))
	self.parked = false
	self.navigator:Stop()
end

function StalkerService:_floorY(_: Vector3): number
	return Config.Level.Origin.y
end

function StalkerService:_park()
	local body = self.body
	body.root.Anchored = true
	body.model:PivotTo(StalkerModel.ParkCFrame)
	self.parked = true
	self.navigator:Stop()
	self:_setVisible({})
	for _, track in body.tracks do
		track:Stop(0)
	end
end

function StalkerService:_unanchor()
	local root = self.body.root
	if root.Anchored then
		root.Anchored = false
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
end

function StalkerService:_face(position: Vector3)
	local root = self.body.root
	if not root.Anchored then
		return
	end
	local here = root.Position
	local target = Vector3.new(position.X, here.Y, position.Z)
	if (target - here).Magnitude > 0.1 then
		self.body.model:PivotTo(CFrame.lookAt(here, target))
	end
end

function StalkerService:_walkTo(position: Vector3, speed: number, avoid)
	self:_unanchor()
	self.navigator:SetDestination(position, { speed = speed, avoid = avoid })
end

function StalkerService:_animate()
	local body = self.body
	local tracks = body.tracks
	local moving = not body.root.Anchored and flat(body.root.AssemblyLinearVelocity).Magnitude > 1
	local wanted = nil
	if not self.parked then
		if moving then
			wanted = body.humanoid.WalkSpeed > 12 and "run" or "walk"
		else
			wanted = "idle"
		end
	end
	if wanted ~= self.currentTrack then
		for name, track in tracks do
			if name ~= wanted and track.IsPlaying then
				track:Stop(0.2)
			end
		end
		local track = wanted and tracks[wanted]
		if track then
			track:Play(0.2)
			-- Slightly too slow: it moves like something imitating walking.
			track:AdjustSpeed(wanted == "walk" and 0.75 or 1)
		end
		self.currentTrack = wanted
	end
end

local function playSound(parent: Instance, id: string, volume: number, pitch: number)
	if id == "" or not parent then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.RollOffMaxDistance = 90
	sound.Parent = parent
	sound:Play()
	task.delay(5, function()
		sound:Destroy()
	end)
end

-- Candidate standing spots: room centres, inner corners and doorway approaches.
function StalkerService:_spots()
	local world = self.services.WorldService.World
	if self.spotCache and self.spotCacheFor == world then
		return self.spotCache
	end
	local spots = {}
	for id, room in world.rooms do
		table.insert(spots, { position = room.center, roomId = id })
		for _, offset in { Vector3.new(8, 0, 8), Vector3.new(-8, 0, 8), Vector3.new(8, 0, -8), Vector3.new(-8, 0, -8) } do
			table.insert(spots, { position = room.center + offset, roomId = id })
		end
		for _, n in self.services.WorldService:Neighbours(id) do
			table.insert(
				spots,
				{ position = self.services.WorldService:ApproachPoint(id, n, 3), roomId = id, doorway = true }
			)
		end
	end
	self.spotCache = spots
	self.spotCacheFor = world
	return spots
end

local function eyeOf(services, player: Player): Vector3?
	local head = services.PlayerStateService:Head(player)
	return head and head.Position
end

-- Is a standing spot in view of any living player (line of sight to where
-- the stalker's head would be, inside their view cone)?
function StalkerService:_spotSeen(position: Vector3): boolean
	return self.perception:AnyoneLookingAt(position + Vector3.new(0, 5, 0), 120)
end

function StalkerService:_minPlayerDistance(position: Vector3): number
	local best = math.huge
	for _, player in self.services.PlayerStateService:LivingPlayers() do
		local pos = self.services.PlayerStateService:Position(player)
		if pos then
			best = math.min(best, (flat(pos) - flat(position)).Magnitude)
		end
	end
	return best
end

function StalkerService:_lanternAvoid()
	local avoid = {}
	local world = self.services.WorldService.World
	for roomId, shrine in world.shrines do
		if shrine.lit then
			avoid[roomId] = true
		end
	end
	return avoid
end

-- Director (1 Hz) ------------------------------------------------------------------

function StalkerService:_direct()
	local now = os.clock()
	local runTime = now - self.runStart
	if self.resolved then
		return
	end
	local decision = self.director:Evaluate(runTime)
	if self.tierOverride then
		decision.tier = math.min(self.tierOverride, 3)
		if self.tierOverride >= 4 and self.mode ~= Modes.Hunting and self.mode ~= Modes.Telegraph then
			decision.huntDue = true
		end
	end
	if self.mode == Modes.Hunting or self.mode == Modes.Telegraph or self.mode == Modes.Retreating or self.final then
		return
	end
	self.tier = decision.tier
	if decision.huntDue then
		self:_beginTelegraph()
		return
	end
	local desired = TIER_MODES[self.tier] or Modes.Dormant
	if desired ~= self.mode then
		self:_enter(desired)
	end
	local card = self.director:MaybeScare(self.tier)
	if card then
		self:_scare(card)
	end
	self:_publish()
end

function StalkerService:_enter(mode: string)
	self.mode = mode
	self.data = { entered = os.clock() }
	self.coStare = 0
	if mode == Modes.Dormant then
		self:_park()
	elseif mode == Modes.Watching then
		self:_park()
		self.data.nextAppearance = os.clock() + self.rng:NextNumber(4, 12)
	elseif mode == Modes.Closing or mode == Modes.Intruding then
		self:_park()
		self.data.placed = false
	end
	self:_publish()
end

-- Scares ---------------------------------------------------------------------------

function StalkerService:_scare(card)
	local services = self.services
	local living = services.PlayerStateService:ActivePlayers()
	if #living == 0 then
		return
	end
	local victim = self.rng:Pick(living)
	for _, player in living do
		if services.PlayerStateService:IsIsolated(player) then
			victim = player
		end
	end
	local pos = services.PlayerStateService:Position(victim)
	if not pos then
		return
	end
	local divergence = services.DivergenceService
	local angle = self.rng:NextNumber(0, math.pi * 2)
	local around = pos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * self.rng:NextNumber(14, 24)
	if card.id == "knock" then
		local best, bestDistance = nil, 30
		for _, door in services.WorldService.World.doors do
			local d = (door.position - pos).Magnitude
			if not door.open and d < bestDistance and d > 6 then
				best, bestDistance = door, d
			end
		end
		if best then
			services.DoorService:Knock(best)
		end
	elseif card.id == "distantSteps" then
		divergence:Scare(victim, { kind = "steps", position = around })
	elseif card.id == "flicker" then
		local roomId = services.WorldService:RoomAt(pos)
		for _, player in services.PlayerStateService:RunPlayers() do
			divergence:Scare(player, { kind = "flicker", roomId = roomId, duration = 2.5 })
		end
	elseif card.id == "coldSpot" then
		divergence:Scare(victim, {
			kind = "coldSpot",
			position = pos + Vector3.new(self.rng:NextNumber(-4, 4), 0, self.rng:NextNumber(-4, 4)),
		})
	elseif card.id == "doorSlam" then
		for _, door in services.WorldService.World.doors do
			if door.open and (door.position - pos).Magnitude < 40 and not self:_spotSeen(door.position) then
				services.DoorService:SetOpen(door, false, nil, true)
				break
			end
		end
	elseif card.id == "whisper" then
		local root = services.PlayerStateService:Root(victim)
		local behind = root and (root.Position - root.CFrame.LookVector * 4) or around
		divergence:Scare(victim, { kind = "whisper", position = behind })
	elseif card.id == "figure" and self.tier >= 1 then
		divergence:Scare(victim, { kind = "figure", position = around, duration = 1.6 })
	end
end

-- Body update (15 Hz) ---------------------------------------------------------------

function StalkerService:_update(dt: number)
	local now = os.clock()
	local listenBoost = self.data.listening and 2 or 1
	self.perception:Update(listenBoost)
	local watchers = self.parked and {} or self.perception:Watchers(dt, self.visibleTo)
	self.watchers = watchers
	local playerWatchers = {}
	for _, w in watchers do
		if typeof(w) == "Instance" then
			table.insert(playerWatchers, w)
		end
	end
	if #playerWatchers > 0 then
		self.services.SquadProfileService:RecordGaze(dt * #playerWatchers)
	end

	-- Two Witnesses holding the stare together, with Focus, drive it off.
	local stareable = self.mode == Modes.Closing
		or self.mode == Modes.Intruding
		or self.mode == Modes.Hunting
		or self.mode == Modes.Watching
	if #watchers >= 2 and stareable and not self.parked then
		local withFocus = 0
		for _, player in playerWatchers do
			self.services.WitnessService:DrainFocus(player, Config.Witness.CoStareFocusPerSecond * dt)
			if self.services.WitnessService:Focus(player) > 0 then
				withFocus += 1
			end
		end
		if withFocus + (#watchers - #playerWatchers) >= 2 then
			self.coStare += dt
		end
		if self.coStare >= Config.Witness.CoStareSeconds then
			self.coStare = 0
			Net.get("Notify"):FireAllClients("You held its gaze together. It backs away.", "good")
			self:_retreat("stared down")
			self:_animate()
			return
		end
	else
		self.coStare = math.max(0, self.coStare - dt * 2)
	end

	local frozen = not self.parked and (#watchers >= 2 or now < (self.frozenUntil or 0))
	if frozen and self.mode ~= Modes.Retreating then
		self.navigator:Stop()
		self:_animate()
		return
	end

	local mode = self.mode
	if mode == Modes.Watching then
		self:_updateWatching(now, dt)
	elseif mode == Modes.Closing then
		self:_updateClosing(now, dt, watchers)
	elseif mode == Modes.Intruding then
		self:_updateIntruding(now, dt, watchers)
	elseif mode == Modes.Telegraph then
		self:_updateTelegraph(now)
	elseif mode == Modes.Hunting then
		self:_updateHunting(now, dt, watchers)
	elseif mode == Modes.Retreating then
		self:_updateRetreating(now)
	end
	if not self.parked and not self.body.root.Anchored then
		self.navigator:Step(now)
	end
	self:_animate()
end

-- Tier 1: a figure far down a sightline, visible to one Witness only. It is
-- gone when a friend turns to look.
function StalkerService:_updateWatching(now: number, _: number)
	local data = self.data
	local services = self.services
	if self.parked then
		if now < (data.nextAppearance or 0) then
			return
		end
		data.nextAppearance = now + 5
		local active = services.PlayerStateService:ActivePlayers()
		if #active == 0 then
			return
		end
		local viewer = self.rng:Pick(active)
		for _, player in active do
			if services.PlayerStateService:IsIsolated(player) then
				viewer = player
			end
		end
		local eye = eyeOf(services, viewer)
		local viewCF = services.WitnessService:GetView(viewer)
		if not eye or not viewCF then
			return
		end
		local candidates = {}
		for _, spot in self:_spots() do
			local d = (flat(spot.position) - flat(eye)).Magnitude
			if d >= S.Tier1MinDistance and d <= 75 then
				local head = spot.position + Vector3.new(0, 6, 0)
				local inView = viewCF.LookVector:Dot((head - viewCF.Position).Unit)
				if inView > 0.2 and services.WitnessService:ClearLine(eye, head, {}) then
					local seenByOthers = false
					for _, other in services.PlayerStateService:LivingPlayers() do
						if other ~= viewer and services.WitnessService:IsLookingAt(other, head, 120, 140) then
							seenByOthers = true
						end
					end
					if not seenByOthers and self:_minPlayerDistance(spot.position) >= S.Tier1MinDistance then
						table.insert(candidates, { spot = spot, weight = 0.5 + inView })
					end
				end
			end
		end
		if #candidates == 0 then
			return
		end
		local pick = self.rng:WeightedPick(candidates, function(c)
			return c.weight
		end)
		self:_place(pick.spot.position, eye)
		self:_setVisible({ [viewer] = true })
		data.viewer = viewer
		data.appearedAt = now
		data.seen = false
		data.notWatchedFor = 0
		return
	end
	-- On stage: stare at the viewer.
	local viewer = data.viewer
	local eye = viewer and viewer.Parent and eyeOf(services, viewer)
	if not eye then
		self:_vanish(now)
		return
	end
	self:_face(eye)
	local torso = self.body.root.Position + Vector3.new(0, 1.5, 0)
	for _, other in services.PlayerStateService:LivingPlayers() do
		if
			other ~= viewer
			and services.WitnessService:IsLookingAt(other, torso, S.WatchConeDegrees, S.WatchRange, { self.body.model })
		then
			self:_vanish(now)
			return
		end
	end
	local watched = (self.perception.watchTime[viewer] or 0) >= S.WatchedAfterSeconds
	if watched then
		data.seen = true
		data.notWatchedFor = 0
	elseif data.seen then
		data.notWatchedFor += 1 / S.BodyHz
		if data.notWatchedFor > 0.6 then
			self:_vanish(now)
			return
		end
	end
	if now - data.appearedAt > S.Tier1VisibleMaxSeconds then
		self:_vanish(now)
	end
end

function StalkerService:_vanish(now: number)
	self:_park()
	self.data.viewer = nil
	self.data.nextAppearance = now + self.rng:NextNumber(S.Tier1Cooldown[1], S.Tier1Cooldown[2])
end

-- Pick a target for stalking: whoever is alone, else anyone.
function StalkerService:_chooseTarget(): Player?
	local services = self.services
	local active = services.PlayerStateService:ActivePlayers()
	local target = self.rng:Pick(active)
	for _, player in active do
		if services.PlayerStateService:IsIsolated(player) then
			target = player
		end
	end
	return target
end

-- Out-of-sight spot between minD and maxD studs from a position, preferring
-- spots that cut the distance to `toward` the most.
function StalkerService:_hiddenSpot(toward: Vector3, minD: number, maxD: number, from: Vector3?)
	local best, bestScore = nil, -math.huge
	for _, spot in self:_spots() do
		local d = (flat(spot.position) - flat(toward)).Magnitude
		if
			d >= minD
			and d <= maxD
			and self:_minPlayerDistance(spot.position) >= minD
			and not self:_spotSeen(spot.position)
		then
			local score = -d + self.rng:NextNumber(0, 4)
			if from then
				score = -math.abs(d - (maxD + minD) / 2) + self.rng:NextNumber(0, 3)
			end
			if score > bestScore then
				best, bestScore = spot, score
			end
		end
	end
	return best
end

-- Tier 2: closer every time you look.
function StalkerService:_updateClosing(now: number, dt: number, watchers)
	local data = self.data
	local services = self.services
	if not data.target or not data.target.Parent or not services.PlayerStateService:IsActive(data.target) then
		data.target = self:_chooseTarget()
		data.placed = false
	end
	local target = data.target
	local targetPos = target and services.PlayerStateService:Position(target)
	if not targetPos then
		return
	end
	if not data.placed then
		local spot = self:_hiddenSpot(targetPos, 22, 36, self.body.root.Position)
		if spot then
			self:_place(spot.position, targetPos)
			self:_setVisible("all")
			data.placed = true
			data.detected = false
			data.singleWatch = 0
			data.lastMove = now
		end
		return
	end
	local here = self.body.root.Position
	local distance = self:_minPlayerDistance(here)
	if distance < S.Tier2MinDistance then
		-- Never attacks at tier 2: it simply isn't there any more.
		self:_park()
		data.placed = false
		return
	end
	if #watchers == 1 then
		data.detected = true
		if now < (data.stepUntil or 0) then
			return -- finishing a slow step
		end
		data.singleWatch += dt
		self.navigator:Stop()
		self.body.root.Anchored = true
		self:_face(targetPos)
		if data.singleWatch >= S.Tier2ReactionDelay then
			-- One slow step closer, while you watch.
			data.singleWatch = 0
			local step = flat(targetPos - here)
			if step.Magnitude > S.Tier2MinDistance + 3 then
				self:_walkTo(here + step.Unit * 3, S.StalkSpeed)
				data.stepUntil = now + 1.4
			end
		end
	elseif #watchers == 0 then
		data.singleWatch = 0
		if data.detected then
			-- Relocate 8-15 studs closer while nobody looks.
			local current = (flat(here) - flat(targetPos)).Magnitude
			local stepMin, stepMax = S.Tier2Step[1], S.Tier2Step[2]
			local spot = self:_hiddenSpot(
				targetPos,
				math.max(S.Tier2MinDistance + 2, current - stepMax),
				math.max(S.Tier2MinDistance + 3, current - stepMin)
			)
			if spot then
				self:_place(spot.position, targetPos)
				data.detected = false
				data.lastMove = now
			end
		elseif now - data.lastMove > 20 then
			data.lastMove = now
			self:_walkTo(targetPos, S.StalkSpeed)
		elseif self.navigator:Arrived() then
			self.body.root.Anchored = true
			self:_face(targetPos)
		end
	end
end

-- Tier 3: intrusions. In a doorway, within arm's reach, without attacking
-- unless provoked. At most one per Witness every two minutes.
function StalkerService:_updateIntruding(now: number, dt: number, watchers)
	local data = self.data
	local services = self.services
	local intrusion = data.intrusion
	if not intrusion then
		-- Between intrusions it stalks like tier 2.
		self:_updateClosing(now, dt, watchers)
		if (data.nextCheck or 0) > now then
			return
		end
		data.nextCheck = now + 1
		for _, player in services.PlayerStateService:ActivePlayers() do
			local last = self.intrusionLast[player] or -math.huge
			local pos = services.PlayerStateService:Position(player)
			if
				pos
				and now - last >= S.IntrusionCooldownPerPlayer
				and not services.WorldService:IsLanternRoom(services.WorldService:RoomAt(pos))
				and self.rng:Chance(0.12)
			then
				self:_beginIntrusion(player, now)
				return
			end
		end
		return
	end

	local target = intrusion.target
	local targetPos = target.Parent and services.PlayerStateService:Position(target)
	if not targetPos or not services.PlayerStateService:IsActive(target) then
		data.intrusion = nil
		self:_park()
		data.placed = false
		return
	end
	if intrusion.stage == "silence" then
		if now >= intrusion.at then
			local roomId = services.WorldService:RoomAt(targetPos)
			local spot = nil
			if roomId then
				for _, n in services.WorldService:Neighbours(roomId) do
					local p = services.WorldService:ApproachPoint(roomId, n, 2)
					if (flat(p) - flat(targetPos)).Magnitude >= 6 and not self:_spotSeen(p) then
						spot = p
						break
					end
				end
			end
			if not spot then
				data.intrusion = nil
				return
			end
			self:_place(spot, targetPos)
			self:_setVisible("all")
			intrusion.stage = "approach"
			intrusion.provoke = 0
			local door = nil
			for _, d in services.WorldService.World.doors do
				if (d.position - spot).Magnitude < 8 then
					door = d
				end
			end
			if door and not door.open then
				services.DoorService:Knock(door)
			else
				playSound(self.body.head, Assets.Sounds.Groan, 0.35, 0.45)
			end
		end
		return
	end
	local here = self.body.root.Position
	local distance = (flat(here) - flat(targetPos)).Magnitude
	-- Provoked: shining a light in its face up close, or running into it.
	local watchingIt = (self.perception.watchTime[target] or 0) > 0
	if watchingIt and services.PlayerStateService:FlashlightOn(target) and distance < 10 then
		intrusion.provoke += dt
	end
	if intrusion.provoke >= S.ProvokeFlashlightSeconds or distance < 2.2 then
		data.intrusion = nil
		Net.get("Notify"):FireClient(target, "You provoked it.", "danger")
		self:ForceHunt("provoked")
		return
	end
	if intrusion.stage == "approach" then
		if distance > 4 then
			self:_walkTo(targetPos, S.StalkSpeed)
		else
			self.navigator:Stop()
			self.body.root.Anchored = true
			self:_face(targetPos)
			intrusion.stage = "hold"
			intrusion.holdUntil = now + self.rng:NextNumber(S.IntrusionHoldSeconds[1], S.IntrusionHoldSeconds[2])
		end
		if now - intrusion.started > 14 then
			intrusion.stage = "leave"
		end
	elseif intrusion.stage == "hold" then
		self:_face(targetPos)
		if now >= intrusion.holdUntil then
			intrusion.stage = "leave"
		end
	elseif intrusion.stage == "leave" then
		if #watchers == 0 then
			data.intrusion = nil
			self:_park()
			data.placed = false
		else
			local away = here + flat(here - targetPos).Unit * 10
			self:_walkTo(away, S.WalkSpeed)
		end
	end
end

function StalkerService:_beginIntrusion(player: Player, now: number)
	self.intrusionLast[player] = now
	self:_park()
	self.data.intrusion = { target = player, stage = "silence", at = now + 1.6, started = now + 1.6 }
	-- Silence as a weapon: drop the ambience before it arrives.
	for _, p in self.services.PlayerStateService:RunPlayers() do
		self.services.DivergenceService:Scare(p, { kind = "silence", duration = 1.8 })
	end
end

-- Tier 4 --------------------------------------------------------------------------

function StalkerService:_beginTelegraph(seconds: number?)
	local duration = seconds or self.rng:NextNumber(S.TelegraphSeconds[1], S.TelegraphSeconds[2])
	self:_park()
	self.mode = Modes.Telegraph
	self.data = { telegraphUntil = os.clock() + duration }
	Net.get("HuntState")
		:FireAllClients({ state = "telegraph", duration = duration, final = self.final, reason = self.forceReason })
	self.forceReason = nil
	self:_publish()
end

function StalkerService:_updateTelegraph(now: number)
	if now < self.data.telegraphUntil then
		return
	end
	-- Enter at least 30 studs from everyone, out of sight.
	local best, bestScore = nil, -math.huge
	for _, spot in self:_spots() do
		local d = self:_minPlayerDistance(spot.position)
		if d >= 30 and not self:_spotSeen(spot.position) then
			local score = -math.abs(d - 38) + self.rng:NextNumber(0, 6)
			if score > bestScore then
				best, bestScore = spot, score
			end
		end
	end
	if not best then
		for _, spot in self:_spots() do
			local d = self:_minPlayerDistance(spot.position)
			if d > bestScore then
				best, bestScore = spot, d
			end
		end
	end
	self:_place(best.position)
	self:_unanchor()
	self:_setVisible("all")
	self.mode = Modes.Hunting
	self.huntCount += 1
	local duration = self.rng:NextNumber(S.HuntDuration[1], S.HuntDuration[2])
	self.data = {
		started = now,
		endsAt = now + duration,
		plan = nil,
		nextDecision = 0,
		pauseUntil = 0,
	}
	Net.get("HuntState"):FireAllClients({ state = "hunt", final = self.final, duration = self.final and 0 or duration })
	self:_publish()
end

function StalkerService:_runSpeed(watchers): number
	local speed = S.SprintSpeedRatio
		* Config.Player.SprintSpeed
		* (self.difficulty.StalkerSpeedMultiplier or 1)
		* (self.archetype.speedMultiplier or 1)
	if self.final then
		speed *= 0.85
	end
	if self.twist == "Gaze" and #watchers == 0 then
		speed *= 1.2 -- Gaze: faster whenever nobody is looking
	end
	return speed
end

function StalkerService:_catch(player: Player, now: number)
	local services = self.services
	services.SquadProfileService:RecordCatch(player)
	services.PlayerStateService:Down(player)
	playSound(self.body.head, Assets.Sounds.Groan, 0.8, 0.5)
	self.navigator:Stop()
	local data = self.data
	data.pauseUntil = now + (self.final and 8 or 2.5)
	data.plan = nil
	if not self.final then
		data.endsAt = now + math.max(8, (data.endsAt - now) / 2)
	end
end

function StalkerService:_updateHunting(now: number, dt: number, watchers)
	local services = self.services
	local data = self.data
	local here = self.body.root.Position
	if now < data.pauseUntil then
		self.navigator:Stop()
		return
	end

	-- Close calls for the Dossier, and catches.
	for _, player in services.PlayerStateService:LivingPlayers() do
		local pos = services.PlayerStateService:Position(player)
		if pos then
			local d = (flat(pos) - flat(here)).Magnitude
			if d < 14 then
				services.SquadProfileService:RecordCloseCall(player, d)
			end
			if
				d <= S.CatchRadius
				and math.abs(pos.Y - here.Y) < 8
				and services.PlayerStateService:IsActive(player)
				and not services.HidingService:IsHidden(player)
				and not self.perception:InSafeRoom(player)
				and self.perception:CanSee(player)
			then
				self:_catch(player, now)
				return
			end
		end
	end

	local speed = self:_runSpeed(watchers)
	local visible = self.perception:Visible()
	local chase = nil
	for _, entry in visible do
		if services.PlayerStateService:IsActive(entry.player) then
			chase = entry.player
			break
		end
	end
	if chase then
		data.plan = nil
		data.chasing = chase
		local pos = services.PlayerStateService:Position(chase)
		self:_walkTo(pos, speed, self:_lanternAvoid())
	else
		if data.chasing then
			data.chasing = nil
			data.plan = nil
			data.nextDecision = 0
		end
		self:_runPlan(now, dt, speed)
	end

	if not self.final and now >= data.endsAt then
		self:_endHunt()
	end
end

function StalkerService:_runPlan(now: number, _dt: number, speed: number)
	local data = self.data
	local services = self.services
	if not data.plan or data.planIndex > #data.plan then
		if now < data.nextDecision then
			return
		end
		data.nextDecision = now + 1 / S.TacticianHz
		local tactic, plan = self.tactician:Decide(self.final)
		data.tactic = tactic
		data.plan = plan
		data.planIndex = 1
		data.actionStarted = nil
	end
	local action = data.plan[data.planIndex]
	if not action then
		return
	end
	local function nextAction()
		data.planIndex += 1
		data.actionStarted = nil
		self.data.listening = false
	end
	if not data.actionStarted then
		data.actionStarted = now
	end
	local elapsed = now - data.actionStarted
	if action.type == "goto" then
		local ratio = action.speed / (S.SprintSpeedRatio * Config.Player.SprintSpeed)
		self:_walkTo(action.position, speed * math.min(1, ratio), self:_lanternAvoid())
		if self.navigator:Arrived() or elapsed > 25 then
			nextAction()
		end
	elseif action.type == "wait" then
		self.navigator:Stop()
		self.data.listening = action.listen == true
		if elapsed >= action.seconds then
			nextAction()
		end
	elseif action.type == "inspect" then
		self.navigator:Stop()
		local spot = action.spot
		if not data.inspectSound then
			data.inspectSound = true
			playSound(spot.anchor, Assets.Sounds.Thud, 0.7, 0.8)
		end
		if elapsed >= S.InspectSeconds then
			data.inspectSound = nil
			local found = services.HidingService:Inspect(spot)
			for _, player in found do
				self:_catch(player, now)
			end
			nextAction()
		end
	elseif action.type == "lights" then
		for _, roomId in action.rooms do
			services.WorldService:SetRoomLight(roomId, false)
			task.delay(45, function()
				if services.WorldService.World then
					services.WorldService:SetRoomLight(roomId, true)
				end
			end)
		end
		nextAction()
	elseif action.type == "waitFocus" then
		self.navigator:Stop()
		local active = services.PlayerStateService:ActivePlayers()
		local total = 0
		for _, p in active do
			total += services.WitnessService:Focus(p)
		end
		local average = #active > 0 and total / #active or 0
		if average < action.threshold or elapsed >= action.seconds then
			nextAction()
		end
	elseif action.type == "fakePing" then
		local living = services.PlayerStateService:LivingPlayers()
		local impersonate = self.rng:Pick(living)
		if impersonate and #living >= 2 then
			services.WitnessService:FakePing(impersonate, "Follow", action.position)
		end
		nextAction()
	elseif action.type == "knock" then
		services.DoorService:Knock(action.door)
		nextAction()
	elseif action.type == "noise" then
		playSound(self.body.root, Assets.Sounds.Footstep, 1, 0.6)
		nextAction()
	else
		nextAction()
	end
end

function StalkerService:_endHunt()
	local services = self.services
	if #services.PlayerStateService:ActivePlayers() > 0 then
		services.DriftService:Apply("HuntSurvived")
		Net.get("Notify"):FireAllClients("It's over. For now.", "good")
	end
	Net.get("HuntState"):FireAllClients({ state = "end" })
	self.director:HuntEnded(os.clock())
	self:_retreat("hunt over")
end

-- After every hunt: it visibly walks away, then dissolves (doc section 5).
function StalkerService:_retreat(reason: string)
	local now = os.clock()
	local wasHunting = self.mode == Modes.Hunting or self.mode == Modes.Telegraph
	if wasHunting and reason == "stared down" and not self.final then
		self.services.DriftService:Apply("HuntSurvived")
		Net.get("HuntState"):FireAllClients({ state = "end" })
		self.director:HuntEnded(now)
	elseif reason == "stared down" and not self.final then
		self.director.retreatUntil = now + 30
	end
	self.mode = Modes.Retreating
	self.data = {
		walkUntil = now + 4,
		returnToHunt = (self.final and reason == "stared down") and now + 15 or nil,
	}
	if self.parked then
		self.data.walkUntil = now
	else
		local here = self.body.root.Position
		local best, bestDistance = nil, -1
		local hereRoom = self.services.WorldService:RoomAt(here)
		for _, n in hereRoom and self.services.WorldService:Neighbours(hereRoom) or {} do
			local center = self.services.WorldService:Room(n).center
			local d = self:_minPlayerDistance(center)
			if d > bestDistance then
				best, bestDistance = center, d
			end
		end
		if best then
			self:_walkTo(best, S.WalkSpeed)
		end
	end
	self:_publish()
end

function StalkerService:_updateRetreating(now: number)
	local data = self.data
	if not data.fading and now >= data.walkUntil then
		data.fading = true
		data.fadeUntil = now + 1.5
		Net.get("HuntState"):FireAllClients({ state = "dissolve" })
	elseif data.fading and not data.parkedAt and now >= data.fadeUntil then
		self:_park()
		data.parkedAt = now
	end
	if data.parkedAt then
		if data.returnToHunt then
			if now >= data.returnToHunt and self.final then
				self:_beginTelegraph(3)
			end
		else
			self:_enter(Modes.Dormant)
			self:_publish()
		end
	end
end

-- Keep late joiners and respawned characters consistent.
Players.PlayerRemoving:Connect(function(player)
	if StalkerService.visibleTo then
		StalkerService.visibleTo[player] = nil
	end
	if StalkerService.intrusionLast then
		StalkerService.intrusionLast[player] = nil
	end
end)

return StalkerService
