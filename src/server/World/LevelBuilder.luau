-- Turns a layout from Logic/LevelGraph into parts in the Workspace.
--
-- Rooms are 40x40 cells. Every wall between two rooms is built the same way:
-- two wall pieces, a lintel, and a doorway-sized "seam" panel. On a real
-- doorway the panel is invisible and non-collidable; on a solid wall it is
-- solid. Because every shared wall has a seam, a divergence can flip any of
-- them for one Witness (PerceptionController) without the house looking
-- different where nothing is wrong.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Props = require(Shared.Data.Props)
local PropFactory = require(Shared.World.PropFactory)

local Tags = Constants.Tags
local Attr = Constants.Attributes

local LevelBuilder = {}

local CELL = Config.Level.CellSize
local HALF = CELL / 2
local WALL = Config.Level.WallThickness
local INNER = HALF - WALL -- inner face of a wall, 19.5
local HEIGHT = Config.Level.WallHeight
local DOOR_W = Config.Level.DoorWidth
local DOOR_H = Config.Level.DoorHeight

local WORLD_DIRS = {
	N = Vector3.new(0, 0, -1),
	E = Vector3.new(1, 0, 0),
	S = Vector3.new(0, 0, 1),
	W = Vector3.new(-1, 0, 0),
}
LevelBuilder.WorldDirs = WORLD_DIRS

local SIDE_LOCAL = {
	N = function(along, y)
		return Vector3.new(along, y, -INNER), Vector3.new(0, 0, 1)
	end,
	S = function(along, y)
		return Vector3.new(along, y, INNER), Vector3.new(0, 0, -1)
	end,
	W = function(along, y)
		return Vector3.new(-INNER, y, along), Vector3.new(1, 0, 0)
	end,
	E = function(along, y)
		return Vector3.new(INNER, y, along), Vector3.new(-1, 0, 0)
	end,
}

local function origin(): Vector3
	local o = Config.Level.Origin
	return Vector3.new(o.x, o.y, o.z)
end

function LevelBuilder.cellCenter(gx: number, gz: number): Vector3
	return origin() + Vector3.new(gx * CELL, 0, gz * CELL)
end

-- CFrame on a wall's inner face, LookVector pointing into the room.
local function wallCFrame(roomCF: CFrame, side: string, along: number, y: number): CFrame
	local localPos, localNormal = SIDE_LOCAL[side](along, y)
	local pos = roomCF:PointToWorldSpace(localPos)
	local normal = roomCF:VectorToWorldSpace(localNormal)
	return CFrame.lookAt(pos, pos + normal)
end
LevelBuilder.wallCFrame = wallCFrame

local function tag(instance: Instance, tagName: string)
	CollectionService:AddTag(instance, tagName)
end

local function setId(instance: Instance, id: string, label: string?)
	instance:SetAttribute(Attr.CId, id)
	if label then
		instance:SetAttribute(Attr.Label, label)
	end
	tag(instance, Tags.Object)
end

-- Build one wall layer of a room on a world side.
local function buildWall(parent, center: Vector3, dirName: string, gap: boolean, color: Color3, material)
	local dir = WORLD_DIRS[dirName]
	local alongAxis = Vector3.new(math.abs(dir.Z), 0, math.abs(dir.X))
	local base = center + dir * (HALF - WALL / 2)
	local function piece(name, alongCenter, alongLength, yCenter, height)
		local size = dir.Z ~= 0 and Vector3.new(alongLength, height, WALL) or Vector3.new(WALL, height, alongLength)
		return PropFactory.part(
			parent,
			name,
			size,
			CFrame.new(base + alongAxis * alongCenter + Vector3.new(0, yCenter, 0)),
			color,
			material
		)
	end
	if not gap then
		piece("Wall", 0, CELL, HEIGHT / 2, HEIGHT)
		return nil
	end
	local sideLength = HALF - DOOR_W / 2
	piece("Wall", -(DOOR_W / 2 + sideLength / 2), sideLength, HEIGHT / 2, HEIGHT)
	piece("Wall", DOOR_W / 2 + sideLength / 2, sideLength, HEIGHT / 2, HEIGHT)
	piece("Lintel", 0, DOOR_W, DOOR_H + (HEIGHT - DOOR_H) / 2, HEIGHT - DOOR_H)
	local panel = piece("SeamPanel", 0, DOOR_W, DOOR_H / 2, DOOR_H)
	return panel
