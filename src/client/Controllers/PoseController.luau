-- Players' bodies, posed in code over the default animation (Logic/
-- PlayerPose; the squad playtest, 2026-10-08: "there is no down animation",
-- and crouching needs a body that crouches). Every client poses every
-- character from what the server says about them: downed (a fall to the
-- floor, then a crawl), kneeling over a friend they're reviving, crouched
-- (a creep), ducking into a hiding place. Nothing is uploaded: the joints
-- are written each frame after the Animator, the way GuestController poses
-- The Guest, and eased in and out so nobody snaps.
--
-- The joints are AnimationConstraints in this place's rig (Motor6Ds in an
-- older one); both take a Transform.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local PlayerPose = require(Shared.Logic.PlayerPose)

local PA = Constants.PlayerAttributes
local P = Config.Pose

local PoseController = {}

function PoseController:Init(controllers)
	self.controllers = controllers
	self.rigs = setmetatable({}, { __mode = "k" }) -- character -> rig state
end

function PoseController:Start()
	RunService.Stepped:Connect(function(_, dt)
		local ok, err = pcall(self._frame, self, dt)
		if not ok then
			warn("[Consensus] pose update failed: " .. tostring(err))
		end
	end)
end

-- A character's joints by name, found once.
function PoseController:_rig(character: Model)
	local rig = self.rigs[character]
	if rig and rig.complete then
		return rig
	end
	rig = rig or { joints = {}, weight = 0, phase = 0, pose = nil }
	local found = 0
	for _, d in character:GetDescendants() do
		if (d:IsA("AnimationConstraint") or d:IsA("Motor6D")) and PlayerPose.Rig[d.Name] then
			rig.joints[d.Name] = d
		end
	end
	for _ in rig.joints do
		found += 1
	end
	rig.complete = found >= #PlayerPose.Order
	self.rigs[character] = rig
	return rig
end

-- What the server says this player's body is doing, and how fast to get there.
local function wanted(player: Player): (string?, number)
	if player:GetAttribute(PA.State) == Constants.PlayerStates.Downed then
		return "prone", P.FallSeconds
	elseif player:GetAttribute(PA.Reviving) then
		return "kneel", P.CrouchSeconds
	elseif player:GetAttribute(PA.Crouched) or player:GetAttribute(PA.HideEnter) then
		return "crouch", P.CrouchSeconds
	end
	return nil, player:GetAttribute(PA.State) == Constants.PlayerStates.Active and P.RiseSeconds or P.CrouchSeconds
end

function PoseController:_frame(dt: number)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			self:_pose(player, character, root, dt)
		end
	end
end

function PoseController:_pose(player: Player, character: Model, root: BasePart, dt: number)
	local target, seconds = wanted(player)
	local rig = self:_rig(character)
	if not rig.complete then
		return
	end
	if target then
		if rig.pose ~= target and rig.weight > 0 then
			-- From one pose to another: through standing would look wrong, so
			-- blend from where the joints are now.
			rig.from = rig.last
			rig.fromAt = 0
		end
		rig.pose = target
	end
	local goal = target and 1 or 0
	local rate = dt / math.max(seconds, 0.05)
	rig.weight = goal > rig.weight and math.min(goal, rig.weight + rate) or math.max(goal, rig.weight - rate)
	if rig.weight <= 0 then
		if rig.wrote then
			-- Let the default animation have them back.
			for _, joint in rig.joints do
				joint.Transform = CFrame.identity
			end
			rig.wrote = false
			rig.pose = nil
		end
		return
	end
	-- The gait runs with the ground covered, so standing still it holds.
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local moving = math.clamp(speed / 3, 0, 1)
	local values
	if rig.pose == "prone" then
		rig.phase += speed * dt * P.CrawlStride
		values = PlayerPose.prone(rig.phase, moving)
	elseif rig.pose == "kneel" then
		values = PlayerPose.kneel()
	else
		rig.phase += speed * dt * P.CrouchStride
		values = PlayerPose.crouch(rig.phase, moving)
	end
	if rig.from then
		rig.fromAt = math.min(1, (rig.fromAt or 0) + dt / P.CrouchSeconds)
		values = PlayerPose.blend(rig.from, values, rig.fromAt)
		if rig.fromAt >= 1 then
			rig.from = nil
		end
	end
	rig.last = values
	-- Eased: in and out of a pose like a body, not a switch.
	local w = rig.weight * rig.weight * (3 - 2 * rig.weight)
	for name, joint in rig.joints do
		local v = values[name]
		if v then
			local pose = CFrame.new(v[4], v[5], v[6]) * CFrame.Angles(v[1], v[2], v[3])
			joint.Transform = w >= 0.999 and pose or joint.Transform:Lerp(pose, w)
		end
	end
	rig.wrote = true
end

return PoseController
