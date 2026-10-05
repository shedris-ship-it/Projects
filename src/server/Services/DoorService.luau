-- Doors (doc section 5, "Loop mechanics"): players open and close them with a
-- prompt and can brace a closed door for a short time. The stalker needs
-- 1.5-3 seconds to open a closed door (less for one left ajar), longer if
-- braced, and every door it opens makes noise.
--
-- Each door has an angle (docs/plans/gameplay-rework.md section 4.5): 0 shut,
-- Config.Doors.OpenAngle wide open, stepped here on the server towards a
-- target by Logic/Articulation and written with BulkMoveTo. `door.open` means
-- "open enough to walk through" (Config.Doors.PassAngle), which is all The
-- Guest's code and the passage model read. Players drag the angle with their
-- hands (Services/HandsService, Controllers/HandsController): holding a door
-- shut braces it, and a door swung into The Guest stops dead against him.
--
-- Doors have momentum (R2c, the physics feel pass): let go of one mid-swing
-- and it swings on, bounces off the wall, slams if flung shut (loud: a lure
-- if nobody held it, a giveaway if you did), or stops ajar. It stops dead
-- against a body in its way, anyone's. While one moves, clients are told its
-- motion a few times a second (Lib/MotionState) and draw it smoothly
-- themselves (Controllers/MotionController).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Articulation = require(Shared.Logic.Articulation)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Joint = require(Shared.Lib.Joint)
local MotionState = require(Shared.Lib.MotionState)
local Net = require(Shared.Net)
local Sfx = require(Shared.Lib.Sfx)

local D = Config.Doors
local H = Config.Hands
local DOOR_LENGTH = Config.Level.DoorWidth

local DoorService = {}

local BRACE_SECONDS = 10
local BRACE_COOLDOWN = 30

function DoorService:Init(services)
	self.World = services.WorldService
	self.Push = services.PushService
	self.Noise = services.NoiseService
	self.PlayerState = services.PlayerStateService
	self.SquadProfile = services.SquadProfileService
	self.Stalker = services.StalkerService
	self.moving = {} -- [door] = true while it swings
end

function DoorService:Start()
	self.World.Built:Connect(function(world)
		for _, door in world.doors do
			self:_setup(door)
		end
	end)
	self.World.Cleared:Connect(function()
		table.clear(self.moving)
	end)
	RunService.Heartbeat:Connect(function(dt)
		for door in self.moving do
			self:_step(door, dt)
		end
	end)
end

function DoorService:_setup(door)
	-- Every part keeps its place on the slab as it swings.
	door.parts, door.offsets = {}, {}
	for _, p in door.model:GetChildren() do
		if p:IsA("BasePart") then
			table.insert(door.parts, p)
			table.insert(door.offsets, door.slab.CFrame:ToObjectSpace(p.CFrame))
		end
	end
	-- What a client needs to draw it, or turn its own copy (Controllers/
	-- MotionController, Controllers/HandsController).
	door.joint = {
		kind = "hinge",
		hinge = door.hinge,
		axis = Vector3.yAxis,
		sign = 1,
		shut = door.closedCFrame,
		max = D.OpenAngle,
		rate = D.SwingRate,
		latch = D.LatchAngle,
	}
	door.state = Articulation.new(Joint.motionSpec(door.joint, "door", door.restAngle or 0))
	door.open = Articulation.passable(door.state)
	Joint.write(door.slab, door.joint)
	door.slab:SetAttribute("Momentum", "door")
	door.slab:SetAttribute("Value", door.state.value)
	CollectionService:AddTag(door.slab, Constants.Tags.Articulated)
	door.holder, door.heldUntil, door.forcedUntil = nil, 0, 0

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DoorPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Door"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = door.slab
	prompt.Triggered:Connect(function(player)
		if not self.PlayerState:CanAct(player) then
			return
		end
		self:Toggle(door, player)
	end)

	local brace = Instance.new("ProximityPrompt")
	brace.Name = "BracePrompt"
	brace.ActionText = "Brace"
	brace.ObjectText = "Door"
	brace.KeyboardKeyCode = Enum.KeyCode.B
	-- LB: Y opens the map (Controllers/ActionController).
	brace.GamepadKeyCode = Enum.KeyCode.ButtonL1
	brace.MaxActivationDistance = 7
	brace.RequiresLineOfSight = false
	brace.HoldDuration = 0.8
	brace.UIOffset = Vector2.new(0, 60)
	brace.Parent = door.slab
	brace.Triggered:Connect(function(player)
		if not self.PlayerState:CanAct(player) or door.open then
			return
		end
		local now = os.clock()
		if now - door.lastBraced < BRACE_COOLDOWN then
			return
		end
		door.lastBraced = now
		door.bracedUntil = now + BRACE_SECONDS
		brace.Enabled = false
		task.delay(BRACE_COOLDOWN, function()
			if brace.Parent then
				brace.Enabled = not door.open
			end
		end)
	end)
	door.prompt = prompt
	door.bracePrompt = brace
