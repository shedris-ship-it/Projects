-- What you hold (owner, 2026-10-03; reworked 2026-10-04): ONE thing in your
-- hands at a time, the flashlight or the found tool in the slot you chose
-- (Logic/Inventory, UI/Hotbar), with sleeved arms reaching up to it. All parts
-- are built in code (World/ToolModel, Lib/ViewModel), local to this client,
-- attached to the camera. Roblox's own first-person arms are hidden so these
-- replace them. Pulled back and down against a wall so nothing clips through.
--
-- Where each item sits, and how its hands reach it, is Config.ViewModel.Poses
-- (in camera-frame studs; Logic/ViewFrame and its spec keep every hand on
-- screen). Every item hangs on the same lagged aim and counter-sway, so a hard
-- turn drags the torch and the camera alike.
--
-- Aim is untouched: the torch's light is still ActionController's, but it
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
local Inventory = require(Shared.Logic.Inventory)
local ViewModel = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("ViewModel"))

local PA = Constants.PlayerAttributes
local VM = Config.ViewModel
local player = Players.LocalPlayer

local ViewModelController = {}

local SCALE = VM.Scale
local REACH = 2.1 -- how far in front of you a wall must be before the models tuck back

local function turnOf(pose): CFrame
	local t = pose.turn
	return CFrame.Angles(math.rad(t[1]), 0, 0)
		* CFrame.Angles(0, math.rad(t[2]), 0)
		* CFrame.Angles(0, 0, math.rad(t[3]))
end

-- A forearm: swung out to one side, rising towards the hand.
local function armTurn(yaw: number, tilt: number): CFrame
	return CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(tilt), 0, 0)
end

function ViewModelController:Init(controllers)
	self.controllers = controllers
	self.state = controllers.StateController
	self.rightArm, self.leftArm = nil, nil
	self.item, self.itemId = nil, nil
	self.lower = 0 -- 0 raised, 1 lowered (while you switch what you hold)
	self.tuck = 0
	self.rayParams = nil
	self.shadowParts = nil
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
	self.rightArm = ViewModel.arm(shirt, skin)
	self.leftArm = ViewModel.arm(shirt, skin)
	for _, model in { self.rightArm, self.leftArm } do
		model:ScaleTo(SCALE)
		model.Parent = camera
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, camera }
	self.rayParams = params
	self.builtFor = character
end

function ViewModelController:_hideAll()
	for _, model in { self.rightArm, self.leftArm, self.item } do
		if model and model.Parent then
			model.Parent = nil
		end
	end
	self:_shadowless(player.Character, false)
	-- Not holding a torch: ActionController puts the light back at the camera.
	local actions = self.controllers.ActionController
	if actions then
		actions.beamCFrame = nil
	end
end

-- Roblox shows the avatar's own arms in first person; ours replace them.
local function hideStockBody(character: Model)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		end
	end
end

-- While you look out of your own head, the hidden body stops casting shadows on
-- this client, or it would throw one across the torch beam that starts just
-- beside it. Put back exactly as it was when you leave first person.
function ViewModelController:_shadowless(character: Model?, on: boolean)
	if on and character and not self.shadowParts then
		self.shadowParts = {}
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") and d.CastShadow then
				d.CastShadow = false
				table.insert(self.shadowParts, d)
			end
		end
	elseif not on and self.shadowParts then
		for _, d in self.shadowParts do
			if d.Parent then
				d.CastShadow = true
			end
		end
		self.shadowParts = nil
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
		position = from + offset.Unit * math.max(0, hit.Distance - VM.BeamWallGap)
	end
	return CFrame.new(position) * muzzle.Rotation
end

function ViewModelController:_tuckAmount(camera: Camera, dt: number): number
	local hit = Workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * REACH, self.rayParams)
	local target = hit and math.clamp((REACH - hit.Distance) / REACH, 0, 1) or 0
	self.tuck += (target - self.tuck) * math.clamp(dt * 12, 0, 1)
	return self.tuck
end

