-- Builds the lobby's mall from Data/Mall (docs/plans/lobby-rework.md, LB1a:
-- the grey box, walked and judged before anything is modelled). Rooms are
-- floors, walls cut by their doors (Logic/MallLayout) and ceilings; doors
-- get their grilles, glass or shutters; then the signs, the lights, the
-- stand-in blocks, and the story the investigators left: the generator's
-- cables over the floor, strings of bulbs, the old ad lightboxes they
-- powered again. A run server builds only the waiting room (Mall.Waiting),
-- with doors to rooms it doesn't build walled up. Once the kit's meshes are
-- in (LB1b, kit.py mall1), what has a modelled piece wears it over its
-- grey box.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Kit = require(Shared.World.Kit)
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

-- A frame at a floor-plan point, its front (-Z) looking `face`; "UP" lies
-- on the floor face up, reading from the south.
local function facing(origin: Vector3, x: number, y: number, z: number, face: string): CFrame
	local p = origin + Vector3.new(x, y, z)
	if face == "UP" then
		return CFrame.lookAt(p, p + Vector3.yAxis, Vector3.new(0, 0, -1))
	end
	return CFrame.lookAt(p, p + FACES[face])
end

local function v3(t): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

-- Degrees about X, Y and Z, for a block that tips, lies over or turns.
local function turned(rot): CFrame
	if not rot then
		return CFrame.identity
	end
	return CFrame.Angles(math.rad(rot[1] or 0), math.rad(rot[2] or 0), math.rad(rot[3] or 0))
end

local function decor(folder: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material)
	return part(folder, name, size, cf, color, mat, { collide = false, query = false, castShadow = false })
end

-- The kit's look for the mall (LB1b; Data/Kit `Parts`, World/Kit): what to
-- dress once the meshes are in (MallBuilder.build runs these after
-- Kit.preload). The grey box stands until then, and wherever a piece isn't
-- imported yet (Kit.place and Kit.dressPart give nil).
local jobs: { () -> () } = {}
local function later(job: () -> ())
	table.insert(jobs, job)
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
	end
	-- A flat skylight in the hole, unless a vault (Mall.Vaults) rises over it.
	if sky and not room.vault then
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
	elseif not sky then
		slab(x0, z0, x1, z1)
	end
end

