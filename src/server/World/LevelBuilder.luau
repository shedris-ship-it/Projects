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
local Corridor = require(Shared.Logic.Corridor)
local LevelGraph = require(Shared.Logic.LevelGraph)
local Props = require(Shared.Data.Props)
local PropFactory = require(Shared.World.PropFactory)
local Rng = require(Shared.Lib.Rng)
local Dressing = require(script.Parent.Dressing)
local WindowView = require(Shared.Logic.WindowView)
local Grime = require(script.Parent.Grime)
local Trim = require(script.Parent.Trim)

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

-- `inner` (optional): the room's inner half extents in its own frame,
-- { x, z }, for rooms that aren't 40x40 cells (World/MansionBuilder).
local SIDE_LOCAL = {
	N = function(along, y, inner)
		return Vector3.new(along, y, -(inner and inner.z or INNER)), Vector3.new(0, 0, 1)
	end,
	S = function(along, y, inner)
		return Vector3.new(along, y, inner and inner.z or INNER), Vector3.new(0, 0, -1)
	end,
	W = function(along, y, inner)
		return Vector3.new(-(inner and inner.x or INNER), y, along), Vector3.new(1, 0, 0)
	end,
	E = function(along, y, inner)
		return Vector3.new(inner and inner.x or INNER, y, along), Vector3.new(-1, 0, 0)
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
local function wallCFrame(roomCF: CFrame, side: string, along: number, y: number, inner): CFrame
	local localPos, localNormal = SIDE_LOCAL[side](along, y, inner)
	local pos = roomCF:PointToWorldSpace(localPos)
	local normal = roomCF:VectorToWorldSpace(localNormal)
	return CFrame.lookAt(pos, pos + normal)
end
LevelBuilder.wallCFrame = wallCFrame

-- A wall position from template data: on an outer wall ({ side, along }) or on
-- any inner wall face, such as a corridor closet ({ x, z, face }, face being
-- the direction it faces). LookVector points into the room.
local function slotCFrame(roomCF: CFrame, slot, y: number, inner): CFrame
	if slot.face then
		local pos = roomCF:PointToWorldSpace(Vector3.new(slot.x, y, slot.z))
		local normal = roomCF:VectorToWorldSpace(WORLD_DIRS[slot.face])
		return CFrame.lookAt(pos, pos + normal)
	end
	return wallCFrame(roomCF, slot.side, slot.along, y, inner)
end
LevelBuilder.slotCFrame = slotCFrame

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

-- Build one wall layer of a room on a world side, in the room's wall
-- surface (color, material, variant).
local function buildWall(parent, center: Vector3, dirName: string, gap: boolean, surface)
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
			surface.color,
			surface.material,
			{ variant = surface.variant }
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

-- Which face of `part` points most nearly straight down (the pendant's glowing
-- disc is a cylinder stood on its side, so its "Bottom" isn't world down).
local function downFace(part: BasePart): Enum.NormalId
	local best, bestDot = Enum.NormalId.Bottom, -math.huge
	for _, face in
		{
			Enum.NormalId.Top,
			Enum.NormalId.Bottom,
			Enum.NormalId.Left,
			Enum.NormalId.Right,
			Enum.NormalId.Front,
			Enum.NormalId.Back,
		}
	do
		local dot = -part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face)).Y
		if dot > bestDot then
			best, bestDot = face, dot
		end
	end
	return best
end

local function lightFor(kind: string, parentPart: BasePart, template)
	local palette = Config.Lighting
	local light
	if kind == "lamp" then
		light = Instance.new("PointLight")
		light.Color = PropFactory.rgb(palette.Lamp)
		light.Range = palette.LampRange
		light.Brightness = palette.LampBrightness
	elseif kind == "tv" then
		light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Back
		light.Color = PropFactory.rgb(palette.Screen)
		light.Range = palette.ScreenRange
		light.Brightness = palette.ScreenBrightness
		light.Angle = palette.SurfaceAngle
	elseif kind == "window" then
		light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Front
		light.Color = PropFactory.rgb(palette.Moonlight)
		light.Range = palette.WindowRange
		light.Brightness = palette.WindowBrightness
		light.Angle = palette.SurfaceAngle
	else
		-- Ceiling light: fluorescent in utility rooms, tungsten everywhere else.
		local settings = template.light or {}
		local family = palette.Families[template.family] or palette.Families.living
		if palette.CeilingSpot and template.fixture ~= "bulb" then
			-- A cone aimed down: nothing above the fixture is lit (see Config.Lighting).
			-- (A bare bulb hangs well clear of the ceiling and lights all round:
			-- the cellar's joists, the attic's rafters.)
			local spot = Instance.new("SpotLight")
			spot.Face = downFace(parentPart)
			spot.Angle = palette.CeilingSpotAngle
			light = spot
		else
			light = Instance.new("PointLight")
		end
		light.Color = PropFactory.rgb(settings.color or palette[family.ceiling])
		light.Range = math.min((settings.range or 24) * palette.CeilingRangeScale, palette.CeilingMaxRange)
		light.Brightness = (settings.brightness or 1.2) * palette.CeilingBrightnessScale
	end
	light.Name = "KeyLight"
	light.Shadows = true
	light.Parent = parentPart
	return light