end

local function lightFor(kind: string, parentPart: BasePart, template)
	local palette = Config.Lighting
	local light
	if kind == "lamp" then
		light = Instance.new("PointLight")
		light.Color = PropFactory.rgb(palette.Lamp)
		light.Range = 26
		light.Brightness = 1.7
	elseif kind == "tv" then
		light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Back
		light.Color = PropFactory.rgb(palette.Screen)
		light.Range = 22
		light.Brightness = 2.2
		light.Angle = 100
	elseif kind == "window" then
		light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Front
		light.Color = PropFactory.rgb(palette.Moonlight)
		light.Range = 24
		light.Brightness = 1.6
		light.Angle = 75
	else
		-- Ceiling light: fluorescent in utility rooms, tungsten everywhere else.
		local settings = template.light or {}
		light = Instance.new("PointLight")
		light.Color =
			PropFactory.rgb(settings.color or (template.family == "utility" and palette.Fluorescent or palette.Lamp))
		light.Range = settings.range or 24
		light.Brightness = settings.brightness or 1.2
	end
	light.Name = "KeyLight"
	light.Shadows = true
	light.Parent = parentPart
	return light
end

local function hideGeometry(category: string, depth: number)
	-- eye height while hidden, and where the body sits
	if category == "bed" then
		return 0.9, Vector3.new(0, 0.6, 0)
	elseif category == "table" then
		return 1.4, Vector3.new(0, 1, 0)
	elseif category == "curtain" then
		return 5.2, Vector3.new(0, 3, -depth / 2 + 0.3)
	end
	return 5.6, Vector3.new(0, 3, 0)
end

