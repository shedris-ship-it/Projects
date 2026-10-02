-- Builds the stalker's body. Silhouette first (doc section 8): very tall,
-- narrow, near-black, faceless, head tilted slightly off human. Uses a
-- standard R15 rig so default animations work; falls back to a hand-built
-- R6 rig if the avatar service is unavailable (e.g. in a test place offline).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared.Constants)

local StalkerModel = {}

local R15_ANIMS = {
	walk = "rbxassetid://507777826",
	run = "rbxassetid://507767714",
	idle = "rbxassetid://507766388",
}
local R6_ANIMS = {
	walk = "rbxassetid://180426354",
	run = "rbxassetid://180426354",
	idle = "rbxassetid://180435571",
}

StalkerModel.ParkCFrame = CFrame.new(0, 400, -4000)

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function buildR15(archetype)
	local description = Instance.new("HumanoidDescription")
	local body, head = rgb(archetype.bodyColor), rgb(archetype.headColor)
	description.HeadColor = head
	description.TorsoColor = body
	description.LeftArmColor = body
	description.RightArmColor = body
	description.LeftLegColor = body
	description.RightLegColor = body
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	-- Stretch the rig with the humanoid scale values; automatic scaling
	-- rescales parts, joints and hip height together.
	local scales = {
		BodyHeightScale = archetype.height / 5.2,
		BodyWidthScale = 0.72,
		BodyDepthScale = 0.72,
		HeadScale = 0.92,
	}
	for name, value in scales do
		local holder = humanoid:FindFirstChild(name)
		if holder and holder:IsA("NumberValue") then
			holder.Value = value
		end
	end
	return model, R15_ANIMS
end

local function buildR6(archetype)
	local s = archetype.height / 5
	local body, headColor = rgb(archetype.bodyColor), rgb(archetype.headColor)
	local model = Instance.new("Model")
	local function part(name, size, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * s
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), body)
	root.Transparency = 1
	local torso = part("Torso", Vector3.new(1.6, 2, 0.8), body)
	local head = part("Head", Vector3.new(1, 1.2, 1), headColor)
	local la = part("Left Arm", Vector3.new(0.6, 2.6, 0.6), body)
	local ra = part("Right Arm", Vector3.new(0.6, 2.6, 0.6), body)
	local ll = part("Left Leg", Vector3.new(0.7, 2, 0.7), body)
	local rl = part("Right Leg", Vector3.new(0.7, 2, 0.7), body)
	local function motor(name, p0, p1, c0, c1)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = c0
		m.C1 = c1
		m.Parent = p0
		return m
	end
	motor("RootJoint", root, torso, CFrame.new(), CFrame.new())
	motor("Neck", torso, head, CFrame.new(0, 1 * s, 0), CFrame.new(0, -0.6 * s, 0))
	motor("Left Shoulder", torso, la, CFrame.new(-1.1 * s, 0.7 * s, 0), CFrame.new(0, 1.0 * s, 0))
	motor("Right Shoulder", torso, ra, CFrame.new(1.1 * s, 0.7 * s, 0), CFrame.new(0, 1.0 * s, 0))
	motor("Left Hip", torso, ll, CFrame.new(-0.45 * s, -1 * s, 0), CFrame.new(0, 1 * s, 0))
	motor("Right Hip", torso, rl, CFrame.new(0.45 * s, -1 * s, 0), CFrame.new(0, 1 * s, 0))
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model
	model.PrimaryPart = root
	return model, R6_ANIMS
end

-- Returns { model, humanoid, root, head, tracks }.
function StalkerModel.build(archetype, parent: Instance)
	local ok, model, anims = pcall(buildR15, archetype)
	if not ok then
		warn("[Consensus] R15 stalker unavailable, using block rig: " .. tostring(model))
		model, anims = buildR6(archetype)
	end
	model.Name = "Stalker"
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head")
	model.PrimaryPart = root

	-- Faceless and featureless.
	for _, d in model:GetDescendants() do
		if d:IsA("Decal") or d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		end
	end
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid.AutoJumpEnabled = false

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = Constants.CollisionGroups.Stalker
			d.CastShadow = true
			if d.Name ~= "HumanoidRootPart" then
				d.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	model:SetAttribute(Constants.Attributes.CId, "stalker")
	CollectionService:AddTag(model, Constants.Tags.Stalker)

	-- Head tilt: wrongness through posture (doc section 8).
	local neck = head
		and (head:FindFirstChild("Neck") or (model:FindFirstChild("Torso") and model.Torso:FindFirstChild("Neck")))
	if neck and neck:IsA("Motor6D") then
		neck.C0 = neck.C0 * CFrame.Angles(0, 0, math.rad(archetype.headTiltDegrees or 10))
	end

	model:PivotTo(StalkerModel.ParkCFrame)
	root.Anchored = true
	model.Parent = parent

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local tracks = {}
	for name, id in anims do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local okLoad, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if okLoad then
			track.Looped = true
			tracks[name] = track
		end
	end

	-- Height of the root above the floor, for placing the body by teleport.
	-- Wait a moment so automatic scaling has resized the rig.
	task.wait(0.2)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local groundOffset = root.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)

	return {
		model = model,
		humanoid = humanoid,
		root = root,
		head = head,
		tracks = tracks,
		groundOffset = groundOffset,
	}
end

return StalkerModel
