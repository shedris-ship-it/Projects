-- The landmarks hung on corridor walls (Data/Landmarks, Services/
-- LandmarkService): each built from parts at `cf`, its back to the wall and
-- its front (+Z) into the corridor, centred about eye height.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PropFactory = require(Shared.World.PropFactory)

local part = PropFactory.part
local QUIET = { collide = false, castShadow = false }
local CYL = Enum.PartType.Cylinder
local GILT = Color3.fromRGB(176, 146, 76)

local LandmarkProps = {}

local builders = {}

-- A stag's head on a shield-shaped plaque, antlers spread.
function builders.stag(model: Model, cf: CFrame)
	local wood = PropFactory.material("Wood")
	part(
		model,
		"Plaque",
		Vector3.new(1.4, 1.8, 0.15),
		cf * CFrame.new(0, 0, 0.08),
		Color3.fromRGB(86, 58, 36),
		wood,
		QUIET
	)
	local hide = Color3.fromRGB(110, 78, 52)
	local fabric = PropFactory.material("Fabric")
	part(model, "Neck", Vector3.new(0.8, 1, 0.9), cf * CFrame.new(0, -0.1, 0.55), hide, fabric, QUIET)
	part(
		model,
		"Head",
		Vector3.new(0.6, 0.6, 1.1),
		cf * CFrame.new(0, 0.35, 1.1) * CFrame.Angles(math.rad(-20), 0, 0),
		hide,
		fabric,
		QUIET
	)
	part(
		model,
		"Muzzle",
		Vector3.new(0.4, 0.35, 0.4),
		cf * CFrame.new(0, 0.15, 1.65),
		Color3.fromRGB(70, 50, 36),
		fabric,
		QUIET
	)
	local bone = Color3.fromRGB(214, 200, 170)
	for _, side in { -1, 1 } do
		part(
			model,
			"Eye",
			Vector3.new(0.08, 0.08, 0.08),
			cf * CFrame.new(side * 0.25, 0.45, 1.25),
			Color3.fromRGB(10, 10, 10),
			PropFactory.material("Glass"),
			QUIET
		)
		local base = cf * CFrame.new(side * 0.2, 0.75, 0.95)
		part(
			model,
			"Antler",
			Vector3.new(0.09, 1.1, 0.09),
			base * CFrame.Angles(0, 0, side * math.rad(-30)) * CFrame.new(0, 0.5, 0),
			bone,
			wood,
			QUIET
		)
		for k = 1, 3 do
			part(
				model,
				"Tine",
				Vector3.new(0.07, 0.45, 0.07),
				base
					* CFrame.Angles(0, 0, side * math.rad(-30))
					* CFrame.new(0, 0.25 + k * 0.25, 0)
					* CFrame.Angles(0, 0, side * math.rad(-35))
					* CFrame.new(0, 0.2, 0),
				bone,
				wood,
				QUIET
			)
		end
	end
end

-- A big oil portrait in a gilt frame, a brass plate under it (the family's
-- founder, by their surname: Logic/Family).
function builders.portrait(model: Model, cf: CFrame, opts)
	local metal = PropFactory.material("Metal")
	part(model, "Frame", Vector3.new(2.6, 3.4, 0.16), cf * CFrame.new(0, 0.3, 0.08), GILT, metal, QUIET)
	-- A sitter in black against a muddy brown ground: shoulders, a pale
	-- face, dark hair, two eyes that follow you.
	local fabric = PropFactory.material("Fabric")
	local smooth = PropFactory.material("SmoothPlastic")
	local black = Color3.fromRGB(16, 14, 14)
	part(
		model,
		"Canvas",
		Vector3.new(2.2, 3, 0.04),
		cf * CFrame.new(0, 0.3, 0.17),
		Color3.fromRGB(86, 70, 46),
		fabric,
		QUIET
	)
	part(model, "Coat", Vector3.new(1.3, 1.1, 0.02), cf * CFrame.new(0, -0.65, 0.2), black, fabric, QUIET)
	part(model, "Shoulders", Vector3.new(1.75, 0.4, 0.02), cf * CFrame.new(0, -0.05, 0.2), black, fabric, QUIET)
	part(
		model,
		"Collar",
		Vector3.new(0.35, 0.3, 0.02),
		cf * CFrame.new(0, 0.05, 0.21),
		Color3.fromRGB(220, 214, 200),
		smooth,
		QUIET
	)
	part(
		model,
		"Face",
		Vector3.new(0.52, 0.66, 0.02),
		cf * CFrame.new(0, 0.6, 0.2),
		Color3.fromRGB(190, 158, 126),
		smooth,
		QUIET
	)
	part(
		model,
		"Hair",
		Vector3.new(0.58, 0.2, 0.02),
		cf * CFrame.new(0, 0.92, 0.21),
		Color3.fromRGB(30, 24, 20),
		fabric,
		QUIET
	)
	for _, x in { -0.11, 0.11 } do
		part(
			model,
			"Eye",
			Vector3.new(0.07, 0.05, 0.02),
			cf * CFrame.new(x, 0.66, 0.22),
			Color3.fromRGB(20, 16, 14),
			smooth,
			QUIET
		)
	end
	local plate = part(model, "Plate", Vector3.new(1, 0.25, 0.04), cf * CFrame.new(0, -1.55, 0.17), GILT, metal, QUIET)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(200, 50)
	gui.LightInfluence = 1
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Garamond
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(40, 30, 16)
	text.Text = opts.surname and ("EZRA " .. string.upper(opts.surname) .. ", 1921") or "THE FOUNDER, 1921"
	text.Parent = gui
	gui.Parent = plate
