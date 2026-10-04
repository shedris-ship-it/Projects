-- What you hold (owner, 2026-10-03): a torch in your right hand that trails
-- your turns, the tool you picked in your left, and sleeved arms reaching up
-- to them. All parts built in code (Lib/ViewModel), local to this client,
-- attached to the camera. Roblox's own first-person arms are hidden so these
-- replace them. Pulled back and down against a wall so nothing clips through.
-- Aim is untouched: the torch's light is still ActionController's, but it now
-- leaves from the torch's lens (the Muzzle part) instead of from your eye
-- (owner, 2026-10-04: "the beam comes through my face"). ActionController keeps
-- the on/off and the lagged aim; this file tells it where the muzzle is.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local ViewModel = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("ViewModel"))

local PA = Constants.PlayerAttributes
local player = Players.LocalPlayer

local ViewModelController = {}

-- Everything is built a little big for the screen; this brings it to size.
local SCALE = 0.7

-- Offsets from the camera (studs): right, up, forward (negative Z).
local TORCH = Vector3.new(0.6, -0.55, -1.15)
local TOOL = Vector3.new(-0.56, -0.5, -1.25)
local REACH = 2.1 -- how far in front of you a wall must be before the models tuck back

function ViewModelController:Init(controllers)
	self.controllers = controllers
	self.state = controllers.StateController
	self.torch, self.lens = nil, nil
	self.rightArm, self.leftArm = nil, nil
	self.tool, self.toolId = nil, nil
	self.lower = 0 -- 0 raised, 1 lowered (while you switch tools)
	self.tuck = 0
	self.rayParams = nil
end

function ViewModelController:_build()
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local torso = character and character:FindFirstChild("UpperTorso")
	local head = character and character:FindFirstChild("Head")
	local shirt = torso and torso.Color or Color3.fromRGB(150, 130, 100)
	local skin = head and head.Color or Color3.fromRGB(220, 180, 150)
	ViewModel.destroy(self.rightArm)
	ViewModel.destroy(self.leftArm)
	ViewModel.destroy(self.torch)
	self.torch, self.lens = ViewModel.torch()
	self.rightArm = ViewModel.arm(shirt, skin)
	self.leftArm = ViewModel.arm(shirt, skin)
	for _, model in { self.torch, self.rightArm, self.leftArm } do
		model:ScaleTo(SCALE)
		model.Parent = camera
	end
	-- Just enough light on your own hands to see them in a dark room. Small
	-- on purpose: it must not light the room (see _update, off when the torch is on).
	local fill = Instance.new("PointLight")
	fill.Name = "HandFill"
	fill.Range = 3.2
	fill.Brightness = 0.55
	fill.Color = Color3.fromRGB(255, 226, 180)
	fill.Shadows = false
	fill.Parent = self.torch.PrimaryPart
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, camera }
	self.rayParams = params
	self.builtFor = character
end

function ViewModelController:_hideAll()
	for _, model in { self.torch, self.rightArm, self.leftArm, self.tool } do
		if model and model.Parent then
			model.Parent = nil
		end
	end
	-- Not holding a torch: ActionController puts the light back at the camera.
	local actions = self.controllers.ActionController
	if actions then
		actions.beamCFrame = nil
	end
end

-- Roblox shows the avatar's own arms in first person; ours replace them. The
-- hidden body also stops casting shadows on this client, or it would throw one
-- across the torch beam that now starts just beside it.
local function hideStockBody(character: Model)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
			if d.CastShadow then
				d.CastShadow = false
			end
		end
	end
end

-- Where the beam leaves: the torch's muzzle, pulled back along the line from
-- your eye if a wall is between them (a shadow-casting light inside a wall
-- lights nothing).
function ViewModelController:_beamOrigin(camera: Camera, muzzle: CFrame): CFrame
	local from = camera.CFrame.Position
	local offset = muzzle.Position - from
	local position = muzzle.Position
	local hit = self.rayParams and Workspace:Raycast(from, offset, self.rayParams)
	if hit then
		position = from + offset.Unit * math.max(0, hit.Distance - Config.ViewModel.BeamWallGap)
	end
	return CFrame.new(position) * muzzle.Rotation
end

function ViewModelController:_tuckAmount(camera: Camera, dt: number): number
	local hit = Workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * REACH, self.rayParams)
	local target = hit and math.clamp((REACH - hit.Distance) / REACH, 0, 1) or 0
	self.tuck += (target - self.tuck) * math.clamp(dt * 12, 0, 1)
	return self.tuck
