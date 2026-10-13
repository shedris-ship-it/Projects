-- The night outside the mansion (the visual rework V2, 2026-10-12: you can
-- see outside, the owner's note after IT WANTS IN). Seen only through the
-- windows' real openings (Logic/Windows) and from the front porch at the
-- end: a lawn round the house, a gravel drive from the front door, a ring of
-- trees thinning into the fog, a sodium streetlamp at the end of the drive.
-- Decoration only: nobody walks out here before the end (each window has a
-- bar), the Guest never comes out, and nothing in the run reads it. Built
-- from the run's seed (its own fork), so a house always has the same night.
--
-- The plants: dense woods mostly still in leaf, undergrowth, and a garden of
-- shrubs and tall evergreens along the walls (Logic/Grounds; the owner,
-- 2026-10-12: "more dense foliage"). Each is a modelled tree, bush or
-- arborvitae (kit.py kit9, Data/Kit `Outside`; World/Kit.placeOutside),
-- scaled to its plant and turned and tinted at random; until those are in,
-- stand-ins built from parts. The lawn is terrain grass, whose blades Roblox
-- draws.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Grounds = require(Shared.Logic.Grounds)
local Kit = require(Shared.World.Kit)
local MansionHouse = require(Shared.Logic.MansionHouse)
local PropFactory = require(Shared.World.PropFactory)
local WindowView = require(Shared.Logic.WindowView)

local E = Config.Exterior

local Exterior = {}

local DIRS = {
	N = Vector3.new(0, 0, -1),
	E = Vector3.new(1, 0, 0),
	S = Vector3.new(0, 0, 1),
	W = Vector3.new(-1, 0, 0),
}

local function scenery(model, name: string, size: Vector3, cf: CFrame, color: Color3, material: string, extra)
	local opts = { collide = false, query = false, castShadow = true }
	for k, v in extra or {} do
		opts[k] = v
	end
	return PropFactory.part(model, name, size, cf, color, PropFactory.material(material), opts)
end

-- The modelled plants (Data/Kit `Outside`), by kind: each plant wears one of
-- its kind's, picked from the seed.
local LOOKS = {
	leafy = { "TreeOakA", "TreeOakB" },
	turning = { "TreeTurning" },
	bare = { "TreeBareA", "TreeBareB" },
	conifer = { "ConiferA", "ConiferB" },
	bush = { "BushA", "BushB" },
	column = { "Arborvitae" },
}

-- A modelled plant at `at` on the lawn, `height` tall, at most `reach` from
-- `at` sideways (never nearer the house than its plant allows: the old
-- stand-ins kept to the same), at most `top` high if given (a shrub under
-- the sills): turned at random, leaning a little, tinted a shade lighter or
-- darker (a handful of shades: Kit.tint). nil when its look isn't in.
local function standPlant(model, names: { string }, at: Vector3, height: number, reach: number, rng, top: number?)
	local name = names[rng:NextInteger(1, #names)]
	local entry = Kit.measures("Outside", name)
	if not entry then
		return nil
	end
	local size = Vector3.new(entry.size[1], entry.size[2], entry.size[3])
	local centre = entry.centre or { 0, 0 }
	local k = height / size.Y
	-- (Its widest reach from its foot: half its box past its box's middle.)
	local spread = math.max(size.X, size.Z) / 2 + math.max(math.abs(centre[1]), math.abs(centre[2]))
	local wide = math.min(k, math.max(reach, 0.5) / spread)
	local tall = k
	if top then
		tall = math.min(k, top / (size.Y + (entry.floor or 0)))
	end
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-3, 3)), 0, math.rad(rng:NextNumber(-3, 3)))
	local cf = CFrame.new(at) * lean * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local mesh = Kit.placeOutside(model, name, cf, Vector3.new(wide, tall, wide))
	local T = E.KitTint
	local shade = T.Shades[rng:NextInteger(1, #T.Shades)] * T.Tone
	Kit.tint(mesh, Color3.new(shade, shade, shade))
	return mesh
end

-- A mass of leaves: an ellipsoid (a block drawn as a sphere mesh, so it can
-- be wider than tall), leafy, never casting a shadow (cheap, and the moon's
-- shadows are for the house).
local function blob(model, name: string, size: Vector3, cf: CFrame, color: Color3)
	local p = scenery(model, name, size, cf, color, "LeafyGrass", { castShadow = false })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- A leaf colour from the palette, a little varied.
local function leafColour(rng, base: { number }?): Color3
	local c = base or E.Leaves[rng:NextInteger(1, #E.Leaves)]
	local k = rng:NextNumber(0.85, 1.12)
	return Color3.fromRGB(math.min(c[1] * k, 255), math.min(c[2] * k, 255), math.min(c[3] * k, 255))
end

-- A trunk, leaning a little: its base CFrame and girth.
local function trunk(model, at: Vector3, height: number, rng, girth: number): CFrame
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), 0, math.rad(rng:NextNumber(-4, 4)))
	local base = CFrame.new(at) * lean
	scenery(
		model,
		"Trunk",
		Vector3.new(height, girth, girth),
		base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		PropFactory.rgb(E.Bark),
		"Wood",
		{ shape = Enum.PartType.Cylinder }
	)
	return base
end

local function branch(model, base: CFrame, height: number, girth: number, rng, from: { number }, len: { number })
	local start = base * CFrame.new(0, height * rng:NextNumber(from[1], from[2]), 0)
	local length = height * rng:NextNumber(len[1], len[2])
	local dir = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		* CFrame.Angles(math.rad(rng:NextNumber(25, 55)), 0, 0)
	local thick = girth * rng:NextNumber(0.25, 0.45)
	scenery(
		model,
		"Branch",
		Vector3.new(length, thick, thick),
		start * dir * CFrame.new(0, length / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		PropFactory.rgb(E.Bark),
		"Wood",
		{ shape = Enum.PartType.Cylinder, castShadow = false }
	)
end

-- A bare autumn tree: a trunk and a handful of branches reaching up and out.
local function bareTree(model, at: Vector3, height: number, far: boolean, clear: number, rng)
	local mesh = standPlant(model, LOOKS.bare, at, height, clear - 0.5 - 0.05 * height, rng)
	if mesh then
		mesh.CastShadow = not far
		return
	end
	local girth = rng:NextNumber(0.7, 1.4)
	local base = trunk(model, at, height, rng, girth)
	for _ = 1, far and rng:NextInteger(3, 4) or rng:NextInteger(4, 7) do
		branch(model, base, height, girth, rng, { 0.45, 0.9 }, { 0.25, 0.45 })
	end
end

-- A tree still in leaf: a trunk, a limb or two, and a crown of overlapping
-- masses of leaves round its upper part: lumpy, never a lollipop.
local function leafyTree(model, at: Vector3, height: number, far: boolean, clear: number, rng)
	-- (One in five turning, as the stand-ins' palette had it.)
	local turning = rng:NextInteger(1, #E.Leaves) == #E.Leaves
	local mesh =
		standPlant(model, turning and LOOKS.turning or LOOKS.leafy, at, height, clear - 0.5 - 0.05 * height, rng)
	if mesh then
		mesh.CastShadow = not far
		return
	end
	local girth = rng:NextNumber(0.8, 1.5)
	local base = trunk(model, at, height * 0.8, rng, girth)
	for _ = 1, far and 1 or 2 do
		branch(model, base, height, girth, rng, { 0.4, 0.6 }, { 0.2, 0.32 })
	end
	local C = E.Canopy
	-- (The crown reaches about 1.6 radii from its middle, which the trunk's
	-- lean moves: never as far as the house.)
	local radius = math.min(height * rng:NextNumber(C.Radius[1], C.Radius[2]), (clear - 0.5 - 0.05 * height) / 1.65)
	-- (Crowns sit at different heights and stand taller or squatter, so
	-- their undersides never line up into one row of mushrooms: seen
	-- 2026-10-12.)
	local centre = (base * CFrame.new(0, height * rng:NextNumber(0.56, 0.74), 0)).Position
	local palette = E.Leaves[rng:NextInteger(1, #E.Leaves)]
	local count = far and rng:NextInteger(3, 4) or rng:NextInteger(C.Blobs[1], C.Blobs[2])
	for i = 1, count do
		-- The first mass is the crown's heart; the rest bulge out round it.
		local spread = i == 1 and 0 or radius * rng:NextNumber(0.45, 0.8)
		local angle = rng:NextNumber(0, math.pi * 2)
		local up = i == 1 and 0 or radius * rng:NextNumber(-0.35, 0.5)
		local wide = radius * (i == 1 and 1.5 or rng:NextNumber(0.9, 1.3)) * (far and 1.25 or 1)
		local tall = wide * rng:NextNumber(0.7, 1.2)
		blob(
			model,
			"Leaves",
			Vector3.new(wide, tall, wide * rng:NextNumber(0.85, 1.1)),
			CFrame.new(centre + Vector3.new(math.cos(angle) * spread, up, math.sin(angle) * spread))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			leafColour(rng, palette)
		)
	end
end

-- A dark conifer: a short trunk and tiers of needles, each tall and narrow
-- and deep in the one below, so the outline is a spire (round tiers apart
-- read as snowmen, 2026-10-12).
local TIERS = {
	{ y = 0.32, tall = 0.56, wide = 1 },
	{ y = 0.55, tall = 0.44, wide = 0.7 },
	{ y = 0.76, tall = 0.34, wide = 0.42 },
}
local FAR_TIERS = { TIERS[1], { y = 0.62, tall = 0.62, wide = 0.55 } }

local function conifer(model, at: Vector3, height: number, far: boolean, clear: number, rng)
	local mesh = standPlant(model, LOOKS.conifer, at, height, clear - 0.5, rng)
	if mesh then
		mesh.CastShadow = not far
		return
	end
	local base = trunk(model, at, height * 0.35, rng, rng:NextNumber(0.6, 1))
	local wide = math.min(height * rng:NextNumber(0.24, 0.32), (clear - 0.5) * 2)
	for _, tier in far and FAR_TIERS or TIERS do
		blob(
			model,
			"Needles",
			Vector3.new(wide * tier.wide, height * tier.tall, wide * tier.wide * rng:NextNumber(0.9, 1.1)),
			base * CFrame.new(0, height * tier.y, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			leafColour(rng, E.Needles)
		)
	end
end

-- A bush: two to three low masses run together, half sunk in the grass;
-- nothing of it as far as `clear` (the house), its top under `high`.
local function bush(model, at: Vector3, scale: number, far: boolean, clear: number, rng, high: number?)
	local U = E.Undergrowth
	-- (A bush's masses spread about its size across: the modelled one as
	-- wide; never casting a shadow, as the masses never did.)
	local width = (U.Size[1] + U.Size[2]) / 2 * scale
	local look = Kit.measures("Outside", LOOKS.bush[1])
	if look then
		local height = width * look.size[2] / look.size[1]
		local mesh = standPlant(model, LOOKS.bush, at, height, clear - 0.3, rng, high)
		if mesh then
			mesh.CastShadow = false
			return
		end
	end
	local palette = E.Leaves[rng:NextInteger(1, #E.Leaves - 1)] -- (no turning colour this low)
	local limit = clear - 0.3
	for i = 1, far and 2 or rng:NextInteger(2, 3) do
		local wide = math.min(rng:NextNumber(U.Size[1], U.Size[2]) * scale, limit * 1.8)
		local tall = wide * rng:NextNumber(0.55, 0.8)
		if high then
			tall = math.min(tall, high / 0.8) -- (its top: 0.8 of its height above the ground)
		end
		local off = i == 1 and Vector3.zero
			or Vector3.new(rng:NextNumber(-0.5, 0.5) * wide, 0, rng:NextNumber(-0.5, 0.5) * wide)
		local room = math.max(limit - wide / 2, 0)
		if off.Magnitude > room then
			off = off.Unit * room
		end
		blob(
			model,
			"Bush",
			Vector3.new(wide, tall, wide * rng:NextNumber(0.75, 1)),
			CFrame.new(at + off + Vector3.new(0, tall * 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			leafColour(rng, palette)
		)
	end
end

-- A tall narrow evergreen by the house (an arborvitae, as 1988's gardens
-- had): one tall mass and a smaller one at its foot.
local function column(model, at: Vector3, height: number, clear: number, rng)
	local mesh = standPlant(model, LOOKS.column, at, height, clear - 0.75, rng)
	if mesh then
		mesh.CastShadow = false
		return
	end
	local needles = E.Needles
	local wide = math.min(rng:NextNumber(2.4, 3.2), (clear - 0.75) * 2 / 1.15) -- (its foot is the wider)
	blob(
		model,
		"Evergreen",
		Vector3.new(wide, height, wide),
		CFrame.new(at + Vector3.new(0, height * 0.48, 0)),
		leafColour(rng, needles)
	)
	blob(
		model,
		"Evergreen",
		Vector3.new(wide * 1.15, height * 0.4, wide * 1.1),
		CFrame.new(at + Vector3.new(rng:NextNumber(-0.3, 0.3), height * 0.18, rng:NextNumber(-0.3, 0.3))),
		leafColour(rng, needles)
	)
end

-- The lawn as terrain grass, with the house and the drive cut out (the
-- grass's blades would show through the ground floor). Remembered, so the
-- next run's Exterior.clear() takes it away again.
local filled: { cf: CFrame, size: Vector3 }? = nil

local function lawnOfGrass(centre: Vector3, size: Vector3, groundY: number, holes)
	local T = E.Terrain
	local terrain = Workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Grass, PropFactory.rgb(T.Colour))
	local cf = CFrame.new(centre.X, groundY - T.Depth / 2, centre.Z)
	local block = Vector3.new(size.X, T.Depth, size.Z)
	terrain:FillBlock(cf, block, Enum.Material.Grass)
	filled = { cf = cf, size = block }
	for _, hole in holes do
		terrain:FillBlock(
			CFrame.new(hole.x, groundY - T.Depth / 2, hole.z),
			Vector3.new(hole.w, T.Depth + 8, hole.d),
			Enum.Material.Air
		)
	end
end

-- Takes the last run's grass away (WorldService:Clear).
function Exterior.clear()
	if filled then
		Workspace.Terrain:FillBlock(filled.cf, filled.size + Vector3.new(8, 8, 8), Enum.Material.Air)
		filled = nil
	end
end

local function streetlamp(model, at: Vector3, facing: Vector3)
	local iron = PropFactory.rgb(E.Iron)
	scenery(
		model,
		"LampPost",
		Vector3.new(E.LampHeight, 0.45, 0.45),
		CFrame.new(at + Vector3.new(0, E.LampHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		iron,
		"Metal",
		{ shape = Enum.PartType.Cylinder }
	)
	local top = at + Vector3.new(0, E.LampHeight, 0)
	local armEnd = top + facing * 2.4
	scenery(model, "LampArm", Vector3.new(0.3, 0.3, 2.6), CFrame.lookAt((top + armEnd) / 2, armEnd), iron, "Metal")
	local head = scenery(
		model,
		"LampHead",
		Vector3.new(1.4, 0.5, 0.9),
		CFrame.lookAt(armEnd - Vector3.new(0, 0.3, 0), armEnd - Vector3.new(0, 0.3, 0) + facing),
		PropFactory.rgb(E.Sodium),
		"Neon",
		{ castShadow = false }
	)
	local pool = Instance.new("SpotLight")
	pool.Name = "StreetLight"
	pool.Face = Enum.NormalId.Bottom
	pool.Angle = 120
	pool.Range = E.LampRange
	pool.Brightness = E.LampBrightness
	pool.Color = PropFactory.rgb(E.Sodium)
	pool.Shadows = true
	pool.Parent = head
	local glow = Instance.new("PointLight")
	glow.Name = "StreetGlow"
	glow.Range = 10
	glow.Brightness = 0.6
	glow.Color = PropFactory.rgb(E.Sodium)
	glow.Shadows = false
	glow.Parent = head
	CollectionService:AddTag(head, "ConsensusGlare") -- Controllers/LensController draws its halo
	-- The modelled lamp (Data/Kit Streetlamp): its arm reaches toward `facing`
	-- (its -Z), its refractor glowing where the head's lights shine from.
	if Kit.placeOutside(model, "Streetlamp", CFrame.lookAt(at, at + facing), Vector3.one) then
		for _, name in { "LampPost", "LampArm", "LampHead" } do
			for _, part in model:GetChildren() do
				if part.Name == name and part:IsA("BasePart") then
					Kit.hide(part)
				end
			end
		end
	end
	return head
end

-- The sky. Roblox's night sky is black, so dark trees against it are
-- nothing; a ring of panels beyond the trees, each a gradient from a moonlit
-- blue-grey at the horizon fading up into the real sky, gives them something
-- to stand against (seen 2026-10-12: at radius 200 the fog swallows it, at
-- 110 it reads). Panels are chords of the circle, edge to edge: overlapping
-- ones doubled up into bright seams. Server-made SurfaceGuis (Studio's
-- screenshots skip client-made ones).
local function skyRing(model, centre: Vector3, radius: number)
	local S = E.Sky
	local chord = 2 * radius * math.sin(math.pi / S.Panels)
	local inset = radius * math.cos(math.pi / S.Panels)
	local colours = {}
	for _, stop in S.Gradient do
		table.insert(colours, ColorSequenceKeypoint.new(stop[1], PropFactory.rgb(stop[2])))
	end
	local alphas = {}
	for _, stop in S.Fade do
		table.insert(alphas, NumberSequenceKeypoint.new(stop[1], stop[2]))
	end
	for i = 0, S.Panels - 1 do
		local a = (i + 0.5) / S.Panels * math.pi * 2
		local at = centre + Vector3.new(math.sin(a) * inset, S.Height / 2 - S.Sink, -math.cos(a) * inset)
		local panel = scenery(
			model,
			"SkyPanel",
			Vector3.new(chord, S.Height, 0.2),
			CFrame.lookAt(at, Vector3.new(centre.X, at.Y, centre.Z)),
			Color3.new(),
			"SmoothPlastic",
			{ transparency = 1, castShadow = false }
		)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Night"
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.Brightness = 1
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 2
		gui.Parent = panel
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = Color3.new(1, 1, 1)
		fill.Parent = gui
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new(colours)
		gradient.Transparency = NumberSequence.new(alphas)
		gradient.Parent = fill
	end
end

-- The run's moon (Logic/WindowView: a compass bearing and a height), low and
-- pale in front of the sky ring, with a soft halo: the same moon the windows
-- that face it see.
local function moonOf(model, centre: Vector3, radius: number, moon)
	if not moon then
		return
	end
	local dir = Vector3.new(WindowView.direction(moon)) -- (the windows' beams use the same)
	local distance = radius - 2
	local at = centre + dir * distance
	local halo = E.Sky.MoonHalo
	local plane = scenery(
		model,
		"Moon",
		Vector3.new(halo, halo, 0.2),
		CFrame.lookAt(at, centre),
		Color3.new(),
		"SmoothPlastic",
		{ transparency = 1, castShadow = false }
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "MoonGlow"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = E.Sky.MoonBrightness
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 8
	gui.Parent = plane
	local glow = Instance.new("ImageLabel")
	glow.Size = UDim2.fromScale(1, 1)
	glow.BackgroundTransparency = 1
	glow.Image = E.Sky.HaloImage
	glow.ImageColor3 = PropFactory.rgb(E.Sky.MoonColour)
	glow.ImageTransparency = 0.35
	glow.Parent = gui
	local disc = Instance.new("Frame")
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromScale(E.Sky.MoonDisc / halo, E.Sky.MoonDisc / halo)
	disc.BorderSizePixel = 0
	disc.BackgroundColor3 = PropFactory.rgb(E.Sky.MoonColour)
	disc.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = disc
end

-- Builds the night round a mansion. layout: the house's (rooms, frontDoor);
-- folder: the level folder; origin: Config.Level.Origin as a Vector3; moon:
-- the run's (World's `moon`, Logic/WindowView).
function Exterior.build(layout, folder: Instance, origin: Vector3, rng, moon)
	local model = Instance.new("Model")
	model.Name = "Exterior"
	-- The house's footprint on its main floors.
	local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
	for _, room in layout.rooms do
		local floor = room.floor or 0
		if floor >= 0 and floor <= 1 then
			x0, z0 = math.min(x0, room.x), math.min(z0, room.z)
			x1, z1 = math.max(x1, room.x + room.w), math.max(z1, room.z + room.d)
		end
	end
	if x0 == math.huge then
		return nil
	end
	x0, z0, x1, z1 = x0 + origin.X, z0 + origin.Z, x1 + origin.X, z1 + origin.Z
	local middle = Vector3.new((x0 + x1) / 2, origin.Y, (z0 + z1) / 2)
	local groundY = origin.Y - E.GroundDrop

	-- The lawn: one wide slab under everything (its top under the house's
	-- floors, which stand on it).
	scenery(
		model,
		"Lawn",
		Vector3.new(E.Reach * 2 + (x1 - x0), 1, E.Reach * 2 + (z1 - z0)),
		CFrame.new(middle.X, groundY - 0.5, middle.Z),
		PropFactory.rgb(E.Grass),
		"Grass",
		{ castShadow = false, collide = true, query = true } -- (the porch steps out onto it at the end)
	)

	-- The drive: gravel from the front door straight out, the streetlamp at
	-- its end.
	local front = layout.frontDoor
	local driveDir, driveFrom = nil, nil
	if front then
		driveDir = DIRS[front.dir]
		local along = front.along
		local onX = front.dir == "N" or front.dir == "S"
		local line = front.line
		local door = onX and Vector3.new(origin.X + along, groundY, origin.Z + line)
			or Vector3.new(origin.X + line, groundY, origin.Z + along)
		driveFrom = door
		local length = E.DriveLength
		local centre = door + driveDir * (length / 2 + 6)
		scenery(
			model,
			"Drive",
			onX and Vector3.new(E.DriveWidth, 0.2, length) or Vector3.new(length, 0.2, E.DriveWidth),
			CFrame.new(centre + Vector3.new(0, 0.05, 0)),
			PropFactory.rgb(E.Gravel),
			"Pebble",
			{ castShadow = false, collide = true, query = true }
		)
		local side = Vector3.new(-driveDir.Z, 0, driveDir.X)
		streetlamp(model, door + driveDir * (length + 4) + side * (E.DriveWidth / 2 + 2), -side)
	end

	-- The plants (Logic/Grounds): the woods, the undergrowth and the garden.
	-- The windows' spots keep the tall evergreens from standing in front of
	-- one.
	local windows = {}
	for _, d in folder:GetDescendants() do
		if d.Name == "Glass" and d.Parent and d.Parent.Name == "Window" and d:IsA("BasePart") then
			table.insert(windows, { x = d.Position.X - origin.X, z = d.Position.Z - origin.Z })
		end
	end
	local house = { rooms = MansionHouse.withPassages(layout), frontDoor = layout.frontDoor }
	local plants, rects = Grounds.plan(house, windows, E, rng:Fork("grounds"))
	local trees = 0
	for _, plant in plants do
		local at = Vector3.new(plant.x + origin.X, groundY, plant.z + origin.Z)
		if plant.kind == "leafy" then
			leafyTree(model, at, plant.size, plant.far, plant.clear, rng)
			trees += 1
		elseif plant.kind == "bare" then
			bareTree(model, at, plant.size, plant.far, plant.clear, rng)
			trees += 1
		elseif plant.kind == "conifer" then
			conifer(model, at, plant.size, plant.far, plant.clear, rng)
			trees += 1
		elseif plant.kind == "bush" then
			bush(model, at, plant.size, plant.far, plant.clear, rng)
		elseif plant.kind == "shrub" then
			bush(model, at, plant.size * 0.8, false, plant.clear, rng, E.Garden.High)
		elseif plant.kind == "column" then
			column(model, at, plant.size, plant.clear, rng)
		end
	end
	model:SetAttribute("Trees", trees)
	model:SetAttribute("Plants", #plants)

	-- The lawn as terrain grass, but never under the house or the drive.
	local holes = {}
	local margin = E.Terrain.Margin
	for _, r in rects do
		table.insert(holes, {
			x = (r[1] + r[3]) / 2 + origin.X,
			z = (r[2] + r[4]) / 2 + origin.Z,
			w = r[3] - r[1] + margin * 2,
			d = r[4] - r[2] + margin * 2,
		})
	end
	if driveDir then
		local reach = E.DriveLength + 8
		local mid = driveFrom + driveDir * (reach / 2 - 1)
		local alongX = driveDir.X ~= 0
		table.insert(holes, {
			x = mid.X,
			z = mid.Z,
			w = alongX and reach or E.DriveWidth + 1,
			d = alongX and E.DriveWidth + 1 or reach,
		})
	end
	lawnOfGrass(middle, Vector3.new(E.Reach * 2 + (x1 - x0), 0, E.Reach * 2 + (z1 - z0)), groundY, holes)

	-- The sky ring just past the last trees, and the moon on it.
	local halfDiagonal = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2) / 2
	local radius = halfDiagonal + E.Reach + E.Sky.Beyond
	local centre = Vector3.new(middle.X, groundY, middle.Z)
	skyRing(model, centre, radius)
	moonOf(model, centre, radius, moon)
	model.Parent = folder
	return model
end

return Exterior