end

-- A tapestry on a rod, deep red with a gold border and bands.
function builders.tapestry(model: Model, cf: CFrame)
	local fabric = PropFactory.material("Fabric")
	part(
		model,
		"Rod",
		Vector3.new(3.2, 0.1, 0.1),
		cf * CFrame.new(0, 2, 0.15) * CFrame.Angles(0, 0, 0),
		GILT,
		PropFactory.material("Metal"),
		QUIET
	)
	part(
		model,
		"Cloth",
		Vector3.new(2.8, 3.6, 0.05),
		cf * CFrame.new(0, 0.15, 0.12),
		Color3.fromRGB(110, 26, 30),
		fabric,
		QUIET
	)
	for _, y in { 1.6, 0.15, -1.3 } do
		part(
			model,
			"Band",
			Vector3.new(2.8, 0.18, 0.02),
			cf * CFrame.new(0, y, 0.15),
			Color3.fromRGB(196, 160, 70),
			fabric,
			QUIET
		)
	end
	part(
		model,
		"Emblem",
		Vector3.new(0.9, 0.9, 0.02),
		cf * CFrame.new(0, 0.85, 0.16) * CFrame.Angles(0, 0, math.rad(45)),
		Color3.fromRGB(40, 50, 90),
		fabric,
		QUIET
	)
end

-- A big round wall clock, its hands stopped at a quarter to three.
function builders.clock(model: Model, cf: CFrame)
	local wood = PropFactory.material("Wood")
	part(
		model,
		"Rim",
		Vector3.new(0.2, 2.4, 2.4),
		cf * CFrame.new(0, 0.3, 0.1) * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(70, 46, 30),
		wood,
		{ collide = false, castShadow = false, shape = CYL }
	)
	part(
		model,
		"Dial",
		Vector3.new(0.05, 2.1, 2.1),
		cf * CFrame.new(0, 0.3, 0.22) * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(226, 216, 190),
		PropFactory.material("SmoothPlastic"),
		{ collide = false, castShadow = false, shape = CYL }
	)
	local black = Color3.fromRGB(20, 18, 18)
	local metal = PropFactory.material("Metal")
	for h = 0, 11 do
		local a = math.rad(h * 30)
		part(
			model,
			"Tick",
			Vector3.new(0.06, 0.18, 0.02),
			cf * CFrame.new(math.sin(a) * 0.88, 0.3 + math.cos(a) * 0.88, 0.26) * CFrame.Angles(0, 0, -a),
			black,
			metal,
			QUIET
		)
	end
	-- 2:45: the hour hand most of the way to three, the minute at nine.
	local hour = math.rad(82)
	part(
		model,
		"Hour",
		Vector3.new(0.07, 0.55, 0.02),
		cf * CFrame.new(math.sin(hour) * 0.25, 0.3 + math.cos(hour) * 0.25, 0.27) * CFrame.Angles(0, 0, -hour),
		black,
		metal,
		QUIET
	)
	local minute = math.rad(270)
	part(
		model,
		"Minute",
		Vector3.new(0.05, 0.8, 0.02),
		cf * CFrame.new(math.sin(minute) * 0.38, 0.3 + math.cos(minute) * 0.38, 0.28) * CFrame.Angles(0, 0, -minute),
		black,
		metal,
		QUIET
	)
end

-- A ship's wheel: a rim, a hub and eight spokes with handles.
function builders.wheel(model: Model, cf: CFrame)
	local wood = PropFactory.material("Wood")
	local oak = Color3.fromRGB(120, 82, 48)
	local center = cf * CFrame.new(0, 0.3, 0.3)
	part(
		model,
		"Hub",
		Vector3.new(0.35, 0.5, 0.5),
		center * CFrame.Angles(0, math.pi / 2, 0),
		GILT,
		PropFactory.material("Metal"),
		{ collide = false, castShadow = false, shape = CYL }
	)
	for k = 0, 7 do
		local a = math.rad(k * 45)
		part(model, "Spoke", Vector3.new(0.1, 2.6, 0.1), center * CFrame.Angles(0, 0, a), oak, wood, QUIET)
	end
	for k = 0, 15 do
		local a = math.rad(k * 22.5)
		part(
			model,
			"Rim",
			Vector3.new(0.12, 0.42, 0.14),
			center * CFrame.new(math.sin(a) * 0.95, math.cos(a) * 0.95, 0) * CFrame.Angles(0, 0, -a),
			oak,
			wood,
			QUIET
		)
	end
end

-- Build `kind` at `cf` into `parent`. Returns the model.
function LandmarkProps.build(kind: string, cf: CFrame, parent: Instance, opts): Model?
	local builder = builders[kind]
	if not builder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Landmark"
	model:SetAttribute("Landmark", kind)
	builder(model, cf, opts or {})
	model:SetAttribute("RunContent", true)
	model.Parent = parent
	return model
end

return LandmarkProps
