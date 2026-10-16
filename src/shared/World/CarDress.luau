-- A party car dressed in its driver's bits (LB4; docs/plans/lobby-rework.md,
-- "The garage"; Data/CarBits, Logic/Catalog.carOf). Both sides use it: the
-- server on the garage's cars (Services/CarService), a client on the
-- pegboard's preview (UI/Wares).
--
-- In the car's own frame: its grey body (the model's `Body`, 7 x 5 x 14,
-- its middle 2.5 over the floor), its front -Z toward the garage door, the
-- driver's side -X. Each bit is the kit's mesh once it's in (Data/Kit Parts:
-- the `mall4` batch, tools/blender/kitlib/carbits), or a grey box in its
-- colours until then. The paint needs the car's tintable body (`MallCarBody`,
-- the same batch: the car as first imported has its maroon baked in), so
-- until then a car keeps its maroon; the woodgrain likewise comes off with
-- that batch.

local CarBits = require(script.Parent.Parent.Data.CarBits)
local Kit = require(script.Parent.Kit)

local CarDress = {}

local W, D = 7, 14
local HUB, WHEELS = -1.5, { -4.5, 4.5 }
-- The tintable body's paint (kitlib/carbits BASE): a SurfaceAppearance's
-- Color multiplies its map, so a paint is asked for that much brighter.
local BASE = 230

local function tint(t): Color3
	local k = 255 / BASE
	return Color3.fromRGB(math.min(255, t[1] * k), math.min(255, t[2] * k), math.min(255, t[3] * k))
end

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local CHROME = Color3.fromRGB(196, 198, 200)

