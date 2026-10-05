-- Builds a mansion layout (Logic/MansionGen, docs/plans/mansion-generation.md)
-- into parts:
--   * rooms as rectangles over their storeys (-1 the cellar to 2 the attic;
--     docs/plans/level-design.md section 10.1), each wall broken for its
--     doorways, on each storey it stands on;
--   * the double-height grand hall: a gallery round three walls, a staircase
--     up the middle and the locked front door;
--   * dog-leg stairwells whose doorway on both floors is in the south wall;
--   * every room's contents from LevelBuilder.furnish, with its template's
--     furniture fitted to the room's size and doorways (Logic/RoomFit).
--
-- It returns the same world description LevelBuilder does, so the rest of
-- the game runs on either house. Room records add `floor`, `tall`, `rect`
-- (the layout rectangle), `walls` (for Grime) and `seamList`; `center` is a
-- clear, walkable point (in the hall it is in front of the staircase).
--
-- Stairs are walkable wedge ramps (invisible) under steps you see but can't
-- collide with, so players, The Guest and the Companion walk them smoothly.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local LevelGraph = require(Shared.Logic.LevelGraph)
local MansionHouse = require(Shared.Logic.MansionHouse)
local RoomFit = require(Shared.Logic.RoomFit)
local RoomRects = require(Shared.Logic.RoomRects)
local TallRooms = require(Shared.Logic.TallRooms)
local PropFactory = require(Shared.World.PropFactory)
local WindowView = require(Shared.Logic.WindowView)
local Dressing = require(script.Parent.Dressing)
local Grime = require(script.Parent.Grime)
local LevelBuilder = require(script.Parent.LevelBuilder)
local Trim = require(script.Parent.Trim)

local Tags = Constants.Tags
local Attr = Constants.Attributes

local MansionBuilder = {}

local M = Config.Mansion
local PITCH = M.FloorPitch
local WALL = Config.Level.WallThickness
local HEIGHT = Config.Level.WallHeight
local DOOR_W = Config.Level.DoorWidth
local DOOR_H = Config.Level.DoorHeight
local DIRS = LevelBuilder.WorldDirs
local OPPOSITE = RoomRects.Opposite
local UP = Vector3.new(0, 1, 0)
-- How far below the floor's top above a room's top wall band stops: inside
-- the slab (ceiling, then the floor over it), never level with its top, where
-- it showed through the room upstairs as a stripe (owner, 2026-10-04).
local SLAB_TUCK = 0.25

-- The hall's gallery and staircase, in the hall's own frame (40x50). The
-- numbers live in Logic/TallRooms, which the walkers' graph reads too.
local STAIR_HALF = TallRooms.Hall.StairHalf
local STAIR_FOOT = TallRooms.Hall.StairFoot
local RAIL = TallRooms.Hall.Rail

local function origin(): Vector3
	local o = Config.Level.Origin
	return Vector3.new(o.x, o.y, o.z)
end

function MansionBuilder.floorY(floor: number): number
	return origin().Y + floor * PITCH
end

local function tag(instance: Instance, name: string)
	LevelBuilder.tag(instance, name)
end

local function quiet(extra)
	local options = { collide = false, query = false, castShadow = false }
	for k, v in extra or {} do
		options[k] = v
	end
	return options
end

-- Along-the-wall axis of a world side, and the half extent across it.
local function axisOf(dir: Vector3): Vector3
	return Vector3.new(math.abs(dir.Z), 0, math.abs(dir.X))
end

-- One storey of one wall: wall pieces either side of each opening, a lintel
-- over each, and a seam panel in each seam's opening. `base` is the wall's
-- centre line at the band's bottom; `openings` are { offset, seam? } along
-- the wall from its middle. Returns the panels by seam id.
local function wallBand(model, base: Vector3, dir: Vector3, length: number, height: number, openings, surface)
	local axis = axisOf(dir)
	local function piece(name: string, at: number, alongLength: number, y0: number, h: number)
		if alongLength < 0.05 or h < 0.05 then
			return nil
		end
		local size = dir.Z ~= 0 and Vector3.new(alongLength, h, WALL) or Vector3.new(WALL, h, alongLength)
		return PropFactory.part(
			model,
			name,
			size,
			CFrame.new(base + axis * at + UP * (y0 + h / 2)),
			surface.color,
			surface.material,
			{ variant = surface.variant }
		)
	end
	local sorted = table.clone(openings)
	table.sort(sorted, function(a, b)
		return a.offset < b.offset
	end)
	local panels = {}
	local from = -length / 2
	for _, opening in sorted do
		local width = opening.width or DOOR_W
		local a, b = opening.offset - width / 2, opening.offset + width / 2
		piece("Wall", (from + a) / 2, a - from, 0, height)
		piece("Lintel", opening.offset, width, DOOR_H, height - DOOR_H)
		if opening.seam then
			panels[opening.seam.id] = piece("SeamPanel", opening.offset, width, 0, DOOR_H)
		end
		from = b
	end
	piece("Wall", (from + length / 2) / 2, length / 2 - from, 0, height)
	return panels
end

