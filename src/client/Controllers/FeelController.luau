-- How movement feels through the camera (owner, 2026-10-03): head bob (light
-- walking, intense sprinting), a roll sway and lean into turns, a sprint FOV
-- kick and a dip when you land. The maths is Logic/Feel; everything scales
-- with the "Camera motion" setting and 0 turns it all off.
--
-- Only position and roll move. Position goes through Humanoid.CameraOffset
-- (the engine camera applies it, so Aim, ReportView and the flashlight all see
-- the bobbed camera) and roll turns the camera about its look axis after the
-- camera script, which never changes LookVector: pitch or yaw bob would change
-- what the server thinks you're looking at (the watch cones).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Feel = require(Shared.Logic.Feel)

local P, F = Config.Player, Config.Feel
local player = Players.LocalPlayer

local FeelController = {}

function FeelController:Init(controllers)
	self.controllers = controllers
	self.state = controllers.StateController
	self.phase = 0 -- in steps
	self.amp = { 0, 0, 0 } -- smoothed bob amplitude: vertical, sideways, roll
	self.dip = 0 -- studs the camera is dipped after a landing
	self.kick = 0 -- degrees of FOV added
	self.roll = 0 -- degrees applied after the camera script
	self.lean = 0
	self.fallSpeed = 0
	self.lastYaw = nil
	self.active = false
	self.wroteFov = false
	self.sway = Vector2.zero
end

function FeelController:_intensity(): number
	local value = self.state.settings.cameraMotion
	return type(value) == "number" and math.clamp(value, 0, 1) or 1
end

-- First person in a run, on your feet or crawling, not hiding.
function FeelController:_isActive(): boolean
	return self.state:InRun() and not self.state:IsHidden() and player.CameraMode == Enum.CameraMode.LockFirstPerson
end

function FeelController:_watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed then
			local intensity = self:_intensity()
			self.dip = math.max(self.dip, Feel.landingDip(self.fallSpeed, intensity, F))
			local footsteps = self.controllers.FootstepController
			if footsteps and footsteps.Land then
				footsteps:Land(self.fallSpeed)
			end
			self.fallSpeed = 0
		end
	end)
end

-- A short kick of the field of view (a throw), scaled by Camera motion.
function FeelController:Kick(degrees: number)
	self.burst = math.max(self.burst or 0, degrees * self:_intensity())
end

function FeelController:Start()
	player.CharacterAdded:Connect(function(character)
		self:_watch(character)
	end)
	if player.Character then
		task.spawn(function()
			self:_watch(player.Character)
		end)
	end
	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(self._update, self, dt)
		if not ok then
			warn("[Consensus] feel update failed: " .. tostring(err))
		end
	end)
	RunService:BindToRenderStep("ConsensusFeelRoll", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = Workspace.CurrentCamera
		-- No roll while your hands hold something still (a door's held view).
		local hands = self.controllers.HandsController
		local holding = hands and hands.drag ~= nil
		if camera and self.active and not holding and math.abs(self.roll) > 0.001 then
			camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, math.rad(self.roll))
		end
	end)
end

function FeelController:_update(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if not (humanoid and root and camera) then
		return
	end
	local intensity = self:_intensity()
	local active = self:_isActive()
	self.active = active
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if not grounded then
		self.fallSpeed = math.max(self.fallSpeed, -velocity.Y)
	end

	-- Bob: the amplitude eases towards what this speed calls for.
	local targets = { 0, 0, 0 }
	if active then
		targets = { Feel.bobAmplitude(speed, grounded, intensity, P, F) }
		local actions = self.controllers.ActionController
		if actions and actions.exhausted then
			-- Out of stamina: a sloppier stagger.
			targets[2] *= 1.6
			targets[3] *= 1.5
		end
	end
	local ease = math.clamp(dt * F.BobEase, 0, 1)
	for i = 1, 3 do
		self.amp[i] += (targets[i] - self.amp[i]) * ease
	end
	if active and grounded and speed > 0.5 then
		self.phase += speed * dt / Feel.stride(speed, P, F)
	end
	local y, x, roll = Feel.bobAt(self.phase, self.amp[1], self.amp[2], self.amp[3])

	-- A slow breathing sway while standing still.
	local idle = 0
	if active and speed < 0.5 then
		idle = math.sin(os.clock() * 1.1) * 0.012 * intensity
	end

	-- A landing dips the camera, then it comes back up.
	self.dip += (0 - self.dip) * math.clamp(dt * 7, 0, 1)

	-- Lean into turns.
	local yaw = math.deg(math.atan2(-camera.CFrame.LookVector.X, -camera.CFrame.LookVector.Z))
	if self.lastYaw and dt > 0 then
		local delta = (yaw - self.lastYaw + 540) % 360 - 180
		local rate = delta / dt
		local target = active and Feel.turnLean(rate, intensity, F) or 0
		self.lean += (target - self.lean) * math.clamp(dt * 8, 0, 1)
	end
	self.lastYaw = yaw
	self.roll = roll + self.lean

	humanoid.CameraOffset = active and Vector3.new(x, y + idle - self.dip, 0) or Vector3.zero
	-- How far the camera has moved with the bob: the hands lag behind it.
	self.sway = active and Vector2.new(x, y + idle - self.dip) or Vector2.zero

	-- Sprint FOV kick on top of the player's own setting, and any burst (a throw).
	local base = self.state.settings.fov or Config.Camera.FieldOfView
	local kickTarget = active and Feel.fovKick(speed, intensity, P, F) or 0
	self.kick += (kickTarget - self.kick) * math.clamp(dt * F.FovEase, 0, 1)
	self.burst = (self.burst or 0) * math.exp(-dt * 7)
	local total = self.kick + self.burst
	if math.abs(total) > 0.01 then
		camera.FieldOfView = base + total
		self.wroteFov = true
	elseif self.wroteFov then
		camera.FieldOfView = base
		self.wroteFov = false
	end
end

return FeelController
