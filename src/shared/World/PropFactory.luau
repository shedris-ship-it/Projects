-- Builds grey-box furniture and tell props out of Parts. Every builder takes
-- a base CFrame on the floor whose +Z axis points out of the prop's front
-- (toward the room), matching Data/Props.
--
-- Lives in Shared because clients reuse it to build their local-only phantom
-- props. These are placeholders for the hand-built prefabs the doc calls for; the
-- naming conventions (e.g. a Clock's "Face" SurfaceGui) are what the client
-- PerceptionController relies on, so keep them if you replace a builder.

local ClockFace = require(script.Parent.Parent.Logic.ClockFace)
local Config = require(script.Parent.Parent.Config)
local Materials = require(script.Parent.Parent.Data.Materials)
local Props = require(script.Parent.Parent.Data.Props)
local Tells = require(script.Parent.Parent.Data.Tells)
local Rng = require(script.Parent.Parent.Lib.Rng)

local PropFactory = {}

local materialCache = {}
function PropFactory.material(name: string?): Enum.Material
	name = name or "SmoothPlastic"
	if materialCache[name] then
		return materialCache[name]
	end
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	local material = ok and value or Enum.Material.SmoothPlastic
	materialCache[name] = material
	return material
end

-- A surface by name: one of the house's MaterialVariants (Data/Materials), or
-- a built-in material. Returns the material and the variant, if any. A
-- variant whose texture hasn't been uploaded falls back to its base.
function PropFactory.surface(name: string?): (Enum.Material, string?)
	local variant = name and Materials.ByName[name]
	if variant then
		local textured = variant.maps ~= nil and variant.maps.color ~= ""
		return PropFactory.material(variant.base), textured and variant.name or nil
	end
	return PropFactory.material(name), nil
end

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end
PropFactory.rgb = rgb

local function shade(color: Color3, factor: number): Color3
	return Color3.new(
		math.clamp(color.R * factor, 0, 1),
		math.clamp(color.G * factor, 0, 1),
		math.clamp(color.B * factor, 0, 1)
	)
end
PropFactory.shade = shade

-- Create an anchored part. opts: collide, shape, transparency, castShadow,
-- query, reflectance, variant (a MaterialVariant name)
function PropFactory.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	opts: { [string]: any }?
)
	local o = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.shape then
		p.Shape = o.shape
	end
	p.CanCollide = o.collide ~= false
	p.CanTouch = false
	p.CanQuery = o.query ~= false
	p.CastShadow = o.castShadow ~= false
	p.Transparency = o.transparency or 0
	if o.reflectance then
		p.Reflectance = o.reflectance
	end
	if o.variant then
		p.MaterialVariant = o.variant
	end
	p.Parent = parent
	return p
end
local part = PropFactory.part

local function surfaceText(target: BasePart, face: Enum.NormalId, name: string, text: string, opts)
	local o = opts or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = o.ppu or 40
	gui.LightInfluence = o.lightInfluence or 1
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Name = o.labelName or "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = o.font or Enum.Font.SpecialElite
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = o.color or Color3.fromRGB(30, 26, 22)
	label.Text = text
	label.Parent = gui
	return label
end
PropFactory.surfaceText = surfaceText

-- Clocks ------------------------------------------------------------------
-- Every clock in the house shows its time with hands (docs/ART.md, Hero
-- props), so a "Clocks disagree" clue clock looks exactly like any other.
-- `surface` is the wall or case face at the clock's centre, LookVector out
-- towards the viewer. The Dial keeps its Face/Time label (hidden) because the
-- client reads and writes it.

local HAND_INK = Color3.fromRGB(28, 24, 20)
local HANDS = {
	HourHand = { length = 0.56, width = 0.11, tail = 0.12, z = 0.05 },
	MinuteHand = { length = 0.86, width = 0.07, tail = 0.16, z = 0.08 },
}

-- A cylinder whose flat faces look along the surface's LookVector.
local function disc(model, name, surface: CFrame, z: number, diameter: number, depth: number, color, material)
	return part(
		model,
		name,
		Vector3.new(depth, diameter, diameter),
		surface * CFrame.new(0, 0, -z) * CFrame.Angles(0, math.pi / 2, 0),
		color,
		material,
		{ collide = false, castShadow = false, shape = Enum.PartType.Cylinder }
	)
end

-- Point the hands at a time ("3:15"). The dial's own frame gives the centre.
function PropFactory.setClockHands(model: Instance, value: any)
	local dial = model:FindFirstChild("Dial", true)
	if not dial or not dial:IsA("BasePart") then
		return
	end
	local centre = dial.CFrame * CFrame.Angles(0, -math.pi / 2, 0) -- LookVector out again
	local hourAngle, minuteAngle = ClockFace.angles(tostring(value))
	local scale = dial.Size.Y / 2
	for name, angle in { HourHand = hourAngle, MinuteHand = minuteAngle } do
		local hand = model:FindFirstChild(name, true)
		local spec = HANDS[name]
		if hand and hand:IsA("BasePart") then
			-- Clockwise as the viewer sees it is a positive turn about the
			-- dial's forward axis.
			local reach = spec.length * scale
			hand.CFrame = centre
				* CFrame.Angles(0, 0, math.rad(angle))
				* CFrame.new(0, reach / 2 - spec.tail * scale, -(dial.Size.X / 2 + spec.z))
		end
	end
end

-- A round clock face: rim (named `rimName`), cream dial, twelve ticks, hands
-- and a centre cap.
local function clockFace(model, surface: CFrame, radius: number, value: any, rimName: string, rimDepth: number)
	disc(
		model,
		rimName,
		surface,
		rimDepth / 2,
		radius * 2,
		rimDepth,
		Color3.fromRGB(74, 51, 36),
		PropFactory.material("Wood")
	)
	local dialDiameter = radius * 2 * 0.86
	local dial = disc(
		model,
		"Dial",
		surface,
		rimDepth + 0.02,
		dialDiameter,
		0.04,
		Color3.fromRGB(226, 216, 190),
		PropFactory.material("SmoothPlastic")
	)
	local label = surfaceText(dial, Enum.NormalId.Right, "Face", tostring(value), { labelName = "Time", ppu = 60 })
	label.TextTransparency = 1
	local r = dialDiameter / 2
	for i = 0, 11 do
		local major = i % 3 == 0
		local a = math.rad(i * 30)
		local length = (major and 0.2 or 0.11) * r / 0.9
		part(
			model,
			"Tick",
			Vector3.new(major and 0.09 or 0.05, length, 0.02),
			surface
				* CFrame.new(0, 0, -(rimDepth + 0.05))
				* CFrame.Angles(0, 0, a)
				* CFrame.new(0, r * 0.86 - length / 2, 0),
			HAND_INK,
			PropFactory.material("SmoothPlastic"),
			{ collide = false, castShadow = false, query = false }
		)
	end
	for name, spec in HANDS do
		part(
			model,
			name,
			Vector3.new(spec.width * r / 0.9, spec.length * r, 0.03),
			surface,
			HAND_INK,
			PropFactory.material("Metal"),
			{ collide = false, castShadow = false, query = false }
		)
	end
	disc(
		model,
		"Cap",
		surface,
		rimDepth + 0.13,
		0.14,
		0.03,
		Color3.fromRGB(150, 128, 84),
		PropFactory.material("Metal")
	)
	PropFactory.setClockHands(model, value)
	return dial