-- A flight of stairs in a room's frame: an invisible ramp to walk on and
-- solid-looking steps that don't collide. `from` and `to` are the bottom and
-- top of its centre line (floor points, room frame), `width` across it;
-- `base` is the height its steps stand on (they are solid down to it, and
-- the ramp is a wedge). With no `base` the flight hangs over another one (a
-- stacked stairwell): the ramp is a sloped slab and the steps have a thin
-- soffit, so there is headroom underneath.
local function flight(model, roomCF: CFrame, from: Vector3, to: Vector3, width: number, base: number?, surface, runner)
	local run = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = run.Magnitude
	local rise = to.Y - from.Y
	local dirLocal = run.Unit
	local mid = (from + to) / 2
	local ramp
	if base then
		-- The ramp: a wedge's high end is its +Z face.
		local wedgeCF = roomCF
			* CFrame.lookAt(
				Vector3.new(mid.X, from.Y + rise / 2, mid.Z),
				Vector3.new(mid.X, from.Y + rise / 2, mid.Z) - dirLocal
			)
		ramp = Instance.new("WedgePart")
		ramp.Size = Vector3.new(width, rise, length)
		ramp.CFrame = wedgeCF
	else
		-- A slab one stud thick whose top runs from `from` to `to`.
		local slope = to - from
		local forward = slope.Unit
		local right = forward:Cross(UP).Unit
		local up = right:Cross(forward)
		ramp = Instance.new("Part")
		ramp.Size = Vector3.new(width, 1, slope.Magnitude)
		ramp.CFrame = roomCF * CFrame.fromMatrix(mid - up * 0.5, right, up, -forward)
	end
	ramp.Name = "StairRamp"
	ramp.Anchored = true
	ramp.Transparency = 1
	ramp.CastShadow = false
	ramp.Parent = model
	if base and from.Y > base + 0.01 then
		-- What the flight stands on, up to its bottom step.
		local support = from.Y - base
		PropFactory.part(
			model,
			"StairSupport",
			Vector3.new(width, support, length),
			roomCF
				* CFrame.lookAt(
					Vector3.new(mid.X, base + support / 2, mid.Z),
					Vector3.new(mid.X, base + support / 2, mid.Z) + dirLocal
				),
			surface.color,
			surface.material,
			{ variant = surface.variant, transparency = 1, castShadow = false }
		)
	end
	local steps = math.max(1, math.floor(rise / 0.5 + 0.5))
	local tread = length / steps
	for i = 1, steps do
		local top = from.Y + rise * i / steps
		local bottom = base or (top - rise / steps - 0.6)
		local centre = from + dirLocal * (tread * (i - 0.5))
		local frame = roomCF
			* CFrame.lookAt(
				Vector3.new(centre.X, bottom + (top - bottom) / 2, centre.Z),
				Vector3.new(centre.X, bottom + (top - bottom) / 2, centre.Z) + dirLocal
			)
		PropFactory.part(
			model,
			"Step",
			Vector3.new(width, top - bottom, tread),
			frame,
			surface.color,
			surface.material,
			{ collide = false, variant = surface.variant }
		)
		if runner then
			PropFactory.part(
				model,
				"StairRunner",
				Vector3.new(width * 0.62, 0.06, tread + 0.02),
				roomCF
					* CFrame.lookAt(
						Vector3.new(centre.X, top + 0.03, centre.Z),
						Vector3.new(centre.X, top + 0.03, centre.Z) + dirLocal
					),
				runner,
				PropFactory.material("Fabric"),
				quiet()
			)
		end
	end
	return ramp
end

-- A railing between two points in a room's frame (at the floor it stands
-- on): top and bottom rails, balusters, and an invisible collider.
local function railing(model, roomCF: CFrame, a: Vector3, b: Vector3, height: number?)
	local h = height or RAIL
	local span = b - a
	local length = span.Magnitude
	if length < 0.3 then
		return
	end
	local along = span.Unit
	local wood, material = PropFactory.rgb(Config.Trim.Wood), PropFactory.material("Wood")
	local function bar(name: string, y: number, size: Vector3)
		local mid = (a + b) / 2 + UP * y
		PropFactory.part(model, name, size, roomCF * CFrame.lookAt(mid, mid + along), wood, material, quiet())
	end
	bar("HandRail", h, Vector3.new(0.45, 0.3, length))
	bar("BottomRail", 0.3, Vector3.new(0.3, 0.2, length))
	local count = math.max(1, math.floor(length / 1.2))
	for i = 0, count do
		local p = a + span * (i / count) + UP * (h / 2)
		PropFactory.part(
			model,
			"Baluster",
			Vector3.new(0.22, h - 0.1, 0.22),
			roomCF * CFrame.new(p),
			PropFactory.rgb(Config.Trim.Paint),
			material,
			quiet()
		)
	end
	local mid = (a + b) / 2 + UP * (h + 0.5) / 2
	local collider = PropFactory.part(
		model,
		"Railing",
		Vector3.new(0.3, h + 0.5, length),
		roomCF * CFrame.lookAt(mid, mid + along),
		Color3.new(),
		PropFactory.material("SmoothPlastic"),
		{ transparency = 1, query = false, castShadow = false }
	)
	-- Queries can't see it, so Stalker/Clearance finds it by tag.
	tag(collider, Tags.Railing)
end