-- Build everything. Returns the world description used by WorldService.
function LevelBuilder.build(layout, templatesById, folder: Instance, rng)
	local world = {
		layout = layout,
		rooms = {},
		seams = {},
		hidingSpots = {},
		doors = {},
		spawns = {},
		shrines = {},
		props = {},
	}
	local cells = layout.cells
	local prefabs = ServerStorage:FindFirstChild("RoomPrefabs")

	local function neighbourAt(room, dirName)
		local d = WORLD_DIRS[dirName]
		return cells[(room.gx + d.X) .. "," .. (room.gz + d.Z)]
	end

	-- Pick the exit side before walls go up.
	local exitSide = nil
	for _, room in layout.rooms do
		if room.id == layout.exit then
			for _, dirName in { "N", "E", "S", "W" } do
				if not neighbourAt(room, dirName) then
					exitSide = dirName
					break
				end
			end
		end
	end

	for _, room in layout.rooms do
		local template = templatesById[room.template]
		local center = LevelBuilder.cellCenter(room.gx, room.gz)
		local roomCF = CFrame.new(center) * CFrame.Angles(0, room.rotation * math.pi / 2, 0)
		local model = Instance.new("Model")
		model.Name = string.format("Room%02d_%s", room.id, template.id)
		model:SetAttribute(Attr.RoomId, room.id)
		model.Parent = folder

		local floorColor = PropFactory.rgb(template.floor.color)
		local wallColor = PropFactory.rgb(template.wall.color)
		local wallMaterial = PropFactory.material(template.wall.material)
		PropFactory.part(
			model,
			"Floor",
			Vector3.new(CELL, 1, CELL),
			CFrame.new(center - Vector3.new(0, 0.5, 0)),
			floorColor,
			PropFactory.material(template.floor.material)
		)
		PropFactory.part(
			model,
			"Ceiling",
			Vector3.new(CELL, 1, CELL),
			CFrame.new(center + Vector3.new(0, HEIGHT + 0.5, 0)),
			PropFactory.shade(wallColor, 0.7),
			PropFactory.material("Plaster")
		)

		local record = {
			id = room.id,
			gx = room.gx,
			gz = room.gz,
			template = template,
			name = template.name,
			role = room.role,
			lantern = room.lantern,
			mood = template.mood,
			center = center,
			cframe = roomCF,
			model = model,
			sides = {},
			wallSlots = {},
			floorSlots = {},
			hidingSpots = {},
			props = {},
			lightOn = true,
		}
		world.rooms[room.id] = record

		-- Walls: every side gets this room's own wall layer.
		for _, dirName in { "N", "E", "S", "W" } do
			local neighbour = neighbourAt(room, dirName)
			local isExitSide = room.id == layout.exit and dirName == exitSide
			local panel = buildWall(model, center, dirName, neighbour ~= nil or isExitSide, wallColor, wallMaterial)
			record.sides[dirName] = { neighbour = neighbour, panel = panel, exit = isExitSide }
		end

		-- Furniture: a hand-built prefab if one exists, otherwise the grey-box.
		local prefab = prefabs and prefabs:FindFirstChild(template.id)
		local keyLightPart, keyLightKind = nil, nil
		if prefab then
			-- Prefab conventions (see README): a Light tagged ConsensusRoomLight
			-- is the key light; a BasePart with a HideCategory attribute is a
			-- hiding spot whose LookVector faces into the room; a BasePart with
			-- a Deliberation attribute is the Deliberation Table.
			local clone = prefab:Clone()
			clone:PivotTo(roomCF)
			clone.Parent = model
			for _, d in clone:GetDescendants() do
				if d:IsA("Light") and CollectionService:HasTag(d, Tags.RoomLight) and not keyLightPart then
					keyLightPart = d.Parent
				elseif d:IsA("BasePart") then
					local category = d:GetAttribute("HideCategory")
					if category then
						local depth = d.Size.Z
						local eye, inside = hideGeometry(category, depth)
						local frontDir = d.CFrame.LookVector
						local base = d.CFrame * CFrame.new(0, -d.Size.Y / 2, 0)
						local peekPos = (base * CFrame.new(0, eye, -depth / 2 - 0.35)).Position
						local spotId = "hide:" .. room.id .. ":" .. d.Name .. #record.hidingSpots
						d:SetAttribute(Attr.CId, spotId)
						d:SetAttribute(Attr.Category, category)
						tag(d, Tags.HidingSpot)
						world.hidingSpots[spotId] = {
							id = spotId,
							roomId = room.id,
							category = category,
							capacity = d:GetAttribute("Capacity") or 1,
							noise = d:GetAttribute("Noise") or 8,
							occupants = {},
							heat = 0,
							model = d,
							anchor = d,
							insideCFrame = base * CFrame.new(inside.X, inside.Y, -inside.Z),
							peekCFrame = CFrame.lookAt(peekPos, peekPos + frontDir),
							frontPosition = (base * CFrame.new(0, 0, -depth / 2 - 2.6)).Position,
							label = d:GetAttribute("Label") or category,
						}
						table.insert(record.hidingSpots, spotId)
					end
					if d:GetAttribute("Deliberation") then
						world.deliberationTable = d
						world.deliberationPosition = d.Position
					end
				end
			end
		else
			for _, prop in template.props do
				local cf = roomCF * CFrame.new(prop.x, 0, prop.z) * CFrame.Angles(0, math.rad(prop.ry or 0), 0)
				local propModel, lightPart = PropFactory.build(prop.kind, cf, model, { name = prop.id })
				local propId = "prop:" .. room.id .. ":" .. prop.id
				propModel:SetAttribute(Attr.CId, propId)
				record.props[prop.id] = { model = propModel, cframe = cf, kind = prop.kind, id = propId }
				table.insert(world.props, { id = propId, model = propModel, roomId = room.id, kind = prop.kind })
				local kind = Props.Kinds[prop.kind]
				if prop.key and lightPart then
					keyLightPart, keyLightKind = lightPart, kind.light
				end
				if kind.hide then
					local w, h, d = kind.size[1], kind.size[2], kind.size[3]
					local eye, inside = hideGeometry(kind.hide, d)
					local frontDir = cf.LookVector * -1 -- prop front is +Z
					local peekPos = cf:PointToWorldSpace(Vector3.new(0, eye, d / 2 + 0.35))
					local anchor = PropFactory.part(
						model,
						"HideAnchor",
						Vector3.new(math.min(w, 3), math.min(h, 3), 0.2),
						cf * CFrame.new(0, math.min(h, 5) / 2, d / 2 + 0.2),
						Color3.new(),
						PropFactory.material("SmoothPlastic"),
						{ collide = false, transparency = 1, castShadow = false }
					)
					local spotId = "hide:" .. room.id .. ":" .. prop.id
					local spot = {
						id = spotId,
						roomId = room.id,
						category = kind.hide,
						capacity = kind.capacity or 1,
						noise = kind.noise or 8,
						occupants = {},
						heat = 0,
						model = propModel,
						anchor = anchor,
						insideCFrame = cf * CFrame.new(inside),
						peekCFrame = CFrame.lookAt(peekPos, peekPos + frontDir),
						frontPosition = cf:PointToWorldSpace(Vector3.new(0, 0, d / 2 + 2.6)),
						label = prop.kind,
					}
					anchor:SetAttribute(Attr.CId, spotId)
					anchor:SetAttribute(Attr.Category, kind.hide)
					tag(anchor, Tags.HidingSpot)
					world.hidingSpots[spotId] = spot
					table.insert(record.hidingSpots, spotId)
				end
				if prop.deliberation then
					world.deliberationTable = propModel
					world.deliberationPosition = cf.Position
				end
			end
			for _, decor in template.decor do
				local cf = wallCFrame(roomCF, decor.side, decor.along, decor.y)
				local decorModel, lightPart = PropFactory.buildDecor(decor.kind, cf, model, room.id * 100 + #decor.id)
				decorModel:SetAttribute(Attr.CId, "decor:" .. room.id .. ":" .. decor.id)
				if decor.key and lightPart then
					keyLightPart, keyLightKind = lightPart, "window"
				end
				if decor.kind == "Painting" then
					record.paintings = record.paintings or {}
					table.insert(record.paintings, { model = decorModel, cframe = cf })
				end
			end
		end

		-- Key light: one motivated source per room (doc section 8).
		if not keyLightPart then
			keyLightPart = PropFactory.part(
				model,
				"CeilingLamp",
				Vector3.new(2.2, 0.5, 2.2),
				CFrame.new(center + Vector3.new(0, HEIGHT - 0.25, 0)),
				Color3.fromRGB(240, 226, 200),
				PropFactory.material("Neon"),
				{ collide = false, castShadow = false }
			)
			keyLightKind = "ceiling"
		end
		local light = keyLightPart:FindFirstChildWhichIsA("Light")
			or lightFor(keyLightKind or "ceiling", keyLightPart, template)
		keyLightPart:SetAttribute(Attr.RoomId, room.id)
		keyLightPart:SetAttribute(Attr.Lit, true)
		tag(keyLightPart, Tags.RoomLight)
		record.light = light
		record.lightPart = keyLightPart
		record.lightBrightness = light.Brightness

		-- Fill: a soft, shadowless light under the ceiling centre so the room
		-- reads without the flashlight (docs/ART.md rule 1). Tagged like the key
		-- light so flickers and blackouts take it too.
		local lighting = Config.Lighting
		local family = lighting.Families[template.family] or lighting.Families.living
		local fillPart = PropFactory.part(
			model,
			"FillLight",
			Vector3.new(0.2, 0.2, 0.2),
			CFrame.new(center + Vector3.new(0, HEIGHT - lighting.FillDrop, 0)),
			Color3.new(),
			PropFactory.material("SmoothPlastic"),
			{ collide = false, transparency = 1, query = false, castShadow = false }
		)
		local fill = Instance.new("PointLight")
		fill.Name = "FillLight"
		fill.Shadows = false
		fill.Range = lighting.FillRange
		fill.Color = PropFactory.rgb(lighting[family.fill])
		fill.Brightness = light:IsA("SurfaceLight") and lighting.FillWithoutLamp or family.brightness
		fill.Parent = fillPart
		fillPart:SetAttribute(Attr.RoomId, room.id)
		tag(fillPart, Tags.RoomLight)
		record.fill = fill

		-- Slots for tells and Sources.
		for _, slot in template.wallSlots do
			table.insert(
				record.wallSlots,
				{ cframe = wallCFrame(roomCF, slot.side, slot.along, slot.y or 6.5), used = false }
			)
		end
		for _, slot in template.floorSlots do
			local pos = roomCF:PointToWorldSpace(Vector3.new(slot.x, 0, slot.z))
			table.insert(record.floorSlots, {
				-- face the room centre
				cframe = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)) * CFrame.Angles(0, math.pi, 0),
				position = pos,
				used = false,
			})
		end

		-- Role furniture.
		if room.role == "start" then
			for _, spawn in template.spawns or {} do
				table.insert(world.spawns, CFrame.new(roomCF:PointToWorldSpace(Vector3.new(spawn.x, 3, spawn.z))))
			end
			local board = template.caseBoard or { side = "E", along = 10 }
			local cf = wallCFrame(roomCF, board.side, board.along, 6.5)
			local boardPart = PropFactory.part(
				model,
				"CaseBoard",
				Vector3.new(9, 5.5, 0.3),
				cf * CFrame.new(0, 0, -0.15),
				Color3.fromRGB(150, 110, 74),
				PropFactory.material("Fabric"),
				{ collide = false }
			)
			world.caseBoardPart = boardPart
		end
		if room.lantern then
			local s = template.shrine
			local pos = roomCF:PointToWorldSpace(Vector3.new(s.x, 0, s.z))
			local cf = CFrame.lookAt(pos, Vector3.new(center.X, 0, center.Z)) * CFrame.Angles(0, math.pi, 0)
			local shrineModel, glass = PropFactory.build("Shrine", cf, model, { name = "LanternShrine" })
			local lanternLight = Instance.new("PointLight")
			lanternLight.Name = "LanternLight"
			lanternLight.Color = Color3.fromRGB(255, 190, 110)
			lanternLight.Range = 30
			lanternLight.Brightness = 1.8
			lanternLight.Shadows = true
			lanternLight.Enabled = false
			lanternLight.Parent = glass
			local shrineId = "shrine:" .. room.id
			glass:SetAttribute(Attr.CId, shrineId)
			glass:SetAttribute(Attr.RoomId, room.id)
			tag(glass, Tags.LanternShrine)
			world.shrines[room.id] = {
				id = shrineId,
				roomId = room.id,
				model = shrineModel,
				glass = glass,
				light = lanternLight,
				lit = false,
			}
			record.shrine = world.shrines[room.id]
		end
		if room.role == "exit" and exitSide then
			local dir = WORLD_DIRS[exitSide]
			local doorPos = center + dir * HALF + Vector3.new(0, DOOR_H / 2, 0)
			local side = record.sides[exitSide]
			if side.panel then
				side.panel:Destroy()
				side.panel = nil
			end
			local size = dir.Z ~= 0 and Vector3.new(DOOR_W, DOOR_H, 0.6) or Vector3.new(0.6, DOOR_H, DOOR_W)
			local exitDoor = PropFactory.part(
				model,
				"ExitDoor",
				size,
				CFrame.new(doorPos),
				Color3.fromRGB(60, 40, 30),
				PropFactory.material("Wood")
			)
			PropFactory.surfaceText(
				exitDoor,
				dir.Z < 0 and Enum.NormalId.Back
					or dir.Z > 0 and Enum.NormalId.Front
					or dir.X > 0 and Enum.NormalId.Left
					or Enum.NormalId.Right,
				"Sign",
				"EXIT",
				{ color = Color3.fromRGB(200, 60, 50), ppu = 20 }
			)
			local porchCenter = center + dir * (HALF + 6)
			local porchSize = dir.Z ~= 0 and Vector3.new(14, 1, 12) or Vector3.new(12, 1, 14)
			PropFactory.part(
				model,
				"Porch",
				porchSize,
				CFrame.new(porchCenter - Vector3.new(0, 0.5, 0)),
				Color3.fromRGB(70, 66, 60),
				PropFactory.material("Concrete")
			)
			local zone = PropFactory.part(
				model,
				"ExitZone",
				Vector3.new(8, 8, 8),
				CFrame.new(porchCenter + Vector3.new(0, 4, 0)),
				Color3.fromRGB(180, 220, 255),
				PropFactory.material("Neon"),
				{ collide = false, transparency = 1, query = false, castShadow = false }
			)
			local porchLight = Instance.new("PointLight")
			porchLight.Color = Color3.fromRGB(170, 200, 255)
			porchLight.Range = 20
			porchLight.Brightness = 2
			porchLight.Enabled = false
			porchLight.Parent = zone
			world.exit = {
				door = exitDoor,
				zone = zone,
				light = porchLight,
				position = porchCenter,
				roomId = room.id,
				side = exitSide,
			}
		end
	end

	-- Seams and doors, once per pair of neighbouring rooms.
	for _, seam in layout.seams do
		local roomA, roomB = world.rooms[seam.a], world.rooms[seam.b]
		local delta = roomB.center - roomA.center
		local normal = delta.Unit
		local dirA = (math.abs(delta.X) > math.abs(delta.Z)) and (delta.X > 0 and "E" or "W")
			or (delta.Z > 0 and "S" or "N")
		local dirB = ({ N = "S", S = "N", E = "W", W = "E" })[dirA]
		local panels = { roomA.sides[dirA].panel, roomB.sides[dirB].panel }
		local midpoint = (roomA.center + roomB.center) / 2
		local record = {
			id = seam.id,
			a = seam.a,
			b = seam.b,
			connected = seam.connected,
			panels = panels,
			position = midpoint + Vector3.new(0, DOOR_H / 2, 0),
			floorPosition = midpoint,
			normal = normal,
		}
		for _, panel in panels do
			panel.CollisionGroup = Constants.CollisionGroups.Seam
			panel:SetAttribute(Attr.SeamId, seam.id)
			panel:SetAttribute(Attr.Connected, seam.connected)
			tag(panel, Tags.Seam)
			if seam.connected then
				panel.Transparency = 1
				panel.CanCollide = false
				panel.CanQuery = false
				panel.CastShadow = false
			end
		end
		roomA.sides[dirA].seam = record
		roomB.sides[dirB].seam = record
		world.seams[seam.id] = record

		if seam.connected and seam.door then
			local doorId = "door:" .. seam.a .. "-" .. seam.b
			local closed = CFrame.lookAt(
				midpoint + Vector3.new(0, DOOR_H / 2 - 0.05, 0),
				midpoint + Vector3.new(0, DOOR_H / 2 - 0.05, 0) + normal
			)
			local doorModel = Instance.new("Model")
			doorModel.Name = "Door"
			local slab = PropFactory.part(
				doorModel,
				"Slab",
				Vector3.new(DOOR_W - 0.2, DOOR_H - 0.2, 0.35),
				closed,
				Color3.fromRGB(96, 70, 50),
				PropFactory.material("Wood")
			)
			-- Hinge on the slab's +X edge, knob on the -X edge.
			local hinge = (closed * CFrame.new(DOOR_W / 2 - 0.1, 0, 0)).Position
			local knobOffset = -(DOOR_W / 2 - 0.7)
			PropFactory.part(
				doorModel,
				"Knob",
				Vector3.new(0.3, 0.3, 0.7),
				closed * CFrame.new(knobOffset, -0.5, 0),
				Color3.fromRGB(190, 170, 110),
				PropFactory.material("Metal"),
				{ collide = false }
			)
			slab.CollisionGroup = Constants.CollisionGroups.Door
			doorModel.PrimaryPart = slab
			doorModel.Parent = roomA.model
			setId(slab, doorId, "Door")
			tag(slab, Tags.Door)
			local door = {
				id = doorId,
				seamId = seam.id,
				a = seam.a,
				b = seam.b,
				model = doorModel,
				slab = slab,
				closedCFrame = doorModel:GetPivot(),
				hinge = hinge,
				open = false,
				bracedUntil = 0,
				lastBraced = -math.huge,
				position = midpoint,
			}
			world.doors[doorId] = door
			record.door = door
		end
	end

	world.rng = rng
	return world
end

return LevelBuilder