end

-- A plausible time for a decorative clock: the same pool the clue clocks
-- draw from, so a clue can't be spotted by its time alone.
function PropFactory.decorClockTime(rng): string
	return rng:Pick(Tells.clock_disagree.variants)
end

-- Builders ---------------------------------------------------------------

local builders = {}

local function legs(model, cf, w, d, h, color, material, inset)
	inset = inset or 0.4
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(
				model,
				"Leg",
				Vector3.new(0.4, h, 0.4),
				cf * CFrame.new(sx * (w / 2 - inset), h / 2, sz * (d / 2 - inset)),
				color,
				material
			)
		end
	end
end

function builders.Bed(model, cf, size, color, material)
	local w, d = size.X, size.Z
	local wood = Color3.fromRGB(70, 50, 36)
	legs(model, cf, w, d, 1, wood, PropFactory.material("Wood"))
	part(model, "Frame", Vector3.new(w, 0.8, d), cf * CFrame.new(0, 1.4, 0), wood, PropFactory.material("Wood"))
	part(
		model,
		"Mattress",
		Vector3.new(w - 0.4, 0.9, d - 0.6),
		cf * CFrame.new(0, 2.25, 0.1),
		Color3.fromRGB(214, 210, 200),
		PropFactory.material("Fabric")
	)
	part(model, "Blanket", Vector3.new(w - 0.2, 0.3, d * 0.6), cf * CFrame.new(0, 2.75, d * 0.18), color, material)
	part(
		model,
		"Headboard",
		Vector3.new(w, 4.5, 0.5),
		cf * CFrame.new(0, 2.25, -d / 2 + 0.25),
		wood,
		PropFactory.material("Wood")
	)
	part(
		model,
		"Pillow",
		Vector3.new(w * 0.6, 0.5, 1.6),
		cf * CFrame.new(0, 2.95, -d / 2 + 1.5),
		Color3.fromRGB(230, 228, 220),
		PropFactory.material("Fabric")
	)
end