-- A wall sconce: a brass plate, an arm and a glowing shade, with a warm light
-- that casts shadows (so it never lights the room next door). `at` is on the
-- wall face at floor level in the room's frame, `facing` points into the
-- room. It belongs to the room: tagged as its light, so flickers and
-- blackouts take it too.
local function sconce(model, roomCF: CFrame, roomId: number, at: Vector3, facing: Vector3)
	local S = M.Sconce
	local cf = roomCF * CFrame.lookAt(at + UP * S.height, at + UP * S.height + facing)
	local brass = PropFactory.rgb(Config.Trim.Knob)
	local fixture = Instance.new("Model")
	fixture.Name = "Sconce"
	PropFactory.part(
		fixture,
		"Plate",
		Vector3.new(0.6, 1, 0.12),
		cf * CFrame.new(0, 0, -0.06),
		brass,
		PropFactory.material("Metal"),
		quiet()
	)
	PropFactory.part(
		fixture,
		"Arm",
		Vector3.new(0.12, 0.12, 0.7),
		cf * CFrame.new(0, 0, -0.4),
		brass,
		PropFactory.material("Metal"),
		quiet()
	)
	local shade = PropFactory.part(
		fixture,
		"Shade",
		Vector3.new(0.9, 0.7, 0.9),
		cf * CFrame.new(0, 0.25, -0.8),
		Color3.fromRGB(240, 210, 150),
		PropFactory.material("Neon"),
		quiet()
	)
	shade:SetAttribute(Attr.LampGlow, true)
	local light = Instance.new("PointLight")
	light.Name = "SconceLight"
	light.Color = PropFactory.rgb(Config.Lighting.Lamp)
	light.Range = S.range
	light.Brightness = S.brightness
	light.Shadows = true
	light.Parent = shade
	shade:SetAttribute(Attr.RoomId, roomId)
	shade:SetAttribute(Attr.Lit, true)
	tag(shade, Tags.RoomLight)
	fixture.Parent = model
	return light
end

-- The grand hall's gallery and staircase (hall frame: x across, z from the
-- back wall at -25 to the front door at +25). `doorsAt(floor, side)` lists
-- the doorway offsets along a wall. Returns its sconces' lights.
local function buildGrandHall(model, roomCF: CFrame, roomId: number, inner, floorSurface, doorsAt)
	local shape = TallRooms.hall(inner, PITCH)
	local top = shape.top
	local edgeZ = shape.edgeZ -- the north strip's open edge
	local edgeX = shape.edgeX -- the side strips' open edges
	local function slab(name, x0, x1, z0, z1)
		PropFactory.part(
			model,
			name,
			Vector3.new(x1 - x0, 1, z1 - z0),
			roomCF * CFrame.new((x0 + x1) / 2, top - 0.5, (z0 + z1) / 2),
			floorSurface.color,
			floorSurface.material,
			{ variant = floorSurface.variant }
		)
	end
	slab("GalleryFloor", -inner.x, inner.x, -inner.z, edgeZ)
	slab("GalleryFloor", -inner.x, -edgeX, edgeZ, inner.z)
	slab("GalleryFloor", edgeX, inner.x, edgeZ, inner.z)
	-- Railings along the open edges, broken where the staircase arrives.
	local y = top
	railing(model, roomCF, Vector3.new(-edgeX, y, edgeZ), Vector3.new(-STAIR_HALF - 0.3, y, edgeZ))
	railing(model, roomCF, Vector3.new(STAIR_HALF + 0.3, y, edgeZ), Vector3.new(edgeX, y, edgeZ))
	railing(model, roomCF, Vector3.new(-edgeX, y, edgeZ), Vector3.new(-edgeX, y, inner.z))
	railing(model, roomCF, Vector3.new(edgeX, y, edgeZ), Vector3.new(edgeX, y, inner.z))
	-- The staircase, straight up the middle to the gallery, with a carpet
	-- runner and handrails on both sides.
	local stairSurface = {
		color = PropFactory.shade(floorSurface.color, 0.85),
		material = floorSurface.material,
		variant = floorSurface.variant,
	}
	flight(
		model,
		roomCF,
		Vector3.new(0, 0, STAIR_FOOT),
		Vector3.new(0, top, edgeZ),
		2 * STAIR_HALF,
		0,
		stairSurface,
		Color3.fromRGB(104, 34, 32)
	)
	for _, side in { -1, 1 } do
		local x = side * (STAIR_HALF - 0.25)
		local a, b = Vector3.new(x, 0, STAIR_FOOT), Vector3.new(x, top, edgeZ)
		local span = b - a
		local mid = (a + b) / 2 + UP * RAIL
		PropFactory.part(
			model,
			"HandRail",
			Vector3.new(0.45, 0.3, span.Magnitude),
			roomCF * CFrame.lookAt(mid, mid + span.Unit),
			PropFactory.rgb(Config.Trim.Wood),
			PropFactory.material("Wood"),
			quiet()
		)
		PropFactory.part(
			model,
			"Newel",
			Vector3.new(0.8, RAIL + 0.6, 0.8),
			roomCF * CFrame.new(x, (RAIL + 0.6) / 2, STAIR_FOOT - 0.4),
			PropFactory.rgb(Config.Trim.Wood),
			PropFactory.material("Wood"),
			quiet()
		)
	end
	-- Sconces: a pair either side of the front door, and four along the
	-- gallery, which the light over the stairs can't reach. Each slides along
	-- its wall until it is clear of the doorways there.
	local function clearSpot(floor: number, side: string, along: number, reach: number): number?
		local doors = doorsAt(floor, side)
		for step = 0, 2 * math.ceil(reach) do
			local candidate = along + (step % 2 == 0 and 1 or -1) * math.ceil(step / 2)
			local ok = math.abs(candidate) <= reach
			for _, door in doors do
				if math.abs(candidate - door) < DOOR_W / 2 + 2.5 then
					ok = false
				end
			end
			if ok then
				return candidate
			end
		end
		return nil
	end
	local lights = {}
	for _, sx in { -1, 1 } do
		local front = clearSpot(0, "S", sx * 7.5, inner.x - 2)
		if front then
			table.insert(lights, sconce(model, roomCF, roomId, Vector3.new(front, 0, inner.z), Vector3.new(0, 0, -1)))
		end
		local back = clearSpot(1, "N", sx * 11, inner.x - 2)
		if back then
			table.insert(lights, sconce(model, roomCF, roomId, Vector3.new(back, top, -inner.z), Vector3.new(0, 0, 1)))
		end
		local side = clearSpot(1, sx < 0 and "W" or "E", 6, inner.z - 2)
		if side then
			table.insert(
				lights,
				sconce(model, roomCF, roomId, Vector3.new(sx * inner.x, top, side), Vector3.new(-sx, 0, 0))
			)
		end
	end
	return lights
