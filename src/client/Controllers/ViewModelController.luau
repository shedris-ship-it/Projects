-- What you hold (owner, 2026-10-03; reworked 2026-10-04 and 2026-10-12): the
-- torch in your left hand while it's up (F), and the found tool from the slot
-- you chose in your right (Logic/Inventory, UI/Hotbar), each with a sleeved arm
-- reaching up to it. All parts are built in code (World/ToolModel,
-- Lib/ViewModel), local to this client, attached to the camera. Your own body
-- below the waist is Controllers/BodyController's. Pulled back and down against
-- a wall so nothing clips through.
--
-- The torch swings (docs/plans/gameplay-rework.md section 20, the owner: "you
-- press F and you flip it up, press F again and its gone ... I want it to have
-- a clean animation"): up from your hip on a spring that overshoots a touch and
-- settles, the switch clicked under your thumb as it lights at the top; away,
-- the click first, then it drops. Working a tool lock with both hands, it goes
-- to your shirt (the clip light) until you stop.
--
-- Where each item sits, and how its hand reaches it, is Config.ViewModel.Poses
-- (in camera-frame studs; Logic/ViewFrame and its spec keep every hand on
-- screen). Everything hangs on the same lagged aim and counter-sway, so a hard
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
local ArmReach = require(Shared.Logic.ArmReach)
local Inventory = require(Shared.Logic.Inventory)
local ViewModel = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("ViewModel"))

local PA = Constants.PlayerAttributes
local VM = Config.ViewModel
local player = Players.LocalPlayer

local ViewModelController = {}

local SCALE = VM.Scale
local REACH = 2.1 -- how far in front of you a wall must be before the models tuck back
local SHOWN = 0.02 -- a torch swung further out than this from its pocket is drawn

local function angles(t): CFrame
	return CFrame.Angles(math.rad(t[1]), 0, 0)
		* CFrame.Angles(0, math.rad(t[2]), 0)
		* CFrame.Angles(0, 0, math.rad(t[3]))
end

-- Just enough light on your own hands to see them in a dark room. Small on
-- purpose: it must not light the room (off while the torch is lit).
local function addFill(model: Model)
	local fill = Instance.new("PointLight")
	fill.Name = "HandFill"
	fill.Range = 3.2
	fill.Brightness = 0.55
	fill.Color = Color3.fromRGB(255, 226, 180)
	fill.Shadows = false
	fill.Parent = model.PrimaryPart
end

local function setFill(model: Model?, on: boolean)
	local fill = model and model.PrimaryPart and model.PrimaryPart:FindFirstChild("HandFill") :: PointLight?
	if fill then
		fill.Enabled = on
	end
end

function ViewModelController:Init(controllers)
	self.controllers = controllers
	self.state = controllers.StateController
	self.arms = {} -- "Left"/"Right" -> { model, bones, look }: your own arms
	self.item, self.itemId = nil, nil -- the right hand's
	self.lower = 0 -- 0 raised, 1 lowered (while the right hand switches what it holds)
	self.torch = nil -- the left hand's
	self.swing, self.swingSpeed = 0, 0 -- the torch: 0 put away, 1 up (a spring)
	self.kick = 0 -- the switch under your thumb
	self.tuck = 0
	self.rayParams = nil
end

-- The torch again, wearing its modelled body: the server hands the tools'
-- meshes over a moment after start (World/Kit.share), often after the torch
-- was first built.
function ViewModelController:_rebuildTorch()
	if not self.torch then
		return
	end
	ViewModel.destroy(self.torch)
	self.torch = ViewModel.torch()
	self.torch:ScaleTo(SCALE)
	addFill(self.torch)
	if self.itemId then
		self:_swapItem(self.itemId)
	end
end

function ViewModelController:_build()
	local camera = Workspace.CurrentCamera
	local character = player.Character
	for side, arm in self.arms do
		ViewModel.destroy(arm.model)
		self.arms[side] = nil
	end
	ViewModel.destroy(self.torch)
	self.torch = ViewModel.torch()
	self.torch:ScaleTo(SCALE)
	addFill(self.torch)
	self.swing, self.swingSpeed = 0, 0
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, camera }
	self.rayParams = params
	self.builtFor = character
end