-- A floor above, round a room's open middle (the court's void, the dead
-- mall's): its slab along each of `sides`, a parapet with a handrail on the
-- edge over the void, and the columns that hold it. Out of reach: the
-- investigators only use the ground floor.
local function buildGallery(folder: Instance, origin: Vector3, g)
	local room = Mall.Rooms[g.room]
	local x0, z0, x1, z1 = room.rect[1], room.rect[2], room.rect[3], room.rect[4]
	local t = Mall.Wall
	local d = g.depth
	local has = {}
	for _, side in g.sides do
		has[side] = true
	end
	-- The void's edges.
	local vx0 = has.W and x0 + t + d or x0 + t
	local vx1 = has.E and x1 - t - d or x1 - t
	local vz0 = has.N and z0 + t + d or z0 + t
	local vz1 = has.S and z1 - t - d or z1 - t
	local model = Instance.new("Folder")
	model.Name = "Gallery_" .. g.room
	model.Parent = folder
	local color = rgb(g.color or (room.wall and room.wall.color) or { 200, 200, 200 })
	local y = g.level
	local function slab(ax0: number, az0: number, ax1: number, az1: number)
		part(
			model,
			"GalleryFloor",
			Vector3.new(ax1 - ax0, 1.2, az1 - az0),
			CFrame.new(origin + Vector3.new((ax0 + ax1) / 2, y - 0.6, (az0 + az1) / 2)),
			color,
			material("SmoothPlastic")
		)
	end
	-- `void`: which way the open middle is from this edge.
	local function parapet(ax0: number, az0: number, ax1: number, az1: number, void: Vector3)
		local centre = origin + Vector3.new((ax0 + ax1) / 2, y + g.parapet / 2, (az0 + az1) / 2)
		local size = Vector3.new(math.max(ax1 - ax0, 0.6), g.parapet, math.max(az1 - az0, 0.6))
		local wall = part(model, "Parapet", size, CFrame.new(centre), color, material("SmoothPlastic"))
		local rail = decor(
			model,
			"Handrail",
			Vector3.new(size.X + 0.1, 0.3, size.Z + 0.1),
			CFrame.new(centre + Vector3.new(0, g.parapet / 2 + 0.15, 0)),
			STEEL,
			material("Metal")
		)
		-- The kit's edge in lengths of about its own (each from the slab's
		-- underside to the rail's top), stretched to fit the run.
		later(function()
			local along = size.X > size.Z and Vector3.xAxis or Vector3.zAxis
			local length = math.max(size.X, size.Z)
			local count = math.max(1, math.round(length / 10))
			local piece = length / count
			local height = g.parapet + 1.5
			local mid = Vector3.new(centre.X, y - 1.2 + height / 2, centre.Z)
			local placed = false
			for i = 1, count do
				local at = mid + along * (-length / 2 + (i - 0.5) * piece)
				if
					Kit.place(model, "GalleryParapet", CFrame.lookAt(at, at - void), Vector3.new(piece, height, 0.74))
				then
					placed = true
				end
			end
			if placed then
				Kit.hide(wall)
				Kit.hide(rail)
			end
		end)
	end
	if has.N then
		slab(x0 + t, z0 + t, x1 - t, vz0)
		parapet(vx0, vz0 - 0.6, vx1, vz0, Vector3.zAxis)
	end
	if has.S then
		slab(x0 + t, vz1, x1 - t, z1 - t)
		parapet(vx0, vz1, vx1, vz1 + 0.6, -Vector3.zAxis)
	end
	if has.W then
		slab(x0 + t, vz0, vx0, vz1)
		parapet(vx0 - 0.6, vz0, vx0, vz1, Vector3.xAxis)
	end
	if has.E then
		slab(vx1, vz0, x1 - t, vz1)
		parapet(vx1, vz0, vx1 + 0.6, vz1, -Vector3.xAxis)
	end
	for _, c in g.columns or {} do
		local upright = CFrame.new(origin + Vector3.new(c[1], (y - 1.2) / 2, c[2]))
		local p = part(
			model,
			"Column",
			Vector3.new(y - 1.2, 2, 2),
			upright * CFrame.Angles(0, 0, math.pi / 2),
			color,
			material("SmoothPlastic")
		)
		p.Shape = Enum.PartType.Cylinder
		later(function()
			if Kit.place(model, "MallColumn", upright) then
				Kit.hide(p)
			end
		end)
	end
end

-- A glass barrel vault over a void: a half-ellipse across z, from `spring`
-- up `rise` at the middle, glass bands between steel ribs, its two ends
-- closed by stepped gables.
local function buildVault(folder: Instance, origin: Vector3, v)
	local model = Instance.new("Folder")
	model.Name = "Vault_" .. v.room
	model.Parent = folder
	local cz = (v.z0 + v.z1) / 2
	local r = (v.z1 - v.z0) / 2
	local n = v.segments or 10
	local points = {}
	for i = 0, n do
		local a = math.pi * i / n
		table.insert(points, Vector3.new(0, v.spring + v.rise * math.sin(a), cz - r * math.cos(a)))
	end
	local length = v.x1 - v.x0
	local midX = (v.x0 + v.x1) / 2
	-- A frame on the arc between two points: X along the vault, Z along the arc.
	local function arcFrame(x: number, p: Vector3, q: Vector3): (CFrame, number)
		local dir = (q - p)
		local seg = dir.Magnitude
		dir = dir.Unit
		local up = Vector3.new(0, dir.Z, -dir.Y)
		local centre = origin + Vector3.new(x, (p.Y + q.Y) / 2, (p.Z + q.Z) / 2)
		return CFrame.fromMatrix(centre, Vector3.xAxis, up), seg
	end
	for i = 1, n do
		local cf, seg = arcFrame(midX, points[i], points[i + 1])
		part(
			model,
			"VaultGlass",
			Vector3.new(length, 0.3, seg + 0.1),
			cf,
			Color3.fromRGB(120, 140, 160),
			material("Glass"),
			{
				transparency = 0.6,
				castShadow = false,
			}
		)
	end
	local ribs = v.ribs or 8
	for k = 0, ribs - 1 do
		local x = v.x0 + length * k / (ribs - 1)
		local segments = {}
		for i = 1, n do
			local cf, seg = arcFrame(x, points[i], points[i + 1])
			table.insert(
				segments,
				decor(
					model,
					"VaultRib",
					Vector3.new(0.5, 0.7, seg + 0.3),
					cf * CFrame.new(0, -0.3, 0),
					DARK_STEEL,
					material("Metal")
				)
			)
		end
		-- The kit's lattice rib in place of the grey box's segments.
		if v.kit then
			later(function()
				if Kit.place(model, v.kit.rib, CFrame.new(origin + Vector3.new(x, v.spring, cz))) then
					for _, p in segments do
						Kit.hide(p)
					end
				end
			end)
		end
	end
	local wall = rgb(v.gable or { 170, 164, 152 })
	for e, x in { v.x0, v.x1 } do
		local steps = 4
		local gable = {}
		for j = 1, steps do
			local low = v.rise * (j - 1) / steps
			local halfWidth = r * math.sqrt(math.max(0, 1 - (low / v.rise) ^ 2))
			table.insert(
				gable,
				part(
					model,
					"Gable",
					Vector3.new(1, v.rise / steps, halfWidth * 2),
					CFrame.new(origin + Vector3.new(x, v.spring + low + v.rise / steps / 2, cz)),
					wall,
					material("SmoothPlastic")
				)
			)
		end
		-- The kit's lunette, its front into the vault, for the stepped ends.
		if v.kit then
			later(function()
				local turn = CFrame.Angles(0, math.rad(e == 1 and 90 or -90), 0)
				if Kit.place(model, v.kit.gable, CFrame.new(origin + Vector3.new(x, v.spring, cz)) * turn) then
					for _, p in gable do
						Kit.hide(p)
					end
				end
			end)
		end
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