end

-- A dog-leg stairwell (frame 20x30: x across, the doorway in the south wall
-- at z +15 on every storey), one dog-leg a storey, stacked (the back stairs
-- may run from the cellar to the attic; docs/plans/level-design.md section
-- 10.2). On each storey flight one climbs the west half to a half landing
-- at the north end, and flight two comes back up the east half to the next
-- storey's landing over the entrance. `storeys` is how many it stands on.
local function buildStairwell(model, roomCF: CFrame, roomId: number, inner, surface, floorSurface, storeys: number)
	local shape = TallRooms.stairwell(inner, PITCH)
	local half = shape.half
	local landingZ = shape.landingZ -- the half landing's edge
	local upperZ = shape.upperZ -- the upper landing's edge
	local lights = {}
	local w = shape.width
	for k = 0, storeys - 2 do
		local y = k * PITCH
		-- The half landing: solid down to the floor on the lowest storey, a
		-- slab over the one below on the others.
		local depth = k == 0 and half or 1
		PropFactory.part(
			model,
			"Landing",
			Vector3.new(2 * inner.x, depth, landingZ + inner.z),
			roomCF * CFrame.new(0, y + half - depth / 2, (-inner.z + landingZ) / 2),
			floorSurface.color,
			floorSurface.material,
			{ variant = floorSurface.variant }
		)
		-- The next storey's landing over the entrance.
		PropFactory.part(
			model,
			"Landing",
			Vector3.new(2 * inner.x, 1, inner.z - upperZ),
			roomCF * CFrame.new(0, y + PITCH - 0.5, (upperZ + inner.z) / 2),
			floorSurface.color,
			floorSurface.material,
			{ variant = floorSurface.variant }
		)
		-- Above the lowest storey a flight is a sloped slab, so there is
		-- headroom on the one under it.
		local base = k == 0 and 0 or nil
		flight(
			model,
			roomCF,
			Vector3.new(-shape.flightX, y, upperZ),
			Vector3.new(-shape.flightX, y + half, landingZ),
			w,
			base,
			floorSurface
		)
		flight(
			model,
			roomCF,
			Vector3.new(shape.flightX, y + half, landingZ),
			Vector3.new(shape.flightX, y + PITCH, upperZ),
			w,
			base,
			floorSurface
		)
		-- A sconce over each half landing, where the light from above is weakest.
		table.insert(lights, sconce(model, roomCF, roomId, Vector3.new(0, y + half, -inner.z), Vector3.new(0, 0, 1)))
	end
	-- The wall between the flights, high enough to lean on from the top one.
	local spineHeight = (storeys - 1) * PITCH + RAIL + 0.5
	PropFactory.part(
		model,
		"Wall",
		Vector3.new(1, spineHeight, upperZ - landingZ),
		roomCF * CFrame.new(0, spineHeight / 2, (upperZ + landingZ) / 2),
		surface.color,
		surface.material,
		{ variant = surface.variant }
	)
	-- Railing on the top landing's edge over the last flight one.
	local top = (storeys - 1) * PITCH
	railing(model, roomCF, Vector3.new(-inner.x, top, upperZ), Vector3.new(-0.5, top, upperZ))
	return lights
end

-- The locked front door: the squad came in through it, and it shut.
local function frontDoor(model, point: Vector3, dir: Vector3)
	local face = point - dir * WALL
	Trim.exitCasing(model, CFrame.lookAt(face, face - dir))
	local size = dir.Z ~= 0 and Vector3.new(DOOR_W, DOOR_H, 0.6) or Vector3.new(0.6, DOOR_H, DOOR_W)
	local doorPos = point + UP * (DOOR_H / 2)
	local door = PropFactory.part(
		model,
		"FrontDoor",
		size,
		CFrame.new(doorPos),
		PropFactory.rgb(Config.Trim.Wood),
		PropFactory.material("Wood")
	)
	local inside = CFrame.lookAt(doorPos, doorPos - dir)
	local brass = PropFactory.rgb(Config.Trim.Knob)
	for _, sx in { -1, 1 } do
		for _, panel in { { y = 1.6, h = 3.4 }, { y = -2.1, h = 2.6 } } do
			PropFactory.part(
				door,
				"Panel",
				Vector3.new(2, panel.h, 0.08),
				inside * CFrame.new(sx * 1.3, panel.y, -0.34),
				PropFactory.shade(PropFactory.rgb(Config.Trim.Wood), 1.18),
				PropFactory.material("Wood"),
				quiet()
			)
		end
	end
	PropFactory.part(
		door,
		"Knob",
		Vector3.new(0.45, 0.45, 0.45),
		inside * CFrame.new(-DOOR_W / 2 + 0.8, -0.5, -0.55),
		brass,
		PropFactory.material("Metal"),
		quiet({ shape = Enum.PartType.Ball })
	)
	return door