-- Your arm on `side`, copied from your character (Lib/ViewModel.armFrom), and
-- copied again whenever it changes (the outfit painted after you spawned).
function ViewModelController:_arm(side: string)
	local character = player.Character
	if not character then
		return nil
	end
	local look = ViewModel.armLook(character, side)
	local arm = self.arms[side]
	if arm and arm.look == look then
		return arm
	end
	if arm then
		ViewModel.destroy(arm.model)
	end
	local A = VM.Arm
	local model, bones, sleeves = ViewModel.armFrom(character, side, A.Scale, A.Thickness)
	arm = model and { model = model, bones = bones, sleeves = sleeves, look = look } or nil
	self.arms[side] = arm
	return arm
end

local function hide(model: Instance?)
	if model and model.Parent then
		model.Parent = nil
	end
end

-- A bone part between two joints: its +Y from `from` towards `to` (a Roblox
-- limb's top is the joint nearer the body), turned so its front faces `facing`.
local function bone(from: Vector3, to: Vector3, facing: Vector3): CFrame
	local y = (to - from).Unit
	local x = facing:Cross(y)
	x = x.Magnitude > 1e-4 and x.Unit or Vector3.xAxis
	return CFrame.fromMatrix((from + to) / 2, x, y, x:Cross(y))
end

-- The hand closed round what it holds (a pose's `grip`): the fist's middle at
-- `grip.at` on the thing (its own frame), the thing running through the fist
-- along `grip.through` (out past the little finger, as a Roblox hand holds a
-- tool), its wrist side turned toward your shoulder. Returns the hand's
-- CFrame and where its wrist is. (The hand used to lie along the forearm,
-- so it slid down the torch's barrel instead of holding it: the owner,
-- 2026-10-15, "the hand is going through the flashlight".)
local function fist(item: CFrame, grip, shoulder: Vector3, hand: BasePart): (CFrame, Vector3)
	local at = (item * CFrame.new(grip.at[1], grip.at[2], grip.at[3])).Position
	local z = item:VectorToWorldSpace(Vector3.new(grip.through[1], grip.through[2], grip.through[3])).Unit
	local toward = shoulder - at
	local y = toward - z * toward:Dot(z)
	y = if y.Magnitude > 1e-4 then y.Unit else -item.UpVector
	local half = hand.Size.Y * 0.5
	local cf = CFrame.fromMatrix(at + y * half * (grip.shift or 0), y:Cross(z), y, z)
	return cf, cf.Position + y * half
end

-- Bend your arm on `side` (1 right, -1 left) from its shoulder (held to your
-- eye) to `wrist`, the hand beyond it along the forearm; or, given `hold`
-- (the thing's CFrame and its pose's grip), with the hand closed round it.
function ViewModelController:_poseArm(
	sideName: string,
	side: number,
	eye: CFrame,
	wrist: Vector3,
	camera: Camera,
	hold: { item: CFrame, grip: any }?
)
	local arm = self:_arm(sideName)
	if not arm then
		return
	end
	local A = VM.Arm
	local bones = arm.bones
	local s = A.Shoulder
	local shoulder = (eye * CFrame.new(s[1] * side, s[2], s[3])).Position
	local held
	if hold then
		held, wrist = fist(hold.item, hold.grip, shoulder, bones.hand)
	end
	local pole = eye:VectorToWorldSpace(Vector3.new(A.Pole[1] * side, A.Pole[2], A.Pole[3]))
	-- The bones overlap a little at the elbow, as a Roblox arm's do.
	local upper, lower = bones.upper.Size.Y * 0.94, bones.lower.Size.Y * 0.94
	local e, sh = ArmReach.solve(
		{ shoulder.X, shoulder.Y, shoulder.Z },
		{ wrist.X, wrist.Y, wrist.Z },
		upper,
		lower,
		{ pole.X, pole.Y, pole.Z }
	)
	local elbow, top = Vector3.new(e[1], e[2], e[3]), Vector3.new(sh[1], sh[2], sh[3])
	local facing = -camera.CFrame.LookVector
	bones.upper.CFrame = bone(elbow, top, facing)
	bones.lower.CFrame = bone(wrist, elbow, facing)
	if held then
		bones.hand.CFrame = held
	else
		local along = (wrist - elbow).Unit
		local tip = wrist + along * bones.hand.Size.Y * 0.9
		bones.hand.CFrame = bone(tip, wrist, facing)
	end
	ViewModel.carry(arm.sleeves)
	arm.model.Parent = camera
end

function ViewModelController:_hideArm(side: string)
	local arm = self.arms[side]
	if arm then
		hide(arm.model)
	end
end

function ViewModelController:_hideAll()
	for _, model in { self.item, self.torch } do
		hide(model)
	end
	self:_hideArm("Left")
	self:_hideArm("Right")
	-- Not holding a torch: ActionController puts the light back at the camera.
	local actions = self.controllers.ActionController
	if actions then
		actions.beamCFrame = nil
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

-- The found tool in your right hand, or nothing. A free hand draws nothing,
-- as in Amnesia: a clean view until you grab something (tried 2026-10-04: two
-- open primitive hands at the bottom of the screen read as bricks).
function ViewModelController:_heldId(): string?
	local tool = player:GetAttribute(PA.Tool)
	if type(tool) == "string" and tool ~= "" then
		return tool
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
	local model = ViewModel.tool(id)
	if not model then
		return
	end
	model:ScaleTo(SCALE)
	addFill(model)
	self.item = model
end

-- Lower what the right hand holds, swap it, raise the new one.
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

-- The torch's swing: a spring towards up (1) or away (0), stepped in small
-- steps so a slow frame can't throw it.
function ViewModelController:_updateSwing(dt: number, up: boolean)
	local spring = up and VM.TorchRaise or VM.TorchLower
	local omega, zeta = spring[1], spring[2]
	local target = up and 1 or 0
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	for _ = 1, steps do
		local accel = omega * omega * (target - self.swing) - 2 * zeta * omega * self.swingSpeed
		self.swingSpeed += accel * h
		self.swing += self.swingSpeed * h
	end
	-- Put away is put away: no bounce below the hip.
	if not up and self.swing < 0 then
		self.swing, self.swingSpeed = 0, 0
	end
	self.kick *= math.exp(-dt * 16)
end

-- The switch under your thumb (ActionController, as the light comes on or goes off).
function ViewModelController:Click()
	self.kick = 1
end

-- What the right hand does at a tool lock (Services/LockService): the crowbar
-- levers at the boards, the cutters bite at the chain, stroke after stroke.
function ViewModelController:_workMotion(dt: number): CFrame
	local working = player:GetAttribute("Working")
	if not working then
		self.workPhase = 0
		return CFrame.identity
	end
	self.workPhase = (self.workPhase or 0) + dt
	local t = self.workPhase
	if working == "boards" then
		local heave = math.sin(t * 7)
		return CFrame.new(0, math.abs(heave) * 0.08 - 0.04, -0.14 * math.max(0, heave))
			* CFrame.Angles(heave * 0.24, 0, 0)
	end
	local bite = math.max(0, math.sin(t * 9))
	return CFrame.new(math.sin(t * 23) * 0.015, math.sin(t * 19) * 0.015, -0.12 * bite)
		* CFrame.Angles(0, 0, math.sin(t * 9) * 0.06)
end

function ViewModelController:_update(dt: number)
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local firstPerson = player.CameraMode == Enum.CameraMode.LockFirstPerson
	-- (No arms in front of a cutscene's camera: Controllers/CinemaController.)
	local cinema = self.controllers.CinemaController
	local active = camera
		and character
		and firstPerson
		and not (cinema and cinema:Active())
		and self.state:InRun()
		and self.state:IsActive()
		and not self.state:IsTucked()
	if not active then
		self:_hideAll()
		self.swing, self.swingSpeed = 0, 0
		return
	end
	if self.builtFor ~= character or not self.torch then
		self:_build()
	end
	self:_updateItem(dt)

	local actions = self.controllers.ActionController
	-- Up while you want it up (F, ahead of the server's word), and not while
	-- both hands work a tool lock (it rides on your shirt then).
	local wantUp = actions ~= nil and actions:TorchWanted() and player:GetAttribute("Working") == nil
	self:_updateSwing(dt, wantUp)

	local feel = self.controllers.FeelController
	local aim = (actions and actions.flashlightRotation) or camera.CFrame.Rotation
	local sway = feel and feel.sway or Vector2.zero
	local tuck = self:_tuckAmount(camera, dt)
	-- Counter-sway: the camera already bobs, so the hands lag a little behind it.
	local counter = Vector3.new(-sway.X * 1.4, -sway.Y * 1.4, 0)
	local eye = CFrame.new(camera.CFrame.Position) * aim
	local pulled = counter + Vector3.new(0, -tuck * 0.28, tuck * 1.1)

	-- The right hand: the tool.
	local pose = self.itemId and VM.Poses[self.itemId]
	if self.item and pose then
		local at = pose.at
		local offset = Vector3.new(at[1], at[2], -at[3]) + pulled + Vector3.new(0, -self.lower * 0.9, 0)
		local base = eye * CFrame.new(offset) * self:_workMotion(dt)
		local item = base * angles(pose.turn)
		self.item:PivotTo(item)
		local wrist = pose.wrist
		local hold = pose.grip and { item = item, grip = pose.grip } or nil
		self:_poseArm("Right", 1, eye, (base * CFrame.new(wrist[1], wrist[2], wrist[3])).Position, camera, hold)
		self.item.Parent = camera
	else
		hide(self.item)
		self:_hideArm("Right")
	end

	-- The left hand: the torch, somewhere on its swing between your hip and its pose.
	local torchOn = player:GetAttribute(PA.Flashlight) == true and wantUp
	local torchPose = VM.Poses[Inventory.TORCH]
	if self.swing > SHOWN and torchPose then
		local s = self.swing
		local away = VM.TorchAway
		local at = torchPose.at
		local rest = Vector3.new(at[1], at[2], -at[3])
		local hip = rest + Vector3.new(away.at[1], away.at[2], -away.at[3])
		-- Past 1 (the spring's overshoot) it carries on a little past its pose: the flick.
		local offset = hip:Lerp(rest, s) + pulled + Vector3.new(0, 0, self.kick * 0.03)
		local turn = {
			away.turn[1] * (1 - s) + torchPose.turn[1] - self.kick * VM.TorchClickKick,
			away.turn[2] * (1 - s) + torchPose.turn[2],
			away.turn[3] * (1 - s) + torchPose.turn[3],
		}
		local base = eye * CFrame.new(offset)
		self.torch:PivotTo(base * angles(turn))
		-- The hand keeps hold of it all the way: the wrist turns with the torch.
		local wrist = torchPose.wrist
		local carried = angles(turn) * angles(torchPose.turn):Inverse()
		local hold = torchPose.grip and { item = base * angles(turn), grip = torchPose.grip } or nil
		self:_poseArm(
			"Left",
			-1,
			eye,
			(base * carried * CFrame.new(wrist[1], wrist[2], wrist[3])).Position,
			camera,
			hold
		)
		self.torch.Parent = camera
		ViewModel.setTorchOn(self.torch, torchOn)
		setFill(self.torch, not torchOn)
		local muzzle = self.torch:FindFirstChild("Muzzle") :: BasePart?
		-- (On its way to your shirt for a tool lock, the light is the clip's already.)
		if muzzle and actions and player:GetAttribute(PA.TorchClipped) ~= true then
			local beam = self:_beamOrigin(camera, muzzle.CFrame)
			actions.beamCFrame = beam
			if actions.lightPart then
				actions.lightPart.CFrame = beam -- ActionController may have run first this frame
			end
		end
	else
		hide(self.torch)
		self:_hideArm("Left")
		if actions then
			actions.beamCFrame = nil
		end
	end

	-- The tool in the other hand: lit by the torch when it's on.
	if self.item then
		setFill(self.item, not torchOn)
		local core = self.item:FindFirstChild("Core") :: BasePart?
		if core then
			core.Transparency = player:GetAttribute("LanternOn") == true and 0 or 0.8
		end
	end
end

function ViewModelController:Start()
	-- The tools' meshes arrive from the server (World/Kit.share): the torch
	-- and what's in your hand put on their modelled bodies then.
	task.spawn(function()
		local kit = ReplicatedStorage:WaitForChild("Kit", 30)
		local meshes = kit and kit:WaitForChild("Meshes", 120)
		if meshes then
			meshes.ChildAdded:Connect(function()
				task.defer(self._rebuildTorch, self)
			end)
			if #meshes:GetChildren() > 0 then
				self:_rebuildTorch()
			end
		end
	end)
	-- After the camera script and the roll sway, so the models sit on the final camera.
	RunService:BindToRenderStep("ConsensusViewModel", Enum.RenderPriority.Camera.Value + 3, function(dt)
		local ok, err = pcall(self._update, self, dt)
		if not ok then
			warn("[Consensus] view model failed: " .. tostring(err))
		end
	end)
end

return ViewModelController