end

-- The ceiling light of a room without a lamp of its own (docs/ART.md,
-- Hero props): a flush fluorescent fixture in utility rooms, a bare bulb
-- where the template asks for one (`fixture = "bulb"`: the cellar), a
-- hanging drum pendant everywhere else. The pendant's shade stops at 8.6 studs so The
-- Guest (8.4) passes under it. Returns the glowing diffuser that carries the
-- room's key light.
local function ceilingFixture(parent, center: Vector3, family: string?): BasePart
	local fixture = Instance.new("Model")
	fixture.Name = "CeilingFixture"
	local glow = function(p: BasePart)
		p:SetAttribute(Attr.LampGlow, true)
		return p
	end
	local quiet = { collide = false, castShadow = false, query = false }
	local diffuser
	if family == "bulb" then
		-- A bare bulb on its flex, with a pull-chain (the cellar's).
		PropFactory.part(
			fixture,
			"Cord",
			Vector3.new(0.05, 1.2, 0.05),
			CFrame.new(center + Vector3.new(0, HEIGHT - 0.6, 0)),
			Color3.fromRGB(30, 28, 26),
			PropFactory.material("Fabric"),
			quiet
		)
		PropFactory.part(
			fixture,
			"Holder",
			Vector3.new(0.3, 0.35, 0.3),
			CFrame.new(center + Vector3.new(0, HEIGHT - 1.3, 0)),
			Color3.fromRGB(150, 128, 84),
			PropFactory.material("Metal"),
			quiet
		)
		PropFactory.part(
			fixture,
			"Chain",
			Vector3.new(0.04, 1.6, 0.04),
			CFrame.new(center + Vector3.new(0.18, HEIGHT - 2.2, 0)),
			Color3.fromRGB(170, 150, 110),
			PropFactory.material("Metal"),
			quiet
		)
		diffuser = glow(
			PropFactory.part(
				fixture,
				"CeilingLamp",
				Vector3.new(0.55, 0.55, 0.55),
				CFrame.new(center + Vector3.new(0, HEIGHT - 1.7, 0)),
				Color3.fromRGB(255, 226, 170),
				PropFactory.material("Neon"),
				{ collide = false, castShadow = false, query = false, shape = Enum.PartType.Ball }
			)
		)
	elseif family == "utility" then
		PropFactory.part(
			fixture,
			"Housing",
			Vector3.new(4.4, 0.25, 1.2),
			CFrame.new(center + Vector3.new(0, HEIGHT - 0.125, 0)),
			Color3.fromRGB(206, 206, 198),
			PropFactory.material("Metal"),
			quiet
		)
		diffuser = glow(
			PropFactory.part(
				fixture,
				"CeilingLamp",
				Vector3.new(4, 0.06, 0.9),
				CFrame.new(center + Vector3.new(0, HEIGHT - 0.28, 0)),
				Color3.fromRGB(226, 238, 230),
				PropFactory.material("Neon"),
				quiet
			)
		)
	else
		local round = { collide = false, castShadow = false, query = false, shape = Enum.PartType.Cylinder }
		local upright = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is X; stand it up
		PropFactory.part(
			fixture,
			"Canopy",
			Vector3.new(0.12, 0.6, 0.6),
			CFrame.new(center + Vector3.new(0, HEIGHT - 0.06, 0)) * upright,
			Color3.fromRGB(150, 128, 84),
			PropFactory.material("Metal"),
			round
		)
		PropFactory.part(
			fixture,
			"Cord",
			Vector3.new(0.05, 0.7, 0.05),
			CFrame.new(center + Vector3.new(0, HEIGHT - 0.45, 0)),
			Color3.fromRGB(30, 28, 26),
			PropFactory.material("Fabric"),
			quiet
		)
		-- A fabric drum, glowing faintly from the bulb inside, and a brighter
		-- diffuser underneath. The light is a downward cone (lightFor), so the
		-- ceiling right above stays dark, like a real shaded lamp. The shade no
		-- longer casts a shadow: with the light 0.02 under it, it only ever
		-- confused the shadow map.
		glow(
			PropFactory.part(
				fixture,
				"Shade",
				Vector3.new(0.7, 2.2, 2.2),
				CFrame.new(center + Vector3.new(0, HEIGHT - 1.05, 0)) * upright,
				Color3.fromRGB(150, 116, 70),
				PropFactory.material("Neon"),
				{ collide = false, castShadow = false, query = false, shape = Enum.PartType.Cylinder }
			)
		)
		diffuser = glow(
			PropFactory.part(
				fixture,
				"CeilingLamp",
				Vector3.new(0.04, 2, 2),
				CFrame.new(center + Vector3.new(0, HEIGHT - 1.42, 0)) * upright,
				Color3.fromRGB(240, 220, 176),
				PropFactory.material("Neon"),
				round
			)
		)
	end
	fixture.Parent = parent
	return diffuser
end

LevelBuilder.lightFor = lightFor
LevelBuilder.ceilingFixture = ceilingFixture

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

-- A room's contents from its template: furniture (or a hand-built prefab),
-- hiding spots, decor and windows, the key light and its bounce, tell slots,
-- the start room's spawns and Case Board, and a Lantern room's shrine.
-- ctx: { room (layout record: id, role, lantern), record, template, roomCF,
-- model, rng, center (floor point the room faces), prefabs, inner (optional
-- inner half extents), fixtureAt (optional: where the ceiling light hangs
-- from, for a double-height room), facesOutside(slot), inFilledArm(x, z),
-- wallInFilledArm(slot) }.
function LevelBuilder.furnish(world, ctx)
	local room, record, template = ctx.room, ctx.record, ctx.template
	local roomCF, model, rng, center = ctx.roomCF, ctx.model, ctx.rng, ctx.center
	local prefabs, inner = ctx.prefabs, ctx.inner
	local facesOutside, inFilledArm, wallInFilledArm = ctx.facesOutside, ctx.inFilledArm, ctx.wallInFilledArm
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
			if inFilledArm(prop.x, prop.z) then
				continue
			end
			local cf = roomCF * CFrame.new(prop.x, 0, prop.z) * CFrame.Angles(0, math.rad(prop.ry or 0), 0)
			local propModel, lightPart = PropFactory.build(prop.kind, cf, model, { name = prop.id })
			local propId = "prop:" .. room.id .. ":" .. prop.id
			propModel:SetAttribute(Attr.CId, propId)
			record.props[prop.id] = { model = propModel, cframe = cf, kind = prop.kind, id = propId }
			table.insert(
				world.props,
				{ id = propId, model = propModel, roomId = room.id, kind = prop.kind, frame = cf }
			)
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
					-- A walk-in closet: hidden by standing inside with its doors
					-- shut (Services/HidingService), not by a prompt.
					physical = kind.physical,
					interior = kind.physical and {
						cframe = cf * CFrame.new(0, h / 2, -0.3),
						size = Vector3.new(w - 0.6, h, d - 0.9),
					} or nil,
				}
				if kind.physical then
					-- Its mirrors are panes he can show in (Lib/GuestReflection).
					for _, door in propModel:GetChildren() do
						if door:GetAttribute("Kind") == "Mirror" then
							CollectionService:AddTag(door, Tags.Window)
						end
					end
				end
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
			-- A window that still faces another room after LevelGraph turned the
			-- room is left out; if it was the key light, the ceiling lamp below
			-- takes over.
			if (decor.kind == "Window" and not facesOutside(decor)) or wallInFilledArm(decor) then
				continue
			end
			local cf = slotCFrame(roomCF, decor, decor.y, inner)
			-- What is outside this window: which covering it has, and the moon where one
			-- faces it. Its own fork of the seed, so no other part of the house moves.
			local decorOptions
			if decor.kind == "Window" then
				local outward = -cf.LookVector
				decorOptions = {
					key = decor.key == true,
					view = WindowView.view(
						rng:Fork("window:" .. room.id .. ":" .. decor.id),
						WindowView.azimuth(outward.X, outward.Z),
						world.moon,
						Config.Window
					),
				}
			end
			local decorModel, lightPart =
				PropFactory.buildDecor(decor.kind, cf, model, room.id * 100 + #decor.id, decorOptions)
			decorModel:SetAttribute(Attr.CId, "decor:" .. room.id .. ":" .. decor.id)
			if decor.key and lightPart then
				keyLightPart, keyLightKind = lightPart, "window"
			end
			if decor.kind == "Painting" then
				record.paintings = record.paintings or {}
				table.insert(record.paintings, { model = decorModel, cframe = cf })
			end
			-- Panes The Guest can show in: his reflection behind you, or a
			-- face at the glass (Lib/GuestReflection).
			local glass = decorModel:FindFirstChild("Glass")
			if (decor.kind == "Window" or decor.kind == "Mirror") and glass then
				decorModel:SetAttribute("Kind", decor.kind)
				CollectionService:AddTag(decorModel, Tags.Window)
				record.windows = record.windows or {}
				table.insert(record.windows, { glass = glass, kind = decor.kind, cframe = cf })
			end
		end
	end

	-- Key light: one motivated source per room (doc section 8).
	if not keyLightPart then
		keyLightPart = ceilingFixture(model, ctx.fixtureAt or center, template.fixture or template.family)
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
	-- What lights it: "ceiling", "lamp", "tv" or "window" (moonlight, which
	-- no switch or breaker turns off: WorldService:SetLightCause).
	record.lightKind = keyLightKind or "ceiling"

	-- Bounce: a room lit only by a window or TV gets a soft light in front of
	-- it, standing in for light off the walls (warm for a TV, moonlight for a
	-- window). It casts shadows so it can't leak into the next room, and it's
	-- tagged like the key light so flickers and blackouts take it too.
	if light:IsA("SurfaceLight") then
		local lighting = Config.Lighting
		local facing = light.Face == Enum.NormalId.Back and -keyLightPart.CFrame.LookVector
			or keyLightPart.CFrame.LookVector
		local flat = Vector3.new(facing.X, 0, facing.Z)
		local offset = flat.Magnitude > 0.1 and flat.Unit * lighting.BounceOffset or Vector3.zero
		local bouncePart = PropFactory.part(
			model,
			"BounceLight",
			Vector3.new(0.2, 0.2, 0.2),
			CFrame.new(keyLightPart.Position + offset + Vector3.new(0, 1.5, 0)),
			Color3.new(),
			PropFactory.material("SmoothPlastic"),
			{ collide = false, transparency = 1, query = false, castShadow = false }
		)
		local bounce = Instance.new("PointLight")
		bounce.Name = "BounceLight"
		bounce.Shadows = true
		bounce.Range = lighting.BounceRange
		bounce.Brightness = lighting.BounceBrightness
		bounce.Color = PropFactory.rgb(keyLightKind == "tv" and lighting.Lamp or lighting.Moonlight)
		bounce.Parent = bouncePart
		bouncePart:SetAttribute(Attr.RoomId, room.id)
		tag(bouncePart, Tags.RoomLight)
		record.bounce = bounce
	end

	-- Slots for tells and Sources.
	-- `outside` marks slots on an outer wall, for tells that need one (a window).
	for _, slot in template.wallSlots do
		if not wallInFilledArm(slot) then
			table.insert(record.wallSlots, {
				cframe = slotCFrame(roomCF, slot, slot.y or 6.5, inner),
				outside = facesOutside(slot),
				used = false,
			})
		end
	end
	for _, slot in template.floorSlots do
		if inFilledArm(slot.x, slot.z) then
			continue
		end
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
	end
	if room.lantern and template.shrine then
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
end

-- The exit: its door in the wall (casing, panels, knob, EXIT sign), the porch
-- outside and the zone that counts as out. `dir` points out of the room;
-- `doorPos` is the doorway's centre, `face` the wall's inner face at floor
-- level, `porchCenter` the porch's centre at ground level.
function LevelBuilder.exitDoor(
	world,
	model,
	roomId: number,
	side: string,
	dir: Vector3,
	doorPos: Vector3,
	face: Vector3,
	porchCenter: Vector3
)
	Trim.exitCasing(model, CFrame.lookAt(face, face - dir))
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
		{
			color = Color3.fromRGB(200, 60, 50),
			ppu = Config.Exit.Sign.ppu,
			size = UDim2.fromScale(Config.Exit.Sign.w, Config.Exit.Sign.h),
			position = UDim2.fromScale(Config.Exit.Sign.x, Config.Exit.Sign.y),
		}
	)
	-- Panels, a knob and a kick plate on the house side, like the other doors
	-- (they are children, so they open with the slab).
	local inner = CFrame.lookAt(doorPos, doorPos - dir)
	local brass = Color3.fromRGB(176, 142, 74)
	local function detail(name, detailSize, offset, colour, material, shape)
		return PropFactory.part(
			exitDoor,
			name,
			detailSize,
			inner * offset,
			colour,
			PropFactory.material(material),
			{ collide = false, castShadow = false, shape = shape }
		)
	end
	local exitCfg = Config.Exit
	for _, sx in { -1, 1 } do
		detail(
			"Panel",
			Vector3.new(DOOR_W * exitCfg.PanelSize[1], DOOR_H * exitCfg.PanelSize[2], 0.08),
			CFrame.new(sx * DOOR_W * exitCfg.PanelOffset[1], DOOR_H * exitCfg.PanelOffset[2], -0.34),
			Color3.fromRGB(78, 54, 40),
			"Wood"
		)
	end
	detail(
		"KickPlate",
		Vector3.new(DOOR_W - 0.7, exitCfg.KickPlateHeight, 0.06),
		CFrame.new(0, -DOOR_H / 2 + 0.6, -0.32),
		brass,
		"Metal"
	)
	detail(
		"KnobPlate",
		Vector3.new(exitCfg.KnobPlate[1], exitCfg.KnobPlate[2], 0.06),
		CFrame.new(DOOR_W * exitCfg.KnobOffset[1], DOOR_H * exitCfg.KnobOffset[2], -0.33),
		brass,
		"Metal"
	)
	detail(
		"Knob",
		Vector3.new(0.45, 0.45, 0.45),
		CFrame.new(DOOR_W * exitCfg.KnobOffset[1], DOOR_H * exitCfg.KnobOffset[2], -0.55),
		brass,
		"Metal",
		Enum.PartType.Ball
	)
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
		roomId = roomId,
		side = side,
	}
