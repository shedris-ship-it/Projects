-- Builds local-only phantom objects for divergences: things one Witness sees
-- that don't exist on the server or for anyone else. Everything here is
-- non-collidable, so a phantom can never block or trap anyone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PropFactory = require(Shared.World.PropFactory)
local Constants = require(Shared.Constants)

local PhantomFactory = {}

local part = PropFactory.part
local NC = { collide = false, castShadow = false }

local function finish(model: Model, id: string?, label: string?)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CollisionGroup = Constants.CollisionGroups.Phantom
		end
	end
	if id then
		model:SetAttribute(Constants.Attributes.CId, id)
	end
	if label then
		model:SetAttribute(Constants.Attributes.Label, label)
	end
	return model
end

-- A still, featureless human figure.
local function figure(model: Model, cf: CFrame, color: Color3, transparency: number?)
	local opts = { collide = false, castShadow = true, transparency = transparency or 0 }
	local m = PropFactory.material("SmoothPlastic")
	part(model, "Torso", Vector3.new(2, 2.2, 1), cf * CFrame.new(0, 3.9, 0), color, m, opts)
	part(model, "Head", Vector3.new(1.1, 1.2, 1.1), cf * CFrame.new(0, 5.65, 0), color, m, opts)
	for _, x in { -1.45, 1.45 } do
		part(model, "Arm", Vector3.new(0.8, 2.3, 0.8), cf * CFrame.new(x, 3.75, 0), color, m, opts)
	end
	for _, x in { -0.5, 0.5 } do
		part(model, "Leg", Vector3.new(0.9, 2.8, 0.9), cf * CFrame.new(x, 1.4, 0), color, m, opts)
	end
end
PhantomFactory.figure = figure

local function footprints(model: Model, cf: CFrame, color: Color3, glossy: boolean)
	-- A trail walking away from the room centre (-Z of cf) that stops dead.
	for i = 0, 6 do
		local side = (i % 2 == 0) and -0.45 or 0.45
		local print_ = part(
			model,
			"Print",
			Vector3.new(0.7, 0.04, 1.3),
			cf * CFrame.new(side, 0.03, -i * 1.6),
			color,
			PropFactory.material(glossy and "Glass" or "SmoothPlastic"),
			NC
		)
		print_.Transparency = glossy and 0.25 or 0.1
		if glossy then
			print_.Reflectance = 0.3
		end
	end
end

local function shadow(model: Model, cf: CFrame, length: number)
	local black = Color3.new(0, 0, 0)
	local m = PropFactory.material("SmoothPlastic")
	local opts = { collide = false, castShadow = false, transparency = 0.35 }
	part(model, "Body", Vector3.new(1.6, 0.03, 2.4 * length), cf * CFrame.new(0, 0.03, -1.2 * length), black, m, opts)
	part(model, "Head", Vector3.new(1, 0.03, 1), cf * CFrame.new(0, 0.03, -2.4 * length - 0.5), black, m, opts)
	part(model, "Legs", Vector3.new(1.2, 0.03, 1.6 * length), cf * CFrame.new(0, 0.03, 0.8 * length), black, m, opts)
end

