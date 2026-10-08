-- Builds The Guest's body (docs/ART.md "The Guest"): a dinner guest who
-- stayed far too long. Tall (8.4 studs) and thin, arms reaching past the
-- knees, narrow sloping shoulders and a small black head under a porcelain
-- mask, in a long black overcoat with its collar turned up. In low light he
-- is one tall stooped shape with a pale face and pale hands (doc section 8:
-- silhouette first).
--
-- A custom rig with R15 part and joint names, built from the proportions in
-- Logic/GuestPose so the server and every client agree on where his head is.
-- The joint parts are invisible "bones"; smooth primitives welded to them
-- are the clothes and skin, so nothing needs uploading. There is no
-- Animator: each client animates the joints itself (Controllers/
-- GuestController), and builds his face, smile and fingers locally.

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
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

local SHIRT = Color3.fromRGB(150, 143, 130) -- grubby, gone grey
local DARK = Color3.fromRGB(7, 6, 8) -- what is under the mask
local BONE = Color3.fromRGB(176, 170, 158) -- his wrists, where the sleeves fall short
local TIE = Color3.fromRGB(48, 22, 26)
local SHOE = Color3.fromRGB(12, 11, 12)
local LAPEL = Color3.fromRGB(30, 28, 32)
local BUTTON = Color3.fromRGB(58, 50, 40) -- dull horn
-- His coat's cloth: matte black wool (Data/Materials), never a sheen.
local WOOL = "CoatWool"

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
	if material == Enum.Material.Fabric then
		p.MaterialVariant = WOOL
	end
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
		-- The coat's skirt hangs from the hip on a joint of its own: each client
		-- swings it after the thigh, only part of the way (Config.Guest.CoatSwing),
		-- so it flares as he walks instead of splitting into trouser legs.
		l.coat = bone(model, side .. "CoatTail", at(0.4, 0.4, 0.4), l.hip)
		motor(side .. "Coat", lower, l.coat, l.hip)
	end

	-- Skin and clothes --------------------------------------------------------
	-- A long, matte black overcoat over the dark (docs/ART.md "The Guest"; the
	-- body pass of 2026-10-07, the owner: "his body doesn't really look very
	-- good"). The coat swallows the torch, so what reads is the mask, the bony
	-- hands and wrists, and one tall stooped shape: rounded and tapering
	-- everywhere, no straight posts. Matte wool: plain Fabric's speckle
	-- glittered in the torch like stone, and smooth plastic shone like latex.
	local Cloth, Smooth = Enum.Material.Fabric, Enum.Material.SmoothPlastic
	-- The head under the mask is dark (the mask over the dark, 2026-10-07):
	-- each client lays the porcelain mask over its face (Lib/GuestFace), so
	-- where the mask breaks there is only black. The neck is black too, so the
	-- mask floats.
	head.Transparency = 0
	head.Color = DARK
	head.Material = Smooth
	head.Reflectance = 0
	head.CanQuery = true
	head.CastShadow = true
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Sphere
	headMesh.Parent = head
	skin(head, "NeckSkin", "tube", at(0.34, Rig.neckLength + 0.3, 0.34), at(0, Rig.neckY + 0.12, 0.02), DARK, Smooth)

	-- The coat's body: a chest that narrows to the waist, round shoulders
	-- sloping into the sleeves, a stoop between the shoulder blades, and the
	-- collar turned up round the neck.
	skin(upper, "Coat", "tube", at(1.16, 1.5, 0.7), at(0, Rig.waistY + 0.72, 0.02), suit, Cloth)
	skin(upper, "Chest", "ball", at(1.32, 1.5, 0.8), at(0, Rig.shoulderY - 0.42, 0.02), suit, Cloth)
	skin(upper, "Stoop", "ball", at(1.0, 0.95, 0.56), at(0, Rig.shoulderY - 0.3, 0.26), suit, Cloth)
	skin(upper, "Collar", "tube", at(0.62, 0.42, 0.56), at(0, Rig.neckY + 0.09, 0.04), suit, Cloth)
	for _, sx in { -1, 1 } do
		skin(upper, "Shoulder", "ball", at(0.64, 0.32, 0.6), at(sx * 0.6, Rig.shoulderY - 0.04, 0.03), suit, Cloth, {
			rotation = CFrame.Angles(0, 0, sx * math.rad(-18)),
		})
		skin(upper, "Lapel", "block", at(0.1, 1.1, 0.03), at(sx * 0.16, Rig.neckY - 0.62, -0.4), LAPEL, Cloth, {
			rotation = CFrame.Angles(math.rad(-6), 0, sx * math.rad(16)),
			shadow = false,
		})
	end
	-- A narrow V of grubby shirt and a dark tie under the collar: a dinner
	-- guest, still.
	skin(upper, "ShirtFront", "ball", at(0.2, 0.6, 0.05), at(0, Rig.neckY - 0.36, -0.385), SHIRT, Smooth, {
		shadow = false,
	})
	skin(upper, "Tie", "block", at(0.06, 0.5, 0.03), at(0, Rig.neckY - 0.42, -0.405), TIE, Smooth, {
		shadow = false,
	})
	for i = 1, 3 do
		skin(
			upper,
			"Button",
			"ball",
			at(0.07, 0.07, 0.04),
			at(-0.05, Rig.waistY + 1.15 - i * 0.42, -0.37),
			BUTTON,
			Smooth,
			{
				shadow = false,
				query = false,
			}
		)
	end
	-- The skirt of the coat: a band round the hips, then one half on each
	-- thigh down to below the knee, flaring out and back, so it parts as he
	-- walks instead of his legs pushing through it.
	skin(lower, "CoatWaist", "tube", at(1.2, 0.9, 0.74), at(0, Rig.hipY + 0.3, 0.02), suit, Cloth)
	local hem = Config.Guest.CoatHem
	for side, l in limbs do
		local sx = side == "Left" and -1 or 1
		local top = Rig.hipY + 0.15
		skin(l.coat, "Skirt", "tube", at(0.68, top - hem, 0.76), at(sx * 0.32, (top + hem) / 2, 0.06), suit, Cloth, {
			rotation = CFrame.Angles(math.rad(-3), 0, sx * math.rad(4)),
		})
	end

	for _, l in limbs do
		-- Sleeves that taper from the shoulder to a cuff that stops short, so
		-- a thin bony wrist shows.
		local s = l.shoulder
		skin(l.upperArm, "Sleeve", "tube", at(0.37, 1.05, 0.37), s - at(0, 0.5, 0), suit, Cloth)
		skin(l.upperArm, "Sleeve", "tube", at(0.33, 1.1, 0.33), s - at(0, 1.45, 0), suit, Cloth)
		skin(l.upperArm, "ElbowCap", "ball", at(0.32, 0.36, 0.32), l.elbow, suit, Cloth)
		local short = 0.34
		skin(l.lowerArm, "Forearm", "tube", at(0.31, 0.85, 0.31), l.elbow - at(0, 0.45, 0), suit, Cloth)
		skin(
			l.lowerArm,
			"Forearm",
			"tube",
			at(0.28, Rig.lowerArm - short - 0.8, 0.28),
			l.wrist + at(0, short + (Rig.lowerArm - short - 0.8) / 2, 0),
			suit,
			Cloth
		)
		skin(l.lowerArm, "Cuff", "tube", at(0.32, 0.1, 0.32), l.wrist + at(0, short + 0.05, 0), suit, Cloth)
		skin(l.lowerArm, "Wrist", "tube", at(0.15, short + 0.06, 0.15), l.wrist + at(0, short / 2, 0), BONE, Smooth)
		skin(l.lowerArm, "WristKnob", "ball", at(0.19, 0.16, 0.17), l.wrist + at(0, 0.06, 0), BONE, Smooth)
		-- Long, narrow, bony hands. The fingers are built on each client.
		skin(l.hand, "Palm", "tube", at(0.085, Rig.hand - 0.08, 0.2), l.hand.Position + at(0, 0.04, 0), BONE, Smooth)
		-- Trousers, thin under the coat; the shins taper to the shoes.
		skin(l.upperLeg, "Trouser", "tube", at(0.42, Rig.upperLeg + 0.1, 0.42), l.upperLeg.Position, suit, Cloth)
		skin(l.upperLeg, "KneeCap", "ball", at(0.38, 0.4, 0.38), l.knee, suit, Cloth)
		skin(l.lowerLeg, "Shin", "tube", at(0.34, 1.0, 0.34), l.knee - at(0, 0.55, 0), suit, Cloth)
		skin(
			l.lowerLeg,
			"Shin",
			"tube",
			at(0.29, Rig.lowerLeg - 0.9, 0.29),
			l.ankle + at(0, (Rig.lowerLeg - 0.9) / 2, 0),
			suit,
			Cloth
		)
		-- Old dress shoes: a squared heel and a long rounded toe.
		local f = l.foot.Position
		skin(l.foot, "Shoe", "block", at(0.32, 0.24, 0.5), f + at(0, 0.0, 0.22), SHOE, Smooth, { reflectance = 0.06 })
		skin(l.foot, "Shoe", "ball", at(0.34, 0.26, 0.8), f + at(0, 0.0, -0.12), SHOE, Smooth, { reflectance = 0.06 })
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

	-- His legs, to the world (the squad playtest, 2026-10-08: "Guest gets
	-- stuck on top furniture"). Only the root collided, riding 3.9 to 5.3
	-- studs up, above beds (3) and tables (3.4): the Humanoid took their tops
	-- for floor and he walked up onto them. An invisible guard from knee
	-- height down to 1.2 over his feet stops at furniture like a wall, and
	-- still clears the stairs' ramps underfoot.
	local shins = Instance.new("Part")
	shins.Name = "Shins"
	shins.Size = Vector3.new(1.1, Rig.rootY - 0.7 - 1.2, 0.8)
	shins.CFrame = CFrame.new(0, 1.2 + shins.Size.Y / 2, 0)
	shins.Transparency = 1
	shins.CanCollide = true
	shins.CanTouch = false
	shins.CanQuery = false
	shins.CastShadow = false
	shins.Massless = true
	shins.Parent = model
	local shinWeld = Instance.new("WeldConstraint")
	shinWeld.Part0 = root
	shinWeld.Part1 = shins
	shinWeld.Parent = shins

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
