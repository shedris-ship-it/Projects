-- Doors (doc section 5, "Loop mechanics"): players open and close them with a
-- prompt and can brace a closed door for a short time. The stalker needs
-- 1.5-3 seconds to open a closed door, longer if braced, and every door it
-- opens makes noise.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Sfx = require(Shared.Lib.Sfx)

local DoorService = {}

local OPEN_ANGLE = math.rad(100)
local BRACE_SECONDS = 10
local BRACE_COOLDOWN = 30

function DoorService:Init(services)
	self.World = services.WorldService
	self.Noise = services.NoiseService
	self.PlayerState = services.PlayerStateService
	self.SquadProfile = services.SquadProfileService
end

function DoorService:Start()
	self.World.Built:Connect(function(world)
		for _, door in world.doors do
			self:_setup(door)
		end
	end)
end

function DoorService:_setup(door)
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

-- Swing the slab and everything on it (panels, knob) together.
function DoorService:_tweenTo(door, cf: CFrame)
	local slab = door.slab
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, p in door.model:GetChildren() do
		if p:IsA("BasePart") and p ~= slab then
			local offset = slab.CFrame:ToObjectSpace(p.CFrame)
			TweenService:Create(p, info, { CFrame = cf * offset }):Play()
		end
	end
	TweenService:Create(slab, info, { CFrame = cf }):Play()
end

-- Open toward room `b` side so the slab swings out of the doorway.
function DoorService:SetOpen(door, open: boolean, byPlayer: Player?, slam: boolean?)
	if door.open == open then
		return
	end
	door.open = open
	local target = door.closedCFrame
	if open then
		local hinge = door.hinge
		local rotation = CFrame.new(hinge) * CFrame.Angles(0, OPEN_ANGLE, 0) * CFrame.new(-hinge)
		target = rotation * door.closedCFrame
		door.bracedUntil = 0
	end
	door.slab.CanCollide = not open
	self:_tweenTo(door, target)
	door.prompt.ActionText = open and "Close" or "Open"
	door.bracePrompt.Enabled = not open and os.clock() - door.lastBraced >= BRACE_COOLDOWN
	local radius = slam and 35 or 18
	self.Noise:Emit(door.position, radius, byPlayer, slam and "slam" or "door")
	-- Through the client so the sliders, muffling and rolloff apply.
	Sfx.play(slam and "DoorSlam" or (open and "DoorOpen" or "DoorClose"), door.position, slam and 1 or 0.6, 1)
end

function DoorService:Toggle(door, player: Player?)
	self:SetOpen(door, not door.open, player, false)
end

-- How long the stalker needs to get through a door, or 0 if it's open.
function DoorService:StalkerDelay(door, rng): number
	if door.open then
		return 0
	end
	local range = Config.Stalker.DoorOpenSeconds
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
