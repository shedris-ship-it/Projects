-- Builds The Guest's body (docs/ART.md "The Guest"): a dinner guest who
-- stayed far too long. Tall (8.4 studs) and thin, arms reaching past the
-- knees, narrow sloping shoulders and a small porcelain head, in a dated,
-- slightly too-big dark suit whose pale collar and cuffs give the body edges
-- in low light (doc section 8: silhouette first).
--
-- A custom rig with R15 part and joint names, built from the proportions in
-- Logic/GuestPose so the server and every client agree on where his head is.
-- The joint parts are invisible "bones"; smooth primitives welded to them
-- are the clothes and skin, so nothing needs uploading. There is no
-- Animator: each client animates the joints itself (Controllers/
-- GuestController), and builds his face, smile and fingers locally.

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared.Constants)
local GuestPose = require(Shared.Logic.GuestPose)

local Rig = GuestPose.Rig

local StalkerModel = {}

StalkerModel.ParkCFrame = CFrame.new(0, 400, -4000)

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

local SHIRT = Color3.fromRGB(210, 204, 190)
local DARK = Color3.fromRGB(7, 6, 8) -- what is under the mask
local BONE = Color3.fromRGB(176, 170, 158) -- his wrists, where the sleeves fall short
local TIE = Color3.fromRGB(48, 22, 26)
local SHOE = Color3.fromRGB(12, 11, 12)
local LAPEL = Color3.fromRGB(36, 34, 38)

