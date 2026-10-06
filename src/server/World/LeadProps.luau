-- The things that lead you to a key or an heirloom (R2c "leads"; Logic/Leads,
-- Services/ItemService): a keepsake box with a lid, a locked glass display
-- case, a key rack, and a note. Built at run time into the run's content
-- folder, so Gate A never sees them.
--
-- Every builder takes `cf` with its front along +Z (as World/PropFactory's
-- furniture does); callers turn a surface or wall spot (LookVector out into
-- the room) half round first. Lids carry their joint the way PropFactory's
-- furniture pieces do (Lib/Joint), so Services/FurnitureService opens them
-- by hand and by prompt like any drawer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Joint = require(Shared.Lib.Joint)
local PropFactory = require(Shared.World.PropFactory)

local part = PropFactory.part
local F = Config.Furniture
local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)
local BRASS = Color3.fromRGB(176, 146, 84)
local SMALL = { collide = false, castShadow = false }

local LeadProps = {}

-- A lid hinged along the top of the box's back edge (-Z), lifting the front.
local function lid(model: Model, primary: BasePart, hinge: Vector3, axis: Vector3, o)
	model.PrimaryPart = primary
	Joint.write(primary, {
		kind = "hinge",
		hinge = hinge,
		axis = axis,
		sign = -1,
		shut = primary.CFrame,
		max = o.max or F.LidOpen,
		rate = o.rate or F.LidRate,
		latch = F.DoorLatch,
	})
	primary:SetAttribute("Group", "Main")
	primary:SetAttribute("Spot", o.spot)
	primary:SetAttribute("Label", o.label)
end

-- Keepsake boxes ---------------------------------------------------------------

-- Three looks, so a box is a box you learn to spot, without every one being
-- the same: a brass-cornered wooden box, a painted biscuit tin, a velvet case.
LeadProps.KeepsakeLooks = {
	{ name = "wood", color = Color3.fromRGB(96, 62, 40), lidColor = Color3.fromRGB(110, 72, 46), material = "Wood" },
	{
		name = "tin",
		color = Color3.fromRGB(46, 70, 92),
		lidColor = Color3.fromRGB(150, 40, 44),
		material = "Metal",
	},
	{
		name = "velvet",
		color = Color3.fromRGB(70, 22, 34),
		lidColor = Color3.fromRGB(84, 28, 40),
		material = "Fabric",
	},
}

function LeadProps.keepsake(cf: CFrame, parent: Instance, look: number): Model
	local style = LeadProps.KeepsakeLooks[look] or LeadProps.KeepsakeLooks[1]
	local material = PropFactory.material(style.material)
	local w, h, d = 1.15, 0.5, 0.8
	local model = Instance.new("Model")
	model.Name = "Keepsake"
	local wall = 0.06
	part(model, "Floor", Vector3.new(w, 0.06, d), cf * CFrame.new(0, 0.03, 0), style.color, material)
	for _, sz in { -1, 1 } do
		part(
			model,
			"Side",
			Vector3.new(w, h - 0.06, wall),
			cf * CFrame.new(0, (h + 0.06) / 2, sz * (d / 2 - wall / 2)),
			style.color,
			material
		)
	end
	for _, sx in { -1, 1 } do
		part(
			model,
			"End",
			Vector3.new(wall, h - 0.06, d - wall * 2),
			cf * CFrame.new(sx * (w / 2 - wall / 2), (h + 0.06) / 2, 0),
			style.color,
			material
		)
	end
	-- The lining: you see it's empty, or what's in it, the moment it opens.
	part(
		model,
		"Lining",
		Vector3.new(w - wall * 2 - 0.02, 0.02, d - wall * 2 - 0.02),
		cf * CFrame.new(0, 0.07, 0),
		Color3.fromRGB(150, 120, 90),
		PropFactory.material("Fabric"),
		SMALL
	)
	local top = Instance.new("Model")
	top.Name = "Lid"
	top.Parent = model
	local board = part(
		top,
		"Lid",
		Vector3.new(w + 0.04, 0.1, d + 0.04),
		cf * CFrame.new(0, h + 0.05, 0),
		style.lidColor,
		material
	)
	if style.name == "wood" then
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				part(
					top,
					"Corner",
					Vector3.new(0.14, 0.12, 0.14),
					cf * CFrame.new(sx * (w / 2 - 0.05), h + 0.05, sz * (d / 2 - 0.05)),
					BRASS,
					PropFactory.material("Metal"),
					SMALL
				)
			end
		end
	elseif style.name == "tin" then
		part(
			top,
			"Band",
			Vector3.new(w + 0.05, 0.03, 0.18),
			cf * CFrame.new(0, h + 0.1, 0),
			Color3.fromRGB(214, 190, 120),
			PropFactory.material("SmoothPlastic"),
			SMALL
		)
	else
		part(
			top,
			"Clasp",
			Vector3.new(0.16, 0.14, 0.05),
			cf * CFrame.new(0, h - 0.02, d / 2 + 0.03),
			BRASS,
			PropFactory.material("Metal"),
			SMALL
		)
	end
	lid(top, board, cf:PointToWorldSpace(Vector3.new(0, h, -d / 2)), cf:VectorToWorldSpace(Vector3.xAxis), {
		spot = cf * CFrame.new(0, 0.09, 0.05),
		label = "Keepsake box",
	})
	model.Parent = parent
	return model