end

-- Build everything. Returns the world description used by WorldService.
function MansionBuilder.build(layout, templatesById, folder: Instance, rng)
	local world = {
		layout = layout,
		rooms = {},
		seams = {},
		hidingSpots = {},
		doors = {},
		spawns = {},
		shrines = {},
		props = {},
		moon = WindowView.moon(rng:Fork("moon"), Config.Window),
	}
	local o = origin()
	-- The house's rooms and doorways and its servants' passages and their
	-- hidden doors (section 10.4), which the game's other logic never counts.
	local rooms, seams = MansionHouse.withPassages(layout)

	-- Which room is where on each floor, for outer walls.
	local index = MansionHouse.indices(M.Lattice)
	for _, room in rooms do
		for _, floor in MansionHouse.floorsOf(room) do
			index[floor]:Add(room)
		end
	end

	-- Every doorway-sized opening per room, floor and side: seams, the exit
	-- and the front door. Offsets run along the wall from its middle.
	local openings = {}
	local function addOpening(room, floor: number, side: string, alongWorld: number, entry)
		openings[room.id] = openings[room.id] or {}
		openings[room.id][floor] = openings[room.id][floor] or { N = {}, E = {}, S = {}, W = {} }
		local middle = (side == "N" or side == "S") and room.x + room.w / 2 or room.z + room.d / 2
		entry.offset = alongWorld - middle
		table.insert(openings[room.id][floor][side], entry)
	end
	local roomsById = {}
	for _, room in rooms do
		roomsById[room.id] = room
	end
	for _, seam in seams do
		-- An archway is wider than a door (section 10.7).
		local width = seam.arch and M.Arches.Width or nil
		addOpening(roomsById[seam.a], seam.floor, seam.dir, seam.along, { seam = seam, width = width })
		addOpening(roomsById[seam.b], seam.floor, OPPOSITE[seam.dir], seam.along, { seam = seam, width = width })
	end
	local exitDoor, front = layout.exitDoor, layout.frontDoor
	if exitDoor then
		addOpening(roomsById[exitDoor.room], 0, exitDoor.dir, exitDoor.along, { exit = true })
	end
	if front then
		addOpening(roomsById[front.room], 0, front.dir, front.along, { front = true })
	end
	local function openingsOf(room, floor: number, side: string)
		local byFloor = openings[room.id] and openings[room.id][floor]
		return byFloor and byFloor[side] or {}
	end

	local ceiling = Config.Ceiling
	local ceilingMaterial, ceilingVariant = PropFactory.surface(ceiling.material)
	local panelsByRoom = {}

	for _, room in rooms do
		local template = templatesById[room.template]
		local floorY = MansionBuilder.floorY(room.floor)
		local top = RoomRects.topOf(room)
		local hx, hz = room.w / 2, room.d / 2
		local center = Vector3.new(o.X + room.x + hx, floorY, o.Z + room.z + hz)
		local roomCF = CFrame.new(center) * CFrame.Angles(0, room.rotation * math.pi / 2, 0)
		local even = room.rotation % 2 == 0
		local inner = { x = (even and hx or hz) - WALL, z = (even and hz or hx) - WALL }
		local model = Instance.new("Model")
		model.Name = string.format("Room%02d_%s", room.id, template.id)
		model:SetAttribute(Attr.RoomId, room.id)
		model.Parent = folder

		local wallColor = PropFactory.rgb(template.wall.color)
		local wallMaterial, wallVariant = PropFactory.surface(template.wall.material)
		local wallSurface = { color = wallColor, material = wallMaterial, variant = wallVariant }
		local wainscot = nil
		if template.wainscot then
			local material, variant = PropFactory.surface(Config.Trim.Wainscot.material)
			wainscot = { color = PropFactory.rgb(Config.Trim.Wainscot.color), material = material, variant = variant }
		end
		local floorMaterial, floorVariant = PropFactory.surface(template.floor.material)
		local floorSurface =
			{ color = PropFactory.rgb(template.floor.color), material = floorMaterial, variant = floorVariant }

		-- Floor and ceiling. Over another room, the floor sits on the ceiling
		-- below; over nothing (the ground, or the cellar's earth) it is thicker.
		local below = index[room.floor - 1]
		local onGround = room.floor <= 0 and (below == nil or below:Free(room))
		local floorThickness = onGround and 1 or 0.5
		PropFactory.part(
			model,
			"Floor",
			Vector3.new(room.w, floorThickness, room.d),
			CFrame.new(center - UP * (floorThickness / 2)),
			floorSurface.color,
			floorSurface.material,
			{ variant = floorSurface.variant }
		)
		local ceilingY = floorY + (top - room.floor) * PITCH + HEIGHT
		-- The cellar's ceiling is the boards of the floor over it.
		local own = template.ceiling
		local roofMaterial, roofVariant = ceilingMaterial, ceilingVariant
		local roofColor = PropFactory.rgb(ceiling.color):Lerp(wallColor, ceiling.wallTint)
		if own then
			roofMaterial, roofVariant = PropFactory.surface(own.material)
			roofColor = PropFactory.rgb(own.color)
		end
		PropFactory.part(
			model,
			"Ceiling",
			Vector3.new(room.w, 0.5, room.d),
			CFrame.new(Vector3.new(center.X, ceilingY + 0.25, center.Z)),
			roofColor,
			roofMaterial,
			{ variant = roofVariant }
		)
		if template.rafters then
			-- Under the roof (the attic): the roof slopes from low on the long
			-- walls to a ridge down the middle, on rafters every few studs.
			-- Nothing collides; furniture in attic rooms stays under the low
			-- side.
			local R = Config.Mansion.Rafters
			local alongX = room.w >= room.d
			local long = (alongX and room.w or room.d) - 2 * WALL
			local half = (alongX and room.d or room.w) / 2 - WALL
			local axis = alongX and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
			local across = alongX and Vector3.new(0, 0, 1) or Vector3.new(1, 0, 0)
			local ridge = Vector3.new(center.X, ceilingY, center.Z)
			local wood = roofColor:Lerp(Color3.new(), 0.3)
			for _, side in { -1, 1 } do
				local low = Vector3.new(center.X, floorY + R.knee, center.Z) + across * side * half
				local slope = ridge - low
				local mid = (low + ridge) / 2
				local look = CFrame.lookAt(mid, mid + slope.Unit, UP)
				PropFactory.part(
					model,
					"Roof",
					Vector3.new(long, 0.3, slope.Magnitude),
					look * CFrame.new(0, 0.15, 0),
					roofColor,
					roofMaterial,
					{ variant = roofVariant, collide = false, query = false }
				)
				local count = math.max(1, math.floor(long / R.every))
				for i = 1, count do
					local offset = -long / 2 + (i - 0.5) * long / count
					PropFactory.part(
						model,
						"Rafter",
						Vector3.new(R.width, R.depth, slope.Magnitude),
						look * CFrame.new(0, -R.depth / 2, 0) + axis * offset,
						wood,
						roofMaterial,
						{ variant = roofVariant, collide = false, query = false }
					)
				end
			end
			PropFactory.part(
				model,
				"Ridge",
				alongX and Vector3.new(long, 0.8, 0.6) or Vector3.new(0.6, 0.8, long),
				CFrame.new(ridge - UP * 0.4),
				wood,
				roofMaterial,
				{ variant = roofVariant, collide = false, query = false }
			)
		end
		if template.joists then
			-- Joists across the short way, every few studs, under the boards.
			local acrossX = room.w <= room.d
			local long = acrossX and room.d or room.w
			local span = (acrossX and room.w or room.d) - 2 * WALL
			local beam = Config.Mansion.Joists
			local count = math.floor((long - 2 * WALL) / beam.every)
			for i = 1, count do
				local offset = -long / 2 + WALL + (i - 0.5) * (long - 2 * WALL) / count
				local at = Vector3.new(center.X, ceilingY - beam.depth / 2, center.Z)
					+ (acrossX and Vector3.new(0, 0, offset) or Vector3.new(offset, 0, 0))
				PropFactory.part(
					model,
					"Joist",
					acrossX and Vector3.new(span, beam.depth, beam.width) or Vector3.new(beam.width, beam.depth, span),
					CFrame.new(at),
					roofColor:Lerp(Color3.new(), 0.25),
					roofMaterial,
					{ variant = roofVariant, collide = false, castShadow = true, query = false }
				)
			end
		end

		-- Walls, one band per storey. The top band stops inside the slab over
		-- it (or just over its own ceiling); a tall room's lower bands meet the
		-- band above.
		local panels = {}
		local storeys = MansionHouse.floorsOf(room)
		for band, floor in storeys do
			local baseY = MansionBuilder.floorY(floor)
			local bandTop = band < #storeys and PITCH or PITCH - SLAB_TUCK
			for side, dir in DIRS do
				local across = (side == "N" or side == "S") and hz or hx
				local length = (side == "N" or side == "S") and room.w or room.d
				local base = Vector3.new(center.X, baseY, center.Z) + dir * (across - WALL / 2)
				local list = {}
				for _, entry in openingsOf(room, floor, side) do
					table.insert(list, entry)
				end
				for id, panel in wallBand(model, base, dir, length, bandTop, list, wallSurface) do
					panels[id] = panel
				end
			end
		end
		panelsByRoom[room.id] = panels

		-- Trim: baseboards broken for doorways; crown under the ceiling.
		for band, floor in storeys do
			local baseY = MansionBuilder.floorY(floor)
			local frame = CFrame.new(Vector3.new(center.X, baseY, center.Z))
			for side, dir in DIRS do
				local across = ((side == "N" or side == "S") and hz or hx) - WALL
				local half = ((side == "N" or side == "S") and hx or hz) - WALL
				local axis = axisOf(dir)
				local cuts = {}
				for _, entry in openingsOf(room, floor, side) do
					table.insert(cuts, entry.offset + half)
				end
				local a, b = dir * across - axis * half, dir * across + axis * half
				local lowerOfTwo = room.tall and band < #storeys
				local upperOfTwo = room.tall and band > 1
				local baseboard = true
				if upperOfTwo then
					-- Upstairs in the hall only the gallery walls have a floor; in a
					-- stairwell none do.
					baseboard = room.kind ~= "stair" and side ~= "S"
				end
				Trim.stretch(model, frame, a, b, -dir, cuts, band == 1 and wainscot or nil, not lowerOfTwo, baseboard)
			end
		end

		-- Double-height rooms.
		local tallLights = {}
		if template.id == "grand_hall" then
			tallLights = buildGrandHall(model, roomCF, room.id, inner, floorSurface, function(floor, side)
				local offsets = {}
				for _, entry in openingsOf(room, floor, side) do
					table.insert(offsets, entry.offset)
				end
				return offsets
			end)
		elseif room.kind == "stair" then
			tallLights = buildStairwell(model, roomCF, room.id, inner, wallSurface, floorSurface, #storeys)
		end

		-- A clear spot to walk to: in front of the hall's staircase, at the foot
		-- of a stairwell, the middle of anything else.
		local walkTo = center
		if template.id == "grand_hall" then
			walkTo = roomCF:PointToWorldSpace(Vector3.new(0, 0, (STAIR_FOOT + inner.z) / 2))
		elseif room.kind == "stair" then
			walkTo = roomCF:PointToWorldSpace(Vector3.new(0, 0, inner.z - 4))
		end

		-- Grime's view of the walls (World/Grime): the storey it decorates.
		local baseFloor = room.floor
		local wallOpenings = {}
		for side in DIRS do
			wallOpenings[side] = {}
			for _, entry in openingsOf(room, baseFloor, side) do
				table.insert(wallOpenings[side], entry.offset)
			end
		end

		local record = {
			id = room.id,
			template = template,
			name = template.name,
			role = room.role,
			lantern = room.lantern,
			mood = template.mood,
			center = walkTo,
			cframe = roomCF,
			model = model,
			floor = baseFloor,
			tall = room.tall == true,
			kind = room.kind,
			rect = { x = room.x, z = room.z, w = room.w, d = room.d },
			inner = inner,
			sides = {},
			seamList = {},
			wallSlots = {},
			floorSlots = {},
			hidingSpots = {},
			props = {},
			extraLights = tallLights,
			lightOn = true,
			wallSurface = wallSurface,
			wainscot = wainscot,
			walls = {
				center = center,
				inner = { N = hz - WALL, S = hz - WALL, E = hx - WALL, W = hx - WALL },
				half = { N = hx - WALL, S = hx - WALL, E = hz - WALL, W = hz - WALL },
				openings = wallOpenings,
				radius = math.max(1, math.min(hx, hz) - 3),
				ceiling = ceilingY - floorY,
			},
		}
		for side in DIRS do
			record.sides[side] = { exit = false }
		end
		world.rooms[room.id] = record

		-- Contents: the template's furniture fitted to this room's size and
		-- doorways (the ground storey's, for a double-height room). The lock
		-- planner sees the same fit (Logic/Dumbwaiter).
		for side in DIRS do
			for _, entry in openingsOf(room, baseFloor, side) do
				if entry.exit then
					record.sides[side].exit = true
				end
			end
		end
		local fitted = RoomFit.inMansion(layout, room, template, WALL)
		if room.lantern and not fitted.shrine then
			fitted.shrine = { x = 0, z = 0 }
		end
		local fittedTemplate = setmetatable({
			props = fitted.props,
			decor = fitted.decor,
			wallSlots = fitted.wallSlots,
			floorSlots = fitted.floorSlots,
			spawns = fitted.spawns,
			shrine = fitted.shrine,
			caseBoard = fitted.caseBoard,
		}, { __index = template })

		-- A wall position faces outside if the wall there touches no other room
		-- on this storey (windows look out, tells that need a window too).
		local function facesOutside(slot): boolean
			if slot.side == nil or baseFloor < 0 then
				-- (Under the ground there is no outside to face.)
				return false
			end
			local side = LevelGraph.worldSide(slot.side, room.rotation)
			local localPos = (slot.side == "N" or slot.side == "S") and Vector3.new(slot.along, 0, 0)
				or Vector3.new(0, 0, slot.along)
			local worldPos = roomCF:PointToWorldSpace(localPos)
			local along = (side == "N" or side == "S") and worldPos.X - o.X or worldPos.Z - o.Z
			for _, span in index[baseFloor]:OuterSpans(room, side) do
				if span.from <= along - 3.5 and span.to >= along + 3.5 then
					return true
				end
			end
			return false
		end
		LevelBuilder.furnish(world, {
			room = room,
			record = record,
			template = fittedTemplate,
			roomCF = roomCF,
			model = model,
			rng = rng,
			center = center,
			prefabs = nil,
			inner = inner,
			fixtureAt = room.tall and center + UP * (top - room.floor) * PITCH or nil,
			facesOutside = facesOutside,
			inFilledArm = function()
				return false
			end,
			wallInFilledArm = function()
				return false
			end,
		})

		-- A long corridor gets more lights than the one in its middle: a pair
		-- every 22 studs out from it, dimmed and blacked out with the room's own
		-- (WorldService:SetRoomLight). Pools of light with dark between, like
		-- P.T.'s hallway.
		if room.corridor then
			local long = math.max(room.w, room.d)
			local axis = room.w >= room.d and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
			for k = 1, math.floor((long / 2 - 8) / 22) do
				for _, sign in { -1, 1 } do
					local point = center + axis * sign * 22 * k
					local diffuser = LevelBuilder.ceilingFixture(model, point, template.fixture or template.family)
					local light = LevelBuilder.lightFor("ceiling", diffuser, template)
					diffuser:SetAttribute(Attr.RoomId, room.id)
					diffuser:SetAttribute(Attr.Lit, true)
					tag(diffuser, Tags.RoomLight)
					table.insert(record.extraLights, light)
				end
			end
			-- A runner down the middle (P.T.'s hallway carpet).
			PropFactory.part(
				model,
				"Runner",
				room.w >= room.d and Vector3.new(room.w - 4, 0.06, 5) or Vector3.new(5, 0.06, room.d - 4),
				CFrame.new(center + UP * 0.03),
				Color3.fromRGB(92, 40, 36),
				PropFactory.material("Fabric"),
				quiet()
			)
		end

		-- The front door, locked behind the squad.
		if front and front.room == room.id then
			local point = o + Vector3.new(RoomRects.doorPoint(front.dir, front.line, front.along))
			point = Vector3.new(point.X, floorY, point.Z)
			world.frontDoor = frontDoor(model, point, DIRS[front.dir])
		end
		-- The exit.
		if exitDoor and exitDoor.room == room.id then
			local x, z = RoomRects.doorPoint(exitDoor.dir, exitDoor.line, exitDoor.along)
			local point = Vector3.new(o.X + x, floorY, o.Z + z)
			local dir = DIRS[exitDoor.dir]
			LevelBuilder.exitDoor(
				world,
				model,
				room.id,
				exitDoor.dir,
				dir,
				point + UP * (DOOR_H / 2),
				point - dir * WALL,
				point + dir * 6
			)
		end
	end

	-- Seams and doors, once per pair of rooms that share a wall.
	local ajarRng = rng:Fork("ajar")
	for _, seam in seams do
		local roomA, roomB = world.rooms[seam.a], world.rooms[seam.b]
		local x, z = RoomRects.doorPoint(seam.dir, seam.line, seam.along)
		local midpoint = Vector3.new(o.X + x, MansionBuilder.floorY(seam.floor), o.Z + z)
		local normal = DIRS[seam.dir]
		local panels = { panelsByRoom[seam.a][seam.id], panelsByRoom[seam.b][seam.id] }
		local record = {
			id = seam.id,
			a = seam.a,
			b = seam.b,
			connected = seam.connected,
			panels = panels,
			position = midpoint + UP * (DOOR_H / 2),
			floorPosition = midpoint,
			normal = normal,
			floor = seam.floor,
			hidden = seam.hidden,
			arch = seam.arch,
			width = seam.arch and M.Arches.Width or nil,
		}
		LevelBuilder.markSeamPanels(panels, seam)
		table.insert(roomA.seamList, record)
		table.insert(roomB.seamList, record)
		roomA.sides[seam.dir].seam = roomA.sides[seam.dir].seam or record
		roomB.sides[OPPOSITE[seam.dir]].seam = roomB.sides[OPPOSITE[seam.dir]].seam or record
		world.seams[seam.id] = record

		-- Each room's wall skin covers the stretch of wall around this doorway,
		-- halfway to the next doorway or to the corner.
		local function faceOf(roomRecord, layoutRoom, side: string, dir: Vector3)
			local face = midpoint - dir * WALL
			local cf = CFrame.lookAt(face, face - dir)
			local half = ((side == "N" or side == "S") and layoutRoom.w or layoutRoom.d) / 2 - WALL
			local mine
			local offsets = {}
			for _, entry in openingsOf(layoutRoom, seam.floor, side) do
				table.insert(offsets, entry.offset)
				if entry.seam == seam then
					mine = entry.offset
				end
			end
			table.sort(offsets)
			local left, right = -half, half
			for _, offset in offsets do
				if offset < mine then
					left = math.max(left, (offset + mine) / 2)
				elseif offset > mine then
					right = math.min(right, (offset + mine) / 2)
				end
			end
			-- The face's own x axis may run the other way along the wall.
			local sign = cf.RightVector:Dot(axisOf(dir)) >= 0 and 1 or -1
			local s0, s1 = (left - mine) * sign, (right - mine) * sign
			return {
				parent = roomRecord.model,
				face = cf,
				surface = roomRecord.wallSurface,
				wainscot = seam.floor == roomRecord.floor and roomRecord.wainscot or nil,
				span = { math.min(s0, s1), math.max(s0, s1) },
				-- A hidden door's room side (its passage is seam.b).
				hidden = seam.hidden and roomRecord == roomA or nil,
			}
		end
		Trim.seam(record, {
			faceOf(roomA, roomsById[seam.a], seam.dir, normal),
			faceOf(roomB, roomsById[seam.b], OPPOSITE[seam.dir], -normal),
		}, midpoint, normal)

		if seam.connected and seam.door then
			local hidden = nil
			if seam.hidden then
				-- A bookcase in a lived-in room, the wall itself elsewhere.
				local family = roomA.template.family
				hidden = {
					kind = (family == "living" or family == "bedroom") and "bookcase" or "panel",
					surface = roomA.wallSurface,
				}
			end
			-- A gate into a wing has glass in it (section 10.7).
			local lock = layout.progression and layout.progression.locks[seam.id]
			local glazed = lock ~= nil and Config.Trim.GlassDoor.Kinds[lock.kind] == true
			LevelBuilder.seamDoor(world, seam, record, roomA, midpoint, normal, ajarRng, hidden, glazed)
		end
	end

	Grime.build(world, rng:Fork("grime"))
	Dressing.build(world, rng:Fork("dressing"))

	world.rng = rng
	world.index = index
	return world
end

return MansionBuilder
