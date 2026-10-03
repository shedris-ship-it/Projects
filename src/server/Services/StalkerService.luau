-- The stalker, The Guest (doc section 5; owner decisions 2026-10-03).
--   Director  (Stalker/Director)  pacing: target tier, hunts, scares
--   Stalk     (Stalker/Stalk)     between hunts: peeks, creeping, the lunge
--   Tactician (Stalker/Tactician) decisions during hunts, from the squad profile
--   Body      (Stalker/Body, Perception, Navigator, Sight)
--
-- He is always somewhere in the house once he has arrived (three knocks at
-- the front door when the quiet start ends). He never teleports, parks or
-- dissolves after that, and never turns his back on you: retreats are him
-- backing away, still watching. Who can see him changes only while they
-- aren't looking.
--
-- The observation rule:
--   watched by nobody      -> he moves freely
--   watched by one player  -> tier 1: he's gone; tier 2: he holds and
--                             stares; tier 3: he keeps creeping
--   watched by two or more -> frozen; hold the stare ~3 s with Focus and he
--                             backs away
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
local GuestPose = require(Shared.Logic.GuestPose)
local Net = require(Shared.Net)
local StalkRules = require(Shared.Logic.StalkRules)

local StalkerFolder = script.Parent.Parent:WaitForChild("Stalker")
local StalkerModel = require(StalkerFolder.StalkerModel)
local Body = require(StalkerFolder.Body)
local Navigator = require(StalkerFolder.Navigator)
local Perception = require(StalkerFolder.Perception)
local Sight = require(StalkerFolder.Sight)
local Stalk = require(StalkerFolder.Stalk)
local Tactician = require(StalkerFolder.Tactician)
local Director = require(StalkerFolder.Director)