-- A roll-up shutter's kit piece (mall3), stretched to its opening, in place
-- of the grey box's sheet and ribs (the sheet stays solid: it's the wall).
-- `cf` as doorFrame's: its -Z toward whoever looks at it.
local function dressShutter(parent: Instance, cf: CFrame, width: number, height: number, sheet: BasePart, ribs)
	later(function()
		if Kit.place(parent, "RollUpShutter", cf, Vector3.new(width, height, 0.58)) then
			Kit.hide(sheet)
			for _, rib in ribs do
				Kit.hide(rib)
			end
		end
	end)
end

local function buildDoor(folder: Instance, origin: Vector3, door)
	local width = door.to - door.from
	local h = door.height
	local t = Mall.Wall
	local model = Instance.new("Folder")
	model.Name = "Door_" .. (door.b or door.kind)
	model.Parent = folder
	if door.grille == "rolled" or door.grille == "down" then
		if door.grille == "down" then
			bars(model, doorFrame(origin, door, 0.5, h / 2), width, h, 0.9, 0.16, STEEL)
		end
		-- Its box over the opening, on the front (rolled up in it, or down).
		local box = decor(
			model,
			"GrilleBox",
			Vector3.new(width + 1, 1.4, 1.4),
			doorFrame(origin, door, t + 0.7, h + 0.7),
			STEEL,
			material("Metal")
		)
		later(function()
			Kit.dressPart(box, "GrilleBox")
		end)
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
		local shutter =
			part(model, "Shutter", Vector3.new(width, h, 0.4), cf, Color3.fromRGB(104, 104, 100), material("Metal"))
		local ribs = {}
		for i = 1, math.floor(h) - 1 do
			table.insert(
				ribs,
				decor(
					model,
					"ShutterRib",
					Vector3.new(width, 0.12, 0.2),
					cf * CFrame.new(0, -h / 2 + i, -0.25),
					Color3.fromRGB(80, 80, 78),
					material("Metal")
				)
			)
		end
		dressShutter(model, cf, width, h, shutter, ribs)
	end
end