-- What is in your hands: the torch, a found tool, or nothing (an empty slot).
function ViewModelController:_heldId(): string?
	local tool = player:GetAttribute(PA.Tool)
	if type(tool) == "string" and tool ~= "" then
		return tool
	end
	if (player:GetAttribute(PA.ActiveSlot) or Inventory.TORCH_SLOT) == Inventory.TORCH_SLOT then
		return Inventory.TORCH
	end
	return nil
end

function ViewModelController:_swapItem(id: string?)
	ViewModel.destroy(self.item)
	self.item = nil
	self.itemId = id
	if not id then
		return
	end
	local model = id == Inventory.TORCH and ViewModel.torch() or ViewModel.tool(id)
	if not model then
		return
	end
	model:ScaleTo(SCALE)
	model.Parent = Workspace.CurrentCamera
	-- Just enough light on your own hands to see them in a dark room. Small
	-- on purpose: it must not light the room (see _update, off while the torch is on).
	local fill = Instance.new("PointLight")
	fill.Name = "HandFill"
	fill.Range = 3.2
	fill.Brightness = 0.55
	fill.Color = Color3.fromRGB(255, 226, 180)
	fill.Shadows = false
	fill.Parent = model.PrimaryPart
	self.item = model
end

-- Lower what you hold, swap it, raise the new one.
function ViewModelController:_updateItem(dt: number)
	local wanted = self:_heldId()
	if wanted ~= self.itemId then
		self.lower = math.min(1, self.lower + dt * 6)
		if self.lower >= 1 then
			self:_swapItem(wanted)
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
	if self.builtFor ~= character or not self.rightArm then
		self.shadowParts = nil -- a new body: the old parts are gone
		self:_build()
	end
	self:_shadowless(character, true)
	self:_updateItem(dt)

	local actions = self.controllers.ActionController
	local pose = self.itemId and VM.Poses[self.itemId]
	if not (self.item and pose) then
		self:_hideAll()
		return
	end
	for _, model in { self.item, self.rightArm } do
		if not model.Parent then
			model.Parent = camera
		end
	end

	local feel = self.controllers.FeelController
	local aim = (actions and actions.flashlightRotation) or camera.CFrame.Rotation
	local sway = feel and feel.sway or Vector2.zero
	local tuck = self:_tuckAmount(camera, dt)
	-- Counter-sway: the camera already bobs, so the hands lag a little behind it.
	local counter = Vector3.new(-sway.X * 1.4, -sway.Y * 1.4, 0)
	local at = pose.at
	local offset = Vector3.new(at[1], at[2], -at[3])
		+ counter
		+ Vector3.new(0, -self.lower * 0.9 - tuck * 0.28, tuck * 1.1)
	local base = CFrame.new(camera.CFrame.Position) * aim * CFrame.new(offset)

	self.item:PivotTo(base * turnOf(pose))
	local wrist = pose.wrist
	self.rightArm:PivotTo(base * CFrame.new(wrist[1], wrist[2], wrist[3]) * armTurn(pose.yaw, pose.tilt))
	if pose.left then
		local left = pose.left
		self.leftArm:PivotTo(base * CFrame.new(left[1], left[2], left[3]) * armTurn(-pose.yaw, pose.tilt))
		self.leftArm.Parent = camera
	else
		self.leftArm.Parent = nil
	end

	local fill = self.item.PrimaryPart:FindFirstChild("HandFill") :: PointLight?
	if self.itemId == Inventory.TORCH then
		local torchOn = player:GetAttribute(PA.Flashlight) == true
		ViewModel.setTorchOn(self.item, torchOn)
		if fill then
			fill.Enabled = not torchOn -- with the torch on, its own light shows your hands
		end
		local muzzle = self.item:FindFirstChild("Muzzle") :: BasePart?
		if muzzle and actions then
			local beam = self:_beamOrigin(camera, muzzle.CFrame)
			actions.beamCFrame = beam
			if actions.lightPart then
				actions.lightPart.CFrame = beam -- ActionController may have run first this frame
			end
		end
	else
		if actions then
			actions.beamCFrame = nil
		end
		if fill then
			fill.Enabled = true
		end
		local core = self.item:FindFirstChild("Core") :: BasePart?
		if core then
			core.Transparency = player:GetAttribute("LanternOn") == true and 0 or 0.8
		end
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