end

-- Display cases -------------------------------------------------------------------

-- A wooden base under a glass cover hinged at the back, held shut by a small
-- brass lock at the front. What's inside is plain to see. Returns the model,
-- the spot inside, the cover's glass panes and the lock plate (the pick
-- prompt goes on it).
function LeadProps.displayCase(cf: CFrame, parent: Instance)
	local w, d, base, glassH = 1.2, 0.9, 0.22, 0.75
	local model = Instance.new("Model")
	model.Name = "DisplayCase"
	local wood = Color3.fromRGB(70, 44, 30)
	part(
		model,
		"Base",
		Vector3.new(w + 0.1, base, d + 0.1),
		cf * CFrame.new(0, base / 2, 0),
		wood,
		PropFactory.material("Wood")
	)
	part(
		model,
		"Felt",
		Vector3.new(w - 0.1, 0.02, d - 0.1),
		cf * CFrame.new(0, base + 0.01, 0),
		Color3.fromRGB(40, 70, 52),
		PropFactory.material("Fabric"),
		SMALL
	)
	local cover = Instance.new("Model")
	cover.Name = "Lid"
	cover.Parent = model
	local glass = PropFactory.material("Glass")
	local tint = Color3.fromRGB(200, 214, 220)
	local pane = { transparency = 0.6, castShadow = false, reflectance = 0.12 }
	local panes = {}
	local y0 = base + glassH / 2
	local top = part(cover, "Glass", Vector3.new(w, 0.05, d), cf * CFrame.new(0, base + glassH, 0), tint, glass, pane)
	table.insert(panes, top)
	for _, sz in { -1, 1 } do
		table.insert(
			panes,
			part(cover, "Glass", Vector3.new(w, glassH, 0.05), cf * CFrame.new(0, y0, sz * d / 2), tint, glass, pane)
		)
	end
	for _, sx in { -1, 1 } do
		table.insert(
			panes,
			part(cover, "Glass", Vector3.new(0.05, glassH, d), cf * CFrame.new(sx * w / 2, y0, 0), tint, glass, pane)
		)
	end
	-- The cover's frame: thin dark edges round the top and down each corner,
	-- so it reads as a glass box.
	local frame = PropFactory.material("Wood")
	local rim = base + glassH
	for _, sz in { -1, 1 } do
		part(cover, "Frame", Vector3.new(w + 0.06, 0.05, 0.05), cf * CFrame.new(0, rim, sz * d / 2), wood, frame, SMALL)
		part(
			cover,
			"Frame",
			Vector3.new(w + 0.06, 0.05, 0.05),
			cf * CFrame.new(0, base + 0.02, sz * d / 2),
			wood,
			frame,
			SMALL
		)
	end
	for _, sx in { -1, 1 } do
		part(cover, "Frame", Vector3.new(0.05, 0.05, d), cf * CFrame.new(sx * w / 2, rim, 0), wood, frame, SMALL)
		for _, sz in { -1, 1 } do
			part(
				cover,
				"Frame",
				Vector3.new(0.05, glassH, 0.05),
				cf * CFrame.new(sx * w / 2, y0, sz * d / 2),
				wood,
				frame,
				SMALL
			)
		end
	end
	local plate = part(
		model,
		"Lock",
		Vector3.new(0.18, 0.16, 0.05),
		cf * CFrame.new(0, base / 2, d / 2 + 0.08),
		BRASS,
		PropFactory.material("Metal"),
		{ collide = false }
	)
	part(
		model,
		"Keyhole",
		Vector3.new(0.04, 0.08, 0.02),
		cf * CFrame.new(0, base / 2, d / 2 + 0.11),
		Color3.fromRGB(20, 18, 16),
		PropFactory.material("SmoothPlastic"),
		SMALL
	)
	local spot = cf * CFrame.new(0, base + 0.03, 0)
	lid(cover, top, cf:PointToWorldSpace(Vector3.new(0, base + glassH, -d / 2)), cf:VectorToWorldSpace(Vector3.xAxis), {
		max = 80,
		spot = spot,
		label = "Display case",
	})
	model.Parent = parent
	return model, spot, panes, plate
