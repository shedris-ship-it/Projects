-- Builds the lobby's mall from Data/Mall (docs/plans/lobby-rework.md, LB1a:
-- the grey box, walked and judged before anything is modelled). Rooms are
-- floors, walls cut by their doors (Logic/MallLayout) and ceilings; doors
-- get their grilles, glass or shutters; then the signs, the lights and the
-- stand-in blocks. A run server builds only the waiting room
-- (Mall.Waiting), with doors to rooms it doesn't build walled up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Mall = require(Shared.Data.Mall)
local MallLayout = require(Shared.Logic.MallLayout)
local PropFactory = require(Shared.World.PropFactory)

local part = PropFactory.part
local material = PropFactory.material

local MallBuilder = {}

local FACES = {
	N = Vector3.new(0, 0, -1),
	S = Vector3.new(0, 0, 1),
	E = Vector3.new(1, 0, 0),
	W = Vector3.new(-1, 0, 0),
}

local STEEL = Color3.fromRGB(120, 122, 126)
local DARK_STEEL = Color3.fromRGB(70, 72, 76)

local function rgb(t): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- A frame at a floor-plan point, its front (-Z) looking `face`.
local function facing(origin: Vector3, x: number, y: number, z: number, face: string): CFrame
	local p = origin + Vector3.new(x, y, z)
	return CFrame.lookAt(p, p + FACES[face])
end

local function decor(folder: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material)
	return part(folder, name, size, cf, color, mat, { collide = false, query = false, castShadow = false })
end