-- An upper floor's shopfront on a room's wall, above the gallery: dead, its
-- shutter down, or a grille with the dark shop behind it.
local function buildUpperFront(folder: Instance, origin: Vector3, f)
	local room = Mall.Rooms[f.room]
	local x0, z0, x1, z1 = room.rect[1], room.rect[2], room.rect[3], room.rect[4]
	local t = Mall.Wall
	local face, inward
	if f.side == "N" then
		face, inward = Vector3.new(0, 0, z0 + t), Vector3.new(0, 0, 1)
	elseif f.side == "S" then
		face, inward = Vector3.new(0, 0, z1 - t), Vector3.new(0, 0, -1)
	elseif f.side == "W" then
		face, inward = Vector3.new(x0 + t, 0, 0), Vector3.new(1, 0, 0)
	else
		face, inward = Vector3.new(x1 - t, 0, 0), Vector3.new(-1, 0, 0)
	end
	local w = f.to - f.from
	local mid = (f.from + f.to) / 2
	local along = (f.side == "N" or f.side == "S") and Vector3.new(mid, 0, 0) or Vector3.new(0, 0, mid)
	local pos = origin + face + along + Vector3.new(0, f.level + f.height / 2, 0) + inward * 0.25
	local cf = CFrame.lookAt(pos, pos + inward)
	if f.kind == "grille" then
		part(
			folder,
			"UpperShopDark",
			Vector3.new(w, f.height, 0.2),
			cf * CFrame.new(0, 0, 0.15),
			Color3.fromRGB(12, 12, 14),
			material("SmoothPlastic")
		)
		bars(folder, cf * CFrame.new(0, 0, -0.15), w, f.height, 0.9, 0.16, STEEL)
	else
		local shutter = part(
			folder,
			"UpperShutter",
			Vector3.new(w, f.height, 0.4),
			cf,
			Color3.fromRGB(96, 96, 92),
			material("Metal")
		)
		local ribs = {}
		for i = 1, math.floor(f.height) - 1 do
			table.insert(
				ribs,
				decor(
					folder,
					"ShutterRib",
					Vector3.new(w, 0.12, 0.2),
					cf * CFrame.new(0, -f.height / 2 + i, -0.25),
					Color3.fromRGB(74, 74, 72),
					material("Metal")
				)
			)
		end
		dressShutter(folder, cf, w, f.height, shutter, ribs)
	end
	-- The bulkhead over it, where its sign was.
	decor(
		folder,
		"UpperBulkhead",
		Vector3.new(w + 2, 2.4, 0.6),
		cf * CFrame.new(0, f.height / 2 + 1.2, -0.1),
		Color3.fromRGB(58, 54, 50),
		material("SmoothPlastic")
	)
end