-- An unanchored part of the rig. Bones are invisible; only the root collides.
local function bone(model: Model, name: string, size: Vector3, position: Vector3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(position)
	p.Transparency = 1
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Massless = name ~= "HumanoidRootPart"
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- A visible piece welded to a bone. shape: "ball" (an ellipsoid of `size`),
-- "tube" (an elliptical cylinder standing upright: size = (width, height,
-- depth)) or "block".
local function skin(
	bonePart: BasePart,
	name: string,
	shape: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material,
	opts
)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Color = color
	p.Material = material
	p.Reflectance = opts.reflectance or 0
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = opts.query ~= false
	p.CastShadow = opts.shadow ~= false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local rotation = opts.rotation or CFrame.identity
	if shape == "tube" then
		-- Cylinders run along X: stand it up, and size it (height, width, depth).
		p.Size = Vector3.new(size.Y, size.X, size.Z)
		rotation = rotation * CFrame.Angles(0, 0, math.pi / 2)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Cylinder
		mesh.Parent = p
	else
		p.Size = size
		if shape == "ball" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
	end
	p.CFrame = CFrame.new(position) * rotation
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bonePart
	weld.Part1 = p
	weld.Parent = p
	p.Parent = bonePart
	return p
end

local function motor(name: string, part0: BasePart, part1: BasePart, joint: Vector3)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:ToObjectSpace(CFrame.new(joint))
	m.C1 = part1.CFrame:ToObjectSpace(CFrame.new(joint))
	m.Parent = part1
	return m
end

-- Returns { model, humanoid, root, head, tracks, groundOffset }. Built at the
-- origin standing on y = 0, then parked out of sight.
function StalkerModel.build(archetype, parent: Instance)
	local suit = rgb(archetype.bodyColor)
	local porcelain = rgb(archetype.headColor)
	local model = Instance.new("Model")
	model.Name = "Stalker"

	local function at(x, y, z)
		return Vector3.new(x, y, z)
	end

	-- Bones -----------------------------------------------------------------
	local root = bone(model, "HumanoidRootPart", v3(Rig.rootSize), at(0, Rig.rootY, 0))
	root.CanCollide = true
	local lower = bone(model, "LowerTorso", v3(Rig.lowerTorsoSize), at(0, Rig.lowerTorsoY, 0))
	local upperH = Rig.upperTorsoSize[2]
	local upper = bone(model, "UpperTorso", v3(Rig.upperTorsoSize), at(0, Rig.waistY + upperH / 2, 0))
	local head = bone(model, "Head", v3(Rig.headSize), at(0, Rig.headY, 0))

	local limbs = {}
	for _, side in { "Left", "Right" } do
		local sx = side == "Left" and -1 or 1
		local shoulder = at(sx * Rig.shoulderX, Rig.shoulderY, 0)
		local elbow = shoulder - at(0, Rig.upperArm, 0)
		local wrist = elbow - at(0, Rig.lowerArm, 0)
		local hip = at(sx * Rig.hipX, Rig.hipY, 0)
		local knee = hip - at(0, Rig.upperLeg, 0)
		local ankle = knee - at(0, Rig.lowerLeg, 0)
		local footSize = v3(Rig.footSize)
		local l = {
			upperArm = bone(
				model,
				side .. "UpperArm",
				at(0.36, Rig.upperArm, 0.36),
				shoulder - at(0, Rig.upperArm / 2, 0)
			),
			lowerArm = bone(
				model,
				side .. "LowerArm",
				at(0.32, Rig.lowerArm, 0.32),
				elbow - at(0, Rig.lowerArm / 2, 0)
			),
			hand = bone(model, side .. "Hand", at(0.26, Rig.hand, 0.14), wrist - at(0, Rig.hand / 2, 0)),
			upperLeg = bone(model, side .. "UpperLeg", at(0.46, Rig.upperLeg, 0.46), hip - at(0, Rig.upperLeg / 2, 0)),
			lowerLeg = bone(model, side .. "LowerLeg", at(0.4, Rig.lowerLeg, 0.4), knee - at(0, Rig.lowerLeg / 2, 0)),
			foot = bone(model, side .. "Foot", footSize, at(ankle.X, footSize.Y / 2, -0.3)),
			shoulder = shoulder,
			elbow = elbow,
			wrist = wrist,
			hip = hip,
			knee = knee,
			ankle = ankle,
		}
		limbs[side] = l
	end

	-- Joints (R15 names, parented to Part1) ---------------------------------
	motor("Root", root, lower, at(0, Rig.lowerTorsoY, 0))
	motor("Waist", lower, upper, at(0, Rig.waistY, 0))
	motor("Neck", upper, head, at(0, Rig.neckY, 0))
	for side, l in limbs do
		motor(side .. "Shoulder", upper, l.upperArm, l.shoulder)
		motor(side .. "Elbow", l.upperArm, l.lowerArm, l.elbow)
		motor(side .. "Wrist", l.lowerArm, l.hand, l.wrist)
		motor(side .. "Hip", lower, l.upperLeg, l.hip)
		motor(side .. "Knee", l.upperLeg, l.lowerLeg, l.knee)
		motor(side .. "Ankle", l.lowerLeg, l.foot, l.ankle)
	end

	-- Skin and clothes --------------------------------------------------------
	local Fabric, Smooth = Enum.Material.Fabric, Enum.Material.SmoothPlastic
	-- The head under the mask is dark (docs/ART.md "The Guest", the mask
	-- over the dark, 2026-10-07): each client lays the porcelain mask over its
	-- face (Lib/GuestFace), so where the mask breaks there is only black.
	head.Transparency = 0
	head.Color = DARK
	head.Material = Smooth
	head.Reflectance = 0
	head.CanQuery = true
	head.CastShadow = true
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Sphere
	headMesh.Parent = head
	local neckSkin = Color3.fromRGB(168, 161, 150)
	skin(head, "NeckSkin", "tube", at(0.3, Rig.neckLength + 0.2, 0.3), at(0, Rig.neckY + 0.1, 0.02), neckSkin, Smooth)

	-- A suit a size too big: a straight chest, padded but narrow shoulders,
	-- lapels, and a jacket hanging to the thigh.
	skin(upper, "Jacket", "tube", at(1.2, 1.95, 0.7), at(0, Rig.waistY + 1.0, 0.02), suit, Fabric)
	skin(lower, "JacketHem", "tube", at(1.3, 1.0, 0.76), at(0, Rig.hipY + 0.4, 0.02), suit, Fabric)
	for _, sx in { -1, 1 } do
		-- Narrow shoulders that slope away: no pads, only the cloth over the joint.
		skin(upper, "ShoulderPad", "ball", at(0.36, 0.24, 0.5), at(sx * 0.56, Rig.shoulderY - 0.12, 0.04), suit, Fabric)
		-- Coat tails, hanging behind his thighs.
		skin(lower, "CoatTail", "block", at(0.5, 1.7, 0.06), at(sx * 0.3, Rig.hipY - 0.55, 0.36), suit, Fabric, {
			rotation = CFrame.Angles(math.rad(-4), 0, sx * math.rad(-3)),
		})
		skin(upper, "Lapel", "block", at(0.09, 1.15, 0.03), at(sx * 0.17, Rig.neckY - 0.6, -0.36), LAPEL, Fabric, {
			rotation = CFrame.Angles(0, 0, sx * math.rad(16)),
			shadow = false,
		})
	end
	-- Pale collar and a narrow V of shirt with a dark tie: edges you can see
	-- in the dark.
	skin(upper, "Collar", "tube", at(0.4, 0.12, 0.38), at(0, Rig.neckY + 0.03, 0.02), SHIRT, Smooth)
	skin(upper, "ShirtFront", "ball", at(0.26, 0.72, 0.06), at(0, Rig.neckY - 0.36, -0.365), SHIRT, Smooth, {
		shadow = false,
	})
	skin(upper, "Tie", "block", at(0.07, 0.56, 0.03), at(0, Rig.neckY - 0.42, -0.39), TIE, Fabric, {
		shadow = false,
	})

	for _, l in limbs do
		skin(l.upperArm, "Sleeve", "tube", at(0.32, Rig.upperArm + 0.1, 0.32), l.upperArm.Position, suit, Fabric)
		skin(l.upperArm, "ElbowCap", "ball", at(0.31, 0.31, 0.31), l.elbow, suit, Fabric)
		-- Sleeves a little short: the cuff rides up, and a bony wrist shows.
		local short = 0.32
		skin(
			l.lowerArm,
			"Forearm",
			"tube",
			at(0.29, Rig.lowerArm - short, 0.29),
			l.lowerArm.Position + at(0, short / 2, 0),
			suit,
			Fabric
		)
		skin(
			l.lowerArm,
			"Cuff",
			"tube",
			at(0.27, 0.12, 0.27),
			l.wrist + at(0, short + 0.04, 0),
			SHIRT,
			Smooth,
			{ shadow = false }
		)
		skin(l.lowerArm, "Wrist", "tube", at(0.17, short + 0.06, 0.17), l.wrist + at(0, short / 2, 0), BONE, Smooth)
		-- Long, narrow, bony hands. The fingers are built on each client.
		skin(l.hand, "Palm", "ball", at(0.24, Rig.hand, 0.12), l.hand.Position, porcelain, Smooth, {
			reflectance = 0.03,
		})
		skin(l.upperLeg, "Trouser", "tube", at(0.48, Rig.upperLeg + 0.1, 0.48), l.upperLeg.Position, suit, Fabric)
		skin(l.upperLeg, "KneeCap", "ball", at(0.44, 0.44, 0.44), l.knee, suit, Fabric)
		skin(l.lowerLeg, "Shin", "tube", at(0.36, Rig.lowerLeg, 0.36), l.lowerLeg.Position, suit, Fabric)
		skin(l.foot, "Shoe", "ball", at(0.4, 0.3, 1.12), l.foot.Position + at(0, 0.02, -0.04), SHOE, Smooth, {
			reflectance = 0.1,
		})
	end

	-- Humanoid: walks with MoveTo, never dies, never jumps or climbs ----------
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.AutomaticScalingEnabled = false
	humanoid.HipHeight = Rig.hipHeight
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.AutoJumpEnabled = false
	humanoid.Parent = model
	for _, state in
		{
			Enum.HumanoidStateType.Dead,
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Climbing,
			Enum.HumanoidStateType.Jumping,
			Enum.HumanoidStateType.Seated,
			Enum.HumanoidStateType.Swimming,
		}
	do
		humanoid:SetStateEnabled(state, false)
	end

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = Constants.CollisionGroups.Stalker
		end
	end
	model.PrimaryPart = root
	model:SetAttribute(Constants.Attributes.CId, "stalker")
	model:SetAttribute("HeadTilt", archetype.headTiltDegrees or 14)
	model:SetAttribute("GuestPose", GuestPose.Poses.Idle)
	model:SetAttribute("GuestForm", 0)
	model:SetAttribute("GuestGaze", 0)
	CollectionService:AddTag(model, Constants.Tags.Stalker)

	model:PivotTo(StalkerModel.ParkCFrame)
	root.Anchored = true
	model.Parent = parent

	return {
		model = model,
		humanoid = humanoid,
		root = root,
		head = head,
		tracks = {}, -- no server animation: clients animate the joints
		groundOffset = Rig.rootY,
	}
end

return StalkerModel