local function buildRoom(folder: Instance, origin: Vector3, id: string, built)
	local room = Mall.Rooms[id]
	local x0, z0, x1, z1 = room.rect[1], room.rect[2], room.rect[3], room.rect[4]
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local t = Mall.Wall
	local h = room.height
	local model = Instance.new("Folder")
	model.Name = id
	model.Parent = folder
	local floor = room.floor or {}
	part(
		model,
		"Floor",
		Vector3.new(x1 - x0, 1, z1 - z0),
		CFrame.new(origin + Vector3.new(cx, -0.5, cz)),
		rgb(floor.color or { 160, 160, 160 }),
		material(floor.material)
	)
	local wall = room.wall or {}
	local wallColor = rgb(wall.color or { 200, 200, 200 })
	local wallMaterial = material(wall.material)
	for _, side in MallLayout.sides(room.rect) do
		local cuts = {}
		for _, cut in MallLayout.cutsFor(id, side, Mall.Doors) do
			-- A door to a room this server doesn't build stays walled up.
			local other = cut.door.a == id and cut.door.b or cut.door.a
			if other == nil or built[other] then
				table.insert(cuts, cut)
			end
		end
		local from, to = side.from, side.to
		if side.runs == "z" then
			from, to = from + t, to - t -- the north and south walls take the corners
		end
		local line = side.at + side.inward * t / 2
		for _, piece in MallLayout.segments(from, to, cuts, h) do
			local length = piece.to - piece.from
			local mid = (piece.from + piece.to) / 2
			local y = (piece.bottom + piece.top) / 2
			local size, at
			if side.runs == "x" then
				size, at = Vector3.new(length, piece.top - piece.bottom, t), Vector3.new(mid, y, line)
			else
				size, at = Vector3.new(t, piece.top - piece.bottom, length), Vector3.new(line, y, mid)
			end
			part(model, "Wall", size, CFrame.new(origin + at), wallColor, wallMaterial)
		end
	end
	-- The ceiling (the court's round its skylight).
	local ceiling = room.ceiling or {}
	local ceilingColor = rgb(ceiling.color or { 150, 146, 140 })
	local function slab(ax0: number, az0: number, ax1: number, az1: number)
		if ax1 - ax0 > 0.01 and az1 - az0 > 0.01 then
			part(
				model,
				"Ceiling",
				Vector3.new(ax1 - ax0, 1, az1 - az0),
				CFrame.new(origin + Vector3.new((ax0 + ax1) / 2, h + 0.5, (az0 + az1) / 2)),
				ceilingColor,
				material("SmoothPlastic")
			)
		end
	end
	local sky = room.skylight
	if sky then
		slab(x0, z0, x1, sky[2])
		slab(x0, sky[4], x1, z1)
		slab(x0, sky[2], sky[1], sky[4])
		slab(sky[3], sky[2], x1, sky[4])
		local w, d = sky[3] - sky[1], sky[4] - sky[2]
		local mid = origin + Vector3.new((sky[1] + sky[3]) / 2, h + 0.5, (sky[2] + sky[4]) / 2)
		part(
			model,
			"Skylight",
			Vector3.new(w, 0.3, d),
			CFrame.new(mid),
			Color3.fromRGB(150, 170, 190),
			material("Glass"),
			{
				transparency = 0.55,
				castShadow = false,
			}
		)
		for i = 1, 3 do
			decor(
				model,
				"SkylightBar",
				Vector3.new(0.5, 0.6, d),
				CFrame.new(mid + Vector3.new(-w / 2 + i * w / 4, -0.1, 0)),
				DARK_STEEL,
				material("Metal")
			)
		end
		decor(
			model,
			"SkylightBar",
			Vector3.new(w, 0.6, 0.5),
			CFrame.new(mid + Vector3.new(0, -0.1, 0)),
			DARK_STEEL,
			material("Metal")
		)
	else
		slab(x0, z0, x1, z1)
	end
end

-- Which way is into room `a` from a door's line.
local function frontOf(door): Vector3
	local room = Mall.Rooms[door.a]
	for _, side in MallLayout.sides(room.rect) do
		if side.runs == door.runs and math.abs(side.at - door.at) < 1e-3 then
			return door.runs == "x" and Vector3.new(0, 0, side.inward) or Vector3.new(side.inward, 0, 0)
		end
	end
	return Vector3.new(0, 0, 1)
end

-- A frame in the door's opening, its X along the opening and its front into room `a`.
local function doorFrame(origin: Vector3, door, out: number, y: number): CFrame
	local x, z = MallLayout.doorCentre(door)
	local front = frontOf(door)
	local p = origin + Vector3.new(x, y, z) + front * out
	return CFrame.lookAt(p, p + front)
end

-- See-through bars over an opening, with one hidden blocker to walk into.
local function bars(folder: Instance, cf: CFrame, width: number, height: number, step: number, thick: number, color)
	local n = math.floor(width / step)
	for i = 1, n - 1 do
		decor(
			folder,
			"GrilleBar",
			Vector3.new(thick, height, thick),
			cf * CFrame.new(-width / 2 + i * step, 0, 0),
			color,
			material("Metal")
		)
	end
	local rails = math.max(2, math.floor(height / 3))
	for i = 0, rails do
		decor(
			folder,
			"GrilleRail",
			Vector3.new(width, thick * 1.4, thick * 1.4),
			cf * CFrame.new(0, -height / 2 + i * height / rails, 0),
			color,
			material("Metal")
		)
	end
	part(folder, "GrilleBlock", Vector3.new(width, height, 0.4), cf, color, material("Metal"), {
		transparency = 1,
		castShadow = false,
	})
end

local function buildDoor(folder: Instance, origin: Vector3, door)
	local width = door.to - door.from
	local h = door.height
	local t = Mall.Wall
	local model = Instance.new("Folder")
	model.Name = "Door_" .. (door.b or door.kind)
	model.Parent = folder
	if door.grille == "rolled" then
		-- Rolled up: its box over the opening, on the front.
		decor(
			model,
			"GrilleBox",
			Vector3.new(width + 1, 1.4, 1.4),
			doorFrame(origin, door, t + 0.7, h + 0.7),
			STEEL,
			material("Metal")
		)
	elseif door.grille == "down" then
		bars(model, doorFrame(origin, door, 0.5, h / 2), width, h, 0.9, 0.16, STEEL)
		decor(
			model,
			"GrilleBox",
			Vector3.new(width + 1, 1.4, 1.4),
			doorFrame(origin, door, t + 0.7, h + 0.7),
			STEEL,
			material("Metal")
		)
	elseif door.grille == "giant" then
		-- The hall's shutter: tall, heavy, padlocked at the floor.
		bars(model, doorFrame(origin, door, 0.5, h / 2), width, h, 1.2, 0.32, DARK_STEEL)
		decor(
			model,
			"ShutterFoot",
			Vector3.new(width, 0.8, 0.8),
			doorFrame(origin, door, 0.5, 0.4),
			DARK_STEEL,
			material("Metal")
		)
		decor(
			model,
			"Padlock",
			Vector3.new(1.2, 1.6, 0.8),
			doorFrame(origin, door, 1.1, 1),
			Color3.fromRGB(150, 130, 70),
			material("Metal")
		)
	end
	if door.fill == "glass" then
		local cf = doorFrame(origin, door, 0, h / 2)
		part(model, "DoorGlass", Vector3.new(width, h, 0.3), cf, Color3.fromRGB(120, 140, 150), material("Glass"), {
			transparency = 0.6,
			castShadow = false,
		})
		for i = 0, 4 do
			decor(
				model,
				"DoorFrame",
				Vector3.new(0.5, h, 0.5),
				cf * CFrame.new(-width / 2 + i * width / 4, 0, 0),
				DARK_STEEL,
				material("Metal")
			)
		end
		decor(
			model,
			"DoorRail",
			Vector3.new(width, 0.5, 0.5),
			cf * CFrame.new(0, h / 2 - 0.25, 0),
			DARK_STEEL,
			material("Metal")
		)
		decor(
			model,
			"Chain",
			Vector3.new(2.6, 0.5, 0.7),
			doorFrame(origin, door, 0.5, h * 0.42),
			Color3.fromRGB(90, 90, 92),
			material("Metal")
		)
	elseif door.fill == "shutter" then
		local cf = doorFrame(origin, door, 0.5, h / 2)
		part(model, "Shutter", Vector3.new(width, h, 0.4), cf, Color3.fromRGB(104, 104, 100), material("Metal"))
		for i = 1, math.floor(h) - 1 do
			decor(
				model,
				"ShutterRib",
				Vector3.new(width, 0.12, 0.2),
				cf * CFrame.new(0, -h / 2 + i, -0.25),
				Color3.fromRGB(80, 80, 78),
				material("Metal")
			)
		end
	end
end

local function buildSign(folder: Instance, origin: Vector3, sign)
	local cf = facing(origin, sign.x, sign.y, sign.z, sign.face)
	local color = rgb(sign.color)
	local panel = part(
		folder,
		"Sign",
		Vector3.new(sign.w, sign.h, 0.2),
		cf,
		Color3.fromRGB(28, 26, 24),
		material("SmoothPlastic"),
		{
			collide = false,
			query = false,
			castShadow = false,
			transparency = sign.glow and 1 or 0,
		}
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = sign.glow and 0 or 0.6
	-- The canvas follows the panel's size (the default fixed 800 x 600 canvas
	-- squashed the words into a thin line).
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = panel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = sign.text
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = color:Lerp(Color3.new(0, 0, 0), 0.5)
	label.TextStrokeTransparency = sign.glow and 0.4 or 1
	local ok, font = pcall(function()
		return (Enum.Font :: any)[sign.font or "SourceSansBold"]
	end)
	label.Font = ok and font or Enum.Font.SourceSansBold
	label.Parent = gui
	if sign.glow then
		local glow = Config.Mall.Lights.sign
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = glow.range
		light.Brightness = glow.brightness
		light.Shadows = false
		local holder = decor(
			folder,
			"SignGlow",
			Vector3.new(0.2, 0.2, 0.2),
			cf * CFrame.new(0, 0, -1.5),
			color,
			material("SmoothPlastic")
		)
		holder.Transparency = 1
		light.Parent = holder
	end
end

local function buildLight(folder: Instance, origin: Vector3, l)
	local look = Config.Mall.Lights[l.kind] or Config.Mall.Lights.warm
	local color = rgb(look.color)
	local at = origin + Vector3.new(l.x, l.y, l.z)
	local holder
	if l.kind == "strip" then
		holder = decor(folder, "Fixture", Vector3.new(8, 0.3, 1), CFrame.new(at), color, material("Neon"))
	elseif l.fixture then
		holder = decor(folder, "Fixture", Vector3.new(3, 0.3, 3), CFrame.new(at), color, material("Neon"))
	elseif l.cord then
		holder = decor(folder, "Pendant", Vector3.new(2.6, 2.6, 2.6), CFrame.new(at), color, material("Neon"))
		holder.Shape = Enum.PartType.Ball
		decor(
			folder,
			"PendantCord",
			Vector3.new(0.15, l.cord - l.y, 0.15),
			CFrame.new(at + Vector3.new(0, (l.cord - l.y) / 2, 0)),
			DARK_STEEL,
			material("Metal")
		)
	else
		holder = decor(folder, "Light", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at), color, material("SmoothPlastic"))
		holder.Transparency = 1
	end
	local light
	if l.kind == "moon" then
		light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Angle = look.angle or 60
	else
		light = Instance.new("PointLight")
	end
	light.Color = color
	light.Range = look.range
	light.Brightness = look.brightness
	light.Shadows = l.shadows == true
	light.Parent = holder