local function buildSign(folder: Instance, origin: Vector3, sign)
	local cf = facing(origin, sign.x, sign.y, sign.z, sign.face)
	if sign.tilt then
		cf *= CFrame.Angles(0, 0, math.rad(sign.tilt)) -- hung or taped up crooked
	end
	local color = rgb(sign.color)
	-- A neon sign is only its letters; a board, a slip of card or tape on
	-- the floor shows its `panel` colour (dark by default).
	local panelColor = sign.panel and rgb(sign.panel) or Color3.fromRGB(28, 26, 24)
	local panel = part(
		folder,
		"Sign",
		Vector3.new(sign.w, sign.h, sign.face == "UP" and 0.04 or 0.2),
		cf,
		panelColor,
		material(sign.material or "SmoothPlastic"),
		{
			collide = false,
			query = false,
			castShadow = false,
			transparency = (sign.glow and not sign.panel) and 1 or (sign.see or 0),
		}
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = sign.glow and 0 or 1
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
		-- Neon on the generator browns out with it; a `battery` sign (the
		-- dead mall's EXIT) doesn't.
		if not sign.battery then
			CollectionService:AddTag(label, Constants.Tags.MallPower)
			CollectionService:AddTag(light, Constants.Tags.MallPower)
		end
	end
	if sign.neon then
		-- Its tubes from the kit (mall3), drawn Neon in its colour (no maps:
		-- the glass is the light), on their raceway; then the text goes.
		later(function()
			local tubes = Kit.place(folder, sign.neon, cf)
			if not tubes then
				return
			end
			for _, look in tubes:GetChildren() do
				if look:IsA("SurfaceAppearance") then
					look:Destroy()
				end
			end
			tubes.Material = Enum.Material.Neon
			tubes.Color = color
			tubes.CastShadow = false
			if not sign.battery then
				CollectionService:AddTag(tubes, Constants.Tags.MallPower)
			end
			-- The raceway under the word, the letters standing up from it (behind
			-- them it read as a line struck through them).
			local under = cf:PointToObjectSpace(tubes.Position).Y - tubes.Size.Y / 2 - 0.4
			Kit.place(folder, "SignRaceway", cf * CFrame.new(0, under, 0), Vector3.new(tubes.Size.X * 0.9, 0.7, 0.58))
			gui.Enabled = false
		end)
	end
end

local function buildLight(folder: Instance, origin: Vector3, l)
	local look = Config.Mall.Lights[l.kind] or Config.Mall.Lights.warm
	local color = rgb(look.color)
	local at = origin + Vector3.new(l.x, l.y, l.z)
	if l.off then
		-- The mall's own lamps: dead since it closed; only the generator's
		-- circuits are lit.
		local dead = Color3.fromRGB(64, 60, 56)
		if l.cord then
			local globe = decor(folder, "Pendant", Vector3.new(2.6, 2.6, 2.6), CFrame.new(at), dead, material("Glass"))
			globe.Shape = Enum.PartType.Ball
			decor(
				folder,
				"PendantCord",
				Vector3.new(0.15, l.cord - l.y, 0.15),
				CFrame.new(at + Vector3.new(0, (l.cord - l.y) / 2, 0)),
				DARK_STEEL,
				material("Metal")
			)
		else
			local size = l.kind == "strip" and Vector3.new(8, 0.3, 1) or Vector3.new(3, 0.3, 3)
			local fixture = decor(folder, "Fixture", size, CFrame.new(at), dead, material("Glass"))
			if l.kind == "strip" then
				-- The kit's strip light, its tubes grey (mall3).
				later(function()
					if Kit.place(folder, "StripFixture", CFrame.new(at)) then
						Kit.hide(fixture)
					end
				end)
			end
		end
		return
	end
	local holder
	if l.stand then
		-- A work lamp on a pole, its head turned down a little.
		local pole = decor(
			folder,
			"LampStand",
			Vector3.new(0.25, l.y - 0.5, 0.25),
			CFrame.new(at - Vector3.new(0, (l.y + 0.5) / 2, 0)),
			DARK_STEEL,
			material("Metal")
		)
		local aim = CFrame.Angles(0, math.rad(l.aim or 0), 0)
		holder = decor(
			folder,
			"WorkLamp",
			Vector3.new(1.2, 0.9, 1.2),
			CFrame.new(at) * aim * CFrame.Angles(math.rad(-20), 0, 0),
			color,
			material("Neon")
		)
		-- The kit's tripod and housing round the lit head (mall3, modelled
		-- with its head 7 up, as the work lamps hang).
		later(function()
			if Kit.place(folder, "WorkLamp", CFrame.new(at - Vector3.new(0, l.y, 0)) * aim) then
				Kit.hide(pole)
			end
		end)
	elseif l.kind == "strip" then
		holder = decor(folder, "Fixture", Vector3.new(8, 0.3, 1), CFrame.new(at), color, material("Neon"))
		-- The kit's strip light round it; the lit part becomes its two tubes'
		-- glow, under the channel (mall3).
		local lit = holder
		later(function()
			if Kit.place(folder, "StripFixture", CFrame.new(at)) then
				lit.Size = Vector3.new(7.3, 0.14, 0.55)
				lit.CFrame = CFrame.new(at - Vector3.new(0, 0.15, 0))
			end
		end)
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
		local cf = l.face and facing(origin, l.x, l.y, l.z, l.face) or CFrame.new(at)
		holder = decor(folder, "Light", Vector3.new(0.2, 0.2, 0.2), cf, color, material("SmoothPlastic"))
		holder.Transparency = 1
	end
	local light
	if l.kind == "moon" or l.kind == "storm" then
		light = Instance.new("SpotLight")
		light.Face = l.kind == "moon" and Enum.NormalId.Bottom or Enum.NormalId.Front
		light.Angle = look.angle or 60
		-- Lightning burns these for an instant (Controllers/WeatherController's
		-- flash, as the house's moon beams).
		CollectionService:AddTag(holder, "ConsensusMoonLight")
	else
		light = Instance.new("PointLight")
	end
	light.Color = color
	light.Range = look.range
	light.Brightness = look.brightness
	light.Shadows = l.shadows == true
	light.Parent = holder
	if not Config.Mall.Unpowered[l.kind] then
		-- On the investigators' generator: it browns out with it.
		CollectionService:AddTag(light, Constants.Tags.MallPower)
		if holder.Material == Enum.Material.Neon then
			CollectionService:AddTag(holder, Constants.Tags.MallPower)
		end
	end
end

-- A drained basin in the kit (`b.hollow`, the fountain): the block stops
-- colliding, an unseen floor and a ring of wall stand in for it so you can
-- step down into it, and the loose bits on its old top (coins, leaves)
-- settle on the floor.
local function hollowOut(p: BasePart, frame: CFrame, b)
	local height, radius = b.size[1], b.size[2] / 2
	local bottom, floor, wall = -height / 2, b.hollow.floor, b.hollow.wall
	p.CanCollide = false
	p.CanQuery = false
	local hidden = { transparency = 1, castShadow = false }
	local base = part(
		p.Parent,
		b.name .. "Floor",
		Vector3.new(floor - bottom, radius * 2, radius * 2),
		frame * CFrame.new(0, (bottom + floor) / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		p.Color,
		p.Material,
		hidden
	)
	base.Shape = Enum.PartType.Cylinder
	local n = 16
	for i = 0, n - 1 do
		part(
			p.Parent,
			b.name .. "Wall",
			Vector3.new(wall, height, 2 * math.pi * radius / n + 0.3),
			frame * CFrame.Angles(0, 2 * math.pi * i / n, 0) * CFrame.new(radius - wall / 2, 0, 0),
			p.Color,
			p.Material,
			hidden
		)
	end
	for _, other in p.Parent:GetChildren() do
		if other:IsA("BasePart") and other ~= p and not other.CanCollide and not other:GetAttribute("Kit") then
			local at = frame:PointToObjectSpace(other.Position)
			if Vector2.new(at.X, at.Z).Magnitude < radius - wall and at.Y > floor and at.Y < height / 2 + 0.2 then
				other.CFrame -= frame.UpVector * (at.Y - floor - 0.03)
			end
		end
	end
end

local function buildBlock(folder: Instance, origin: Vector3, b): BasePart
	local frame = CFrame.new(origin + Vector3.new(b.x, b.y, b.z)) * turned(b.rot)
	local cf = frame
	if b.shape == "Cylinder" then
		cf *= CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is its X: stood upright
	end
	local p =
		part(folder, b.name, Vector3.new(b.size[1], b.size[2], b.size[3]), cf, rgb(b.color), material(b.material), {
			collide = b.collide ~= false,
			query = b.collide ~= false,
			castShadow = b.shadow ~= false,
			transparency = b.transparency,
		})
	if b.shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	elseif b.shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	end
	if b.kit then
		-- Its kit piece stands upright where it stands (a cylinder's own
		-- turn left out), as big as its block (a stretched one).
		local size = b.shape == "Cylinder" and Vector3.new(b.size[2], b.size[1], b.size[3]) or v3(b.size)
		later(function()
			if p.Parent and Kit.place(p.Parent, b.kit, frame, size) then
				Kit.hide(p)
				if b.hollow then
					hollowOut(p, frame, b)
				end
			end
		end)
	end
	return p
end

-- A run of cable over the floor (and up a wall): a strand between each
-- pair of points, a scrap of tape over it every few studs on the floor.
local function buildCable(folder: Instance, origin: Vector3, cable)
	local color = rgb(cable.color or { 230, 120, 30 })
	local thick = cable.thick or 0.32
	local tape = Color3.fromRGB(70, 70, 72)
	for i = 1, #cable.points - 1 do
		local a = origin + v3(cable.points[i])
		local b = origin + v3(cable.points[i + 1])
		local length = (b - a).Magnitude
		if length > 0.01 then
			local cf = CFrame.lookAt((a + b) / 2, b)
			decor(folder, "Cable", Vector3.new(thick, thick, length + thick), cf, color, material("SmoothPlastic"))
			if math.abs(a.Y - b.Y) < 0.05 and a.Y - origin.Y < 0.6 then
				for s = 3, length - 1, 7 do
					decor(
						folder,
						"Tape",
						Vector3.new(1.1, thick + 0.06, 0.5),
						cf * CFrame.new(0, 0, length / 2 - s),
						tape,
						material("Fabric")
					)
				end
			end
		end
	end
end

-- A string of bulbs slung between two points, sagging in the middle;
-- every `lit`-th bulb casts light (Config.Mall.Lights.bulb), the rest only glow.
local function buildString(folder: Instance, origin: Vector3, s)
	local a, b = origin + v3(s.from), origin + v3(s.to)
	local look = Config.Mall.Lights.bulb
	local color = rgb(look.color)
	local n = s.bulbs or 12
	local last = a
	for i = 0, n do
		local t = i / n
		local p = a:Lerp(b, t) - Vector3.new(0, (s.sag or 2) * 4 * t * (1 - t), 0)
		if i > 0 then
			decor(
				folder,
				"BulbWire",
				Vector3.new(0.08, 0.08, (p - last).Magnitude),
				CFrame.lookAt((p + last) / 2, p),
				DARK_STEEL,
				material("SmoothPlastic")
			)
		end
		last = p
		if i > 0 and i < n then
			local bulb = decor(
				folder,
				"Bulb",
				Vector3.new(0.45, 0.45, 0.45),
				CFrame.new(p - Vector3.new(0, 0.3, 0)),
				color,
				material("Neon")
			)
			bulb.Shape = Enum.PartType.Ball
			CollectionService:AddTag(bulb, Constants.Tags.MallPower)
			if i % (s.lit or 4) == 0 then
				local light = Instance.new("PointLight")
				light.Color = color
				light.Range = look.range
				light.Brightness = look.brightness
				light.Shadows = false
				light.Parent = bulb
				CollectionService:AddTag(light, Constants.Tags.MallPower)
			end
		end
	end
end

-- One of the mall's old backlit lightboxes, back on the generator: where
-- Roblox's immersive ads go (docs/plans/lobby-rework.md, "Immersive ads";
-- a billboard is 8 x 4.5 to 32 x 18 studs, nothing in front of it). LB6
-- puts the AdGui on its face; until then it shows a plain placeholder.
local function buildAd(folder: Instance, origin: Vector3, ad)
	local cf = facing(origin, ad.x, ad.y, ad.z, ad.face)
	local look = Config.Mall.Lights.ad
	local frame = decor(
		folder,
		"AdFrame",
		Vector3.new(ad.w + 0.6, ad.h + 0.6, 0.6),
		cf * CFrame.new(0, 0, 0.3),
		DARK_STEEL,
		material("Metal")
	)
	if ad.kit then
		-- Its poster case: a bezel round the face, never over it.
		later(function()
			Kit.dressPart(frame, ad.kit)
		end)
	end
	-- Not Neon: its bloom washes a face out to plain white. The glow is the
	-- SurfaceGui's own, unlit and a little bright, so whatever is on the
	-- face stays readable.
	local face = part(
		folder,
		"AdFace",
		Vector3.new(ad.w, ad.h, 0.1),
		cf * CFrame.new(0, 0, -0.05),
		rgb(look.color),
		material("SmoothPlastic"),
		{
			collide = false,
			castShadow = false,
		}
	)
	face:SetAttribute("AdSlot", ad.slot or true)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Placeholder"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = look.face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = face
	-- Until an ad runs, what an empty lightbox in a dead mall says: the
	-- diffuser yellowed with age, brightest where its tubes are.
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local tubes = Instance.new("UIGradient")
	tubes.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(196, 182, 150)),
		ColorSequenceKeypoint.new(0.3, Color3.fromRGB(236, 226, 200)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(236, 226, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 182, 150)),
	})
	tubes.Parent = panel
	local ink = Color3.fromRGB(74, 58, 42)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.84, 0.44)
	label.Position = UDim2.fromScale(0.08, 0.12)
	label.BackgroundTransparency = 1
	label.Text = "THIS SPACE\nAVAILABLE"
	label.TextScaled = true
	label.TextColor3 = ink
	label.Font = Enum.Font.Bodoni
	label.Parent = panel
	local rule = Instance.new("Frame")
	rule.Size = UDim2.new(0.36, 0, 0, 3)
	rule.Position = UDim2.fromScale(0.32, 0.64)
	rule.BackgroundColor3 = ink
	rule.BorderSizePixel = 0
	rule.Parent = panel
	local small = Instance.new("TextLabel")
	small.Size = UDim2.fromScale(0.8, 0.1)
	small.Position = UDim2.fromScale(0.1, 0.72)
	small.BackgroundTransparency = 1
	small.Text = "LEASING · ENQUIRE AT THE MALL OFFICE"
	small.TextScaled = true
	small.TextColor3 = ink
	small.Font = Enum.Font.SourceSansSemibold
	small.Parent = panel
	CollectionService:AddTag(gui, Constants.Tags.MallPower)
	local light = Instance.new("PointLight")
	light.Color = rgb(look.color)
	light.Range = look.range
	light.Brightness = look.brightness
	light.Shadows = false
	light.Parent = face
	CollectionService:AddTag(face, Constants.Tags.MallPower)
	CollectionService:AddTag(light, Constants.Tags.MallPower)
