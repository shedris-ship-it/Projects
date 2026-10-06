-- The stalker, The Guest (doc section 5; owner decisions 2026-10-03).
--   Director  (Stalker/Director)  pacing: target tier, hunts, scares
--   Stalk     (Stalker/Stalk)     between hunts: peeks, creeping, the lunge
--   Tactician (Stalker/Tactician) decisions during hunts, from the squad profile
--   Body      (Stalker/Body, Perception, Walker, Clearance, Sight)
--
-- He is always somewhere in the house once he has arrived (three knocks at
-- the front door when the quiet start ends). He never teleports, parks or
-- dissolves after that, and never turns his back on you: retreats are him
-- backing away, still watching. Who can see him changes only while they
-- aren't looking.
--
-- The observation rule (Config.Stare since the owner's audit, 2026-10-06):
--   watched by nobody      -> he moves freely
--   watched by one player  -> tier 1: he's gone; tier 2: he holds and
--                             stares; tier 3: he keeps creeping
--   watched by two or more -> frozen; hold the stare together ~3 s and he
--                             backs away. In a hunt the stare only holds him
--                             a few seconds at a time, and never ends it
--   A look counts only while he is in that player's light. Alone, a steady
--   full beam on him counts as the second pair of eyes.
--
-- Tiers: 0 Dormant, 1 Watching, 2 Closing, 3 Intruding, 4 Hunting.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Sfx = require(Shared.Lib.Sfx)
local Archetypes = require(Shared.Data.Archetypes)
local GuestPose = require(Shared.Logic.GuestPose)
local Net = require(Shared.Net)
local Scent = require(Shared.Logic.Scent)
local StalkRules = require(Shared.Logic.StalkRules)
local Throw = require(Shared.Logic.Throw)

local StalkerFolder = script.Parent.Parent:WaitForChild("Stalker")
local StalkerModel = require(StalkerFolder.StalkerModel)
local Body = require(StalkerFolder.Body)
local Walker = require(StalkerFolder.Walker)
local NavTest = require(StalkerFolder.NavTest)
local Retreat = require(StalkerFolder.Retreat)
local Perception = require(StalkerFolder.Perception)
local Sight = require(StalkerFolder.Sight)
local Stalk = require(StalkerFolder.Stalk)
local Tactician = require(StalkerFolder.Tactician)
local Director = require(StalkerFolder.Director)

local S = Config.Stalker
local G = Config.Guest
local H = Config.Hands
local Modes = Constants.StalkerModes
local RS = Constants.RunState
local Poses = GuestPose.Poses

local TIER_MODES = { [0] = Modes.Dormant, [1] = Modes.Watching, [2] = Modes.Closing, [3] = Modes.Intruding }
local INSPECT_REACH = 7 -- studs from a hiding spot's front: further, and he can't check it

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
	-- Something thrown: did its path this step pass through him?
	services.HandsService.Moved:Connect(function(thing, from: Vector3, to: Vector3)
		self:_thrownMoved(thing, from, to)
	end)
	-- Progress wakes a hunt (docs/plans/gameplay-rework.md, R2c "pacing"):
	-- the first step into a newly opened part of the house, and the first
	-- heirloom found. (A new act arms one too: Stalker/Director.)
	services.LockService.RegionEntered:Connect(function(region: number, _player, rooms)
		if self.active and self.director then
			self:HeardProgress(self.director:Arm("region " .. region, rooms))
		end
	end)
	services.ItemService.Found:Connect(function(_player, _token, kind: string)
		if self.active and self.director and kind == "heirloom" and not self.heirloomArmed then
			self.heirloomArmed = true
			self:HeardProgress(self.director:Arm("heirloom"))
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

-- ctx = { archetype = id, rng, difficulty, runStart }
function StalkerService:Begin(ctx)
	self:Stop()
	local archetype = Archetypes[ctx.archetype] or Archetypes.TheGuest
	self.archetype = archetype
	self.rng = ctx.rng
	self.difficulty = ctx.difficulty
	self.runStart = ctx.runStart
	self.body = StalkerModel.build(archetype, self.services.WorldService.folder)
	local built = self.body
	self.navigator = Walker.new(self.services, {
		model = built.model,
		humanoid = built.humanoid,
		root = built.root,
		groundOffset = built.groundOffset,
		group = Constants.CollisionGroups.Stalker,
		halfWidth = 0.9,
		path = Walker.GuestPath,
		opensDoors = "stalker",
		-- Locks hold him only in a chase (docs/plans/gameplay-rework.md 5.5),
		-- so a hunt stays inside the part of the house the squad can reach.
		who = function()
			local mode = self.mode
			local chasing = mode == Modes.Hunting
				or mode == Modes.Telegraph
				or mode == Modes.Retreating
				or mode == Modes.Departing
			return chasing and "guestHunt" or "guest"
		end,
	}, self.rng:Fork("nav"))
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
	self.retreat = Retreat.new(self)
	self.mode = Modes.Dormant
	self.tier = 0
	self.final = false
	self.resolved = false
	self.stunnedUntil = 0
	self.stunImmuneUntil = 0
	self.stuns = {} -- when each recent stun landed (repeats are shorter)
	self.coStare = 0
	self.hold = { held = 0, spent = false, unwatched = 0 } -- the stare in a hunt (StalkRules.huntHold)
	self.holdCues = {} -- player -> times told
	self.visibleTo = {}
	self.parked = true
	self.arrived = false
	self.arrivalAt = self.runStart + Config.Run.StalkerDormantSeconds
	self.knockedAt = nil
	self.data = {}
	self.huntCount = 0
	self.heirloomArmed = false
	self.heirlooms = {}
	self.haunts = {}
	self.nextScent = 0
	self.tableCooldownUntil = 0
	self.tidyCooldownUntil = 0
	self.lungeLast = {}
	self.squadLungeLast = nil
	self.recentDowns = {}
	self.yankTo = nil
	self.active = true
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

-- His tier right now, 4 in a hunt (for the run's numbers, Logic/RunStats).
function StalkerService:TierNow(): number
	if not self.active or not self.arrived then
		return 0
	end
	return self.mode == Modes.Hunting and 4 or self.tier
end

-- Two watchers hold him right now.
function StalkerService:IsFrozen(): boolean
	return self.active and self.watchers ~= nil and StalkRules.frozen(#self.watchers)
end

function StalkerService:ForceHunt(reason: string?)
	if not self.active or self.resolved then
		return
	end
	self.director:ForceHunt()
	self.forceReason = reason
end

-- Thrown things (docs/plans/gameplay-rework.md section 4.4) ------------------

-- A thrown thing moved from `from` to `to` this step (Services/HandsService).
-- It stuns him if that path passed through his body, it was flying fast
-- enough, and its thrower could see him (tier 1 shows him to one player:
-- you can't hit what isn't there for you).
function StalkerService:_thrownMoved(thing, from: Vector3, to: Vector3)
	if not self.active or not self.arrived or self.parked or thing.hitGuest or not thing.thrower then
		return
	end
	local root = thing.root
	if not root or root.AssemblyLinearVelocity.Magnitude < H.StunMinSpeed then
		return
	end
	if self.visibleTo[thing.thrower] ~= true then
		return
	end
	local feet = self.body.root.Position - Vector3.new(0, self.body.groundOffset, 0)
	local top = feet
	for _, point in self.bodyCtl:ExposedPoints() do
		if point.Y > top.Y then
			top = point
		end
	end
	if not Throw.hits(from, to, feet, top, H.StunRadius) then
		return
	end
	-- Only on the throw's first arc: nothing can be steered into him.
	local hands = self.services.HandsService
	if not hands:OnArc(thing, to) then
		return
	end
	thing.hitGuest = true
	hands:BounceOff(thing)
	self:Stun(thing.class.stun, thing.thrower, to)
end

-- Stop him for a moment: `base` seconds, halved for each stun in the last
-- Config.Hands.StunWindow, never again within StunImmuneSeconds of one
-- ending, shorter in the final hunt. He knows who did it and where they
-- stood. Returns the seconds given (0 if he shrugged it off).
function StalkerService:Stun(base: number, by: Player?, at: Vector3?): number
	local now = os.clock()
	if not self.active or now < self.stunImmuneUntil then
		return 0
	end
	if self.mode == Modes.Retreating or self.mode == Modes.Departing then
		return 0
	end
	for i = #self.stuns, 1, -1 do
		if now - self.stuns[i] > H.StunWindow then
			table.remove(self.stuns, i)
		end
	end
	local seconds = Throw.stunSeconds(base, #self.stuns, self.final, H.StunFinalScale)
	table.insert(self.stuns, now)
	self.stunnedUntil = now + seconds
	self.stunImmuneUntil = self.stunnedUntil + H.StunImmuneSeconds
	self.bodyCtl:CancelSpecial()
	Sfx.play("Thud", at or self.body.root.Position, 0.8, 0.7)
	if by and by.Parent then
		local position = self.services.PlayerStateService:Position(by)
		if position then
			self.perception:_remember(by, position, 1, true)
		end
	end
	local telemetry = self.services.Telemetry
	if telemetry then
		telemetry:Log("GuestStunned", { seconds = math.floor(seconds * 100) / 100, by = by and by.UserId })
	end
	return seconds
end

function StalkerService:StartFinalHunt()
	if not self.active then
		return
	end
	self.final = true
	self.director:Disarm(true)
	self:_beginTelegraph(5, "final")
end

-- His things (R2c, "the Guest wants his dinner") -----------------------------------

-- Is this player carrying one of his heirlooms (Logic/Scent)?
function StalkerService:IsCarrier(player: Player): boolean
	return Scent.carrying(self.heirlooms or {}, player)
end

-- Rooms where heirlooms nobody has found yet are kept: he visits them.
function StalkerService:HauntRooms(): { [number]: boolean }
	return self.haunts or {}
end

-- For the Dossier.
function StalkerService:ErrandLines(): { string }
	return self.stalk and self.stalk:ErrandLines() or {}
end

-- Once a second: what he knows of his heirlooms, and what he wants to do
-- about them.
function StalkerService:_heirlooms(now: number)
	local items = self.services.ItemService
	if not items or not self.stalk then
		return
	end
	local heirlooms = items:Heirlooms()
	self.heirlooms = heirlooms
	local haunts = {}
	for _, h in heirlooms do
		local home = not items.found[h.token] and items:HomeOf(h.token)
		if home and home.room then
			haunts[home.room] = true
		end
	end
	self.haunts = haunts
	local worldService = self.services.WorldService
	-- The scent: the carrier's room, every few seconds.
	if now >= self.nextScent then
		self.nextScent = now + Config.Scent.Interval
		for _, sensed in Scent.targets(heirlooms, now, Config.Scent) do
			local player = sensed.player
			local at = sensed.position or self.services.PlayerStateService:Position(player)
			local room = at and worldService:RoomAt(at)
			local record = room and worldService:Room(room)
			if record and player.Parent then
				self.perception:_remember(player, record.center, Config.Scent.Confidence, false)
			end
		end
	end
	self:_errands(now, heirlooms)
end

-- Stalk couldn't reach an errand's spot: not again for a while.
function StalkerService:ErrandGaveUp(id: string)
	local now = os.clock()
	if id == "WaitAtTable" then
		self.tableCooldownUntil = now + Config.Scent.TableWaitCooldown
	elseif id == "Tidy" then
		self.tidyCooldownUntil = now + Config.Scent.TidyCooldown
	end
end

-- Waiting at the head of the table, in his place.
function StalkerService:_seatedAtTable(): boolean
	local errand = self.stalk and self.stalk.errand
	return errand ~= nil and errand.id == "WaitAtTable" and errand.arrived == true
end

-- The heirloom he meant to put back was picked up or moved.
function StalkerService:_tidyMoved(errand, heirlooms): boolean
	for _, h in heirlooms do
		if h.token == errand.token then
			return h.holder ~= nil or h.set or not h.position or (h.position - errand.position).Magnitude > 3
		end
	end
	return true
end

function StalkerService:_errands(now: number, heirlooms)
	local stalk = self.stalk
	local errand = stalk.errand
	local cfg = Config.Scent
	local finale = self.services.FinaleService
	-- Every heirloom still to set is in someone's hands: he goes to the head
	-- of the table and waits for his dinner.
	local wantTable = not self.final
		and finale
		and finale.head ~= nil
		and not finale.served
		and now >= self.tableCooldownUntil
		and Scent.allInHand(heirlooms)
	if errand and errand.id == "WaitAtTable" then
		-- (F2 `table` forces one: it lasts until the time runs out.)
		if (not wantTable and not errand.forced) or now - errand.started > cfg.TableWaitMax then
			stalk.errand = nil
			self.tableCooldownUntil = now + cfg.TableWaitCooldown
		end
	elseif wantTable then
		stalk.errand = { id = "WaitAtTable", started = now, at = finale.head, look = finale.tableFrame.Position }
		-- He's waiting for dinner, not hunting for it.
		self.director:Disarm()
	end
	-- An heirloom left lying about: he puts it back where it was kept.
	errand = stalk.errand
	if
		errand
		and errand.id == "Tidy"
		and (now - errand.started > cfg.TidyGiveUp or self:_tidyMoved(errand, heirlooms))
	then
		stalk.errand = nil
		self.tidyCooldownUntil = now + cfg.TidyCooldown
	elseif not errand and now >= self.tidyCooldownUntil and not self.final then
		for _, h in heirlooms do
			if h.position and Scent.wantsTidy(h, now, self:_minPlayerDistance(h.position), cfg) then
				stalk.errand = { id = "Tidy", started = now, token = h.token, position = h.position }
				break
			end
		end
	end
end

-- Progress was made and a hunt is waking (Stalker/Director:Arm returned the
-- seconds until it's due): somewhere near him a door slams, the house's way
-- of saying it heard. Out of everyone's sight, and only once he's in.
function StalkerService:HeardProgress(dueIn: number?)
	if not dueIn or not self.active or not self.arrived or self.parked or not self.bodyCtl then
		return
	end
	local services = self.services
	services.Telemetry:Log("HuntArmed", { dueIn = math.floor(dueIn), reason = self.director.armedReason })
	local here = self.bodyCtl.root.Position
	local best, bestDistance = nil, 30
	for _, door in services.WorldService.World.doors do
		local d = (door.position - here).Magnitude
		if door.open and not door.locked and d < bestDistance and not self:_spotSeen(door.position) then
			best, bestDistance = door, d
		end
	end
	if best then
		services.DoorService:SetOpen(best, false, nil, true)
	else
		Sfx.play("Thud", here + Vector3.new(0, 4, 0), 1, 0.6)
	end
end

-- The dinner (Services/FinaleService): he's simply there, at the head of the
-- table, looking down it.
function StalkerService:PlaceAt(position: Vector3, lookAt: Vector3?)
	if not self.active or not self.bodyCtl then
		return
	end
	-- Already waiting there (Stalk's WaitAtTable errand): he just stays.
	local here = self.bodyCtl.root.Position
	if (Vector3.new(here.X, 0, here.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude > 2 or self.parked then
		self.bodyCtl:Place(position, lookAt)
	end
	self.parked = false
	self.arrived = true
	self.services.RunLogService:Arrived()
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
	local watch = self.perception.lastWatch
	return {
		mode = self.mode .. (self.arrived and "" or " (not arrived)"),
		tier = self.tier,
		final = self.final,
		watchers = self.watchers and #self.watchers or 0,
		watch = watch and string.format(
			"lit %d · dark %d · beam %d · room %s · hold %.1f%s",
			watch.lit,
			watch.dark,
			watch.beams,
			watch.roomLit and "lit" or "dark",
			self.hold.held,
			self.hold.spent and " spent" or ""
		) or "-",
		coStare = self.coStare,
		memories = memories,
		tactic = hunting and (last and last.tactic or "-") or brain[1],
		top = hunting and (last and last.top or {}) or { brain[2], brain[3], brain[4] },
		target = hunting and (self.data.chasing and self.data.chasing.DisplayName or (last and last.target) or "-")
			or (target and target.DisplayName or "-"),
		director = self.director.lastDecision and self.director.lastDecision.reason or "-",
		nav = self:_navLine(),
	}
end

-- Where he is and where his walk is up to, for the overlay.
function StalkerService:_navLine(): string
	local worldService = self.services.WorldService
	local position = self.bodyCtl.root.Position
	local id = worldService:RoomAt(position)
	local room = id and worldService:Room(id)
	local walker = self.navigator
	return string.format(
		"%s storey %d · goal %d/%d · %d routes, %d re-plans, %d stuck, %d phases",
		self.parked and "parked" or (room and room.name or "outside"),
		worldService.FloorAt(position.Y - Config.Level.Origin.y),
		math.min(walker.index, #walker.goals),
		#walker.goals,
		walker.stats.routes,
		walker.stats.replans,
		walker.stats.stuck,
		self.bodyCtl.phases
	)
end

-- F2 `navtest [fast]` and `where` (Stalker/NavTest).
function StalkerService:NavTest(args: { string }, report: (string) -> ()): string
	return NavTest.run(self, args, report)
end

function StalkerService:DebugWhere(player: Player): string
	return NavTest.where(self, player)
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
		-- Preview the jumpscare without being caught: `guest scare [quiet|rush]`.
		Net.get("GuestEvent"):FireClient(player, { kind = "catch", how = "debug", catch = args[3] })
		return "boo" .. (args[3] and (" (" .. args[3] .. ")") or "")
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
	if self.stalk:Withdrawn(now) or (self.tier <= 1 and self.stalk:Hidden(now)) then
		return false
	end
	-- Waiting at the head of the table, he's there for everyone.
	if self:_seatedAtTable() then
		return true
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
				if want then
					-- He can be seen by someone: a beat in the run's numbers.
					self.services.RunLogService:Sighting(player.DisplayName)
				end
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
-- (docs/ART.md "The Guest"), with Dread (Logic/Dread), so a clean run sees
-- it too. The same for everyone: decay is shared.
function StalkerService:_form(): number
	if self.debugForm then
		return self.debugForm
	end
	if self.final then
		return 2
	end
	local dread = self.services.DriftService:Dread()
	local at = G.FormDrift
	return dread >= at[2] and 2 or dread >= at[1] and 1 or 0
end

-- Helpers --------------------------------------------------------------------------

-- Distances to players are walking distances (WorldService:Separation): a
-- player on the floor above is a staircase away, not right here.
function StalkerService:_minPlayerDistance(position: Vector3): number
	local best = math.huge
	local worldService = self.services.WorldService
	for _, player in self.services.PlayerStateService:LivingPlayers() do
		local pos = self.services.PlayerStateService:Position(player)
		if pos then
			best = math.min(best, worldService:Separation(pos, position))
		end
	end
	return best
end

function StalkerService:_nearestPlayer(position: Vector3): Player?
	local best, bestDistance = nil, math.huge
	local worldService = self.services.WorldService
	for _, player in self.services.PlayerStateService:LivingPlayers() do
		local pos = self.services.PlayerStateService:Position(player)
		local d = pos and worldService:Separation(pos, position)
		if d and d < bestDistance then
			best, bestDistance = player, d
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

-- Backing away, still facing `face` (or whoever is nearest), to the best
-- way out (Stalker/Retreat). Called each tick while retreating.
function StalkerService:_backAwayStep(face: Player?)
	self.retreat:Step(face)
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
	self:_heirlooms(now)
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
		self:_beginTelegraph(nil, decision.reason, decision.falseAlarm)
		return
	end
	local desired = TIER_MODES[self.tier] or Modes.Dormant
	if desired ~= self.mode then
		self.mode = desired
		self:_publish()
	end
	local card = self.director:MaybeScare(self.tier)
	if card then
		if self:_scare(card) == false then
			self.director:Unplayed(card)
		else
			self.services.RunLogService:Scare(card.id)
		end
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
	-- The house's own scares (Services/HouseEventService).
	if card.house then
		return services.HouseEventService:Play(card.id, victim, pos)
	end
	local divergence = services.DivergenceService
	local angle = self.rng:NextNumber(0, math.pi * 2)
	local around = pos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * self.rng:NextNumber(14, 24)
	if card.id == "knock" then
		local best, bestDistance = nil, 30
		for _, door in services.WorldService.World.doors do
			local d = (door.position - pos).Magnitude
			-- A door on your own floor (a knock through the ceiling isn't one).
			if not door.open and d < bestDistance and d > 6 and math.abs(door.position.Y - pos.Y) < 6 then
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
			if
				door.open
				and (door.position - pos).Magnitude < 40
				and math.abs(door.position.Y - pos.Y) < 6
				and not self:_spotSeen(door.position)
			then
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
	return true
end

-- A face at a window, for one Witness only, while he's elsewhere: tapping
-- on the glass, then there when you turn (owner, 2026-10-03). Early Drift
-- only, and never a window he could really be standing behind.
function StalkerService:_windowFace(victim: Player, pos: Vector3)
	local services = self.services
	if services.DriftService:Dread() >= G.WindowFaceMaxDrift then
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

	local mode = self.mode
	local hunting = mode == Modes.Hunting or mode == Modes.Telegraph
	-- Two watchers holding the stare together drive him off between hunts;
	-- not from his place at the table, where he only waits (they still
	-- freeze him). In a hunt the stare only holds him (below) and never
	-- ends the chase (Config.Stare.CoStareEndsHunt keeps the old rule).
	if
		#watchers >= 2
		and (not hunting or Config.Stare.CoStareEndsHunt)
		and mode ~= Modes.Retreating
		and mode ~= Modes.Departing
		and not self:_seatedAtTable()
	then
		self.coStare += dt
		if self.coStare >= Config.Witness.CoStareSeconds then
			self.coStare = 0
			Net.get("Notify"):FireAllClients("You held its gaze together. It backs away.", "good")
			self:_retreat("stared down")
		end
	else
		self.coStare = math.max(0, self.coStare - dt * 2)
	end

	local frozen = StalkRules.frozen(#watchers)
	-- In a hunt two watchers hold him a few seconds at a time, then he comes
	-- on, slowed while they still watch, until they lose him for a moment.
	local held = frozen
	if hunting then
		held = StalkRules.huntHold(self.hold, frozen, dt, Config.Stare)
	end
	self:_holdCues(held, frozen, hunting, watchers)
	if now < self.stunnedUntil and mode ~= Modes.Retreating and mode ~= Modes.Departing then
		-- Something thrown hit him: a moment off balance (Stun). The hunt
		-- waits for him.
		body:CancelSpecial()
		body:Hold()
		body:SetPose(Poses.Stagger)
		if mode == Modes.Hunting and self.data.endsAt then
			self.data.endsAt += dt
		end
	elseif held and mode ~= Modes.Retreating and mode ~= Modes.Departing then
		-- Two watchers lock eyes on him: not a step, and no lunge. A held
		-- hunt waits too: the stare buys a moment, never the clock.
		body:CancelSpecial()
		body:Hold()
		body:SetPose(Poses.Hold)
		local nearest = playerWatchers[1]
		if nearest then
			body:FacePlayer(nearest)
			body:SetGaze(nearest)
		end
		if mode == Modes.Hunting and self.data.endsAt then
			self.data.endsAt += dt
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
	-- He turns towards and lunges at where he knows you are, not where you are.
	body:Update(now, function(player: Player): Vector3?
		return (self.stalk:Known(player))
	end)
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
		-- On the storey the spot is on (he can come in upstairs).
		local floor = Vector3.new(spot.X, services.WorldService:FloorBase(spot.Y), spot.Z)
		if
			self.bodyCtl:Fits(floor)
			and not self:_spotSeen(floor)
			and self:_minPlayerDistance(floor) >= 15
			and self:_squadCanReach(floor)
		then
			local room = services.WorldService:RoomAt(floor)
			local centre = room and services.WorldService:Room(room).center or floor + Vector3.new(0, 0, -1)
			self.bodyCtl:Place(floor, centre)
			self.parked = false
			self.arrived = true
			Net.get("GuestEvent"):FireAllClients({ kind = "arrive", position = floor })
			services.Telemetry:Log("GuestArrived", { runTime = math.floor(now - self.runStart) })
			services.RunLogService:Arrived()
			return
		end
	end
	-- Everywhere is watched: try again shortly.
	self.knockedAt = now - G.ArrivalKnockLead + 1
end

-- Tier 4 --------------------------------------------------------------------------

-- `falseAlarm`: only the telegraph (the hum rises, nothing comes), one of
-- the ways hunts stay off the clock (Stalker/Director).
function StalkerService:_beginTelegraph(seconds: number?, reason: string?, falseAlarm: boolean?)
	local duration = seconds or self.rng:NextNumber(S.TelegraphSeconds[1], S.TelegraphSeconds[2])
	if not seconds and self.difficulty and self.difficulty.TelegraphScale then
		duration *= self.difficulty.TelegraphScale
	end
	if falseAlarm then
		self.services.Telemetry:Log("FalseAlarm", {
			drift = math.floor(self.services.DriftService:Value()),
			dread = math.floor(self.services.DriftService:Dread()),
			act = self.director.act,
		})
	else
		self.director:HuntBegan(reason or self.forceReason or "?")
		self.services.Telemetry:Log("HuntStarted", {
			reason = reason or self.forceReason or "?",
			drift = math.floor(self.services.DriftService:Value()),
			dread = math.floor(self.services.DriftService:Dread()),
			act = self.director.act,
		})
	end
	-- The final hunt can't wait for the knock: he's simply there. And behind a
	-- locked door from them (the escape), he's moved, unseen, to their side.
	if not self.arrived or not self:_squadCanReach(self.bodyCtl.root.Position) then
		self:_forceArrive()
	end
	self.mode = Modes.Telegraph
	self.hold = { held = 0, spent = false, unwatched = 0 }
	local now = os.clock()
	self.data = { telegraphUntil = now + duration, startedAt = now, falseAlarm = falseAlarm == true }
	Net.get("HuntState")
		:FireAllClients({ state = "telegraph", duration = duration, final = self.final, reason = self.forceReason })
	self.forceReason = nil
	-- Nobody stays bent over a puzzle while he comes (R2c).
	local puzzles = self.services.PuzzleService
	if puzzles then
		puzzles:CloseAll("Something's coming. You look up.", duration)
	end
	self:_publish()
end

-- In the escape, only where the squad can get to (Services/LockService): a
-- locked door is a wall to him too, so he must be on their side of it.
function StalkerService:_squadCanReach(position: Vector3): boolean
	local locks = self.services.LockService
	return locks == nil or locks:Reachable(position)
end

function StalkerService:_forceArrive()
	local spot = self.services.WorldService:Room(self.services.WorldService:RoomIds()[1]).center
	local best, bestDistance = spot, -1
	for _, id in self.services.WorldService:RoomIds() do
		local centre = self.services.WorldService:Room(id).center
		local d = self:_minPlayerDistance(centre)
		local reachable = self.services.LockService == nil or self.services.LockService:Reachable(id)
		if d > bestDistance and reachable and not self:_spotSeen(centre) and self.bodyCtl:Fits(centre) then
			best, bestDistance = centre, d
		end
	end
	self.bodyCtl:Place(best)
	self.parked = false
	self.arrived = true
	self.services.RunLogService:Arrived()
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
	if self.data.falseAlarm and now >= self.data.telegraphUntil then
		-- Nothing comes. The hum fades; the real one follows soon.
		Net.get("HuntState"):FireAllClients({ state = "end" })
		self.director:FalseAlarmDone(now)
		self.data = {}
		self.mode = TIER_MODES[self.tier] or Modes.Dormant
		self:_publish()
		return
	end
	if now >= self.data.telegraphUntil and (ready or now >= self.data.telegraphUntil + G.HuntStartMaxWait) then
		self.mode = Modes.Hunting
		self.huntCount += 1
		local duration = self.director:HuntDuration()
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
	-- Two watchers still on him once the hold is spent: he comes on at about
	-- a walk (Config.Stare), so the stare is a choice, not a wall.
	if watchers and StalkRules.frozen(#watchers) then
		speed *= Config.Stare.HuntWatchedSpeedScale
	end
	return speed
end

-- Tell the watchers what their eyes did, the first times it happens
-- (Config.Stare.Cues): he stopped in the light; the hold is spent and he
-- comes on anyway. Captions on the client (Controllers/GuestController).
function StalkerService:_holdCues(held: boolean, frozen: boolean, hunting: boolean, watchers)
	local beam = table.find(watchers, "beam") ~= nil
	local function tell(kind: string)
		for _, w in watchers do
			if typeof(w) == "Instance" then
				local times = self.holdCues[w] or 0
				if times < Config.Stare.Cues then
					self.holdCues[w] = times + 1
					Net.get("GuestEvent"):FireClient(w, { kind = kind, beam = beam, hunt = hunting })
				end
			end
		end
	end
	if held and not self.wasHeld then
		tell("held")
	elseif self.wasHeld and not held and frozen and hunting then
		tell("unheld")
	end
	self.wasHeld = held
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
	services.RunLogService:Catch(player.DisplayName, how or "hunt")
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
		self:_walkTo(self:_leadPoint(chase), speed, self:_lanternAvoid())
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

-- Where a fleeing player he can see will be in a moment: he runs for that,
-- not for where they were (cutting the corner they're about to take). Only
-- a spot he could stand on, on their side of any wall.
function StalkerService:_leadPoint(player: Player): Vector3
	local services = self.services
	local pos = services.PlayerStateService:Position(player)
	local root = services.PlayerStateService:Root(player)
	if not pos or not root then
		return pos or self.bodyCtl.root.Position
	end
	local velocity = flat(root.AssemblyLinearVelocity)
	if velocity.Magnitude < 2 then
		return pos
	end
	local lead = pos + velocity * G.ChaseLead
	if
		services.WorldService:RoomAt(lead)
		and services.WitnessService:ClearLine(pos, lead, { self.body.model })
		and self.bodyCtl:Fits(lead)
	then
		return lead
	end
	return pos
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
		if body:Arrived() or body:Unreachable() or elapsed > 25 then
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
		local spot = action.spot
		-- Only a spot he is standing at: a walk that timed out or found no
		-- way there never checks a hiding place from across the house.
		local front = spot.frontPosition
		local feet = body.root.Position
		if
			front
			and (
				(Vector3.new(front.X, 0, front.Z) - Vector3.new(feet.X, 0, feet.Z)).Magnitude > INSPECT_REACH
				or math.abs(front.Y - feet.Y) > 6
			)
		then
			data.inspectSound = nil
			nextAction()
			return
		end
		body:Hold()
		body:FacePoint(spot.anchor and spot.anchor.Position or body.root.Position)
		if not data.inspectSound then
			data.inspectSound = true
			if spot.anchor then
				Sfx.play("Thud", spot.anchor.Position, 0.7, 0.8)
			end
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
			services.WorldService:SetLightCause(roomId, "killed", true)
			task.delay(45, function()
				if services.WorldService.World then
					services.WorldService:SetLightCause(roomId, "killed", false)
				end
			end)
		end
		nextAction()
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
		Sfx.play("Footstep", self.body.root.Position, 1, 0.6)
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
	self.director:HuntEnded(os.clock(), "survived")
	self:_retreat("hunt over")
end

-- After every hunt, a stare-down or the ritual: he backs away, slowly,
-- never looking away, until nobody can see him. He doesn't vanish; he's
-- still in the house (doc section 5 "Retreat", owner 2026-10-03).
function StalkerService:_retreat(reason: string)
	local now = os.clock()
	local wasHunting = self.mode == Modes.Hunting or self.mode == Modes.Telegraph
	if reason == "stared down" then
		self.services.RunLogService:StareDown(wasHunting)
	end
	if wasHunting and reason == "stared down" and not self.final then
		self.services.DriftService:Apply("HuntSurvived")
		Net.get("HuntState"):FireAllClients({ state = "end" })
		self.director:HuntEnded(now, "stared down")
	elseif reason == "stared down" and not self.final then
		self.director.retreatUntil = now + 30
	end
	self.bodyCtl:CancelSpecial()
	self.mode = reason == "resolved" and Modes.Departing or Modes.Retreating
	self.retreat:Reset()
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