end

-- A little porcelain figure: what a case with nothing of his in it shows.
function LeadProps.figurine(at: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Figurine"
	local porcelain = Color3.fromRGB(232, 228, 220)
	local smooth = PropFactory.material("SmoothPlastic")
	part(
		model,
		"Plinth",
		Vector3.new(0.06, 0.3, 0.3),
		at * CFrame.new(0, 0.03, 0) * UPRIGHT,
		porcelain,
		smooth,
		{ collide = false, shape = CYL }
	)
	part(
		model,
		"Skirt",
		Vector3.new(0.3, 0.26, 0.26),
		at * CFrame.new(0, 0.2, 0) * UPRIGHT,
		Color3.fromRGB(150, 180, 200),
		smooth,
		{ collide = false, shape = CYL }
	)
	part(
		model,
		"Body",
		Vector3.new(0.12, 0.2, 0.1),
		at * CFrame.new(0, 0.42, 0),
		porcelain,
		smooth,
		{ collide = false }
	)
	part(
		model,
		"Head",
		Vector3.new(0.11, 0.11, 0.11),
		at * CFrame.new(0, 0.58, 0),
		porcelain,
		smooth,
		{ collide = false, shape = BALL }
	)
	model.Parent = parent
	return model
end

-- Key racks ----------------------------------------------------------------------

-- A board with four brass hooks, on a wall. Returns the model and where a key
-- hangs on each hook (a CFrame for World/Items.key: its flat face to the room).
function LeadProps.keyRack(cf: CFrame, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "KeyRack"
	local w = 1.9
	part(
		model,
		"Board",
		Vector3.new(w, 0.8, 0.1),
		cf * CFrame.new(0, 0, 0.05),
		Color3.fromRGB(120, 86, 56),
		PropFactory.material("Wood"),
		{ collide = false }
	)
	part(
		model,
		"Rail",
		Vector3.new(w - 0.1, 0.14, 0.06),
		cf * CFrame.new(0, 0.26, 0.13),
		Color3.fromRGB(96, 66, 42),
		PropFactory.material("Wood"),
		SMALL
	)
	local hangs = {}
	for i = 1, 4 do
		local x = -w / 2 + w * (i - 0.5) / 4
		part(
			model,
			"Hook",
			Vector3.new(0.05, 0.05, 0.22),
			cf * CFrame.new(x, 0.02, 0.2),
			BRASS,
			PropFactory.material("Metal"),
			SMALL
		)
		-- World/Items.key lies flat (face up, shaft along X, bow at -X). Turned
		-- so its bow is up on the hook and its face looks into the room.
		hangs[i] = cf
			* CFrame.new(x, -0.26, 0.2)
			* CFrame.fromMatrix(Vector3.zero, Vector3.new(0, -1, 0), Vector3.new(0, 0, 1))
	end
	model.Parent = parent
	return model, hangs
end

-- Notes ----------------------------------------------------------------------------

-- Scribble: lines of something like handwriting you can't read from here.
-- The words are made up from `seed`; the real text only reaches a player who
-- reads the note (Services/ItemService).
local function scribble(seed: number): string
	local rng = Random.new(seed)
	local letters = "mnuwoaecrsvi"
	local lines = {}
	for _ = 1, rng:NextInteger(5, 7) do
		local words = {}
		for _ = 1, rng:NextInteger(2, 4) do
			local word = {}
			for _ = 1, rng:NextInteger(2, 6) do
				local i = rng:NextInteger(1, #letters)
				table.insert(word, string.sub(letters, i, i))
			end
			table.insert(words, table.concat(word))
		end
		table.insert(lines, table.concat(words, " "))
	end
	return table.concat(lines, "\n")
end

-- A sheet of notepaper: pinned to a wall (`onWall`, standing up) or lying on
-- a top. Returns the model and the sheet (the Read prompt goes on it).
function LeadProps.note(cf: CFrame, parent: Instance, onWall: boolean, seed: number)
	local model = Instance.new("Model")
	model.Name = "Note"
	local paper = Color3.fromRGB(232, 224, 196)
	local sheet
	if onWall then
		sheet = part(
			model,
			"Paper",
			Vector3.new(0.85, 1.1, 0.03),
			cf * CFrame.new(0, 0, 0.03),
			paper,
			PropFactory.material("SmoothPlastic"),
			{ collide = false }
		)
		part(
			model,
			"Pin",
			Vector3.new(0.1, 0.1, 0.1),
			cf * CFrame.new(0, 0.45, 0.07),
			Color3.fromRGB(170, 34, 30),
			PropFactory.material("SmoothPlastic"),
			{ collide = false, shape = BALL }
		)
	else
		sheet = part(
			model,
			"Paper",
			Vector3.new(0.85, 0.02, 1.1),
			cf * CFrame.new(0, 0.01, 0),
			paper,
			PropFactory.material("SmoothPlastic"),
			{ collide = false, castShadow = false }
		)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Writing"
	gui.Face = onWall and Enum.NormalId.Back or Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(170, 220)
	gui.LightInfluence = 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 1, -20)
	label.Position = UDim2.fromOffset(10, 10)
	label.BackgroundTransparency = 1
	label.TextWrapped = true
	label.TextSize = 19
	label.Font = Enum.Font.IndieFlower
	label.TextColor3 = Color3.fromRGB(40, 44, 78)
	label.TextTransparency = 0.25
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = scribble(seed)
	label.Parent = gui
	gui.Parent = sheet
	model.Parent = parent
	return model, sheet
end

-- The house plans (docs/plans/level-design.md section 11, L3.5): a sheet of
-- blueprints lying flat, white lines on blue, one corner curling up.
function LeadProps.plans(cf: CFrame, parent: Instance, title: string?)
	local model = Instance.new("Model")
	model.Name = "HousePlans"
	local blue = Color3.fromRGB(38, 70, 128)
	local sheet = part(
		model,
		"Paper",
		Vector3.new(2.2, 0.02, 1.6),
		cf * CFrame.new(0, 0.01, 0),
		blue,
		PropFactory.material("SmoothPlastic"),
		{ collide = false, castShadow = false }
	)
	-- The curl: a thin roll along one short edge.
	part(
		model,
		"Curl",
		Vector3.new(1.6, 0.16, 0.16),
		cf * CFrame.new(1.12, 0.08, 0) * CFrame.Angles(0, math.pi / 2, 0),
		blue,
		PropFactory.material("SmoothPlastic"),
		{ collide = false, castShadow = false, shape = CYL }
	)
	-- A floor plan in white: the outline, and walls between rooms.
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Drawing"
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(220, 160)
	gui.LightInfluence = 1
	local white = Color3.fromRGB(226, 234, 244)
	local function line(x: number, y: number, w: number, h: number)
		local f = Instance.new("Frame")
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, h)
		f.BackgroundColor3 = white
		f.BackgroundTransparency = 0.15
		f.BorderSizePixel = 0
		f.Parent = gui
	end
	line(20, 20, 180, 3)
	line(20, 137, 180, 3)
	line(20, 20, 3, 120)
	line(197, 20, 3, 120)
	line(90, 20, 3, 70)
	line(20, 88, 120, 3)
	line(140, 60, 3, 80)
	line(140, 60, 60, 3)
	local caption = Instance.new("TextLabel")
	caption.BackgroundTransparency = 1
	caption.Position = UDim2.fromOffset(24, 142)
	caption.Size = UDim2.fromOffset(172, 16)
	caption.Font = Enum.Font.Code
	caption.TextSize = 12
	caption.TextColor3 = white
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.Text = title and string.upper(title) or "PLAN - 1961"
	caption.Parent = gui
	gui.Parent = sheet
	model.Parent = parent
	return model, sheet
end

return LeadProps