end

-- The door in a connected seam: a panelled slab hinged on one jamb, some
-- resting ajar (from `ajarRng`). `midpoint` is the doorway's centre at floor
-- level and `normal` points from room A to room B.

-- The room side of a hidden door (docs/plans/level-design.md section 10.4):
-- a bookcase, or a panel of the room's own wall with only a hairline round
-- it. No knob, no casing; it swings out into the room. Its tells: a book
-- pulled half out, or the hairline, and a scuffed arc on the floor where it
-- swings. `closed` is the slab's frame; +Z faces the room.
local function disguise(doorModel, closed: CFrame, hidden)
	local quiet = { collide = false, query = false, castShadow = true }
	local face = closed * CFrame.new(0, 0, WALL)
	if hidden.kind == "bookcase" then
		local wood = PropFactory.rgb(Config.Trim.Wood)
		local depth = 0.9
		local w, h = DOOR_W - 0.1, DOOR_H - 0.1
		local inside = face * CFrame.new(0, 0, depth / 2)
		PropFactory.part(
			doorModel,
			"CaseBack",
			Vector3.new(w, h, 0.1),
			face * CFrame.new(0, 0, 0.05),
			wood,
			PropFactory.material("Wood"),
			quiet
		)
		for _, sx in { -1, 1 } do
			PropFactory.part(
				doorModel,
				"CaseSide",
				Vector3.new(0.25, h, depth),
				inside * CFrame.new(sx * (w / 2 - 0.125), 0, 0),
				wood,
				PropFactory.material("Wood"),
				quiet
			)
		end
		local rng = Rng.new(Rng.hash(tostring(closed.Position)))
		local rows = 4
		local pulled = rng:NextInteger(1, rows)
		for i = 0, rows do
			local y = -h / 2 + 0.15 + i * (h - 0.3) / rows
			PropFactory.part(
				doorModel,
				"Board",
				Vector3.new(w - 0.5, 0.2, depth),
				inside * CFrame.new(0, y, 0),
				wood,
				PropFactory.material("Wood"),
				quiet
			)
			if i < rows then
				local x = -w / 2 + 0.4
				local first = true
				while x < w / 2 - 0.8 do
					local bw = rng:NextNumber(0.3, 0.6)
					local bh = rng:NextNumber(1, 1.5)
					local tint = Color3.fromHSV(rng:NextNumber(), 0.35, rng:NextNumber(0.25, 0.55))
					-- The tell: one book in a row pulled half out.
					local out = (i + 1 == pulled and first and x > -0.5) and 0.45 or 0
					if out > 0 then
						first = false
					end
					PropFactory.part(
						doorModel,
						"Book",
						Vector3.new(bw, bh, depth - 0.3),
						inside * CFrame.new(x + bw / 2, y + 0.1 + bh / 2, out),
						tint,
						PropFactory.material("SmoothPlastic"),
						{ collide = false, query = false, castShadow = false }
					)
					x += bw + rng:NextNumber(0, 0.3)
				end
			end
		end
	else
		local surface = hidden.surface
		PropFactory.part(
			doorModel,
			"WallPanel",
			Vector3.new(DOOR_W - 0.12, DOOR_H - 0.12, 0.06),
			face * CFrame.new(0, 0, 0.03),
			surface.color,
			surface.material,
			{ variant = surface.variant, collide = false, query = false }
		)
		-- The hairline round it.
		local dark = Color3.fromRGB(18, 16, 14)
		for _, edge in
			{
				{ x = 0, y = DOOR_H / 2 - 0.03, w = DOOR_W, h = 0.06 },
				{ x = -DOOR_W / 2 + 0.03, y = 0, w = 0.06, h = DOOR_H },
				{ x = DOOR_W / 2 - 0.03, y = 0, w = 0.06, h = DOOR_H },
			}
		do
			PropFactory.part(
				doorModel,
				"Hairline",
				Vector3.new(edge.w, edge.h, 0.02),
				face * CFrame.new(edge.x, edge.y, 0.01),
				dark,
				PropFactory.material("SmoothPlastic"),
				{ collide = false, query = false, castShadow = false }
			)
		end
		-- The baseboard carries on across it.
		PropFactory.part(
			doorModel,
			"Baseboard",
			Vector3.new(DOOR_W - 0.12, 0.55, 0.12),
			face * CFrame.new(0, -DOOR_H / 2 + 0.33, 0.1),
			PropFactory.rgb(Config.Trim.Wood),
			PropFactory.material("Wood"),
			{ collide = false, query = false }
		)
	end