local function cupboard(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(model, "Body", size, cf * CFrame.new(0, h / 2, 0), color, material)
	for _, sx in { -1, 1 } do
		part(
			model,
			"Door",
			Vector3.new(w / 2 - 0.3, h - 0.8, 0.15),
			cf * CFrame.new(sx * w / 4, h / 2, d / 2 + 0.05),
			shade(color, 1.12),
			material
		)
		part(
			model,
			"Handle",
			Vector3.new(0.15, 1, 0.2),
			cf * CFrame.new(sx * 0.35, h / 2, d / 2 + 0.2),
			Color3.fromRGB(180, 160, 110),
			PropFactory.material("Metal")
		)
	end
end
builders.Wardrobe = cupboard
builders.Cabinet = cupboard

function builders.Locker(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(model, "Body", size, cf * CFrame.new(0, h / 2, 0), color, material)
	part(
		model,
		"Door",
		Vector3.new(w - 0.3, h - 0.4, 0.12),
		cf * CFrame.new(0, h / 2, d / 2 + 0.04),
		shade(color, 1.1),
		material
	)
	for i = 1, 4 do
		part(
			model,
			"Vent",
			Vector3.new(w - 1, 0.1, 0.05),
			cf * CFrame.new(0, h - 1 - i * 0.35, d / 2 + 0.12),
			Color3.fromRGB(20, 20, 22),
			material,
			{ castShadow = false }
		)
	end
	part(
		model,
		"Handle",
		Vector3.new(0.15, 0.8, 0.2),
		cf * CFrame.new(w / 2 - 0.5, h / 2, d / 2 + 0.15),
		Color3.fromRGB(160, 160, 160),
		material
	)
end

function builders.Table(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(model, "Top", Vector3.new(w, 0.3, d), cf * CFrame.new(0, h - 0.15, 0), color, material)
	legs(model, cf, w, d, h - 0.3, shade(color, 0.85), material)
end
builders.DiningTable = builders.Table

function builders.Desk(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(model, "Top", Vector3.new(w, 0.3, d), cf * CFrame.new(0, h - 0.15, 0), color, material)
	part(
		model,
		"Drawers",
		Vector3.new(2.2, h - 0.3, d - 0.2),
		cf * CFrame.new(w / 2 - 1.2, (h - 0.3) / 2, 0),
		shade(color, 0.9),
		material
	)
	part(
		model,
		"Side",
		Vector3.new(0.3, h - 0.3, d - 0.2),
		cf * CFrame.new(-w / 2 + 0.2, (h - 0.3) / 2, 0),
		shade(color, 0.9),
		material
	)
end

function builders.Curtain(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(
		model,
		"Rod",
		Vector3.new(w + 0.6, 0.2, 0.2),
		cf * CFrame.new(0, h, 0),
		Color3.fromRGB(120, 100, 70),
		PropFactory.material("Metal")
	)
	for i = -1, 1 do
		part(
			model,
			"Fold",
			Vector3.new(w / 3 + 0.1, h - 0.3, d - 0.4 + (i == 0 and 0.2 or 0)),
			cf * CFrame.new(i * w / 3, (h - 0.3) / 2 + 0.1, 0),
			shade(color, 1 + i * 0.08),
			material
		)
	end
end

function builders.Bathtub(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(model, "Tub", size, cf * CFrame.new(0, h / 2, 0), color, material)
	part(
		model,
		"Water",
		Vector3.new(w - 0.8, 0.1, d - 0.8),
		cf * CFrame.new(0, h - 0.04, 0),
		Color3.fromRGB(60, 70, 74),
		PropFactory.material("Glass"),
		{ castShadow = false }
	)
	part(
		model,
		"Rail",
		Vector3.new(w, 0.15, 0.15),
		cf * CFrame.new(0, 8, d / 2),
		Color3.fromRGB(170, 170, 170),
		PropFactory.material("Metal")
	)
	part(
		model,
		"ShowerCurtain",
		Vector3.new(w * 0.7, 5, 0.1),
		cf * CFrame.new(-w * 0.15, 5.4, d / 2),
		Color3.fromRGB(190, 200, 190),
		PropFactory.material("Fabric"),
		{ transparency = 0.15 }
	)
end

function builders.Sofa(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(model, "Base", Vector3.new(w, 1.6, d), cf * CFrame.new(0, 0.8, 0), color, material)
	part(
		model,
		"Back",
		Vector3.new(w, h - 1.6, 1),
		cf * CFrame.new(0, 1.6 + (h - 1.6) / 2, -d / 2 + 0.5),
		shade(color, 0.9),
		material
	)
	for _, sx in { -1, 1 } do
		part(
			model,
			"Arm",
			Vector3.new(0.8, 2.4, d),
			cf * CFrame.new(sx * (w / 2 - 0.4), 1.2, 0),
			shade(color, 0.85),
			material
		)
	end
	part(
		model,
		"Cushion",
		Vector3.new(w - 1.8, 0.4, d - 1.1),
		cf * CFrame.new(0, 1.8, 0.45),
		shade(color, 1.1),
		material
	)
end
builders.Armchair = builders.Sofa

function builders.Counter(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(
		model,
		"Cabinets",
		Vector3.new(w, h - 0.3, d - 0.2),
		cf * CFrame.new(0, (h - 0.3) / 2, -0.1),
		Color3.fromRGB(150, 130, 100),
		PropFactory.material("Wood")
	)
	part(model, "Top", Vector3.new(w, 0.3, d), cf * CFrame.new(0, h - 0.15, 0), color, material)
end

function builders.Fridge(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(model, "Body", size, cf * CFrame.new(0, h / 2, 0), color, material)
	part(
		model,
		"Split",
		Vector3.new(w - 0.2, 0.1, 0.05),
		cf * CFrame.new(0, h * 0.62, d / 2 + 0.02),
		Color3.fromRGB(120, 120, 120),
		material
	)
	part(
		model,
		"Handle",
		Vector3.new(0.2, 2, 0.3),
		cf * CFrame.new(w / 2 - 0.5, h * 0.42, d / 2 + 0.15),
		Color3.fromRGB(150, 150, 150),
		PropFactory.material("Metal")
	)
end

function builders.Stove(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(model, "Body", size, cf * CFrame.new(0, h / 2, 0), color, material)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(
				model,
				"Burner",
				Vector3.new(0.15, 1.1, 1.1),
				cf * CFrame.new(sx * w / 4, h + 0.05, sz * d / 4) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(20, 20, 20),
				material,
				{ shape = Enum.PartType.Cylinder }
			)
		end
	end
end

function builders.Shelf(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(model, "Back", Vector3.new(w, h, 0.2), cf * CFrame.new(0, h / 2, -d / 2 + 0.1), shade(color, 0.85), material)
	for _, sx in { -1, 1 } do
		part(model, "Side", Vector3.new(0.3, h, d), cf * CFrame.new(sx * (w / 2 - 0.15), h / 2, 0), color, material)
	end
	local rng = Rng.new(Rng.hash(tostring(cf.Position)))
	for i = 0, 4 do
		local y = 0.2 + i * (h - 0.4) / 4
		part(model, "Board", Vector3.new(w - 0.6, 0.2, d), cf * CFrame.new(0, y, 0), color, material)
		if i < 4 then
			local x = -w / 2 + 0.6
			while x < w / 2 - 1 do
				local bw = rng:NextNumber(0.3, 0.6)
				local bh = rng:NextNumber(1, 1.6)
				local tint = Color3.fromHSV(rng:NextNumber(), 0.35, rng:NextNumber(0.25, 0.55))
				part(
					model,
					"Book",
					Vector3.new(bw, bh, d - 0.5),
					cf * CFrame.new(x + bw / 2, y + 0.1 + bh / 2, 0),
					tint,
					PropFactory.material("SmoothPlastic"),
					{ castShadow = false, collide = false }
				)
				x += bw + rng:NextNumber(0, 0.4)
			end
		end
	end
end

function builders.Sink(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(
		model,
		"Cabinet",
		Vector3.new(w, h - 0.6, d),
		cf * CFrame.new(0, (h - 0.6) / 2, 0),
		Color3.fromRGB(200, 196, 186),
		PropFactory.material("Wood")
	)
	part(model, "Basin", Vector3.new(w, 0.6, d), cf * CFrame.new(0, h - 0.3, 0), color, material)
	part(
		model,
		"Tap",
		Vector3.new(0.2, 0.8, 0.2),
		cf * CFrame.new(0, h + 0.4, -d / 2 + 0.4),
		Color3.fromRGB(180, 180, 180),
		PropFactory.material("Metal")
	)
end

function builders.Toilet(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(model, "Bowl", Vector3.new(w - 0.4, h * 0.55, d - 1), cf * CFrame.new(0, h * 0.275, 0.4), color, material)
	part(model, "Tank", Vector3.new(w, h, 1), cf * CFrame.new(0, h / 2, -d / 2 + 0.5), color, material)
end

function builders.Crib(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(model, "Base", Vector3.new(w, 0.4, d), cf * CFrame.new(0, 1.2, 0), color, material)
	legs(model, cf, w, d, h, shade(color, 0.9), material, 0.2)
	for i = -4, 4 do
		part(
			model,
			"Bar",
			Vector3.new(0.12, h - 1.4, 0.12),
			cf * CFrame.new(i * w / 9, 2.4, d / 2 - 0.1),
			color,
			material,
			{ castShadow = false }
		)
		part(
			model,
			"Bar",
			Vector3.new(0.12, h - 1.4, 0.12),
			cf * CFrame.new(i * w / 9, 2.4, -d / 2 + 0.1),
			color,
			material,
			{ castShadow = false }
		)
	end
	part(model, "Rail", Vector3.new(w, 0.2, d), cf * CFrame.new(0, h, 0), color, material, { collide = false })
end

function builders.Washer(model, cf, size, color, material)
	local h, d = size.Y, size.Z
	part(model, "Body", size, cf * CFrame.new(0, h / 2, 0), color, material)
	part(
		model,
		"Window",
		Vector3.new(0.2, 2, 2),
		cf * CFrame.new(0, h * 0.45, d / 2 + 0.05) * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(40, 50, 60),
		PropFactory.material("Glass"),
		{ shape = Enum.PartType.Cylinder }
	)
end

function builders.Boxes(model, cf, size, color, material)
	local rng = Rng.new(Rng.hash(tostring(cf.Position)))
	local y = 0
	for i = 1, rng:NextInteger(2, 3) do
		local s = size.X - (i - 1) * 0.8
		local box = part(
			model,
			"Box",
			Vector3.new(s, 1.6, s),
			cf
				* CFrame.new(rng:NextNumber(-0.3, 0.3), y + 0.8, rng:NextNumber(-0.3, 0.3))
				* CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0),
			shade(color, rng:NextNumber(0.85, 1.1)),
			material
		)
		box.Name = "Box" .. i
		y += 1.6
	end
end

function builders.Workbench(model, cf, size, color, material)
	builders.Table(model, cf, size, color, material)
	part(
		model,
		"Vice",
		Vector3.new(0.8, 0.6, 0.8),
		cf * CFrame.new(size.X / 2 - 1, size.Y + 0.3, 0),
		Color3.fromRGB(90, 90, 96),
		PropFactory.material("Metal")
	)
	part(
		model,
		"Pegboard",
		Vector3.new(size.X, 4, 0.2),
		cf * CFrame.new(0, size.Y + 3, -size.Z / 2 + 0.1),
		Color3.fromRGB(160, 130, 90),
		PropFactory.material("Wood")
	)
end

function builders.Car(model, cf, size, color, material)
	local w, d = size.X, size.Z
	part(model, "Body", Vector3.new(w, 2.4, d), cf * CFrame.new(0, 1.8, 0), color, material)
	part(model, "Cabin", Vector3.new(w - 0.6, 2, d * 0.5), cf * CFrame.new(0, 4, -0.5), shade(color, 0.9), material)
	part(
		model,
		"Glass",
		Vector3.new(w - 0.5, 1.6, d * 0.5 + 0.1),
		cf * CFrame.new(0, 4.1, -0.5),
		Color3.fromRGB(30, 36, 40),
		PropFactory.material("Glass"),
		{ transparency = 0.3, collide = false }
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(
				model,
				"Wheel",
				Vector3.new(0.8, 2, 2),
				cf * CFrame.new(sx * (w / 2 - 0.3), 1, sz * (d / 2 - 2.5)),
				Color3.fromRGB(20, 20, 20),
				PropFactory.material("Rubber"),
				{ shape = Enum.PartType.Cylinder }
			)
		end
	end
	part(
		model,
		"Sheet",
		Vector3.new(w + 0.2, 0.1, d * 0.45),
		cf * CFrame.new(0, 3.05, d * 0.28),
		Color3.fromRGB(150, 150, 140),
		PropFactory.material("Fabric"),
		{ collide = false }
	)
end

function builders.Piano(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(model, "Body", Vector3.new(w, h, d - 1), cf * CFrame.new(0, h / 2, -0.5), color, material)
	part(model, "Keybed", Vector3.new(w, 0.5, 1.2), cf * CFrame.new(0, 2.8, d / 2 - 0.6), color, material)
	part(
		model,
		"Keys",
		Vector3.new(w - 0.6, 0.1, 0.9),
		cf * CFrame.new(0, 3.08, d / 2 - 0.55),
		Color3.fromRGB(230, 226, 214),
		PropFactory.material("SmoothPlastic"),
		{ castShadow = false }
	)
	legs(model, cf * CFrame.new(0, 0, d / 2 - 0.6), w, 1, 2.6, color, material, 0.3)
end

function builders.TVStand(model, cf, size, color, material)
	local w, h = size.X, size.Y
	part(model, "Stand", size, cf * CFrame.new(0, h / 2, 0), color, material)
	part(
		model,
		"TV",
		Vector3.new(w * 0.8, 3, 1.2),
		cf * CFrame.new(0, h + 1.5, 0),
		Color3.fromRGB(30, 30, 30),
		PropFactory.material("SmoothPlastic")
	)
	local screen = part(
		model,
		"Screen",
		Vector3.new(w * 0.7, 2.4, 0.1),
		cf * CFrame.new(0, h + 1.5, 0.62),
		Color3.fromRGB(80, 110, 140),
		PropFactory.material("Neon"),
		{ castShadow = false }
	)
	screen.Transparency = 0.4
	return screen
end

function builders.Dresser(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(model, "Body", size, cf * CFrame.new(0, h / 2, 0), color, material)
	for i = 1, 3 do
		part(
			model,
			"Drawer",
			Vector3.new(w - 0.5, h / 3 - 0.3, 0.1),
			cf * CFrame.new(0, (i - 0.5) * h / 3, d / 2 + 0.03),
			shade(color, 1.1),
			material,
			{ castShadow = false }
		)
	end
end

function builders.Plant(model, cf, _size, color, material)
	part(
		model,
		"Pot",
		Vector3.new(1.4, 1.6, 1.4),
		cf * CFrame.new(0, 0.8, 0),
		Color3.fromRGB(150, 80, 60),
		PropFactory.material("Slate")
	)
	part(
		model,
		"Leaves",
		Vector3.new(2.4, 3.2, 2.4),
		cf * CFrame.new(0, 3.2, 0),
		color,
		material,
		{ shape = Enum.PartType.Ball }
	)
end

function builders.GrandfatherClock(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(model, "Case", size, cf * CFrame.new(0, h / 2, 0), color, material)
	-- A hood above the face and a glass door over the pendulum.
	part(
		model,
		"Hood",
		Vector3.new(w + 0.3, 0.35, d + 0.3),
		cf * CFrame.new(0, h + 0.17, 0),
		shade(color, 0.85),
		material
	)
	part(
		model,
		"Door",
		Vector3.new(w - 0.8, h * 0.45, 0.06),
		cf * CFrame.new(0, h * 0.38, d / 2 + 0.03),
		Color3.fromRGB(40, 36, 34),
		PropFactory.material("Glass"),
		{ collide = false, castShadow = false, transparency = 0.3 }
	)
	part(
		model,
		"Pendulum",
		Vector3.new(0.5, 0.5, 0.05),
		cf * CFrame.new(0, h * 0.25, d / 2 - 0.05),
		Color3.fromRGB(150, 128, 84),
		PropFactory.material("Metal"),
		{ collide = false, castShadow = false, shape = Enum.PartType.Cylinder }
	).CFrame = cf
		* CFrame.new(0, h * 0.25, d / 2 - 0.05)
		* CFrame.Angles(0, math.pi / 2, 0)
	-- The face: a seeded time from the clue pool.
	local p = (cf * CFrame.new(0, h - 1.3, d / 2)).Position
	local front = -cf.LookVector -- props face +Z in their own frame
	local rng = Rng.new(Rng.hash(tostring(cf.Position)))
	clockFace(model, CFrame.lookAt(p, p + front), (w - 0.5) / 2, PropFactory.decorClockTime(rng), "Bezel", 0.08)
end

function builders.CoatRack(model, cf, size, color, material)
	part(model, "Pole", Vector3.new(0.3, size.Y, 0.3), cf * CFrame.new(0, size.Y / 2, 0), color, material)
	part(model, "Foot", Vector3.new(1.8, 0.3, 1.8), cf * CFrame.new(0, 0.15, 0), color, material)
	part(
		model,
		"Coat",
		Vector3.new(1.4, 3.4, 0.8),
		cf * CFrame.new(0, size.Y - 2.6, 0.4),
		Color3.fromRGB(60, 50, 40),
		PropFactory.material("Fabric"),
		{ collide = false }
	)
end

function builders.Bench(model, cf, size, color, material)
	builders.Table(model, cf, size, color, material)
end

function builders.WaterHeater(model, cf, size, color, material)
	part(
		model,
		"Tank",
		Vector3.new(size.Y, size.X, size.X),
		cf * CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material,
		{ shape = Enum.PartType.Cylinder }
	)
end

function builders.Chest(model, cf, size, color, material)
	local w, h, d = size.X, size.Y, size.Z
	part(model, "Box", Vector3.new(w, h - 0.6, d), cf * CFrame.new(0, (h - 0.6) / 2, 0), color, material)
	part(model, "Lid", Vector3.new(w + 0.1, 0.6, d + 0.1), cf * CFrame.new(0, h - 0.3, 0), shade(color, 0.85), material)
	part(
		model,
		"Latch",
		Vector3.new(0.5, 0.6, 0.1),
		cf * CFrame.new(0, h - 0.6, d / 2 + 0.06),
		Color3.fromRGB(170, 150, 90),
		PropFactory.material("Metal")
	)
end

function builders.Mannequin(model, cf, _size, color, material)
	part(
		model,
		"Base",
		Vector3.new(1.6, 0.3, 1.6),
		cf * CFrame.new(0, 0.15, 0),
		Color3.fromRGB(50, 40, 30),
		PropFactory.material("Wood")
	)
	part(
		model,
		"Pole",
		Vector3.new(0.25, 2.5, 0.25),
		cf * CFrame.new(0, 1.4, 0),
		Color3.fromRGB(50, 40, 30),
		PropFactory.material("Wood")
	)
	part(model, "Torso", Vector3.new(1.7, 2.6, 1), cf * CFrame.new(0, 3.9, 0), color, material)
	part(model, "Neck", Vector3.new(0.4, 0.4, 0.4), cf * CFrame.new(0, 5.4, 0), color, material)
	part(
		model,
		"Head",
		Vector3.new(1, 1.2, 1),
		cf * CFrame.new(0, 6, 0),
		color,
		material,
		{ shape = Enum.PartType.Ball }
	)
	-- A pinned lace collar on the front so its facing is easy to read.
	part(
		model,
		"Collar",
		Vector3.new(1.2, 0.5, 0.15),
		cf * CFrame.new(0, 4.9, 0.52),
		Color3.fromRGB(150, 30, 40),
		PropFactory.material("Fabric"),
		{ castShadow = false }
	)
end

function builders.FloorLamp(model, cf, size, color, material)
	part(model, "Foot", Vector3.new(1.4, 0.2, 1.4), cf * CFrame.new(0, 0.1, 0), color, material)
	part(model, "Pole", Vector3.new(0.2, size.Y - 1, 0.2), cf * CFrame.new(0, (size.Y - 1) / 2, 0), color, material)
	local shadePart = part(
		model,
		"Shade",
		Vector3.new(1.6, 1.4, 1.6),
		cf * CFrame.new(0, size.Y - 0.6, 0),
		Color3.fromRGB(240, 210, 160),
		PropFactory.material("Fabric"),
		{ castShadow = false }
	)
	return shadePart
end

function builders.Shrine(model, cf, size, color, material)
	part(model, "Pedestal", Vector3.new(size.X, 2.6, size.Z), cf * CFrame.new(0, 1.3, 0), color, material)
	part(
		model,
		"Cage",
		Vector3.new(1.4, 1.8, 1.4),
		cf * CFrame.new(0, 3.5, 0),
		Color3.fromRGB(60, 50, 40),
		PropFactory.material("Metal"),
		{ transparency = 0.2 }
	)
	local glass = part(
		model,
		"Glass",
		Vector3.new(1.1, 1.4, 1.1),
		cf * CFrame.new(0, 3.5, 0),
		Color3.fromRGB(255, 200, 120),
		PropFactory.material("Glass"),
		{ transparency = 0.5, castShadow = false }
	)
	return glass
end

function builders.Chair(model, cf, size, color, material)
	local w, d = size.X, size.Z
	local opts = { collide = false }
	part(model, "Seat", Vector3.new(w, 0.3, d), cf * CFrame.new(0, 2, 0), color, material, opts)
	part(model, "Back", Vector3.new(w, 2.2, 0.3), cf * CFrame.new(0, 3.2, -d / 2 + 0.15), color, material, opts)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(
				model,
				"Leg",
				Vector3.new(0.25, 2, 0.25),
				cf * CFrame.new(sx * (w / 2 - 0.2), 1, sz * (d / 2 - 0.2)),
				color,
				material,
				opts
			)
		end
	end
end

function builders.Rug(model, cf, size, color, material)
	part(
		model,
		"Rug",
		Vector3.new(size.X, 0.1, size.Z),
		cf * CFrame.new(0, 0.05, 0),
		color,
		material,
		{ collide = false, castShadow = false }
	)
end

function builders.Default(model, cf, size, color, material)
	part(model, "Body", size, cf * CFrame.new(0, size.Y / 2, 0), color, material)
end

-- Public API ---------------------------------------------------------------

-- Build a furniture prop. Returns the model and, for light-carrying props,
-- the part the light should live in.
function PropFactory.build(kindName: string, cf: CFrame, parent: Instance, overrides: { [string]: any }?)
	local kind = Props.Kinds[kindName]
	assert(kind, "Unknown prop kind " .. tostring(kindName))
	local o = overrides or {}
	local model = Instance.new("Model")
	model.Name = o.name or kindName
	local size = Vector3.new(kind.size[1], kind.size[2], kind.size[3])
	local color = o.color or rgb(kind.color or { 120, 120, 120 })
	local material = PropFactory.material(o.material or kind.material)
	local builder = builders[kindName] or builders.Default
	local lightPart = builder(model, cf, size, color, material)
	if kind.collide == false then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
	end
	model.Parent = parent
	return model, lightPart
end

-- Wall decor: cf sits on the wall surface, LookVector pointing into the room.
function PropFactory.buildDecor(kindName: string, cf: CFrame, parent: Instance, seed: number?)
	local kind = Props.WallDecor[kindName]
	local model = Instance.new("Model")
	model.Name = kindName
	local w, h = kind.size[1], kind.size[2]
	local rng = Rng.new(seed or Rng.hash(tostring(cf.Position)))
	local lightPart = nil
	local noCollide = { collide = false }
	if kindName == "Painting" then
		part(
			model,
			"Frame",
			Vector3.new(w, h, 0.25),
			cf * CFrame.new(0, 0, -0.12),
			Color3.fromRGB(90, 66, 40),
			PropFactory.material("Wood"),
			noCollide
		)
		local canvas = part(
			model,
			"Canvas",
			Vector3.new(w - 0.6, h - 0.6, 0.05),
			cf * CFrame.new(0, 0, -0.27),
			Color3.fromHSV(rng:NextNumber(), 0.3, 0.35),
			PropFactory.material("Fabric"),
			noCollide
		)
		-- a simple abstract "landscape": a horizon band and a dark shape
		part(
			model,
			"Horizon",
			Vector3.new(w - 0.6, (h - 0.6) * 0.35, 0.05),
			cf * CFrame.new(0, -(h - 0.6) * 0.32, -0.3),
			Color3.fromHSV(rng:NextNumber(), 0.25, 0.25),
			PropFactory.material("Fabric"),
			noCollide
		)
		part(
			model,
			"Shape",
			Vector3.new(0.8, 1.6, 0.05),
			cf * CFrame.new(rng:NextNumber(-1, 1), 0, -0.31),
			Color3.fromRGB(20, 18, 18),
			PropFactory.material("Fabric"),
			noCollide
		)
		canvas.Name = "Canvas"
	elseif kindName == "Window" then
		-- A window you look into rather than a picture of one (docs/ART.md,
		-- step 3): a painted casing and sill around the pane, and behind the
		-- glass the night sky glowing faintly, lighter at the top, with the
		-- muntins dark against it. The casing is lighter than any wall, like a
		-- door's, and the inner opening leaves room for a Sealed window's bricks.
		local paint = rgb(Config.Trim.Paint)
		local cw, cd = 0.45, 0.18
		local iw, ih = w - 2 * cw, h - 2 * cw
		for _, edge in
			{
				{ 0, h / 2 - cw / 2, w, cw },
				{ 0, -(h / 2 - cw / 2), w, cw },
				{ -(w / 2 - cw / 2), 0, cw, ih },
				{ w / 2 - cw / 2, 0, cw, ih },
			}
		do
			part(
				model,
				"Frame",
				Vector3.new(edge[3], edge[4], cd),
				cf * CFrame.new(edge[1], edge[2], -cd / 2),
				paint,
				PropFactory.material("Wood"),
				{ collide = false, castShadow = false }
			)
		end
		part(
			model,
			"Sill",
			Vector3.new(w + 0.5, 0.18, 0.55),
			cf * CFrame.new(0, -h / 2 - 0.09, -0.275),
			paint,
			PropFactory.material("Wood"),
			{ collide = false, castShadow = false }
		)
		-- Layers out from the wall: sky, room for a Sealed window's bricks,
		-- glass, muntins, with clear gaps so nothing flickers.
		local sky = part(
			model,
			"Sky",
			Vector3.new(iw, ih, 0.02),
			cf * CFrame.new(0, 0, -0.01),
			Color3.new(0, 0, 0),
			PropFactory.material("SmoothPlastic"),
			{ collide = false, query = false, castShadow = false }
		)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Night"
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.Brightness = 1.4
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.Parent = sky
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = Color3.new(1, 1, 1)
		fill.Parent = gui
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(74, 94, 140)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(34, 44, 68)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 16, 24)),
		})
		gradient.Parent = fill
		-- A faintly tinted, nearly clear pane. Roblox's Glass material hides the
		-- sky up close (so the window changed with distance), and reflectance
		-- on a clear pane darkens whatever is behind it, a Sealed window's
		-- bricks included.
		local glass = part(
			model,
			"Glass",
			Vector3.new(iw, ih, 0.04),
			cf * CFrame.new(0, 0, -0.07),
			Color3.fromRGB(150, 170, 200),
			PropFactory.material("SmoothPlastic"),
			{ collide = false, transparency = 0.9, castShadow = false }
		)
		part(
			model,
			"MuntinH",
			Vector3.new(iw, 0.12, 0.08),
			cf * CFrame.new(0, 0, -0.12),
			shade(paint, 0.55),
			PropFactory.material("Wood"),
			{ collide = false, castShadow = false }
		)
		part(
			model,
			"MuntinV",
			Vector3.new(0.12, ih, 0.08),
			cf * CFrame.new(0, 0, -0.12),
			shade(paint, 0.55),
			PropFactory.material("Wood"),
			{ collide = false, castShadow = false }
		)
		lightPart = glass
	elseif kindName == "Mirror" then
		part(
			model,
			"Frame",
			Vector3.new(w, h, 0.2),
			cf * CFrame.new(0, 0, -0.1),
			Color3.fromRGB(140, 120, 70),
			PropFactory.material("Metal"),
			noCollide
		)
		local glass = part(
			model,
			"Glass",
			Vector3.new(w - 0.4, h - 0.4, 0.05),
			cf * CFrame.new(0, 0, -0.22),
			Color3.fromRGB(150, 160, 170),
			PropFactory.material("Glass"),
			noCollide
		)
		glass.Reflectance = 0.5
	end
	model.Parent = parent
	return model, lightPart
end

-- Tell-site base props (VariantProp / PhantomSound / PortraitEyes etc.).
-- `value` is the true state the server shows; clients override it locally.
-- cf: for wall props, on the wall surface facing into the room; for floor
-- props, on the floor facing the room centre.
function PropFactory.buildTellBase(model: string, cf: CFrame, parent: Instance, value: any)
	local m = Instance.new("Model")
	m.Name = model
	local noCollide = { collide = false }
	local ink = Color3.fromRGB(30, 26, 22)
	if model == "Clock" then
		-- A 1980s wall clock. Decorative clocks use this same builder.
		clockFace(m, cf, 1.2, value, "Body", 0.3)
	elseif model == "Note" then
		local paper = part(
			m,
			"Paper",
			Vector3.new(2.2, 2.8, 0.05),
			cf * CFrame.new(0, 0, -0.05),
			Color3.fromRGB(226, 216, 186),
			PropFactory.material("SmoothPlastic"),
			noCollide
		)
		surfaceText(
			paper,
			Enum.NormalId.Front,
			"Writing",
			tostring(value),
			{ ppu = 70, font = Enum.Font.Garamond, color = ink }
		)
		part(
			m,
			"Pin",
			Vector3.new(0.2, 0.2, 0.2),
			cf * CFrame.new(0, 1.2, -0.12),
			Color3.fromRGB(180, 30, 30),
			PropFactory.material("SmoothPlastic"),
			noCollide
		)
	elseif model == "Nametag" then
		local hook = part(
			m,
			"Hook",
			Vector3.new(0.3, 0.3, 0.4),
			cf * CFrame.new(0, 1, -0.2),
			Color3.fromRGB(150, 150, 150),
			PropFactory.material("Metal"),
			noCollide
		)
		hook.Name = "Hook"
		local badge = part(
			m,
			"Badge",
			Vector3.new(2.4, 1.4, 0.06),
			cf * CFrame.new(0, 0, -0.08),
			Color3.fromRGB(230, 230, 226),
			PropFactory.material("SmoothPlastic"),
			noCollide
		)
		surfaceText(badge, Enum.NormalId.Front, "Card", tostring(value), { labelName = "Name", ppu = 60 })
	elseif model == "KeyTag" then
		part(
			m,
			"Hook",
			Vector3.new(0.3, 0.3, 0.4),
			cf * CFrame.new(0, 0.8, -0.2),
			Color3.fromRGB(150, 150, 150),
			PropFactory.material("Metal"),
			noCollide
		)
		part(
			m,
			"Key",
			Vector3.new(0.3, 1.2, 0.1),
			cf * CFrame.new(0, 0.1, -0.15),
			Color3.fromRGB(200, 170, 80),
			PropFactory.material("Metal"),
			noCollide
		)
		local tag = part(
			m,
			"Tag",
			Vector3.new(1.6, 0.8, 0.05),
			cf * CFrame.new(0, -0.8, -0.12),
			Color3.fromRGB(210, 196, 160),
			PropFactory.material("SmoothPlastic"),
			noCollide
		)
		surfaceText(tag, Enum.NormalId.Front, "Label", tostring(value), { labelName = "Tag", ppu = 80 })
	elseif model == "Fusebox" then
		part(
			m,
			"Box",
			Vector3.new(2.4, 3, 0.6),
			cf * CFrame.new(0, 0, -0.3),
			Color3.fromRGB(110, 116, 110),
			PropFactory.material("Metal"),
			noCollide
		)
		local indicator = part(
			m,
			"Indicator",
			Vector3.new(0.4, 0.4, 0.1),
			cf * CFrame.new(0, 0.9, -0.64),
			value == "live" and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(60, 20, 20),
			PropFactory.material("Neon"),
			noCollide
		)
		indicator.Name = "Indicator"
		surfaceText(
			part(
				m,
				"Plate",
				Vector3.new(1.8, 0.6, 0.05),
				cf * CFrame.new(0, -0.6, -0.62),
				Color3.fromRGB(200, 200, 190),
				PropFactory.material("SmoothPlastic"),
				noCollide
			),
			Enum.NormalId.Front,
			"Label",
			"MAIN",
			{ ppu = 60 }
		)
	elseif model == "Corkboard" then
		part(
			m,
			"Board",
			Vector3.new(4, 3, 0.2),
			cf * CFrame.new(0, 0, -0.1),
			Color3.fromRGB(170, 130, 90),
			PropFactory.material("Fabric"),
			noCollide
		)
		part(
			m,
			"Map",
			Vector3.new(3.2, 2.2, 0.05),
			cf * CFrame.new(0, 0, -0.23),
			Color3.fromRGB(220, 214, 196),
			PropFactory.material("SmoothPlastic"),
			noCollide
		)
		for i = 1, 4 do
			part(
				m,
				"Pin" .. i,
				Vector3.new(0.25, 0.25, 0.25),
				cf * CFrame.new(-1.2 + i * 0.6, ((i % 2) - 0.5) * 1.2, -0.3),
				Color3.fromRGB(200, 30, 40),
				PropFactory.material("SmoothPlastic"),
				noCollide
			)
		end
	elseif model == "TapeMark" then
		part(
			m,
			"Frame",
			Vector3.new(0.6, 7, 0.3),
			cf * CFrame.new(0, 0, -0.15),
			Color3.fromRGB(210, 200, 180),
			PropFactory.material("Wood"),
			noCollide
		)
		local strip = part(
			m,
			"Strip",
			Vector3.new(0.5, 5, 0.05),
			cf * CFrame.new(0, -0.5, -0.33),
			Color3.fromRGB(230, 226, 214),
			PropFactory.material("SmoothPlastic"),
			noCollide
		)
		surfaceText(
			strip,
			Enum.NormalId.Front,
			"Pencil",
			tostring(value),
			{ labelName = "Marks", ppu = 50, font = Enum.Font.Garamond }
		)
	elseif model == "Window" then
		PropFactory.buildDecor("Window", cf, m)
		-- Bricks fill the opening just behind the glass, as if bricked up
		-- from outside; the muntins and glass stay in front of them.
		local bricks = part(
			m,
			"Bricks",
			Vector3.new(5.1, 4.1, 0.015),
			cf * CFrame.new(0, 0, -0.0375),
			Color3.fromRGB(120, 60, 50),
			PropFactory.material("Brick"),
			{ collide = false, transparency = value == "bricked" and 0 or 1 }
		)
		bricks.Name = "Bricks"
		-- The night sky glow draws over anything just in front of it.
		local night = m:FindFirstChild("Night", true)
		if night then
			night.Enabled = value ~= "bricked"
		end
	elseif model == "Lamp" then
		local _, shadePart = PropFactory.build("FloorLamp", cf, m)
		local light = Instance.new("PointLight")
		light.Name = "TellLight"
		light.Color = Color3.fromRGB(255, 200, 140)
		light.Range = 14
		light.Brightness = 1.4
		light.Shadows = false
		light.Enabled = value == "on"
		light.Parent = shadePart
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
	elseif model == "ScaleChair" or model == "Chair" then
		PropFactory.build("Chair", cf, m)
		if model == "ScaleChair" and type(value) == "number" and value ~= 1 then
			m.Parent = parent
			m:ScaleTo(value)
		end
	elseif model == "Mannequin" then
		local rotated = cf * CFrame.Angles(0, math.rad(tonumber(value) or 0), 0)
		PropFactory.build("Mannequin", rotated, m)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
	elseif model == "Radio" then
		-- A 1970s cabinet radio on a small side table (docs/ART.md, Hero
		-- props). Decorative radios use this same builder, so a radio on its
		-- own is never the clue.
		local walnut = Color3.fromRGB(78, 54, 36)
		part(
			m,
			"Table",
			Vector3.new(2.4, 0.16, 1.9),
			cf * CFrame.new(0, 2.52, 0),
			walnut,
			PropFactory.material("Wood"),
			noCollide
		)
		part(
			m,
			"Shelf",
			Vector3.new(2.1, 0.1, 1.6),
			cf * CFrame.new(0, 0.8, 0),
			walnut,
			PropFactory.material("Wood"),
			noCollide
		)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				part(
					m,
					"Leg",
					Vector3.new(0.14, 2.44, 0.14),
					cf * CFrame.new(sx * 1.05, 1.22, sz * 0.8),
					walnut,
					PropFactory.material("Wood"),
					noCollide
				)
			end
		end
		local body = part(
			m,
			"Body",
			Vector3.new(1.9, 1.05, 0.85),
			cf * CFrame.new(0, 3.13, -0.1),
			Color3.fromRGB(104, 70, 42),
			PropFactory.material("Wood"),
			noCollide
		)
		body.Name = "Body"
		part(
			m,
			"Grille",
			Vector3.new(0.9, 0.78, 0.04),
			cf * CFrame.new(-0.4, 3.13, 0.34),
			Color3.fromRGB(70, 58, 44),
			PropFactory.material("Fabric"),
			{ collide = false, castShadow = false }
		)
		-- The tuning dial, faintly lit, with its needle.
		local dial = part(
			m,
			"Dial",
			Vector3.new(0.72, 0.3, 0.03),
			cf * CFrame.new(0.45, 3.32, 0.34),
			Color3.fromRGB(196, 150, 84),
			PropFactory.material("Neon"),
			{ collide = false, castShadow = false }
		)
		dial.Transparency = 0.45
		part(
			m,
			"Needle",
			Vector3.new(0.025, 0.26, 0.02),
			cf * CFrame.new(0.38, 3.32, 0.36),
			Color3.fromRGB(150, 40, 30),
			PropFactory.material("SmoothPlastic"),
			{ collide = false, castShadow = false, query = false }
		)
		for _, kx in { 0.25, 0.65 } do
			part(
				m,
				"Knob",
				Vector3.new(0.12, 0.2, 0.2),
				cf * CFrame.new(kx, 2.9, 0.38) * CFrame.Angles(0, math.pi / 2, 0),
				Color3.fromRGB(196, 186, 160),
				PropFactory.material("SmoothPlastic"),
				{ collide = false, castShadow = false, shape = Enum.PartType.Cylinder, query = false }
			)
		end
		-- A telescopic aerial, leaning back.
		part(
			m,
			"Aerial",
			Vector3.new(0.04, 1.6, 0.04),
			cf * CFrame.new(0.7, 4.3, -0.4) * CFrame.Angles(math.rad(-25), 0, math.rad(-15)),
			Color3.fromRGB(170, 170, 166),
			PropFactory.material("Metal"),
			{ collide = false, castShadow = false, query = false }
		)
	elseif model == "Portrait" then
		part(
			m,
			"Frame",
			Vector3.new(3.6, 4.6, 0.3),
			cf * CFrame.new(0, 0, -0.15),
			Color3.fromRGB(120, 90, 40),
			PropFactory.material("Wood"),
			noCollide
		)
		part(
			m,
			"Canvas",
			Vector3.new(3, 4, 0.05),
			cf * CFrame.new(0, 0, -0.32),
			Color3.fromRGB(40, 34, 30),
			PropFactory.material("Fabric"),
			noCollide
		)
		part(
			m,
			"Face",
			Vector3.new(1.4, 1.8, 0.05),
			cf * CFrame.new(0, 0.6, -0.35),
			Color3.fromRGB(196, 170, 140),
			PropFactory.material("Fabric"),
			noCollide
		)
		part(
			m,
			"Body",
			Vector3.new(2.4, 1.6, 0.05),
			cf * CFrame.new(0, -1.2, -0.35),
			Color3.fromRGB(30, 30, 40),
			PropFactory.material("Fabric"),
			noCollide
		)
		for _, side in { { "EyeL", -0.3 }, { "EyeR", 0.3 } } do
			local eye = part(
				m,
				side[1],
				Vector3.new(0.22, 0.22, 0.1),
				cf * CFrame.new(side[2], 0.85, -0.39),
				Color3.fromRGB(20, 16, 14),
				PropFactory.material("SmoothPlastic"),
				{ collide = false, shape = Enum.PartType.Ball, castShadow = false }
			)
			eye.Name = side[1]
		end
	elseif model == "WallMarker" then
		-- An empty patch of wall: writing only some Witnesses' flashlights reveal.
		part(
			m,
			"Patch",
			Vector3.new(5, 3, 0.05),
			cf * CFrame.new(0, 0, -0.03),
			Color3.fromRGB(110, 100, 90),
			PropFactory.material("Plaster"),
			{ collide = false, transparency = 1 }
		)
	else
		-- Invisible marker for phantom-only tells; Witnessing resolves to it.
		part(
			m,
			"Marker",
			Vector3.new(1, 1, 1),
			cf * CFrame.new(0, 0.5, 0),
			Color3.new(1, 1, 1),
			PropFactory.material("SmoothPlastic"),
			{ collide = false, transparency = 1, query = false, castShadow = false }
		)
	end
	m.Parent = parent
	return m
end

return PropFactory
