-- Small things on furniture tops (docs/ART.md, Hero props): family photos in
-- standing frames and an old telephone. P.T.'s lesson is that a handful of
-- believable everyday objects does more than a room full of furniture.
--
-- Placed from the seed, so everyone sees the same house. Nothing here ever
-- collides, blocks a ray, or carries a CId: dressing is never Witnessable and
-- never evidence (rule 6). Photos are tagged so the client can age them with
-- Drift (EffectsController).

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Props = require(Shared.Data.Props)
local SurfaceSpots = require(Shared.Logic.SurfaceSpots)
local PropFactory = require(Shared.World.PropFactory)

local D = Config.Dressing
local DECOR = { collide = false, query = false, castShadow = false }

local Dressing = {}

-- An old rotary telephone. `cf` sits on the surface with its LookVector
-- facing out of the furniture's front, so the front of the phone is -Z.
local function telephone(parent, cf: CFrame)
	local model = Instance.new("Model")
	model.Name = "Telephone"
	local shell = Color3.fromRGB(196, 184, 160) -- a beige 1980s rotary phone
	local dark = Color3.fromRGB(40, 36, 32)
	local plastic = PropFactory.material("SmoothPlastic")
	local round = { collide = false, query = false, castShadow = false, shape = Enum.PartType.Cylinder }
	PropFactory.part(model, "Base", Vector3.new(0.9, 0.26, 0.8), cf * CFrame.new(0, 0.13, 0), shell, plastic, DECOR)
	-- The front slopes up towards the cradle; the dial lies on it, facing up
	-- and out.
	local slope = cf * CFrame.new(0, 0.32, -0.12) * CFrame.Angles(math.rad(-16), 0, 0)
	PropFactory.part(model, "Slope", Vector3.new(0.82, 0.14, 0.52), slope, shell, plastic, DECOR)
	local dialCF = slope * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis up
	PropFactory.part(
		model,
		"Dial",
		Vector3.new(0.03, 0.44, 0.44),
		dialCF,
		Color3.fromRGB(226, 220, 204),
		plastic,
		round
	)
	PropFactory.part(
		model,
		"DialHub",
		Vector3.new(0.04, 0.15, 0.15),
		dialCF * CFrame.new(0.01, 0, 0),
		dark,
		plastic,
		round
	)
	-- The finger holes, as a ring of dark dots.
	for i = 0, 9 do
		local a = math.rad(40 + i * 28)
		PropFactory.part(
			model,
			"Hole",
			Vector3.new(0.035, 0.06, 0.06),
			dialCF * CFrame.new(0.01, math.cos(a) * 0.15, math.sin(a) * 0.15),
			dark,
			plastic,
			round
		)
	end
	-- The handset resting in its cradle across the back.
	PropFactory.part(model, "Cradle", Vector3.new(0.7, 0.16, 0.3), cf * CFrame.new(0, 0.34, 0.2), shell, plastic, DECOR)
	PropFactory.part(
		model,
		"Handset",
		Vector3.new(1.04, 0.11, 0.18),
		cf * CFrame.new(0, 0.5, 0.2),
		shell,
		plastic,
		DECOR
	)
	for _, x in { -0.44, 0.44 } do
		PropFactory.part(
			model,
			"Cup",
			Vector3.new(0.24, 0.13, 0.28),
			cf * CFrame.new(x, 0.45, 0.2),
			shell,
			plastic,
			DECOR
		)
	end
	model.Parent = parent
	return model
end

local function photoFrame(parent, cf: CFrame, set: number)
	local model = Instance.new("Model")
	model.Name = "PhotoFrame"
	-- Standing frame leaning back on its strut; its front faces cf's LookVector.
	local lean = cf * CFrame.new(0, 0.62, 0) * CFrame.Angles(math.rad(12), 0, 0)
	PropFactory.part(
		model,
		"Frame",
		Vector3.new(0.95, 1.2, 0.06),
		lean,
		Color3.fromRGB(96, 70, 44),
		PropFactory.material("Wood"),
		DECOR
	)
	local card = PropFactory.part(
		model,
		"Photo",
		Vector3.new(0.8, 1.04, 0.01),
		lean * CFrame.new(0, 0, -0.036),
		Color3.fromRGB(226, 220, 204),
		PropFactory.material("SmoothPlastic"),
		DECOR
	)
	local photo = Assets.Photos[set]
	if photo and photo.normal ~= "" then
		local decal = Instance.new("Decal")
		decal.Name = "Picture"
		decal.Face = Enum.NormalId.Front
		decal.Texture = photo.normal
		decal.Parent = card
		card:SetAttribute("PhotoSet", set)
		CollectionService:AddTag(card, Constants.Tags.Photo)
	end
	PropFactory.part(
		model,
		"Strut",
		Vector3.new(0.08, 1, 0.06),
		cf * CFrame.new(0, 0.5, 0.22) * CFrame.Angles(math.rad(-22), 0, 0),
		Color3.fromRGB(80, 58, 38),
		PropFactory.material("Wood"),
		DECOR
	)
	model.Parent = parent
	return model
