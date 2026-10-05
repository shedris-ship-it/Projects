-- Odd small things kept in drawers and cupboards (docs/plans/gameplay-
-- rework.md section 4.5): what a family leaves in the backs of things in
-- 1988. Services/FurnitureService makes one the first time a drawer or door
-- is opened, never before, and Services/HandsService makes it something
-- your hands can carry and throw (Data/Physical lists each by model name).
-- Until R2a puts keys and items in some of these places, this is all they
-- hold.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PropFactory = require(Shared.World.PropFactory)

local part = PropFactory.part
local CYL = Enum.PartType.Cylinder
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)
local FLAT = { collide = false, castShadow = false }

local function plastic()
	return PropFactory.material("SmoothPlastic")
end

-- Each builder lays its thing on the surface at `at` (its +Y up).
local builders = {}

function builders.Cassette(model, at)
	part(
		model,
		"Case",
		Vector3.new(0.7, 0.12, 0.44),
		at * CFrame.new(0, 0.06, 0),
		Color3.fromRGB(46, 44, 42),
		plastic(),
		FLAT
	)
	part(
		model,
		"Label",
		Vector3.new(0.5, 0.01, 0.22),
		at * CFrame.new(0, 0.125, -0.04),
		Color3.fromRGB(212, 196, 150),
		plastic(),
		FLAT
	)
end

function builders.Matchbox(model, at)
	part(
		model,
		"Box",
		Vector3.new(0.42, 0.14, 0.28),
		at * CFrame.new(0, 0.07, 0),
		Color3.fromRGB(150, 44, 34),
		plastic(),
		FLAT
	)
	part(
		model,
		"Striker",
		Vector3.new(0.42, 0.1, 0.01),
		at * CFrame.new(0, 0.07, 0.145),
		Color3.fromRGB(70, 46, 34),
		PropFactory.material("Sand"),
		FLAT
	)
end

function builders.Letters(model, at)
	local paper = Color3.fromRGB(226, 214, 186)
	for i = 0, 2 do
		part(
			model,
			"Envelope",
			Vector3.new(0.8, 0.05, 0.46),
			at * CFrame.new(0, 0.025 + i * 0.05, 0) * CFrame.Angles(0, math.rad((i - 1) * 6), 0),
			PropFactory.shade(paper, 1 - i * 0.06),
			PropFactory.material("Fabric"),
			FLAT
		)
	end
	part(
		model,
		"Twine",
		Vector3.new(0.05, 0.17, 0.48),
		at * CFrame.new(0.12, 0.08, 0),
		Color3.fromRGB(150, 120, 80),
		PropFactory.material("Fabric"),
		FLAT
	)
end

function builders.Candle(model, at)
	part(
		model,
		"Dish",
		Vector3.new(0.05, 0.5, 0.5),
		at * CFrame.new(0, 0.025, 0) * UPRIGHT,
		Color3.fromRGB(176, 146, 84),
		PropFactory.material("Metal"),
		{ collide = false, castShadow = false, shape = CYL }
	)
	part(
		model,
		"Wax",
		Vector3.new(0.45, 0.22, 0.22),
		at * CFrame.new(0, 0.275, 0) * UPRIGHT,
		Color3.fromRGB(232, 226, 210),
		plastic(),
		{ collide = false, castShadow = false, shape = CYL }
	)
end

function builders.Spool(model, at)
	local wood = Color3.fromRGB(196, 168, 120)
	for _, y in { 0.02, 0.33 } do
		part(
			model,
			"Rim",
			Vector3.new(0.04, 0.34, 0.34),
			at * CFrame.new(0, y, 0) * UPRIGHT,
			wood,
			PropFactory.material("Wood"),
			{ collide = false, castShadow = false, shape = CYL }
		)
	end
	part(
		model,
		"Thread",
		Vector3.new(0.27, 0.27, 0.27),
		at * CFrame.new(0, 0.175, 0) * UPRIGHT,
		Color3.fromRGB(150, 34, 40),
		PropFactory.material("Fabric"),
		{ collide = false, castShadow = false, shape = CYL }
	)
end

function builders.PillBottle(model, at)
	local glass = part(
		model,
		"Bottle",
		Vector3.new(0.36, 0.22, 0.22),
		at * CFrame.new(0, 0.18, 0) * UPRIGHT,
		Color3.fromRGB(150, 84, 30),
		PropFactory.material("Glass"),
		{ collide = false, castShadow = false, shape = CYL }
	)
	glass.Transparency = 0.25
	part(
		model,
		"Cap",
		Vector3.new(0.08, 0.24, 0.24),
		at * CFrame.new(0, 0.4, 0) * UPRIGHT,
		Color3.fromRGB(236, 236, 230),
		plastic(),
		{ collide = false, castShadow = false, shape = CYL }
	)
end

local Junk = {}

Junk.Names = { "Cassette", "Matchbox", "Letters", "Candle", "Spool", "PillBottle" }

-- Make one, lying at `at`, as a model named for it.
function Junk.build(name: string, at: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	builders[name](model, at)
	model.Parent = parent
	return model
end

return Junk
