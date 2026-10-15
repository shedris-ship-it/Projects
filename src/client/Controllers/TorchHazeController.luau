-- Another player's torch in the air (the visual rework V2's finish; an open
-- item from the polish pass): a faint haze and dust drifting ahead of their
-- head, lit by their torch, so only what its cone reaches glows: you see
-- where a friend is shining in a dark house, and the beam sweeps through the
-- dust as they turn. No card or ribbon (the owner, 2026-10-15: they read as
-- "planks of light"). Your own torch has none: from your eye it would only
-- haze the screen.
--
-- Client only, decoration only: the light the rules use is the server's
-- SpotLight on each head (Services/PlayerStateService), unchanged.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)

local H = Config.Torch.Haze
local player = Players.LocalPlayer

local TorchHazeController = {}

function TorchHazeController:Init(controllers)
	self.state = controllers.StateController
end

local hazes = {} -- player -> { box, haze, motes, head }
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

local function emitter(rate: number, lifetime: { number }, size: { number }, transparency: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = Assets.DustTexture
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = rate
	e.Lifetime = NumberRange.new(lifetime[1], lifetime[2])
	e.Speed = NumberRange.new(0.02, 0.1)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-5, 5)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size[1], size[1] * 0.3),
		NumberSequenceKeypoint.new(1, size[2], size[2] * 0.3),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, transparency),
		NumberSequenceKeypoint.new(0.7, transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	-- Lit by the scene, drawn additively: dark unless the torch reaches it.
	e.LightInfluence = 1
	e.LightEmission = 1
	e.Enabled = false
	return e
end

local function make(head: BasePart)
	local box = Instance.new("Part")
	box.Name = "TorchHaze"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	box.Transparency = 1
	box.Size = Vector3.new(1, 1, 1)
	local haze = emitter(H.Haze.Rate, H.Haze.Lifetime, H.Haze.Size, H.Haze.Transparency)
	haze.Parent = box
	local motes = emitter(H.Dust.Rate, H.Dust.Lifetime, { H.Dust.Size, H.Dust.Size * 0.5 }, 0.2)
	motes.Parent = box
	box.Parent = Workspace.CurrentCamera
	return { box = box, haze = haze, motes = motes, head = head }
end

local function drop(other: Player)
	local h = hazes[other]
	if h then
		h.box:Destroy()
		hazes[other] = nil
	end
end

function TorchHazeController:_update()
	local inRun = self.state:InRun()
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local character = other.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		local light = head and head:FindFirstChild("Flashlight") :: SpotLight?
		local h = hazes[other]
		if h and h.head ~= head then
			drop(other)
			h = nil
		end
		local on = inRun and light ~= nil and light.Enabled and light.Brightness > 0
		if not on then
			if h then
				h.haze.Enabled = false
				h.motes.Enabled = false
			end
			continue
		end
		h = h or make(head :: BasePart)
		hazes[other] = h
		-- Out to the first solid thing ahead, as wide as the cone halfway.
		local look = (head :: BasePart).CFrame
		local reach = (light :: SpotLight).Range * H.Reach
		params.FilterDescendantsInstances = { character :: Model, player.Character :: Model }
		local hit = Workspace:Raycast(look.Position, look.LookVector * reach, params)
		local length = hit and math.max(hit.Distance - 0.3, 1) or reach
		local across = 2 * (length * 0.5) * math.tan(math.rad((light :: SpotLight).Angle / 2))
		h.box.Size = Vector3.new(across, across * 0.7, length)
		h.box.CFrame = look * CFrame.new(0, 0, -length / 2 - 0.5)
		h.haze.Enabled = true
		h.motes.Enabled = true
	end
	for other in hazes do
		if other.Parent ~= Players then
			drop(other)
		end
	end
end

function TorchHazeController:Start()
	Players.PlayerRemoving:Connect(drop)
	RunService.Heartbeat:Connect(function()
		self:_update()
	end)
end

return TorchHazeController