end

function ViewModelController:_updateTool(dt: number)
	local wanted = player:GetAttribute(PA.Tool)
	if wanted ~= self.toolId then
		-- Lower the old one, swap, raise the new one.
		self.lower = math.min(1, self.lower + dt * 6)
		if self.lower >= 1 then
			ViewModel.destroy(self.tool)
			self.tool = type(wanted) == "string" and ViewModel.tool(wanted) or nil
			if self.tool then
				self.tool:ScaleTo(SCALE)
			end
			self.toolId = wanted
		end
	else
		self.lower = math.max(0, self.lower - dt * 6)
	end
end

function ViewModelController:_update(dt: number)
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local firstPerson = player.CameraMode == Enum.CameraMode.LockFirstPerson
	local active = camera
		and character
		and firstPerson
		and self.state:InRun()
		and self.state:IsActive()
		and not self.state:IsHidden()
	if not active then
		self:_hideAll()
		return
	end
	hideStockBody(character)
	if self.builtFor ~= character or not self.torch or not self.torch.Parent then
		self:_build()
	end
	self:_updateTool(dt)
	if self.tool and not self.tool.Parent then
		self.tool.Parent = camera
	end

	local actions = self.controllers.ActionController
	local feel = self.controllers.FeelController
	local aim = (actions and actions.flashlightRotation) or camera.CFrame.Rotation
	local sway = feel and feel.sway or Vector2.zero
	local tuck = self:_tuckAmount(camera, dt)
	local origin = CFrame.new(camera.CFrame.Position)
	-- Counter-sway: the camera already bobs, so the hands lag a little behind it.
	local counter = Vector3.new(-sway.X * 1.4, -sway.Y * 1.4, 0)

	-- Right hand: the torch, in the lagged aim so a quick turn drags it.
	local torchOffset = TORCH + counter + Vector3.new(0, -tuck * 0.28, tuck * 1.1)
	local torchCF = origin * aim * CFrame.new(torchOffset) * CFrame.Angles(math.rad(2), math.rad(-3), 0)
	self.torch:PivotTo(torchCF)
	local torchOn = player:GetAttribute(PA.Flashlight) == true
	ViewModel.setTorchOn(self.torch, torchOn)
	local muzzle = self.torch:FindFirstChild("Muzzle") :: BasePart?
	if muzzle and actions then
		local beam = self:_beamOrigin(camera, muzzle.CFrame)
		actions.beamCFrame = beam
		if actions.lightPart then
			actions.lightPart.CFrame = beam -- ActionController may have run first this frame
		end
	end
	local fill = self.torch.PrimaryPart:FindFirstChild("HandFill")
	if fill then
		fill.Enabled = not torchOn -- with the torch on, its own light shows your hands
	end
	local rightWrist = torchCF * CFrame.new(0.02, -0.2, 0.3)
	self.rightArm:PivotTo(rightWrist * CFrame.Angles(math.rad(-28), math.rad(8), 0))

	-- Left hand: the chosen tool, tracking the camera, dipping while it's swapped.
	if self.tool then
		local toolOffset = TOOL + counter + Vector3.new(0, -self.lower * 0.9 - tuck * 0.25, tuck * 1.1)
		local toolCF = camera.CFrame * CFrame.new(toolOffset) * CFrame.Angles(math.rad(8), math.rad(16), math.rad(-3))
		self.tool:PivotTo(toolCF)
		local core = self.tool:FindFirstChild("Core")
		if core then
			core.Transparency = player:GetAttribute("LanternOn") == true and 0 or 0.8
		end
		local leftWrist = toolCF * CFrame.new(0.12, -0.34, 0.16)
		self.leftArm:PivotTo(leftWrist * CFrame.Angles(math.rad(-26), math.rad(-10), 0))
		self.leftArm.Parent = camera
	else
		self.leftArm.Parent = nil
	end
end

function ViewModelController:Start()
	-- After the camera script and the roll sway, so the models sit on the final camera.
	RunService:BindToRenderStep("ConsensusViewModel", Enum.RenderPriority.Camera.Value + 3, function(dt)
		local ok, err = pcall(self._update, self, dt)
		if not ok then
			warn("[Consensus] view model failed: " .. tostring(err))
		end
	end)
end

return ViewModelController