local S = Config.Stalker
local G = Config.Guest
local Modes = Constants.StalkerModes
local RS = Constants.RunState
local Poses = GuestPose.Poses

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
	local services = self.services
	services.WorldService.Cleared:Connect(function()
		self:Stop()
	end)
	services.WitnessService.Anchored:Connect(function(id)
		if id == "stalker" and self.active then
			self.frozenUntil = os.clock() + Config.Witness.StalkerAnchorSeconds
		end
	end)
	-- Downs and revives near a Witness keep him from lunging there for a
	-- while, so a rescue is always possible.
	local function remember(player: Player)
		if self.active and self.recentDowns then
			local pos = services.PlayerStateService:Position(player)
			if pos then
				table.insert(self.recentDowns, { position = pos, t = os.clock() })
			end
		end
	end
	services.PlayerStateService.Downed:Connect(remember)
	services.PlayerStateService.Revived:Connect(remember)

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
	self.navigator = Navigator.new(self.services, self.body, self.rng:Fork("nav"))
	self.bodyCtl = Body.new(self.body, self.navigator)
	self.perception = Perception.new(self.services, self.body, self.bodyCtl)
	self.perception.hearingMultiplier = archetype.hearingMultiplier or 1
	self.sight = Sight.new(self.services, self.bodyCtl)
	self.navigator.canTeleport = function()
		-- The stuck nudge: only while nobody could see any of him.
		return not self.sight:AnyoneSees(self.bodyCtl:ExposedPoints(), 130)
	end
	self.tactician = Tactician.new(self.services, self.perception, archetype, self.rng:Fork("tactics"))
	self.director = Director.new(self.services, self.rng:Fork("director"), ctx.difficulty)
	self.stalk = Stalk.new(self)
	self.mode = Modes.Dormant
	self.tier = 0
	self.final = false
	self.resolved = false
	self.frozenUntil = 0
	self.coStare = 0
	self.visibleTo = {}
	self.parked = true
	self.arrived = false
	self.arrivalAt = self.runStart + Config.Run.StalkerDormantSeconds
	self.knockedAt = nil
	self.data = {}
	self.huntCount = 0
	self.lungeLast = {}
	self.squadLungeLast = nil
	self.recentDowns = {}
	self.yankTo = nil
	self.active = true
	self.services.WitnessService:Register("stalker", {
		kind = "stalker",
		position = function()
			return self.parked and Vector3.new(0, -1e4, 0) or self.bodyCtl:WitnessPoint()
		end,
		-- You can't anchor what you can't see.
		visibleTo = function(player: Player)
			return self.visibleTo[player] == true
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
	self.bodyCtl = nil
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

-- What he did between hunts, for the Dossier.
function StalkerService:StalkSummary()
	return self.stalk and self.stalk:Summary() or {}
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
	local hunting = self.mode == Modes.Hunting
	local last = self.tactician.log[#self.tactician.log]
	local brain = self.stalk:DebugLines()
	local target = self.stalk:Target()
	return {
		mode = self.mode .. (self.arrived and "" or " (not arrived)"),
		tier = self.tier,
		final = self.final,
		watchers = self.watchers and #self.watchers or 0,
		coStare = self.coStare,
		memories = memories,
		tactic = hunting and (last and last.tactic or "-") or brain[1],
		top = hunting and (last and last.top or {}) or { brain[2], brain[3] },
		target = hunting and (self.data.chasing and self.data.chasing.DisplayName or (last and last.target) or "-")
			or (target and target.DisplayName or "-"),
		director = self.director.lastDecision and self.director.lastDecision.reason or "-",
	}
end

-- Debug console: "guest here|walk|pose|form|smile|lean|off" puts him in front
-- of you and poses him, for screenshots and tuning the animation.
function StalkerService:DebugGuest(player: Player, args: { string }): string
	if not self.active or not self.body then
		return "no stalker: start a run first"
	end
	local services = self.services
	local sub = args[2] or "help"
	local root = services.PlayerStateService:Root(player)
	local body = self.bodyCtl
	if sub == "here" or sub == "walk" then
		if not root then
			return "no character"
		end
		local view = services.WitnessService:GetView(player)
		local look = flat(view and view.LookVector or root.CFrame.LookVector)
		if look.Magnitude < 0.1 then
			look = Vector3.new(0, 0, -1)
		end
		local distance = tonumber(args[3]) or 10
		self.debugHold = true
		self.parked = false
		self.arrived = true
		self:_setVisible("all")
		body:SetGaze(player)
		body:FacePlayer(player)
		if sub == "here" then
			body:Place(root.Position + look.Unit * distance, root.Position)
			body:SetPose(self.debugPose or Poses.Idle)
			return string.format("guest %d studs in front of you", distance)
		end
		-- Walk past you: from the left of your view to the right.
		local side = Vector3.new(-look.Z, 0, look.X).Unit
		local start = root.Position + look.Unit * distance - side * 12
		body:Place(start, start + side)
		body:SetPose(Poses.Walk)
		body:FaceMovement()
		body:Go(start + side * 24, tonumber(args[4]) or G.WalkSpeed)
		return "guest walking across your view"
	elseif sub == "pose" then
		local wanted = string.lower(args[3] or "")
		self.debugPose = nil
		for name in Poses do
			if string.lower(name) == wanted then
				self.debugPose = name
			end
		end
		body:SetPose(self.debugPose or Poses.Idle, tonumber(args[4]))
		return "pose " .. tostring(self.debugPose or "auto")
	elseif sub == "form" then
		local form = tonumber(args[3])
		self.debugForm = form and math.clamp(math.floor(form), 0, 2) or nil
		self:_setAttr("GuestForm", self:_form())
		return "form " .. tostring(self.debugForm or "auto")
	elseif sub == "smile" then
		local amount = tonumber(args[3])
		self:_setAttr("GuestSmile", amount and math.clamp(amount, 0, 1) or nil)
		return "smile " .. tostring(amount or "auto")
	elseif sub == "lean" then
		body:SetPose(Poses.Peek, tonumber(args[3]) or 1)
		return "peeking, lean " .. tostring(tonumber(args[3]) or 1)
	elseif sub == "window" then
		-- His face at the nearest window, for you (the windowFace scare).
		local pos = root and root.Position
		local best, bestDistance = nil, math.huge
		for _, room in services.WorldService.World.rooms do
			for _, window in room.windows or {} do
				local d = pos and (window.glass.Position - pos).Magnitude or math.huge
				if window.kind == "Window" and d < bestDistance then
					best, bestDistance = window.glass, d
				end
			end
		end
		if not best then
			return "no windows"
		end
		services.DivergenceService:Scare(player, { kind = "windowFace", glass = best })
		return string.format("face at the window %.0f studs away", bestDistance)
	elseif sub == "scare" then
		-- Preview the jumpscare without being caught.
		Net.get("GuestEvent"):FireClient(player, { kind = "catch", how = "debug" })
		return "boo"
	elseif sub == "move" then
		return self.stalk:DebugMove(args[3])
	elseif sub == "peeks" then
		return self.stalk:DebugPeeks(self.tier)
	elseif sub == "arrive" then
		self.arrivalAt = os.clock()
		return "knock knock"
	elseif sub == "off" then
		self.debugHold, self.debugPose, self.debugForm = false, nil, nil
		self:_setAttr("GuestSmile", nil)
		return "guest back to normal"
	end
	return "guest here [studs] · walk · pose <name> · form <0-2> · smile <0-1> · lean <-1..1> · arrive · move <name> · peeks · window · scare · off"
end

-- Visibility ---------------------------------------------------------------------

-- Force a visibility outright (debug only): set = "all" or { [player] = true }.
function StalkerService:_setVisible(set)
	for _, player in self.services.PlayerStateService:RunPlayers() do
		local visible = set == "all" or (type(set) == "table" and set[player] == true)
		if (self.visibleTo[player] == true) ~= visible then
			self.visibleTo[player] = visible
			Net.get("StalkerVisibility"):FireClient(player, visible)
		end
	end
end

function StalkerService:SyncPlayer(player: Player)
	Net.get("StalkerVisibility"):FireClient(player, self.visibleTo[player] == true)
end

-- Who should see him now: nobody at tier 0, only his target at tier 1 (and
-- nobody while he relocates), everyone from tier 2 and in hunts.
function StalkerService:_wantVisible(player: Player, now: number): boolean
	if not self.arrived or self.parked then
		return false
	end
	local mode = self.mode
	if mode == Modes.Hunting or mode == Modes.Telegraph or mode == Modes.Retreating or mode == Modes.Departing then
		return true
	end
	if self.tier <= 1 and self.stalk:Hidden(now) then
		return false
	end
	return StalkRules.visibleTo(self.tier, player == self.stalk:Target())
end

-- Never pop in or out in front of anyone: a change only applies while that
-- player can't see where he is.
function StalkerService:_updateVisibility(now: number)
	local points = self.bodyCtl:ExposedPoints()
	for _, player in self.services.PlayerStateService:RunPlayers() do
		local want = self:_wantVisible(player, now)
		if (self.visibleTo[player] == true) ~= want then
			if not self.sight:Sees(player, points[1], 130) and not self.sight:Sees(player, points[2], 130) then
				self.visibleTo[player] = want
				Net.get("StalkerVisibility"):FireClient(player, want)
			end
		end
	end
end

-- Attributes for clients: his form, and how strongly lights sag near him.
function StalkerService:_setAttr(name: string, value: any)
	local model = self.body and self.body.model
	if model and model:GetAttribute(name) ~= value then
		model:SetAttribute(name, value)
	end
end

-- 0 Calm, 1 Fraying, 2 Breaking: the smile opens, then the porcelain cracks
-- (docs/ART.md "The Guest"). The same for everyone: decay is shared.
function StalkerService:_form(): number
	if self.debugForm then
		return self.debugForm
	end
	if self.final then
		return 2
	end
	local drift = self.services.DriftService:Value()
	local at = G.FormDrift
	return drift >= at[2] and 2 or drift >= at[1] and 1 or 0
end

-- Helpers --------------------------------------------------------------------------

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

function StalkerService:_nearestPlayer(position: Vector3): Player?
	local best, bestDistance = nil, math.huge
	for _, player in self.services.PlayerStateService:LivingPlayers() do
		local pos = self.services.PlayerStateService:Position(player)
		if pos and (flat(pos) - flat(position)).Magnitude < bestDistance then
			best, bestDistance = player, (flat(pos) - flat(position)).Magnitude
		end
	end
	return best
end

function StalkerService:_spotSeen(position: Vector3): boolean
	return self.sight:AnyoneSees(Sight.BodyPoints(position), 120)
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

local function playerPosition(services)
	return function(player: Player): Vector3?
		return services.PlayerStateService:Position(player)
	end
end

-- Backing away, still facing `face` (or whoever is nearest): towards the
-- neighbouring room furthest from everyone. Called each tick while retreating.
function StalkerService:_backAwayStep(face: Player?)
	local body = self.bodyCtl
	local here = body.root.Position
	local who = (face and face.Parent) and face or self:_nearestPlayer(here)
	if who then
		body:FacePlayer(who)
		body:SetGaze(who)
	end
	body:SetPose(Poses.BackAway)
	local worldService = self.services.WorldService
	local now = os.clock()
	if not self.backAwayGoal or now > (self.backAwayReplan or 0) or body:Arrived() then
		self.backAwayReplan = now + 2
		local best, bestDistance = nil, -1
		local room = worldService:RoomAt(here)
		local options = room and table.clone(worldService:Neighbours(room)) or {}
		if room then
			table.insert(options, room)
		end
		for _, id in options do
			local centre = worldService:Room(id).center
			local d = self:_minPlayerDistance(centre)
			if id == room then
				-- Its own room's far corner from the nearest player.
				local pos = who and self.services.PlayerStateService:Position(who)
				if pos then
					centre = here + flat(here - pos).Unit * 8
					d = self:_minPlayerDistance(centre) - 4
				end
			end
			if d > bestDistance then
				best, bestDistance = centre, d
			end
		end
		self.backAwayGoal = best
	end
	if self.backAwayGoal then
		body:Go(self.backAwayGoal, G.BackAwaySpeed)
	end
end

-- Director (1 Hz) ------------------------------------------------------------------

function StalkerService:_direct()
	local now = os.clock()
	local runTime = now - self.runStart
	self:_setAttr("GuestForm", self:_form())
	-- Forget old downs.
	for i = #self.recentDowns, 1, -1 do
		if now - self.recentDowns[i].t > G.NoLungeNearDownSeconds + 5 then
			table.remove(self.recentDowns, i)
		end
	end
	if self.resolved or self.debugHold then
		return
	end
	local decision = self.director:Evaluate(runTime)
	if self.tierOverride then
		decision.tier = math.min(self.tierOverride, 3)
		if self.tierOverride >= 4 and self.mode ~= Modes.Hunting and self.mode ~= Modes.Telegraph then
			decision.huntDue = true
		end
	end
	local presenceTier = self.mode == Modes.Hunting and 4 or self.tier
	self:_setAttr("GuestPresence", self.arrived and G.PresenceDim[presenceTier] or 0)
	if
		self.mode == Modes.Hunting
		or self.mode == Modes.Telegraph
		or self.mode == Modes.Retreating
		or self.mode == Modes.Departing
		or self.final
	then
		return
	end
	self.tier = decision.tier
	if decision.huntDue and self.arrived then
		self:_beginTelegraph()
		return
	end
	local desired = TIER_MODES[self.tier] or Modes.Dormant
	if desired ~= self.mode then
		self.mode = desired
		self:_publish()
	end
	local card = self.director:MaybeScare(self.tier)
	if card then
		self:_scare(card)
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
	elseif card.id == "windowFace" then
		self:_windowFace(victim, pos)
	end
end

-- A face at a window, for one Witness only, while he's elsewhere: tapping
-- on the glass, then there when you turn (owner, 2026-10-03). Early Drift
-- only, and never a window he could really be standing behind.
function StalkerService:_windowFace(victim: Player, pos: Vector3)
	local services = self.services
	if services.DriftService:Value() >= G.WindowFaceMaxDrift then
		return
	end
	local here = self.body.root.Position
	local best, bestDistance = nil, G.WindowFaceRange
	for _, room in services.WorldService.World.rooms do
		for _, window in room.windows or {} do
			local glass = window.glass
			local d = (glass.Position - pos).Magnitude
			if
				window.kind == "Window"
				and d < bestDistance
				and d > 6
				and (glass.Position - here).Magnitude > 30
				and self.sight:Angle(victim, glass.Position) > 70
			then
				best, bestDistance = glass, d
			end
		end
	end
	if best then
		services.DivergenceService:Scare(victim, { kind = "windowFace", glass = best })
	end
end

-- Body update (15 Hz) ---------------------------------------------------------------

function StalkerService:_update(dt: number)
	local now = os.clock()
	local body = self.bodyCtl
	self.sight:NewTick()
	if self.debugHold then
		body:Update(now, playerPosition(self.services))
		return
	end
	if not self.arrived then
		self:_updateArrival(now)
		return
	end
	self.services.SquadProfileService:SampleGaze(dt)
	local listenBoost = self.data.listening and 2 or 1
	self.perception:Update(listenBoost)
	local watchers = self.perception:Watchers(dt, self.visibleTo)
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

	-- Two Witnesses holding the stare together, with Focus, drive him off.
	if #watchers >= 2 and self.mode ~= Modes.Retreating and self.mode ~= Modes.Departing then
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
		end
	else
		self.coStare = math.max(0, self.coStare - dt * 2)
	end

	local frozen = StalkRules.frozen(#watchers, now < (self.frozenUntil or 0))
	local mode = self.mode
	if frozen and mode ~= Modes.Retreating and mode ~= Modes.Departing then
		-- Two Witnesses lock eyes on him: not a step, and no lunge.
		body:CancelSpecial()
		body:Hold()
		body:SetPose(Poses.Hold)
		local nearest = playerWatchers[1]
		if nearest then
			body:FacePlayer(nearest)
			body:SetGaze(nearest)
		end
	elseif mode == Modes.Telegraph then
		self:_updateTelegraph(now)
	elseif mode == Modes.Hunting then
		self:_updateHunting(now, dt, watchers)
	elseif mode == Modes.Retreating then
		self:_updateRetreating(now, dt, watchers)
	elseif mode == Modes.Departing then
		self:_updateDeparting(now, watchers)
	else
		self.stalk:Update(now, dt, watchers, self.tier)
	end
	body:Update(now, playerPosition(self.services))
	self:_updateVisibility(now)
end

-- Arrival: the quiet start ends with three knocks at the front door, then
-- he's inside, coming in where nobody is looking.
function StalkerService:_updateArrival(now: number)
	if now < self.arrivalAt then
		return
	end
	local services = self.services
	local world = services.WorldService.World
	local exit = world and world.exit
	if not self.knockedAt then
		self.knockedAt = now
		local doorPos = exit and exit.door and exit.door.Position or nil
		if doorPos then
			Net.get("GuestEvent"):FireAllClients({ kind = "knock", position = doorPos })
		end
		return
	end
	if now < self.knockedAt + G.ArrivalKnockLead then
		return
	end
	-- Just inside the front door if nobody's looking there, else a quiet room.
	local candidates = {}
	if exit and exit.door and world.layout.exit then
		local room = services.WorldService:Room(world.layout.exit)
		local inward = flat(room.center - exit.door.Position)
		if inward.Magnitude > 0.1 then
			table.insert(candidates, exit.door.Position + inward.Unit * 5)
		end
		table.insert(candidates, room.center)
	end
	for _ = 1, 6 do
		local id = self.rng:Pick(services.WorldService:RoomIds())
		table.insert(candidates, services.WorldService:RandomPointIn(id, self.rng))
	end
	for _, spot in candidates do
		local floor = Vector3.new(spot.X, Config.Level.Origin.y, spot.Z)
		if self.bodyCtl:Fits(floor) and not self:_spotSeen(floor) and self:_minPlayerDistance(floor) >= 15 then
			local room = services.WorldService:RoomAt(floor)
			local centre = room and services.WorldService:Room(room).center or floor + Vector3.new(0, 0, -1)
			self.bodyCtl:Place(floor, centre)
			self.parked = false
			self.arrived = true
			Net.get("GuestEvent"):FireAllClients({ kind = "arrive", position = floor })
			services.Telemetry:Log("GuestArrived", { runTime = math.floor(now - self.runStart) })
			return
		end
	end
	-- Everywhere is watched: try again shortly.
	self.knockedAt = now - G.ArrivalKnockLead + 1
end

-- Tier 4 --------------------------------------------------------------------------

function StalkerService:_beginTelegraph(seconds: number?)
	local duration = seconds or self.rng:NextNumber(S.TelegraphSeconds[1], S.TelegraphSeconds[2])
	if not self.arrived then
		-- The final hunt can't wait for the knock: he's simply there.
		self:_forceArrive()
	end
	self.mode = Modes.Telegraph
	local now = os.clock()
	self.data = { telegraphUntil = now + duration, startedAt = now }
	Net.get("HuntState")
		:FireAllClients({ state = "telegraph", duration = duration, final = self.final, reason = self.forceReason })
	self.forceReason = nil
	self:_publish()
end

function StalkerService:_forceArrive()
	local spot = self.services.WorldService:Room(self.services.WorldService:RoomIds()[1]).center
	local best, bestDistance = spot, -1
	for _, id in self.services.WorldService:RoomIds() do
		local centre = self.services.WorldService:Room(id).center
		local d = self:_minPlayerDistance(centre)
		if d > bestDistance and not self:_spotSeen(centre) then
			best, bestDistance = centre, d
		end
	end
	self.bodyCtl:Place(best)
	self.parked = false
	self.arrived = true
end

-- The telegraph starts from wherever he is. If he's close to someone, or in
-- sight, he backs away out of sight first: a chase never starts at arm's
-- length (doc: at least 3 viable escapes).
function StalkerService:_updateTelegraph(now: number)
	local body = self.bodyCtl
	local here = body.root.Position
	local near = self:_minPlayerDistance(here)
	local seen = self.sight:AnyoneSees(body:ExposedPoints())
	if near < G.HuntStartMinDistance or seen then
		self:_backAwayStep(nil)
	else
		body:Hold()
		body:SetPose(Poses.Hold)
	end
	local ready = near >= G.HuntStartMinDistance and not seen
	if now >= self.data.telegraphUntil and (ready or now >= self.data.telegraphUntil + G.HuntStartMaxWait) then
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
		body:FaceMovement()
		Net.get("HuntState")
			:FireAllClients({ state = "hunt", final = self.final, duration = self.final and 0 or duration })
		self:_publish()
	end
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

-- Walking in a hunt: facing where he goes, running pose when fast.
function StalkerService:_walkTo(position: Vector3, speed: number, avoid)
	local body = self.bodyCtl
	body:FaceMovement()
	body:SetPose(speed > 12 and Poses.Run or Poses.Walk)
	body:Go(position, speed, avoid)
end

-- Caught: down, a jumpscare for the victim, and a pause. how = "hunt" |
-- "lunge" | "inspect".
function StalkerService:_catch(player: Player, now: number, how: string?)
	local services = self.services
	services.SquadProfileService:RecordCatch(player)
	services.PlayerStateService:Down(player)
	Net.get("GuestEvent"):FireClient(player, { kind = "catch", how = how or "hunt" })
	for _, other in services.PlayerStateService:RunPlayers() do
		if other ~= player then
			Net.get("GuestEvent"):FireClient(other, { kind = "caught", position = self.body.root.Position })
		end
	end
	self.bodyCtl:Hold()
	if self.mode == Modes.Hunting then
		local data = self.data
		data.pauseUntil = now + (self.final and 8 or 2.5)
		data.plan = nil
		if not self.final then
			data.endsAt = now + math.max(8, (data.endsAt - now) / 2)
		end
	end
end

function StalkerService:_updateHunting(now: number, dt: number, watchers)
	local services = self.services
	local data = self.data
	local here = self.body.root.Position
	if now < data.pauseUntil then
		self.bodyCtl:Hold()
		self.bodyCtl:SetPose(Poses.Hold)
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
				self:_catch(player, now, "hunt")
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
		self.bodyCtl:SetGaze(chase)
		local pos = services.PlayerStateService:Position(chase)
		self:_walkTo(pos, speed, self:_lanternAvoid())
	else
		if data.chasing then
			data.chasing = nil
			data.plan = nil
			data.nextDecision = 0
		end
		self.bodyCtl:SetGaze(nil)
		self:_runPlan(now, dt, speed)
	end

	if not self.final and now >= data.endsAt then
		self:_endHunt()
	end
end

function StalkerService:_runPlan(now: number, _dt: number, speed: number)
	local data = self.data
	local services = self.services
	local body = self.bodyCtl
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
		if body:Arrived() or elapsed > 25 then
			nextAction()
		end
	elseif action.type == "wait" then
		body:Hold()
		body:SetPose(Poses.Hold)
		self.data.listening = action.listen == true
		if elapsed >= action.seconds then
			nextAction()
		end
	elseif action.type == "inspect" then
		body:Hold()
		local spot = action.spot
		body:FacePoint(spot.anchor and spot.anchor.Position or body.root.Position)
		if not data.inspectSound then
			data.inspectSound = true
			playSound(spot.anchor, Assets.Sounds.Thud, 0.7, 0.8)
		end
		if elapsed >= S.InspectSeconds then
			data.inspectSound = nil
			local found = services.HidingService:Inspect(spot)
			for _, player in found do
				self:_catch(player, now, "inspect")
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
		body:Hold()
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

-- After every hunt, a stare-down or the ritual: he backs away, slowly,
-- never looking away, until nobody can see him. He doesn't vanish; he's
-- still in the house (doc section 5 "Retreat", owner 2026-10-03).
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
	self.bodyCtl:CancelSpecial()
	self.mode = reason == "resolved" and Modes.Departing or Modes.Retreating
	self.backAwayGoal = nil
	self.data = {
		untilT = now + G.BackAwayMaxSeconds,
		unseenFor = 0,
		returnToHunt = (self.final and reason == "stared down") and now + 15 or nil,
	}
	self:_publish()
end

function StalkerService:_updateRetreating(now: number, dt: number, watchers)
	local data = self.data
	if data.returnToHunt then
		if now >= data.returnToHunt and self.final then
			self:_beginTelegraph(3)
			return
		end
	end
	self:_backAwayStep(nil)
	if #watchers == 0 and not self.sight:AnyoneSees(self.bodyCtl:ExposedPoints()) then
		data.unseenFor += dt
	else
		data.unseenFor = 0
	end
	if not data.returnToHunt and (data.unseenFor > 1.5 or now > data.untilT) then
		self.bodyCtl:Hold()
		self.mode = Modes.Dormant
		self:_publish()
	end
end

-- The ritual is done: he backs off, then stands still and bows as you
-- leave. A polite guest to the end.
function StalkerService:_updateDeparting(now: number, watchers)
	local data = self.data
	local body = self.bodyCtl
	if not data.bowing then
		self:_backAwayStep(nil)
		if self:_minPlayerDistance(body.root.Position) > 18 or now > data.untilT then
			data.bowing = true
		end
		return
	end
	body:Hold()
	body:SetPose(Poses.Bow)
	local who = watchers[1]
	if typeof(who) ~= "Instance" then
		who = self:_nearestPlayer(body.root.Position)
	end
	if who then
		body:FacePlayer(who)
		body:SetGaze(who)
	end
end

-- Keep late joiners and respawned characters consistent.
Players.PlayerRemoving:Connect(function(player)
	if StalkerService.visibleTo then
		StalkerService.visibleTo[player] = nil
	end
	if StalkerService.lungeLast then
		StalkerService.lungeLast[player] = nil
	end
end)

return StalkerService