end

function DoorService:_place(door)
	local slab = Joint.pose(door.joint, door.state.value)
	local cframes = table.create(#door.parts)
	for i, offset in door.offsets do
		cframes[i] = slab * offset
	end
	Workspace:BulkMoveTo(door.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Where a swing from `from` to `to` stops against The Guest, or nil. Not when
-- he's the one opening it (he stands at the doorway as it swings).
function DoorService:_guestStop(door, from: number, to: number): number?
	if door.byGuest then
		return nil
	end
	local guest = self.Stalker and self.Stalker:GetPosition()
	if not guest or math.abs(guest.Y - door.hinge.Y) > 6 then
		return nil
	end
	local shut = door.closedCFrame.Position - door.hinge
	local body = guest - door.hinge
	return Articulation.sweepStop(
		{ x = shut.X, z = shut.Z },
		{ x = body.X, z = body.Z },
		DOOR_LENGTH,
		H.GuestRadius,
		from,
		to
	)
end

-- Where a swing from `from` to `to` stops against a player standing in it,
-- or nil: a door never goes through anyone.
function DoorService:_bodyStop(door, from: number, to: number): number?
	local shut = door.closedCFrame.Position - door.hinge
	local best = nil
	for _, player in self.PlayerState:LivingPlayers() do
		local position = self.PlayerState:Position(player)
		if position and math.abs(position.Y - door.hinge.Y - 3) < 5 then
			local body = position - door.hinge
			local stop = Articulation.sweepStop(
				{ x = shut.X, z = shut.Z },
				{ x = body.X, z = body.Z },
				DOOR_LENGTH,
				H.BodyRadius,
				from,
				to
			)
			if stop and (best == nil or math.abs(stop - from) < math.abs(best - from)) then
				best = stop
			end
		end
	end
	return best
end

-- Where a swing stops against pushed furniture in its way (Services/
-- PushService lets a piece into a shut door's swing, so the door opens only
-- as far as the piece lets it).
function DoorService:_pieceStop(door, from: number, to: number): number?
	return self.Push and self.Push:SwingStop(door, from, to)
end

-- Tell whoever holds it that it stopped in their hands (against him, against
-- a body, or forced), so their own copy agrees.
function DoorService:_dragStopped(door)
	local holder = self:HeldBy(door)
	if holder then
		Net.get("DragStop"):FireClient(holder, door.id, door.state.value)
	end
end

function DoorService:_step(door, dt: number)
	if not door.slab.Parent then
		self.moving[door] = nil
		return
	end
	local state = door.state
	local now = os.clock()
	-- The hand let go (no word from it for a moment): it swings on by itself.
	if state.mode == "held" and not self:HeldBy(door) then
		Articulation.release(state)
	end
	local from = state.value
	local events = Articulation.step(state, dt, door.slamRate)
	local stop = state.value ~= from
		and (
			self:_guestStop(door, from, state.value)
			or self:_bodyStop(door, from, state.value)
			or self:_pieceStop(door, from, state.value)
		)
	if stop then
		-- It stops dead against someone, maybe someone nobody can see.
		Articulation.stop(state, stop)
		-- Stopped short of walkable (against a barricade): it's solid again,
		-- and offers to open.
		if not Articulation.passable(state) then
			door.slab.CanCollide = true
		end
		door.prompt.ActionText = state.target >= D.PassAngle and "Close" or "Open"
		self:_dragStopped(door)
		if now - (door.bumpedAt or 0) > 1 then
			door.bumpedAt = now
			Sfx.play("Thud", door.position, 0.55, 1.15)
		end
	end
	local passable = Articulation.passable(state)
	if passable ~= door.open then
		door.open = passable
		door.slab.CanCollide = not passable
	end
	local holder = self:HeldBy(door)
	-- Who last had their hands on it, for a slam that follows a fling.
	local flung = (door.lastHolder and now - (door.lastHeldAt or 0) < 2) and door.lastHolder or nil
	for _, event in events do
		-- A door moved by hand clicks as it catches and lets go; SetOpen
		-- plays its own sound.
		if event == "slam" then
			-- Flung shut: everyone hears it, and so does he.
			Sfx.play("DoorSlam", door.position, 1, 1)
			self.Noise:Emit(door.position, D.SlamNoise, flung, flung and "slam" or "lure")
		elseif event == "knock" then
			Sfx.play("Thud", door.position, 0.5, 1.3)
		elseif holder and event == "latch" then
			Sfx.play("DoorClose", door.position, 0.3, 1.1)
			self.Noise:Emit(door.position, 8, holder, "door")
		elseif holder and event == "unlatch" then
			Sfx.play("DoorOpen", door.position, 0.22, 1.05)
		end
	end
	-- Swung hard, a door is heard; eased open, it isn't.
	if holder and math.abs(state.value - from) / math.max(dt, 1e-3) > H.DragNoiseSpeed then
		if now - (door.creakedAt or 0) > 0.6 then
			door.creakedAt = now
			self.Noise:Emit(door.position, H.DragNoiseRadius, holder, "door")
			Sfx.play("DoorOpen", door.position, 0.4, 0.9)
		end
	end
	self:_place(door)
	door.bracePrompt.Enabled = not door.open and now - door.lastBraced >= BRACE_COOLDOWN
	if not Articulation.moving(state) then
		self.moving[door] = nil
		door.slamRate = nil
		door.byGuest = nil
		MotionState.settle(door.slab, math.round(state.value * 10) / 10)
	else
		MotionState.publish(door.slab, state, H.MotionHz, door.slamRate)
	end
end

-- A player's hands on the door (Services/HandsService has checked reach and
-- line of sight): turn it towards `degrees`. Quiet unless swung hard. Not
-- while he's forcing it out of their hands. `release` (degrees a second)
-- is the last word as the hand lets go: it swings on at that speed.
function DoorService:Drag(door, degrees: number, player: Player, release: number?): boolean
	if not door.state or os.clock() < door.forcedUntil then
		return false
	end
	if door.locked then
		-- Pulled on: it rattles in its frame (now and then, not 30 times a second).
		if degrees > D.LatchAngle * 2 and os.clock() - (door.triedAt or 0) > 1.2 then
			door.triedAt = os.clock()
			if self.LockHandler then
				self.LockHandler(door, player)
			end
		end
		return false
	end
	local now = os.clock()
	door.lastHolder, door.lastHeldAt = player, now
	local state = door.state
	door.slamRate = nil
	Articulation.hold(state)
	local ok = Articulation.setTarget(state, degrees)
	if release then
		door.holder, door.heldUntil = nil, 0
		Articulation.release(state, release)
	else
		door.holder = player
		door.heldUntil = now + H.HoldSeconds
	end
	self.moving[door] = true
	door.prompt.ActionText = state.target >= D.PassAngle and "Close" or "Open"
	return ok
end

-- Someone has hold of it right now.
function DoorService:HeldBy(door): Player?
	return (door.holder and os.clock() < door.heldUntil) and door.holder or nil
end

-- Swing it towards an angle (F2 `door`, and the hands next). Quiet.
function DoorService:SetAngle(door, degrees: number, rate: number?): boolean
	if not door.state then
		return false
	end
	local ok = Articulation.drive(door.state, degrees)
	door.slamRate = rate
	self.moving[door] = true
	door.prompt.ActionText = door.state.target >= D.PassAngle and "Close" or "Open"
	return ok
end

-- Open toward room `b` side so the slab swings out of the doorway.
function DoorService:SetOpen(door, open: boolean, byPlayer: Player?, slam: boolean?)
	if door.locked then
		return
	end
	local target = open and D.OpenAngle or 0
	if not door.state or door.state.target == target then
		return
	end
	if not byPlayer then
		-- The Guest (or the house) takes it: out of anyone's hands for a moment.
		door.byGuest = open or nil
		if self:HeldBy(door) then
			door.forcedUntil = os.clock() + H.ForcedSeconds
			self:_dragStopped(door)
		end
		door.holder = nil
	end
	self:SetAngle(door, target, slam and D.SlamRate or nil)
	if open then
		door.bracedUntil = 0
		-- Out of your way at once: it never shoves anyone as it swings open.
		door.slab.CanCollide = false
	elseif not Articulation.passable(door.state) then
		-- Shutting a door that never got open enough to walk through.
		door.slab.CanCollide = true
	end
	local radius = slam and 35 or 18
	self.Noise:Emit(door.position, radius, byPlayer, slam and "slam" or "door")
	-- Through the client so the sliders, muffling and rolloff apply.
	Sfx.play(slam and "DoorSlam" or (open and "DoorOpen" or "DoorClose"), door.position, slam and 1 or 0.6, 1)
end

function DoorService:Toggle(door, player: Player?)
	if door.locked then
		-- The escape's locks (Services/LockService) decide: a key, a code, a bolt.
		if self.LockHandler then
			self.LockHandler(door, player)
		end
		return
	end
	local opening = not door.state or door.state.target < D.PassAngle
	self:SetOpen(door, opening, player, false)
end

-- How long the stalker needs to get through a door, or 0 if it's open. A door
-- left ajar only needs a push.
function DoorService:StalkerDelay(door, rng): number
	if door.open then
		return 0
	end
	local ajar = door.state and not door.state.latched
	local range = ajar and Config.Stalker.AjarDoorSeconds or Config.Stalker.DoorOpenSeconds
	local delay = rng:NextNumber(range[1], range[2])
	if self:IsBraced(door) then
		delay += Config.Stalker.BracedDoorSeconds
	end
	return delay
end

-- Braced by the prompt, or held shut by someone's hands.
function DoorService:IsBraced(door): boolean
	if os.clock() < door.bracedUntil then
		return true
	end
	return self:HeldBy(door) ~= nil and door.state.target <= D.LatchAngle * 2
end

-- Locks (the escape, Services/LockService) ------------------------------------

-- Lock a door shut where it is (it's swung shut first), or unlock it. A
-- locked door is a wall to everyone (WorldService:SeamCost).
function DoorService:SetLocked(door, locked: boolean)
	if not door.state then
		return
	end
	if locked then
		local state = door.state
		state.value, state.target, state.latched = 0, 0, true
		state.velocity, state.mode, state.passing = 0, "driven", false
		door.open = false
		door.slab.CanCollide = true
		self.moving[door] = nil
		self:_place(door)
		MotionState.settle(door.slab, 0)
		Articulation.setLocked(state, true)
	else
		Articulation.setLocked(door.state, false)
	end
	door.locked = locked or nil
	door.slab:SetAttribute("Locked", locked or nil)
	-- Echoes drift through doors, but not locked ones: a lost player can't
	-- scout the part of the house the squad hasn't opened (R2c fairness).
	door.slab.CollisionGroup = locked and "Default" or Constants.CollisionGroups.Door
	door.bracePrompt.Enabled = not locked and not door.open
end

function DoorService:RefreshPrompt(door)
	door.prompt.ObjectText = door.locked and "Locked door" or "Door"
	door.prompt.ActionText = door.locked and "Try" or (door.open and "Close" or "Open")
end

-- Parts hung on a door (a lock plate) swing with it.
function DoorService:Adopt(door, model: Instance)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(door.parts, p)
			table.insert(door.offsets, door.slab.CFrame:ToObjectSpace(p.CFrame))
		end
	end
end

function DoorService:Disown(door, model: Instance)
	for i = #door.parts, 1, -1 do
		local p = door.parts[i]
		if not p.Parent or p:IsDescendantOf(model) then
			table.remove(door.parts, i)
			table.remove(door.offsets, i)
		end
	end
end

-- Bang on a braced door (noise only).
function DoorService:Bang(door)
	self.Noise:Emit(door.position, 30, nil, "slam")
	Sfx.play("DoorBang", door.position, 1, 0.9)
end

function DoorService:Knock(door)
	Sfx.play("Knock", door.position, 0.9, 1)
	task.delay(0.35, function()
		Sfx.play("Knock", door.position, 0.9, 1)
	end)
	task.delay(0.7, function()
		Sfx.play("Knock", door.position, 0.9, 1)
	end)
end

function DoorService:DoorBetween(a: number, b: number)
	local seam = self.World:SeamBetween(a, b)
	return seam and seam.door
end

DoorService.Tag = Constants.Tags.Door

return DoorService
