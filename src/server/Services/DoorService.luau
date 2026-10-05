-- Doors (doc section 5, "Loop mechanics"): players open and close them with a
-- prompt and can brace a closed door for a short time. The stalker needs
-- 1.5-3 seconds to open a closed door (less for one left ajar), longer if
-- braced, and every door it opens makes noise.
--
-- Each door has an angle (docs/plans/gameplay-rework.md section 4.5): 0 shut,
-- Config.Doors.OpenAngle wide open, stepped here on the server towards a
-- target by Logic/Articulation and written with BulkMoveTo. `door.open` means
-- "open enough to walk through" (Config.Doors.PassAngle), which is all The
-- Guest's code and the passage model read. Hands will drag the angle (R1a.4).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Articulation = require(Shared.Logic.Articulation)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Sfx = require(Shared.Lib.Sfx)

local D = Config.Doors

local DoorService = {}

local BRACE_SECONDS = 10
local BRACE_COOLDOWN = 30

function DoorService:Init(services)
	self.World = services.WorldService
	self.Noise = services.NoiseService
	self.PlayerState = services.PlayerStateService
	self.SquadProfile = services.SquadProfileService
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
	door.state = Articulation.new({
		max = D.OpenAngle,
		rate = D.SwingRate,
		passAt = D.PassAngle,
		latchAt = D.LatchAngle,
		value = door.restAngle or 0,
	})
	door.open = Articulation.passable(door.state)

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
	brace.GamepadKeyCode = Enum.KeyCode.ButtonY
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

-- Where the slab is at an angle: turned about the hinge from shut.
local function slabAt(door, degrees: number): CFrame
	local hinge = door.hinge
	return CFrame.new(hinge) * CFrame.Angles(0, math.rad(degrees), 0) * CFrame.new(-hinge) * door.closedCFrame
end

function DoorService:_place(door)
	local slab = slabAt(door, door.state.value)
	local cframes = table.create(#door.parts)
	for i, offset in door.offsets do
		cframes[i] = slab * offset
	end
	Workspace:BulkMoveTo(door.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function DoorService:_step(door, dt: number)
	if not door.slab.Parent then
		self.moving[door] = nil
		return
	end
	for _, event in Articulation.step(door.state, dt, door.slamRate) do
		if event == "pass" then
			door.open = true
			door.slab.CanCollide = false
		elseif event == "block" then
			door.open = false
			door.slab.CanCollide = true
		end
	end
	self:_place(door)
	door.bracePrompt.Enabled = not door.open and os.clock() - door.lastBraced >= BRACE_COOLDOWN
	if not Articulation.moving(door.state) then
		self.moving[door] = nil
		door.slamRate = nil
	end
end

-- Swing it towards an angle (F2 `door`, and the hands next). Quiet.
function DoorService:SetAngle(door, degrees: number, rate: number?): boolean
	if not door.state then
		return false
	end
	local ok = Articulation.setTarget(door.state, degrees)
	door.slamRate = rate
	self.moving[door] = true
	door.prompt.ActionText = door.state.target >= D.PassAngle and "Close" or "Open"
	return ok
end

-- Open toward room `b` side so the slab swings out of the doorway.
function DoorService:SetOpen(door, open: boolean, byPlayer: Player?, slam: boolean?)
	local target = open and D.OpenAngle or 0
	if not door.state or door.state.target == target then
		return
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
	if os.clock() < door.bracedUntil then
		delay += Config.Stalker.BracedDoorSeconds
	end
	return delay
end

function DoorService:IsBraced(door): boolean
	return os.clock() < door.bracedUntil
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
