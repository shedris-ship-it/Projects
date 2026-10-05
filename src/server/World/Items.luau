-- The escape's items (docs/plans/gameplay-rework.md section 5.6): keys with
-- a paper tag, the heirlooms the dinner needs, and the computer's printout.
-- Built where they lie; Services/ItemService makes them things your hands
-- can take (Data/Physical lists their classes by model name).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PropFactory = require(Shared.World.PropFactory)

local part = PropFactory.part
local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)
local FLAT = { collide = false, castShadow = false }
local BRASS = Color3.fromRGB(176, 146, 84)
local SILVER = Color3.fromRGB(196, 198, 200)

local function metal()
	return PropFactory.material("Metal")
end

local function tagText(target: BasePart, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(160, 80)
	gui.LightInfluence = 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.SpecialElite
	label.TextColor3 = Color3.fromRGB(40, 32, 26)
	label.Text = text
	label.Parent = gui
	gui.Parent = target
end

local Items = {}

-- A brass key with a paper tag saying which door (`label`, with its mark's
-- `glyph`: docs/plans/level-design.md section 11), lying at `at`.
function Items.key(at: CFrame, label: string, parent: Instance, glyph: string?): Model
	local model = Instance.new("Model")
	model.Name = "Key"
	part(model, "Bow", Vector3.new(0.06, 0.32, 0.32), at * CFrame.new(-0.28, 0.03, 0) * UPRIGHT, BRASS, metal(), {
		collide = false,
		castShadow = false,
		shape = CYL,
	})
	part(model, "Shaft", Vector3.new(0.5, 0.06, 0.08), at * CFrame.new(0.07, 0.03, 0), BRASS, metal(), FLAT)
	part(model, "Bit", Vector3.new(0.1, 0.06, 0.16), at * CFrame.new(0.27, 0.03, 0.08), BRASS, metal(), FLAT)
	local tag = part(
		model,
		"Tag",
		Vector3.new(0.42, 0.02, 0.26),
		at * CFrame.new(-0.6, 0.01, 0.12) * CFrame.Angles(0, 0.3, 0),
		Color3.fromRGB(226, 214, 186),
		PropFactory.material("Fabric"),
		FLAT
	)
	tagText(tag, (glyph and glyph ~= "") and (glyph .. " " .. label) or label)
	model.Parent = parent
	return model
end

-- The heirlooms, a family's treasures. Each builder lays one on the surface at `at`.
local heirlooms = {}

function heirlooms.Candlestick(model, at)
	part(model, "Base", Vector3.new(0.12, 0.6, 0.6), at * CFrame.new(0, 0.06, 0) * UPRIGHT, SILVER, metal(), {
		collide = false,
		shape = CYL,
	})
	part(model, "Stem", Vector3.new(1.1, 0.16, 0.16), at * CFrame.new(0, 0.65, 0) * UPRIGHT, SILVER, metal(), {
		collide = false,
		shape = CYL,
	})
	part(model, "Cup", Vector3.new(0.16, 0.34, 0.34), at * CFrame.new(0, 1.25, 0) * UPRIGHT, SILVER, metal(), {
		collide = false,
		shape = CYL,
	})
	part(
		model,
		"Candle",
		Vector3.new(0.5, 0.18, 0.18),
		at * CFrame.new(0, 1.55, 0) * UPRIGHT,
		Color3.fromRGB(236, 230, 214),
		PropFactory.material("SmoothPlastic"),
		{ collide = false, shape = CYL }
	)
end

function heirlooms.PocketWatch(model, at)
	part(model, "Case", Vector3.new(0.12, 0.6, 0.6), at * CFrame.new(0, 0.06, 0) * UPRIGHT, BRASS, metal(), {
		collide = false,
		shape = CYL,
	})
	part(
		model,
		"Face",
		Vector3.new(0.02, 0.5, 0.5),
		at * CFrame.new(0, 0.125, 0) * UPRIGHT,
		Color3.fromRGB(236, 230, 210),
		PropFactory.material("SmoothPlastic"),
		{ collide = false, shape = CYL, castShadow = false }
	)
	part(model, "Crown", Vector3.new(0.1, 0.1, 0.1), at * CFrame.new(0, 0.06, -0.34), BRASS, metal(), {
		collide = false,
		shape = BALL,
	})
	part(model, "Chain", Vector3.new(0.6, 0.03, 0.04), at * CFrame.new(0.2, 0.02, -0.55), BRASS, metal(), FLAT)
end

function heirlooms.Locket(model, at)
	part(model, "Locket", Vector3.new(0.1, 0.42, 0.42), at * CFrame.new(0, 0.05, 0) * UPRIGHT, BRASS, metal(), {
		collide = false,
		shape = CYL,
	})
	part(model, "Chain", Vector3.new(0.9, 0.03, 0.04), at * CFrame.new(0, 0.02, -0.4), BRASS, metal(), FLAT)
end

function heirlooms.Doll(model, at)
	local porcelain = Color3.fromRGB(232, 222, 210)
	local dress = Color3.fromRGB(120, 60, 70)
	part(
		model,
		"Dress",
		Vector3.new(0.7, 0.5, 0.5),
		at * CFrame.new(0, 0.35, 0) * UPRIGHT,
		dress,
		PropFactory.material("Fabric"),
		{
			collide = false,
			shape = CYL,
		}
	)
	part(
		model,
		"Head",
		Vector3.new(0.34, 0.34, 0.34),
		at * CFrame.new(0, 0.86, 0),
		porcelain,
		PropFactory.material("SmoothPlastic"),
		{ collide = false, shape = BALL }
	)
	part(
		model,
		"Hair",
		Vector3.new(0.36, 0.16, 0.36),
		at * CFrame.new(0, 0.98, 0.02),
		Color3.fromRGB(70, 46, 30),
		PropFactory.material("Fabric"),
		{ collide = false, castShadow = false }
	)
end

function heirlooms.Cup(model, at)
	part(model, "Foot", Vector3.new(0.08, 0.36, 0.36), at * CFrame.new(0, 0.04, 0) * UPRIGHT, SILVER, metal(), {
		collide = false,
		shape = CYL,
	})
	part(model, "Bowl", Vector3.new(0.5, 0.46, 0.46), at * CFrame.new(0, 0.33, 0) * UPRIGHT, SILVER, metal(), {
		collide = false,
		shape = CYL,
	})
	part(
		model,
		"Handle",
		Vector3.new(0.06, 0.3, 0.12),
		at * CFrame.new(0.28, 0.35, 0),
		SILVER,
		metal(),
		{ collide = false, castShadow = false }
	)
end

Items.Heirlooms = {
	{ id = "Candlestick", label = "Silver candlestick" },
	{ id = "PocketWatch", label = "Pocket watch" },
	{ id = "Locket", label = "Locket" },
	{ id = "Doll", label = "Porcelain doll" },
	{ id = "Cup", label = "Christening cup" },
}

-- One heirloom (an entry of Items.Heirlooms), lying at `at`.
function Items.heirloom(kind: string, at: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Heirloom"
	heirlooms[kind](model, at)
	model.Parent = parent
	return model
end

-- The printer's page: `text` printed on it, lying at `at`.
function Items.printout(at: CFrame, text: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Printout"
	local sheet = part(
		model,
		"Sheet",
		Vector3.new(0.85, 0.02, 1.1),
		at * CFrame.new(0, 0.01, 0),
		Color3.fromRGB(236, 234, 224),
		PropFactory.material("Fabric"),
		FLAT
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(170, 220)
	gui.LightInfluence = 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextWrapped = true
	label.TextSize = 22
	label.Font = Enum.Font.Code
	label.TextColor3 = Color3.fromRGB(30, 30, 34)
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = text
	label.Parent = gui
	gui.Parent = sheet
	model.Parent = parent
	return model
end

return Items