end

-- Where one of the mall's sounds comes from (Controllers/MallController
-- plays it: Assets.Mall's candidates, Config.Mall.Sounds).
local function buildSound(folder: Instance, origin: Vector3, s)
	local emitter = decor(
		folder,
		"MallSound",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(origin + Vector3.new(s.x, s.y, s.z)),
		DARK_STEEL,
		material("SmoothPlastic")
	)
	emitter.Transparency = 1
	emitter:SetAttribute("Role", s.role)
	CollectionService:AddTag(emitter, Constants.Tags.MallSound)
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
	-- A room's floor from the kit (`floorKit`: the diner's check, the
	-- arcade's carpet), in panels of about 10 studs stretched to fill it.
	for id, yes in built do
		local room = Mall.Rooms[id]
		if yes and room.floorKit then
			later(function()
				local t = Mall.Wall
				local x0, z0, x1, z1 = room.rect[1] + t, room.rect[2] + t, room.rect[3] - t, room.rect[4] - t
				local nx = math.max(1, math.round((x1 - x0) / 10))
				local nz = math.max(1, math.round((z1 - z0) / 10))
				local w, d = (x1 - x0) / nx, (z1 - z0) / nz
				for i = 0, nx - 1 do
					for j = 0, nz - 1 do
						local at = origin + Vector3.new(x0 + (i + 0.5) * w, 0.03, z0 + (j + 0.5) * d)
						Kit.place(rooms, room.floorKit, CFrame.new(at), Vector3.new(w, 0.05, d))
					end
				end
			end)
		end
	end
	-- The floors above and the vault: the mall's height (the owner, 2026-10-15:
	-- "it doesn't really have that encapsulating grandeur").
	for _, g in Mall.Galleries or {} do
		if built[g.room] then
			buildGallery(rooms, origin, g)
		end
	end
	for _, v in Mall.Vaults or {} do
		if built[v.room] then
			buildVault(rooms, origin, v)
		end
	end
	for _, f in Mall.UpperFronts or {} do
		if built[f.room] then
			buildUpperFront(rooms, origin, f)
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
	local blocks = {} -- room -> block name -> its parts
	for _, b in Mall.Blocks do
		if built[b.room] then
			blocks[b.room] = blocks[b.room] or {}
			blocks[b.room][b.name] = blocks[b.room][b.name] or {}
			table.insert(blocks[b.room][b.name], buildBlock(dressing, origin, b))
		end
	end
	for _, group in Mall.KitGroups or {} do
		if built[group.room] then
			later(function()
				local at = CFrame.new(origin + Vector3.new(group.x, group.y, group.z)) * turned(group.rot)
				if Kit.place(dressing, group.kit, at) then
					for _, name in group.hides do
						for _, p in blocks[group.room][name] or {} do
							Kit.hide(p)
						end
					end
				end
			end)
		end
	end
	for _, cable in Mall.Cables or {} do
		if built[cable.room] then
			buildCable(dressing, origin, cable)
		end
	end
	for _, s in Mall.Strings or {} do
		if built[s.room] then
			buildString(dressing, origin, s)
		end
	end
	for _, ad in Mall.Ads or {} do
		if built[ad.room] then
			buildAd(dressing, origin, ad)
		end
	end
	for _, s in Mall.Sounds or {} do
		if built[s.room] then
			buildSound(dressing, origin, s)
		end
	end
	-- The kit's look, once its meshes are in (they load with the house's,
	-- World/Kit.preload); until then, and for a piece not imported yet, the
	-- grey box.
	local todo = jobs
	jobs = {}
	task.spawn(function()
		Kit.preload()
		local dressed = 0
		for _, job in todo do
			local ok, err = pcall(job)
			if ok then
				dressed += 1
			else
				warn("[Consensus] mall kit: " .. tostring(err))
			end
		end
		parent:SetAttribute("KitDressed", dressed)
	end)
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