end

-- The scuffed arc on the floor where a hidden door swings into the room.
local function scuffs(parent, hinge: Vector3, closed: CFrame)
	local floorY = hinge.Y - DOOR_H / 2 + 0.05 + 0.03
	local dark = Color3.fromRGB(34, 28, 22)
	local radius = DOOR_W - 0.6
	for i = 1, 7 do
		local angle = math.rad(i * 11)
		local away = -closed.RightVector
		local into = closed.LookVector * -1
		local dir = away * math.cos(angle) + into * math.sin(angle)
		local at = Vector3.new(hinge.X, floorY, hinge.Z) + dir * radius
		PropFactory.part(
			parent,
			"Scuff",
			Vector3.new(0.12, 0.02, 0.9),
			CFrame.lookAt(at, at + dir:Cross(Vector3.yAxis)),
			dark,
			PropFactory.material("SmoothPlastic"),
			{ collide = false, query = false, castShadow = false, transparency = 0.55 }
		)
	end
end

-- `hidden` (a servants' passage's door): { kind = "bookcase" | "panel",
-- surface = the room's wall }; its room is seam.a, on the slab's +Z side.
function LevelBuilder.seamDoor(world, seam, record, roomA, midpoint: Vector3, normal: Vector3, ajarRng, hidden, glazed)
	local doorId = "door:" .. seam.a .. "-" .. seam.b
	local full = CFrame.lookAt(
		midpoint + Vector3.new(0, DOOR_H / 2 - 0.05, 0),
		midpoint + Vector3.new(0, DOOR_H / 2 - 0.05, 0) + normal
	)
	local doorModel = Instance.new("Model")
	doorModel.Name = "Door"
	-- Dark panelled wood (docs/ART.md, Materials): four raised panels on
	-- each face catch the light, with the knob on the lock rail.
	local doorColor = PropFactory.rgb(Config.Trim.Wood)
	local height = DOOR_H - 0.2
	-- A glazed door (`glazed`: a gate into a wing, docs/plans/level-design.md
	-- section 10.7) is solid only up to its sill; the glass above lets you see
	-- into the wing before you can get in, and lets sight through too (it
	-- doesn't collide, and rays only meet what does).
	local G = Config.Trim.GlassDoor
	local closed = full
	if glazed then
		closed = full * CFrame.new(0, -height / 2 + G.Sill / 2, 0)
	end
	local slab = PropFactory.part(
		doorModel,
		"Slab",
		Vector3.new(DOOR_W - 0.2, glazed and G.Sill or height, 0.35),
		closed,
		doorColor,
		PropFactory.material("Wood")
	)
	-- (A hidden door is panelled on its passage side only; a glazed one
	-- below its glass only.)
	for _, z in hidden and { -0.2 } or { -0.2, 0.2 } do
		for _, x in { -1.25, 1.25 } do
			for _, panel in glazed and { { y = -2.2, h = 2.4 } } or { { y = 1.55, h = 3.6 }, { y = -2.2, h = 2.4 } } do
				PropFactory.part(
					doorModel,
					"Panel",
					Vector3.new(2, panel.h, 0.06),
					full * CFrame.new(x, panel.y, z),
					PropFactory.shade(doorColor, 1.18),
					PropFactory.material("Wood"),
					{ collide = false, query = false, castShadow = false }
				)
			end
		end
	end
	if glazed then
		local sill = -height / 2 + G.Sill
		local top = height / 2 - G.Rail
		local glassH = top - sill
		local quiet = { collide = false, query = false, castShadow = false }
		for _, sx in { -1, 1 } do
			PropFactory.part(
				doorModel,
				"Stile",
				Vector3.new(G.Stile, glassH, 0.35),
				full * CFrame.new(sx * (DOOR_W / 2 - 0.1 - G.Stile / 2), sill + glassH / 2, 0),
				doorColor,
				PropFactory.material("Wood"),
				quiet
			)
		end
		PropFactory.part(
			doorModel,
			"Rail",
			Vector3.new(DOOR_W - 0.2, G.Rail, 0.35),
			full * CFrame.new(0, height / 2 - G.Rail / 2, 0),
			doorColor,
			PropFactory.material("Wood"),
			quiet
		)
		PropFactory.part(
			doorModel,
			"Muntin",
			Vector3.new(0.14, glassH, 0.2),
			full * CFrame.new(0, sill + glassH / 2, 0),
			doorColor,
			PropFactory.material("Wood"),
			quiet
		)
		PropFactory.part(
			doorModel,
			"Glass",
			Vector3.new(DOOR_W - 0.2 - 2 * G.Stile, glassH, 0.06),
			full * CFrame.new(0, sill + glassH / 2, 0),
			Color3.fromRGB(150, 165, 160),
			PropFactory.material("Glass"),
			{ collide = false, query = false, castShadow = false, transparency = G.Transparency, reflectance = 0.15 }
		)
	end
	-- Hinge on the slab's +X edge, knob on the -X edge.
	local hinge = (full * CFrame.new(DOOR_W / 2 - 0.1, 0, 0)).Position
	local knobOffset = -(DOOR_W / 2 - 0.7)
	if hidden then
		-- A plain latch on the passage side; the room side is disguised.
		PropFactory.part(
			doorModel,
			"Latch",
			Vector3.new(0.9, 0.2, 0.2),
			full * CFrame.new(knobOffset + 0.3, -0.3, -0.25),
			PropFactory.rgb(Config.Trim.Knob),
			PropFactory.material("Metal"),
			{ collide = false }
		)
		disguise(doorModel, full, hidden)
	else
		PropFactory.part(
			doorModel,
			"Knob",
			Vector3.new(0.3, 0.3, 0.7),
			full * CFrame.new(knobOffset, -0.5, 0),
			PropFactory.rgb(Config.Trim.Knob),
			PropFactory.material("Metal"),
			{ collide = false }
		)
	end
	slab.CollisionGroup = Constants.CollisionGroups.Door
	doorModel.PrimaryPart = slab
	-- Some doors rest slightly ajar with darkness behind them (docs/ART.md).
	-- Still closed for play: it blocks the way until someone opens it.
	local ajar = ajarRng:Chance(Config.Trim.AjarChance) and not hidden
	if ajar then
		local swing = CFrame.new(hinge) * CFrame.Angles(0, math.rad(Config.Trim.AjarAngle), 0) * CFrame.new(-hinge)
		for _, p in doorModel:GetChildren() do
			if p:IsA("BasePart") then
				p.CFrame = swing * p.CFrame
			end
		end
	end
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
		closedCFrame = closed,
		hinge = hinge,
		restAngle = ajar and Config.Trim.AjarAngle or 0, -- where it was built (DoorService swings it from here)
		-- A hidden door swings out into its room (it would block the narrow
		-- passage the other way).
		openSign = hidden and -1 or nil,
		hidden = hidden ~= nil,
		open = false,
		bracedUntil = 0,
		lastBraced = -math.huge,
		position = midpoint,
	}
	world.doors[doorId] = door
	record.door = door
	if hidden then
		scuffs(roomA.model, hinge, full)
	end
end

-- A seam's panels (one per wall layer): solid on a wall, invisible and open
-- on a doorway, and tagged so a divergence can flip them for one Witness.
function LevelBuilder.markSeamPanels(panels, seam)
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
		-- One moon a run, in a fixed compass direction (Logic/WindowView): a window
		-- shows it only if it looks that way. A fork, so nothing else moves.
		moon = WindowView.moon(rng:Fork("moon"), Config.Window),
	}
	local cells = layout.cells
	local prefabs = ServerStorage:FindFirstChild("RoomPrefabs")

	local function neighbourAt(room, dirName)
		local d = WORLD_DIRS[dirName]
		return cells[(room.gx + d.X) .. "," .. (room.gz + d.Z)]
	end

	-- Whether a wall position from template data ({ side, along }) is on an
	-- outer wall. Closet faces ({ x, z, face }) are always indoors.
	local function facesOutside(room, slot): boolean
		return slot.side ~= nil and neighbourAt(room, LevelGraph.worldSide(slot.side, room.rotation)) == nil
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

		-- Surfaces (docs/ART.md, Materials): the house's MaterialVariants,
		-- tinted by each template's colours.
		local wallColor = PropFactory.rgb(template.wall.color)
		local wallMaterial, wallVariant = PropFactory.surface(template.wall.material)
		local wallSurface = { color = wallColor, material = wallMaterial, variant = wallVariant }
		local wainscot = nil
		if template.wainscot then
			local material, variant = PropFactory.surface(Config.Trim.Wainscot.material)
			wainscot = { color = PropFactory.rgb(Config.Trim.Wainscot.color), material = material, variant = variant }
		end
		local floorMaterial, floorVariant = PropFactory.surface(template.floor.material)
		PropFactory.part(
			model,
			"Floor",
			Vector3.new(CELL, 1, CELL),
			CFrame.new(center - Vector3.new(0, 0.5, 0)),
			PropFactory.rgb(template.floor.color),
			floorMaterial,
			{ variant = floorVariant }
		)
		local ceiling = Config.Ceiling
		local ceilingMaterial, ceilingVariant = PropFactory.surface(ceiling.material)
		PropFactory.part(
			model,
			"Ceiling",
			Vector3.new(CELL, 1, CELL),
			CFrame.new(center + Vector3.new(0, HEIGHT + 0.5, 0)),
			PropFactory.rgb(ceiling.color):Lerp(wallColor, ceiling.wallTint),
			ceilingMaterial,
			{ variant = ceilingVariant }
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
			wallSurface = wallSurface,
			wainscot = wainscot,
		}
		world.rooms[room.id] = record

		-- Walls: every side gets this room's own wall layer.
		for _, dirName in { "N", "E", "S", "W" } do
			local neighbour = neighbourAt(room, dirName)
			local isExitSide = room.id == layout.exit and dirName == exitSide
			local panel = buildWall(model, center, dirName, neighbour ~= nil or isExitSide, wallSurface)
			record.sides[dirName] = { neighbour = neighbour, panel = panel, exit = isExitSide }
		end

		-- Corridor rooms: closets fill the four corners, leaving a plus-shaped
		-- hallway (docs/ART.md, Scale), and arms that end at an outside wall are
		-- filled in too (Logic/Corridor). They match the walls exactly so nothing
		-- marks them out, and the doorway lanes and centre stay clear for the
		-- stalker's walker (Stalker/Walker). Anything the template put in a filled arm is
		-- left out.
		local filledArms = Corridor.filledArms(template, room, cells)
		local function inFilledArm(x: number, z: number): boolean
			local arm = template.corridor and Corridor.armOf(template.corridor.halfWidth, x, z)
			return arm ~= nil and filledArms[arm] == true
		end
		local function wallInFilledArm(slot): boolean
			local arm = template.corridor and Corridor.armOfWall(template.corridor.halfWidth, slot)
			return arm ~= nil and filledArms[arm] == true
		end
		if template.corridor then
			local h = template.corridor.halfWidth
			local depth = INNER - h
			local c = (h + INNER) / 2
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					PropFactory.part(
						model,
						"Closet",
						Vector3.new(depth, HEIGHT, depth),
						roomCF * CFrame.new(sx * c, HEIGHT / 2, sz * c),
						wallColor,
						wallMaterial,
						{ variant = wallVariant }
					)
				end
			end
			-- The world sides whose arms stay open, for picking walkable points.
			record.corridor = h
			record.corridorOpen = {}
			for _, side in { "N", "E", "S", "W" } do
				if filledArms[side] then
					local axis = SIDE_LOCAL[side](0, 0).Unit
					local size = axis.Z ~= 0 and Vector3.new(2 * h, HEIGHT, depth) or Vector3.new(depth, HEIGHT, 2 * h)
					PropFactory.part(
						model,
						"Closet",
						size,
						roomCF * CFrame.new(axis * c + Vector3.new(0, HEIGHT / 2, 0)),
						wallColor,
						wallMaterial,
						{ variant = wallVariant }
					)
				else
					record.corridorOpen[LevelGraph.worldSide(side, room.rotation)] = true
				end
			end
		end

		-- Baseboards and crown on every wall face; doorway casings come with the
		-- seams below, so they can flip with them.
		local openings = {}
		for dirName, side in record.sides do
			openings[dirName] = side.neighbour ~= nil or side.exit
		end
		Trim.room(model, center, roomCF, WORLD_DIRS, openings, template.corridor and {
			halfWidth = template.corridor.halfWidth,
			filled = filledArms,
			rotate = function(side)
				return LevelGraph.worldSide(side, room.rotation)
			end,
		}, wainscot)

		LevelBuilder.furnish(world, {
			room = room,
			record = record,
			template = template,
			roomCF = roomCF,
			model = model,
			rng = rng,
			center = center,
			prefabs = prefabs,
			facesOutside = function(slot)
				return facesOutside(room, slot)
			end,
			inFilledArm = inFilledArm,
			wallInFilledArm = wallInFilledArm,
		})

		if room.role == "exit" and exitSide then
			local dir = WORLD_DIRS[exitSide]
			local side = record.sides[exitSide]
			if side.panel then
				side.panel:Destroy()
				side.panel = nil
			end
			LevelBuilder.exitDoor(
				world,
				model,
				room.id,
				exitSide,
				dir,
				center + dir * HALF + Vector3.new(0, DOOR_H / 2, 0),
				center + dir * INNER,
				center + dir * (HALF + 6)
			)
		end
	end

	-- Seams and doors, once per pair of neighbouring rooms. Which doors rest
	-- ajar comes from its own fork, so it changes nothing else a seed builds.
	local ajarRng = rng:Fork("ajar")
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
		LevelBuilder.markSeamPanels(panels, seam)
		roomA.sides[dirA].seam = record
		roomB.sides[dirB].seam = record
		world.seams[seam.id] = record
		local faceA = roomA.center + WORLD_DIRS[dirA] * INNER
		local faceB = roomB.center + WORLD_DIRS[dirB] * INNER
		Trim.seam(record, {
			{
				parent = roomA.model,
				face = CFrame.lookAt(faceA, faceA - WORLD_DIRS[dirA]),
				surface = roomA.wallSurface,
				wainscot = roomA.wainscot,
			},
			{
				parent = roomB.model,
				face = CFrame.lookAt(faceB, faceB - WORLD_DIRS[dirB]),
				surface = roomB.wallSurface,
				wainscot = roomB.wainscot,
			},
		}, midpoint, normal)

		if seam.connected and seam.door then
			LevelBuilder.seamDoor(world, seam, record, roomA, midpoint, normal, ajarRng)
		end
	end

	-- Grime last, so it can keep clear of everything placed before it. Its own
	-- fork, so it changes nothing else a seed builds.
	Grime.build(world, rng:Fork("grime"))
	Dressing.build(world, rng:Fork("dressing"))

	world.rng = rng
	return world
end

LevelBuilder.WALL = WALL
LevelBuilder.tag = tag
LevelBuilder.setId = setId

return LevelBuilder