end

local function buildBlock(folder: Instance, origin: Vector3, b)
	local cf = CFrame.new(origin + Vector3.new(b.x, b.y, b.z))
	if b.shape == "Cylinder" then
		cf *= CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is its X: stood upright
	end
	local p =
		part(folder, b.name, Vector3.new(b.size[1], b.size[2], b.size[3]), cf, rgb(b.color), material(b.material), {
			collide = b.collide ~= false,
			transparency = b.transparency,
		})
	if b.shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
end

-- Builds the mall into `parent`, from `origin` (the court's floor middle).
-- only: the rooms to build (a run server's waiting room), or nil for all.
-- Returns where players spawn and come back, and the contract table's spot.
function MallBuilder.build(parent: Instance, origin: Vector3, only: { string }?)
	local built = {}
	for id in Mall.Rooms do
		built[id] = only == nil or table.find(only, id) ~= nil
	end
	local rooms = Instance.new("Folder")
	rooms.Name = "Rooms"
	rooms.Parent = parent
	for id, yes in built do
		if yes then
			buildRoom(rooms, origin, id, built)
		end
	end
	local doors = Instance.new("Folder")
	doors.Name = "Doors"
	doors.Parent = parent
	for _, door in Mall.Doors do
		if built[door.a] and (door.b == nil or built[door.b]) then
			buildDoor(doors, origin, door)
		end
	end
	local dressing = Instance.new("Folder")
	dressing.Name = "Dressing"
	dressing.Parent = parent
	for _, sign in Mall.Signs do
		if built[sign.room] then
			buildSign(dressing, origin, sign)
		end
	end
	for _, l in Mall.Lights do
		if built[l.room] then
			buildLight(dressing, origin, l)
		end
	end
	for _, b in Mall.Blocks do
		if built[b.room] then
			buildBlock(dressing, origin, b)
		end
	end
	local spawn = only and Mall.Waiting.spawn or Mall.Spawn
	local returns = {}
	if built[Mall.Returns.room] then
		for _, spot in Mall.Returns.spots do
			table.insert(returns, facing(origin, spot.x, 3, spot.z, Mall.Returns.face))
		end
	else
		table.insert(returns, facing(origin, spawn.x, 3, spawn.z, spawn.face))
	end
	local contract = Mall.Contract
	return {
		spawn = facing(origin, spawn.x, 0, spawn.z, spawn.face),
		returns = returns,
		contract = built[contract.room] and facing(origin, contract.x, 0, contract.z, contract.face) or nil,
	}
end

return MallBuilder
