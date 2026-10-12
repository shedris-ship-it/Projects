-- The night outside the mansion (the visual rework V2, 2026-10-12: you can
-- see outside, the owner's note after IT WANTS IN). Seen only through the
-- windows' real openings (Logic/Windows) and from the front porch at the
-- end: a lawn round the house, a gravel drive from the front door, a ring of
-- trees thinning into the fog, a sodium streetlamp at the end of the drive.
-- Decoration only: nobody walks out here before the end (each window has a
-- bar), the Guest never comes out, and nothing in the run reads it. Built
-- from the run's seed (its own fork), so a house always has the same night.
--
-- The trees are stand-ins built from parts until their Blender batch lands
-- (the visual rework V4d): bare autumn trees and a few pines, silhouettes in
-- the fog.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
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

-- A bare autumn tree: a trunk and a handful of branches reaching up and out.
local function bareTree(model, at: Vector3, rng)
	local height = rng:NextNumber(E.TreeHeight[1], E.TreeHeight[2])
	local girth = rng:NextNumber(0.7, 1.4)
	local bark = PropFactory.rgb(E.Bark)
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), 0, math.rad(rng:NextNumber(-4, 4)))
	local base = CFrame.new(at) * lean
	scenery(
		model,
		"Trunk",
		Vector3.new(height, girth, girth),
		base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		bark,
		"Wood",
		{ shape = Enum.PartType.Cylinder }
	)
	for _ = 1, rng:NextInteger(4, 7) do
		local from = height * rng:NextNumber(0.45, 0.9)
		local length = height * rng:NextNumber(0.25, 0.45)
		local yaw = rng:NextNumber(0, math.pi * 2)
		local tilt = math.rad(rng:NextNumber(25, 55))
		local thick = girth * rng:NextNumber(0.25, 0.45)
		local dir = CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt, 0, 0)
		local start = base * CFrame.new(0, from, 0)
		local mid = start * dir * CFrame.new(0, length / 2, 0)
		scenery(
			model,
			"Branch",
			Vector3.new(length, thick, thick),
			mid * CFrame.Angles(0, 0, math.rad(90)),
			bark,
			"Wood",
			{ shape = Enum.PartType.Cylinder, castShadow = false }
		)
	end
end

-- A pine: a trunk and tiers of dark needles narrowing to the top.
local function pine(model, at: Vector3, rng)
	local height = rng:NextNumber(E.TreeHeight[1] * 1.1, E.TreeHeight[2] * 1.2)
	local needles = PropFactory.rgb(E.Needles)
	scenery(
		model,
		"Trunk",
		Vector3.new(height * 0.5, 0.9, 0.9),
		CFrame.new(at + Vector3.new(0, height * 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		PropFactory.rgb(E.Bark),
		"Wood",
		{ shape = Enum.PartType.Cylinder }
	)
	local tiers = 4
	for i = 1, tiers do
		local t = (i - 1) / (tiers - 1)
		local width = (1 - t) * height * 0.38 + 1.2
		local y = height * (0.25 + 0.68 * t)
		scenery(
			model,
			"Needles",
			Vector3.new(width, height * 0.22, width),
			CFrame.new(at + Vector3.new(0, y, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			needles,
			"Grass",
			{ shape = Enum.PartType.Ball }
		)
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

	-- The trees: a jittered grid, nothing on the lawn close to the house or on
	-- the drive, denser further out, thinning into the fog.
	local function distanceToHouse(p: Vector3): number
		local dx = math.max(x0 - p.X, 0, p.X - x1)
		local dz = math.max(z0 - p.Z, 0, p.Z - z1)
		return math.sqrt(dx * dx + dz * dz)
	end
	local step = E.TreeSpacing
	local count = 0
	for gx = x0 - E.Reach, x1 + E.Reach, step do
		for gz = z0 - E.Reach, z1 + E.Reach, step do
			local p = Vector3.new(
				gx + rng:NextNumber(-step * 0.45, step * 0.45),
				groundY,
				gz + rng:NextNumber(-step * 0.45, step * 0.45)
			)
			local away = distanceToHouse(p)
			local onDrive = false
			if driveDir then
				local rel = p - driveFrom
				local ahead = rel:Dot(driveDir)
				local across = math.abs(rel:Dot(Vector3.new(-driveDir.Z, 0, driveDir.X)))
				onDrive = ahead > -4 and ahead < E.DriveLength + 12 and across < E.DriveWidth / 2 + 5
			end
			local chance = math.clamp((away - E.LawnClear) / E.ThickAfter, 0, 1)
			if away >= E.LawnClear and away <= E.Reach and not onDrive and rng:NextNumber() < chance * E.Density then
				if rng:NextNumber() < E.PineShare then
					pine(model, p, rng)
				else
					bareTree(model, p, rng)
				end
				count += 1
			end
		end
	end
	model:SetAttribute("Trees", count)

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