-- The grey boxes, each bit in the car's frame `f`.
local GREY = {
	Woodgrain = function(folder: Instance, f: CFrame)
		local wood = Color3.fromRGB(124, 84, 50)
		for _, sx in { -1, 1 } do
			for _, span in { { -3.15, 3.15 }, { 5.85, 6.8 } } do
				local len = span[2] - span[1]
				block(
					folder,
					"Wood",
					Vector3.new(0.04, 1, len),
					f * CFrame.new(sx * (W / 2 - 0.02), -0.55, (span[1] + span[2]) / 2),
					wood,
					Enum.Material.Wood
				)
			end
		end
	end,
	Whitewalls = function(folder: Instance, f: CFrame)
		for _, z in WHEELS do
			for _, sx in { -1, 1 } do
				block(
					folder,
					"Whitewall",
					Vector3.new(0.02, 1.72, 1.72),
					f * CFrame.new(sx * (W / 2 - 0.035), HUB, z),
					Color3.fromRGB(232, 230, 222),
					Enum.Material.SmoothPlastic,
					Enum.PartType.Cylinder
				)
			end
		end
	end,
	RoofRack = function(folder: Instance, f: CFrame)
		for _, z in { 0.2, 2.5, 4.8 } do
			block(
				folder,
				"RackBar",
				Vector3.new(W - 1, 0.1, 0.12),
				f * CFrame.new(0, 2.34, z),
				CHROME,
				Enum.Material.Metal
			)
		end
		block(
			folder,
			"Suitcase",
			Vector3.new(2.4, 0.56, 1.6),
			f * CFrame.new(-1.0, 2.67, 1.4) * CFrame.Angles(0, math.rad(4), 0),
			Color3.fromRGB(150, 108, 64)
		)
		block(
			folder,
			"Suitcase",
			Vector3.new(2.0, 0.5, 1.4),
			f * CFrame.new(1.15, 2.64, 3.4) * CFrame.Angles(0, math.rad(-6), 0),
			Color3.fromRGB(52, 76, 58)
		)
		block(
			folder,
			"Duffel",
			Vector3.new(1.8, 0.86, 0.86),
			f * CFrame.new(0.3, 2.8, 5.3),
			Color3.fromRGB(120, 34, 34),
			Enum.Material.Fabric,
			Enum.PartType.Cylinder
		)
	end,
	Spotlight = function(folder: Instance, f: CFrame)
		block(
			folder,
			"SpotArm",
			Vector3.new(0.56, 0.1, 0.1),
			f * CFrame.new(-(W / 2 - 0.13), 0.9, -2.05),
			CHROME,
			Enum.Material.Metal
		)
		block(
			folder,
			"SpotCan",
			Vector3.new(0.52, 0.52, 0.52),
			f * CFrame.new(-(W / 2 + 0.36), 0.95, -2.15) * CFrame.Angles(0, math.rad(90), 0),
			CHROME,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		block(
			folder,
			"SpotGlass",
			Vector3.new(0.02, 0.44, 0.44),
			f * CFrame.new(-(W / 2 + 0.36), 0.95, -2.42) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(220, 218, 200),
			Enum.Material.Glass,
			Enum.PartType.Cylinder
		)
		-- The CB's whip off the back bumper's other corner, sprung at its foot.
		block(
			folder,
			"WhipSpring",
			Vector3.new(0.14, 0.35, 0.14),
			f * CFrame.new(W / 2 - 0.4, -1.03, D / 2 + 0.05),
			Color3.fromRGB(20, 20, 22)
		)
		block(
			folder,
			"Whip",
			Vector3.new(0.04, 4.2, 0.04),
			f * CFrame.new(W / 2 - 0.4, 1.25, D / 2 + 0.25) * CFrame.Angles(math.rad(6), 0, 0),
			CHROME,
			Enum.Material.Metal
		)
	end,
	Sticker = function(folder: Instance, f: CFrame)
		-- On the tailgate, left of the plate as you look at it.
		local sticker = block(
			folder,
			"Sticker",
			Vector3.new(1.7, 0.36, 0.02),
			f * CFrame.new(-1.55, -0.5, D / 2 + 0.01),
			Color3.fromRGB(236, 232, 220)
		)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 120
		gui.LightInfluence = 1
		gui.Parent = sticker
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = CarBits.Bits.Sticker.text
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = Color3.fromRGB(170, 30, 30)
		label.Parent = gui
	end,
}

-- The bits' kit meshes (the `mall4` batch), in the same frame.
local MESHES = {
	Woodgrain = "MallCarWood",
	Whitewalls = "CarWhitewalls",
	RoofRack = "CarRoofRack",
	Spotlight = "CarSpotlight",
}

-- Dresses `model` (a party car: its `Body` the frame) in `setup` ({ paint,
-- bits, radio }, Logic/Catalog.carOf). Does nothing when it's dressed so
-- already. The radio is the caller's (a sound, CarService).
function CarDress.dress(model: Model, setup)
	local body = model:FindFirstChild("Body") :: BasePart?
	if not body then
		return
	end
	local key = setup.paint
	local ids = {}
	for id in setup.bits do
		table.insert(ids, id)
	end
	table.sort(ids)
	key ..= ":" .. table.concat(ids, ",")
	if model:GetAttribute("Dressed") == key and model:FindFirstChild("Bits") then
		return
	end
	model:SetAttribute("Dressed", key)
	local old = model:FindFirstChild("Bits")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Bits"
	folder.Parent = model
	-- The car's frame: its body, front -Z (the kit's meshes are turned as
	-- the car's own mesh is, CarService's MallCar).
	local f = body.CFrame
	local turned = f * CFrame.Angles(0, math.pi, 0)
	for _, id in CarBits.BitOrder do
		if setup.bits[id] then
			local mesh = MESHES[id] and Kit.place(folder, MESHES[id], turned)
			if not mesh then
				GREY[id](folder, f)
			end
		end
	end
	-- The paint, on the tintable body once it's in (a maroon one before).
	local paint = CarBits.Paints[setup.paint] or CarBits.Paints.Maroon
	local painted = model:FindFirstChild("KitMallCarBody")
	if painted then
		Kit.tint(painted :: MeshPart, tint(paint.color))
	end
end

return CarDress