end

-- Spots across a furniture top, front edge kept clear (Logic/SurfaceSpots).
-- Each spot is a CFrame on the surface whose LookVector faces out of the
-- furniture's front.
local function surfaceSpots(rng, prop, kind)
	local plan = SurfaceSpots.plan(rng, kind, Props.Keepouts(prop.kind, kind.size), D)
	local spots = {}
	for _, spot in plan do
		table.insert(spots, prop.cframe * CFrame.new(spot.x, spot.y, spot.z) * CFrame.Angles(0, spot.yaw, 0))
	end
	return spots
end

-- Clutter ---------------------------------------------------------------------
-- Mugs, plates, books, vases and magazines. Each is one to three small parts,
-- sat on the surface at `cf` (front of the furniture is the LookVector).

local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)
local CYLINDER = Enum.PartType.Cylinder

local function bit(model, name, size, cframe, color, material, shape)
	local opts = { collide = false, query = false, castShadow = false, shape = shape }
	return PropFactory.part(model, name, size, cframe, color, PropFactory.material(material), opts)
end

local function mug(parent, cf, rng)
	local model = Instance.new("Model")
	model.Name = "Mug"
	local tint = Color3.fromHSV(rng:NextNumber(0.02, 0.14), rng:NextNumber(0.05, 0.4), rng:NextNumber(0.55, 0.9))
	bit(
		model,
		"Cup",
		Vector3.new(0.42, 0.38, 0.38),
		cf * CFrame.new(0, 0.21, 0) * UPRIGHT,
		tint,
		"SmoothPlastic",
		CYLINDER
	)
	bit(model, "Handle", Vector3.new(0.3, 0.07, 0.3), cf * CFrame.new(0.26, 0.22, 0), tint, "SmoothPlastic")
	model.Parent = parent
end

local function plate(parent, cf, rng)
	local model = Instance.new("Model")
	model.Name = "Plate"
	local tint = Color3.fromRGB(214, 208, 192):Lerp(Color3.fromHSV(rng:NextNumber(), 0.2, 0.7), rng:NextNumber(0, 0.25))
	bit(
		model,
		"Dish",
		Vector3.new(0.07, 0.95, 0.95),
		cf * CFrame.new(0, 0.04, 0) * UPRIGHT,
		tint,
		"SmoothPlastic",
		CYLINDER
	)
	if rng:Chance(0.5) then
		bit(
			model,
			"Crust",
			Vector3.new(0.14, 0.4, 0.4),
			cf * CFrame.new(0.1, 0.12, 0.05) * UPRIGHT,
			Color3.fromRGB(160, 120, 72),
			"Fabric",
			CYLINDER
		)
	end
	model.Parent = parent
end

local function books(parent, cf, rng)
	local model = Instance.new("Model")
	model.Name = "Books"
	local y = 0
	for _ = 1, rng:NextInteger(2, 3) do
		local h = rng:NextNumber(0.14, 0.26)
		local tint = Color3.fromHSV(rng:NextNumber(), 0.35, rng:NextNumber(0.25, 0.5))
		bit(
			model,
			"Book",
			Vector3.new(rng:NextNumber(0.8, 1.1), h, rng:NextNumber(0.6, 0.8)),
			cf * CFrame.new(rng:NextNumber(-0.05, 0.05), y + h / 2, 0) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0),
			tint,
			"Fabric"
		)
		y += h
	end
	model.Parent = parent
end