local function emitter(parentPart: BasePart, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parentPart
	return e
end

-- cf: on the floor (furniture convention, +Z toward the room) or, for wall
-- models, on the wall surface with LookVector into the room.
function PhantomFactory.build(kind: string, cf: CFrame, parent: Instance, id: string?)
	local model = Instance.new("Model")
	model.Name = "Phantom_" .. kind
	local label = "Something"
	if kind == "Footprints" then
		footprints(model, cf, Color3.fromRGB(40, 30, 24), false)
		label = "Footprints"
	elseif kind == "WetFootprints" then
		footprints(model, cf, Color3.fromRGB(30, 40, 60), true)
		label = "Wet footprints"
	elseif kind == "ExtraFigure" or kind == "Figure" then
		figure(model, cf, Color3.fromRGB(44, 42, 46))
		label = "Figure"
	elseif kind == "Shadow" then
		shadow(model, cf, 1)
		label = "Shadow"
	elseif kind == "LongShadow" then
		shadow(model, cf, 2.4)
		label = "Shadow"
	elseif kind == "DoorShadow" then
		part(
			model,
			"Shadow",
			Vector3.new(4.4, 7.6, 0.03),
			cf * CFrame.new(0, -2.6, -0.06),
			Color3.new(0, 0, 0),
			PropFactory.material("SmoothPlastic"),
			{ collide = false, castShadow = false, transparency = 0.45 }
		)
		label = "Shadow on the wall"
	elseif kind == "Duplicate" or kind == "Chair" then
		PropFactory.build("Chair", cf, model)
		label = "Chair"
	elseif kind == "Vase" then
		part(
			model,
			"Vase",
			Vector3.new(1.2, 2, 1.2),
			cf * CFrame.new(0, 1, 0),
			Color3.fromRGB(150, 160, 190),
			PropFactory.material("Marble"),
			{ collide = false, shape = Enum.PartType.Cylinder }
		)
		model:FindFirstChild("Vase").CFrame = cf * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.pi / 2)
		label = "Vase"
	elseif kind == "Plant" then
		PropFactory.build("Plant", cf, model)
		label = "Plant"
	elseif kind == "Stool" then
		part(
			model,
			"Seat",
			Vector3.new(1.8, 0.3, 1.8),
			cf * CFrame.new(0, 2, 0),
			Color3.fromRGB(110, 80, 56),
			PropFactory.material("Wood"),
			NC
		)
		part(
			model,
			"Leg",
			Vector3.new(0.3, 2, 0.3),
			cf * CFrame.new(0, 1, 0),
			Color3.fromRGB(90, 66, 46),
			PropFactory.material("Wood"),
			NC
		)
		label = "Stool"
	elseif kind == "FloatingItem" then
		local cup = part(
			model,
			"Cup",
			Vector3.new(0.9, 0.6, 0.6),
			cf * CFrame.new(0, 4.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(230, 226, 214),
			PropFactory.material("Marble"),
			{ collide = false, shape = Enum.PartType.Cylinder }
		)
		cup:SetAttribute("Bob", true)
		label = "Floating cup"
	elseif kind == "RainCloud" then
		local source = part(
			model,
			"Rain",
			Vector3.new(8, 0.2, 8),
			cf * CFrame.new(0, 11.4, 0),
			Color3.new(1, 1, 1),
			PropFactory.material("SmoothPlastic"),
			{ collide = false, transparency = 1 }
		)
		emitter(source, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(170, 190, 220)),
			LightEmission = 0.1,
			Size = NumberSequence.new(0.12),
			Speed = NumberRange.new(28, 34),
			Lifetime = NumberRange.new(0.35, 0.45),
			Rate = 160,
			EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(2, 2),
			Transparency = NumberSequence.new(0.3),
		})
		part(
			model,
			"Puddle",
			Vector3.new(7, 0.03, 7),
			cf * CFrame.new(0, 0.03, 0),
			Color3.fromRGB(40, 50, 64),
			PropFactory.material("Glass"),
			{ collide = false, castShadow = false, transparency = 0.4, reflectance = 0.4 }
		)
		label = "Rain"
	elseif kind == "BreathFog" then
		local source = part(
			model,
			"Cold",
			Vector3.new(4, 4, 4),
			cf * CFrame.new(0, 4.5, 0),
			Color3.new(1, 1, 1),
			PropFactory.material("SmoothPlastic"),
			{ collide = false, transparency = 1 }
		)
		emitter(source, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(220, 230, 240)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.4) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) }),
			Speed = NumberRange.new(0.4, 1),
			Lifetime = NumberRange.new(2, 3),
			Rate = 6,
			SpreadAngle = Vector2.new(180, 180),
		})
		label = "Cold spot"
	elseif kind == "Painting" then
		-- Always the same seed: the same painting, wherever it appears.
		PropFactory.buildDecor("Painting", cf, model, 1)
		label = "Painting"
	elseif kind == "Ghost" then
		figure(model, cf, Color3.fromRGB(200, 210, 230), 0.6)
		label = "Teammate?"
	else
		part(
			model,
			"Marker",
			Vector3.new(1, 1, 1),
			cf * CFrame.new(0, 0.5, 0),
			Color3.new(1, 1, 1),
			PropFactory.material("SmoothPlastic"),
			{ collide = false, transparency = 1 }
		)
	end
	finish(model, id, label)
	model.Parent = parent
	return model
end

return PhantomFactory
