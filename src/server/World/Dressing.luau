-- Small things on furniture tops (docs/ART.md, Hero props): family photos in
-- standing frames and an old telephone. P.T.'s lesson is that a handful of
-- believable everyday objects does more than a room full of furniture.
--
-- Placed from the seed, so everyone sees the same house. Nothing here ever
-- collides, blocks a ray, or carries a CId: dressing is never Witnessable and
-- never evidence (rule 6). Photos are tagged so the client can age them with
-- Drift (EffectsController).

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

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

-- Things standing about the house that the space queries can't see (the
-- house's decor is built query-free: a cabinet radio), so a claim checks
-- them by their boxes (DecorService adds them). Emptied with every house.
local obstacles: { Model } = {}

function Dressing.obstacle(model: Model)
	table.insert(obstacles, model)
end

-- And everything the run has set out (its tools, keys, heirlooms, notes,
-- the toys: mostly query-free too), by their boxes, in this folder
-- (WorldService's RunContent).
local runContent: Instance? = nil

function Dressing.watch(folder: Instance?)
	runContent = folder
end

-- Each model the run has set out, one folder deep.
local function runModels(): { Model }
	local list = {}
	for _, child in runContent and runContent:GetChildren() or {} do
		if child:IsA("Model") then
			table.insert(list, child)
		elseif child:IsA("Folder") then
			for _, model in child:GetChildren() do
				if model:IsA("Model") then
					table.insert(list, model)
				end
			end
		end
	end
	return list
end

-- Do two boxes meet (the separating-axis test, as World/ClipScan's)?
local function boxesMeet(cfA: CFrame, sizeA: Vector3, cfB: CFrame, sizeB: Vector3): boolean
	local axesA = { cfA.RightVector, cfA.UpVector, cfA.LookVector }
	local axesB = { cfB.RightVector, cfB.UpVector, cfB.LookVector }
	local ha, hb = { sizeA.X / 2, sizeA.Y / 2, sizeA.Z / 2 }, { sizeB.X / 2, sizeB.Y / 2, sizeB.Z / 2 }
	local offset = cfB.Position - cfA.Position
	local function apart(axis: Vector3): boolean
		if axis.Magnitude < 1e-4 then
			return false
		end
		axis = axis.Unit
		local ra, rb = 0, 0
		for i = 1, 3 do
			ra += math.abs(axesA[i]:Dot(axis)) * ha[i]
			rb += math.abs(axesB[i]:Dot(axis)) * hb[i]
		end
		return math.abs(offset:Dot(axis)) >= ra + rb
	end
	for i = 1, 3 do
		if apart(axesA[i]) or apart(axesB[i]) then
			return false
		end
	end
	for i = 1, 3 do
		for j = 1, 3 do
			if apart(axesA[i]:Cross(axesB[j])) then
				return false
			end
		end
	end
	return true
end

-- An old rotary telephone. `cf` sits on the surface with its LookVector
-- facing out of the furniture's front, so the front of the phone is -Z.
-- (Public since 2026-10-06: Services/HouseEventService puts one in the hall
-- when the dressing placed none, so the telephone can ring in every house.)
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
	local keepouts = Props.Keepouts(prop.kind, kind.size)
	local plan = SurfaceSpots.plan(rng, kind, keepouts, D)
	local spots = {}
	for _, spot in plan do
		table.insert(spots, prop.cframe * CFrame.new(spot.x, spot.y, spot.z) * CFrame.Angles(0, spot.yaw, 0))
	end
	return spots, plan, keepouts
end

-- A top's record of what's on it (the progression audit, 2026-10-10: things
-- were handed spots without their size, so the home computer and the music
-- box shared one): its spots as planned (`raw`, in the prop's frame), which
-- are taken, the stretches of its width in use, and the dressing on each.
local function ready(s, rng)
	if s.spots then
		return
	end
	local spots, plan, keepouts = surfaceSpots(rng, s.prop, s.kind)
	s.spots, s.raw = spots, plan
	s.next = s.next or 0
	s.taken = {}
	s.items = {}
	s.used = {}
	for _, k in keepouts do
		table.insert(s.used, { x0 = k.x0, x1 = k.x1 })
	end
end

-- How far a model reaches along `axis` (a unit vector), end to end.
local function extentAlong(model: Model, axis: Vector3): number
	local cf, size = model:GetBoundingBox()
	return math.abs(axis:Dot(cf.RightVector)) * size.X
		+ math.abs(axis:Dot(cf.UpVector)) * size.Y
		+ math.abs(axis:Dot(cf.LookVector)) * size.Z
end

-- Mark spot `i` taken by something `width` wide centred at `x`.
local function occupy(s, x: number, width: number)
	table.insert(s.used, { x0 = x - width / 2, x1 = x + width / 2 })
	for i, spot in s.raw do
		if not s.taken[i] and math.abs(spot.x - x) < width / 2 + D.SpotWidth / 2 - 0.05 then
			s.taken[i] = true
		end
	end
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
	return model
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
	return model
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
	return model
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
	return model
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
	return model
end

local CLUTTER = { mug, plate, books, vase, magazine }

function Dressing.build(world, rng)
	table.clear(obstacles)
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
		ready(s, rng)
		if s.next >= #s.spots - 1 then
			return nil
		end
		s.next += 1
		s.taken[s.next] = true
		return s.spots[s.next], s.next
	end
	-- What was set on spot `i`: its stretch of the top, as wide as it really is.
	local function set(s, i: number, model: Model, keep: boolean?)
		local half = extentAlong(model, s.prop.cframe.RightVector) / 2
		local stretch = { x0 = s.raw[i].x - half, x1 = s.raw[i].x + half }
		s.items[i] = { model = model, keep = keep, stretch = stretch }
		table.insert(s.used, stretch)
	end

	for _, s in surfaces do
		if phones < D.Telephones and hallLike(s) and rng:Chance(D.TelephoneChance) then
			local spot, i = take(s)
			if spot then
				set(s, i, telephone(s.record.model, spot), true)
				phones += 1
			end
		end
	end
	for _, s in surfaces do
		local family = s.record.template.family
		local fits = D.PhotoKinds[s.prop.kind] and family ~= "utility"
		if photos < D.MaxPhotos and fits and rng:Chance(D.PhotoChance) then
			for _ = 1, rng:NextInteger(1, 2) do
				local spot, i = take(s)
				if spot and photos < D.MaxPhotos then
					set(s, i, photoFrame(s.record.model, spot, rng:NextInteger(1, #Assets.Photos)))
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
				local spot, i = take(s)
				if spot and clutter < D.MaxClutter then
					set(s, i, CLUTTER[rng:NextInteger(1, #CLUTTER)](s.record.model, spot, rng))
					clutter += 1
				end
			end
		end
	end
	-- Plan whatever was never touched, last, so the tool pickups find every top
	-- with its spots. The extra random draws come after all the others, so no
	-- earlier placement moves.
	for _, s in surfaces do
		ready(s, rng)
	end
	world.surfaces = surfaces
	return phones, photos, clutter
end

-- The top's half-width, and its back and front edges, in the prop's frame.
local function bounds(s): (number, number, number)
	local near, far = SurfaceSpots.depthSpan(s.kind)
	return s.kind.size[1] / 2, near, far
end

-- Where on the top a thing `width` wide would go: its x in the prop's frame
-- and the spot it takes after (its z and turn), or nil.
local function place(s, width: number): (number?, any)
	local candidates, order = {}, {}
	for i, spot in s.raw do
		if not s.taken[i] then
			table.insert(candidates, spot.x)
			table.insert(order, spot)
		end
	end
	local halfWidth = bounds(s)
	local x = SurfaceSpots.findX(candidates, s.used, halfWidth, width)
	if not x then
		return nil, nil
	end
	for _, spot in order do
		if spot.x == x then
			return x, spot
		end
	end
	return x, order[1] or s.raw[1]
end

-- How many more ordinary things (an ItemWidth each) the top has room for.
function Dressing.free(s, width: number?): number
	if not s.raw then
		return 0
	end
	local w = width or D.ItemWidth
	local used = table.clone(s.used)
	local halfWidth = bounds(s)
	local n = 0
	for i, spot in s.raw do
		if not s.taken[i] and SurfaceSpots.fits(spot.x, w, used, halfWidth) then
			n += 1
			table.insert(used, { x0 = spot.x - w / 2, x1 = spot.x + w / 2 })
		end
	end
	return n
end

-- A place on the top for something `width` wide and `depth` deep (an
-- ItemWidth square if not given): on the surface, facing out of the
-- furniture's front, clear of everything already there and of the top's
-- edges. nil when it won't fit.
function Dressing.claim(s, width: number?, depth: number?): CFrame?
	if not s.raw then
		return nil
	end
	local w = width or D.ItemWidth
	local _, near, far = bounds(s)
	-- (A few tries: a spot with something standing over it is passed by.)
	for _ = 1, #s.raw + 1 do
		local x, spot = place(s, w)
		if not x or not spot then
			return nil
		end
		local z = SurfaceSpots.clampZ(spot.z, depth or w, near, far)
		occupy(s, x, w)
		local cf = s.prop.cframe * CFrame.new(x, spot.y, z) * CFrame.Angles(0, spot.yaw, 0)
		if Dressing.clear(s, cf, w, depth or w) then
			return cf
		end
	end
	return nil
end

-- Nothing solid in the space a thing `width` by `depth` would fill standing
-- at `cf` on the top, but the furniture under it (the overlap scan,
-- 2026-10-10: a baby monitor's aerial in a cabinet radio's shelf beside its
-- dresser: things beside a top, not on it, are only found this way).
function Dressing.clear(s, cf: CFrame, width: number, depth: number): boolean
	return Dressing.clearAt(cf, Vector3.new(width, D.ItemHeight, depth), { s.prop.model })
end

-- Nothing solid in the box `size` standing on `cf` (its base on the
-- surface, `lift` above it: a floor's rug isn't in the way), but `exclude`:
-- the parts there and the query-free obstacles.
function Dressing.clearAt(cf: CFrame, size: Vector3, exclude: { Instance }?, lift: number?): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude or {}
	local box = cf * CFrame.new(0, size.Y / 2 + (lift or 0.05), 0)
	local skip = {}
	for _, x in exclude or {} do
		skip[x] = true
	end
	for _, list in { obstacles, runModels() } do
		for _, model in list do
			if model.Parent and not skip[model] then
				local ocf, osize = model:GetBoundingBox()
				if boxesMeet(box, size, ocf, osize) then
					return false
				end
			end
		end
	end
	for _, part in Workspace:GetPartBoundsInBox(box, size, params) do
		-- (Not a window's glass or anything else you see through, not a body.)
		local holder = part:FindFirstAncestorOfClass("Model")
		local body = holder ~= nil and holder:FindFirstChildOfClass("Humanoid") ~= nil
		if part.Transparency < 0.5 and not body then
			return false
		end
	end
	return true
end

-- A stretch of the top `width` wide for something that sets itself out in
-- the prop's own frame (the home computer): its middle's x, or nil. With
-- `depth` and `z` (its middle front to back), the space it fills is checked
-- as a claim's is.
function Dressing.claimSpan(s, width: number, depth: number?, z: number?): number?
	if not s.raw then
		return nil
	end
	for _ = 1, #s.raw + 1 do
		local x = place(s, width)
		if not x then
			return nil
		end
		occupy(s, x, width)
		if not depth then
			return x
		end
		local cf = s.prop.cframe * CFrame.new(x, s.kind.size[2], z or 0)
		if Dressing.clear(s, cf, width, depth) then
			return x
		end
	end
	return nil
end

-- Make room for something `width` wide on a top that has none: the house's
-- own dressing on it (a mug, a photo, never anything of the run's) moves to
-- another of `others` where it fits, or goes (the telephone stays), one
-- piece at a time until there's room. Returns whether there now is.
function Dressing.makeRoom(s, width: number, others: { any }): boolean
	if not s.raw then
		return false
	end
	local ids = {}
	for i in s.items do
		table.insert(ids, i)
	end
	table.sort(ids)
	for _, i in ids do
		if place(s, width) then
			return true
		end
		local entry = s.items[i]
		if entry and not entry.keep and entry.model and entry.model.Parent then
			s.items[i] = nil
			local at = table.find(s.used, entry.stretch)
			if at then
				table.remove(s.used, at)
			end
			local moved = false
			for _, other in others do
				if other ~= s and other.raw then
					local cf = Dressing.claim(other, extentAlong(entry.model, other.prop.cframe.RightVector))
					if cf then
						-- As it stood on its old spot, now on the new one.
						entry.model:PivotTo(cf * s.spots[i]:Inverse() * entry.model:GetPivot())
						moved = true
						break
					end
				end
			end
			if not moved then
				entry.model:Destroy()
			end
		end
	end
	return place(s, width) ~= nil
end

Dressing.telephone = telephone

return Dressing