local function vase(parent, cf, rng)
	local model = Instance.new("Model")
	model.Name = "Vase"
	local tint = Color3.fromHSV(rng:NextNumber(0.45, 0.62), 0.25, rng:NextNumber(0.4, 0.65))
	bit(
		model,
		"Body",
		Vector3.new(0.9, 0.55, 0.55),
		cf * CFrame.new(0, 0.45, 0) * UPRIGHT,
		tint,
		"SmoothPlastic",
		CYLINDER
	)
	bit(
		model,
		"Neck",
		Vector3.new(0.4, 0.28, 0.28),
		cf * CFrame.new(0, 1.05, 0) * UPRIGHT,
		tint,
		"SmoothPlastic",
		CYLINDER
	)
	if rng:Chance(0.6) then
		bit(
			model,
			"Stems",
			Vector3.new(0.6, 0.12, 0.12),
			cf * CFrame.new(0, 1.5, 0),
			Color3.fromRGB(70, 74, 44),
			"Fabric"
		)
	end
	model.Parent = parent
end

local function magazine(parent, cf, rng)
	local model = Instance.new("Model")
	model.Name = "Magazine"
	local tint = Color3.fromHSV(rng:NextNumber(), 0.45, 0.6)
	bit(
		model,
		"Cover",
		Vector3.new(0.85, 0.05, 1.1),
		cf * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0),
		tint,
		"Fabric"
	)
	model.Parent = parent
end

local CLUTTER = { mug, plate, books, vase, magazine }

function Dressing.build(world, rng)
	local phones, photos = 0, 0
	-- Telephones first, in the hall-like rooms, then photos everywhere else.
	local surfaces = {}
	for _, room in world.layout.rooms do
		local record = world.rooms[room.id]
		local ids = {}
		for id in record.props do
			table.insert(ids, id)
		end
		table.sort(ids)
		for _, id in ids do
			local prop = record.props[id]
			local kind = Props.Kinds[prop.kind]
			if kind and kind.top and prop.model.Parent then
				table.insert(surfaces, { record = record, prop = prop, kind = kind })
			end
		end
	end
	local hallLike = function(s)
		return s.record.template.family == "corridor" or s.record.template.id == "foyer"
	end

	-- Each surface's spots are worked out once, so nothing lands on top of
	-- something else. The last spot on every top is left free: the house leaves
	-- a found tool there (Services/ToolService, World/ToolPickups).
	local function take(s)
		s.spots = s.spots or surfaceSpots(rng, s.prop, s.kind)
		if (s.next or 0) >= #s.spots - 1 then
			return nil
		end
		s.next = (s.next or 0) + 1
		return s.spots[s.next]
	end

	for _, s in surfaces do
		if phones < D.Telephones and hallLike(s) and rng:Chance(D.TelephoneChance) then
			local spot = take(s)
			if spot then
				telephone(s.record.model, spot)
				phones += 1
			end
		end
	end
	for _, s in surfaces do
		local family = s.record.template.family
		local fits = D.PhotoKinds[s.prop.kind] and family ~= "utility"
		if photos < D.MaxPhotos and fits and rng:Chance(D.PhotoChance) then
			for _ = 1, rng:NextInteger(1, 2) do
				local spot = take(s)
				if spot and photos < D.MaxPhotos then
					photoFrame(s.record.model, spot, rng:NextInteger(1, #Assets.Photos))
					photos += 1
				end
			end
		end
	end
	-- Then a little everyday clutter on the tops that are left.
	local clutter = 0
	for _, s in surfaces do
		if clutter >= D.MaxClutter then
			break
		end
		if rng:Chance(D.ClutterChance) then
			for _ = 1, rng:NextInteger(1, D.ClutterPerSurface) do
				local spot = take(s)
				if spot and clutter < D.MaxClutter then
					CLUTTER[rng:NextInteger(1, #CLUTTER)](s.record.model, spot, rng)
					clutter += 1
				end
			end
		end
	end
	-- Plan whatever was never touched, last, so the tool pickups find every top
	-- with its spots. The extra random draws come after all the others, so no
	-- earlier placement moves.
	for _, s in surfaces do
		s.spots = s.spots or surfaceSpots(rng, s.prop, s.kind)
		s.next = s.next or 0
	end
	world.surfaces = surfaces
	return phones, photos, clutter
end

-- Places left on a top after the dressing, and the next of them.
function Dressing.free(s): number
	return #s.spots - s.next
end

function Dressing.claim(s): CFrame?
	if Dressing.free(s) <= 0 then
		return nil
	end
	s.next += 1
	return s.spots[s.next]
end

return Dressing
