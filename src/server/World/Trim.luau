-- Trim for The Halfway House (docs/ART.md, step 3): baseboards and crown
-- moulding along every wall face, casings around doorways and the exit door,
-- and the pieces that flip with a seam. Trim catching the light is the
-- cheapest way to make a box read as a room, and casings are painted lighter
-- than the walls so exits read (rule 4). Trim never collides, casts no shadow
-- and never blocks a raycast.
--
-- Seams must be invisible (rule 3): every seam gets a baseboard piece across
-- it, shown while it's a wall, and a doorway casing and lining, shown while
-- it's a doorway. PerceptionController flips both with the seam, so a phantom
-- doorway is framed like a real one and a hidden doorway leaves an unbroken
-- baseboard.
--
-- The wall surface flips the same way. Roblox starts a material's pattern
-- afresh on every part, so a patterned wall built from pieces and a seam panel
-- would show a door-shaped outline. A thin skin over the wall face hides that:
-- one unbroken piece while the seam reads as a wall, three pieces around the
-- opening while it reads as a doorway.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local PropFactory = require(Shared.World.PropFactory)

local Attr = Constants.Attributes
local T = Config.Trim

local HALF = Config.Level.CellSize / 2
local WALL = Config.Level.WallThickness
local INNER = HALF - WALL
local HEIGHT = Config.Level.WallHeight
local DOOR_W = Config.Level.DoorWidth
local DOOR_H = Config.Level.DoorHeight
local EDGE = DOOR_W / 2 + T.CasingWidth -- where the baseboard meets a casing

local SKIN_DEPTH = 0.02 -- behind every wall-mounted prop and tell, the closest at 0.025
local UP = Vector3.new(0, 1, 0)
local NO_BLOCK = { collide = false, query = false, castShadow = false }

local Trim = {}

local function wood(): (Color3, Enum.Material)
	return PropFactory.rgb(T.Wood), PropFactory.material("Wood")
end

local function paint(): (Color3, Enum.Material)
	return PropFactory.rgb(T.Paint), PropFactory.material("Wood")
end

-- A strip lying on a wall face between two floor points `a` and `b` (in the
-- frame `frame`), standing out `depth` along `normal`, from `y` up `height`.
local function segment(
	parent,
	name,
	frame: CFrame,
	a: Vector3,
	b: Vector3,
	normal: Vector3,
	y,
	height,
	depth,
	color,
	material,
	variant: string?
)
	local length = (b - a).Magnitude
	if length < 0.05 then
		return nil
	end
	local mid = (a + b) / 2 + normal * (depth / 2) + UP * (y + height / 2)
	return PropFactory.part(
		parent,
		name,
		Vector3.new(length, height, depth),
		frame * CFrame.lookAt(mid, mid + normal),
		color,
		material,
		{ collide = false, query = false, castShadow = false, variant = variant }
	)
end

-- The lower third of a formal room's walls: wood panelling under a dado rail
-- (docs/ART.md, Materials). `wainscot` is the panelling's surface.
local function wainscotStrip(parent, frame: CFrame, a: Vector3, b: Vector3, normal: Vector3, wainscot)
	local panel = segment(
		parent,
		"Wainscot",
		frame,
		a,
		b,
		normal,
		0,
		T.WainscotHeight,
		T.WainscotDepth,
		wainscot.color,
		wainscot.material,
		wainscot.variant
	)
	local color, material = wood()
	local rail = segment(
		parent,
		"DadoRail",
		frame,
		a,
		b,
		normal,
		T.WainscotHeight - T.DadoHeight / 2,
		T.DadoHeight,
		T.DadoDepth,
		color,
		material
	)
	return panel, rail
end

-- Baseboard and crown along a stretch of wall face from `a` to `b`, and the
-- wainscot if the room has one. With `doorway`, the baseboard and wainscot
-- stop at the casing around the middle of the stretch; the crown runs
-- unbroken over the lintel.
local function run(parent, frame: CFrame, a: Vector3, b: Vector3, normal: Vector3, doorway: boolean, wainscot)
	local color, material = wood()
	if wainscot then
		if doorway then
			local mid = (a + b) / 2
			local along = (b - a).Unit
			wainscotStrip(parent, frame, a, mid - along * EDGE, normal, wainscot)
			wainscotStrip(parent, frame, mid + along * EDGE, b, normal, wainscot)
		else
			wainscotStrip(parent, frame, a, b, normal, wainscot)
		end
	end
	if doorway then
		local mid = (a + b) / 2
		local along = (b - a).Unit
		segment(
			parent,
			"Baseboard",
			frame,
			a,
			mid - along * EDGE,
			normal,
			0,
			T.BaseboardHeight,
			T.BaseboardDepth,
			color,
			material
		)
		segment(
			parent,
			"Baseboard",
			frame,
			mid + along * EDGE,
			b,
			normal,
			0,
			T.BaseboardHeight,
			T.BaseboardDepth,
			color,
			material
		)
	else
		segment(parent, "Baseboard", frame, a, b, normal, 0, T.BaseboardHeight, T.BaseboardDepth, color, material)
	end
	segment(parent, "Crown", frame, a, b, normal, HEIGHT - T.CrownHeight, T.CrownHeight, T.CrownDepth, color, material)
end

-- Baseboard (and wainscot) along a stretch of wall face from `a` to `b`,
-- broken for doorways centred at `cuts` (distances from `a`), and the crown
-- above unless `crown` is false (the lower storey of a double-height room);
-- `baseboard` false leaves the baseboard off (a stairwell's upper storey has
-- no floor along most of its walls). For rooms of any size
-- (World/MansionBuilder); `frame` is the frame the points are in, at floor
-- level.
function Trim.stretch(
	parent,
	frame: CFrame,
	a: Vector3,
	b: Vector3,
	normal: Vector3,
	cuts,
	wainscot,
	crown: boolean?,
	baseboard: boolean?
)
	local color, material = wood()
	local length = (b - a).Magnitude
	local along = (b - a).Unit
	local sorted = table.clone(cuts)
	table.sort(sorted)
	local from = 0
	local pieces = {}
	for _, cut in sorted do
		table.insert(pieces, { from, cut - EDGE })
		from = cut + EDGE
	end
	table.insert(pieces, { from, length })
	for _, piece in pieces do
		if baseboard ~= false and piece[2] - piece[1] > 0.05 then
			local p0, p1 = a + along * piece[1], a + along * piece[2]
			if wainscot then
				wainscotStrip(parent, frame, p0, p1, normal, wainscot)
			end
			segment(parent, "Baseboard", frame, p0, p1, normal, 0, T.BaseboardHeight, T.BaseboardDepth, color, material)
		end
	end
	if crown ~= false then
		segment(
			parent,
			"Crown",
			frame,
			a,
			b,
			normal,
			HEIGHT - T.CrownHeight,
			T.CrownHeight,
			T.CrownDepth,
			color,
			material
		)
	end
end

-- Every wall face of a room. `dirs` maps world side names to unit vectors;
-- `openings[side]` is true where the side has a doorway-sized opening (a seam
-- or the exit). For a corridor room, `corridor` = { halfWidth, filled, rotate }
-- where `filled` holds the template sides of filled arms and `rotate` turns a
-- template side into a world side. `wainscot` (a surface: color, material,
-- variant) panels the lower third of the walls; corridors never have one.
function Trim.room(parent, center: Vector3, roomCF: CFrame, dirs, openings, corridor, wainscot)
	local world = CFrame.new(center)
	for side, dir in dirs do
		local perp = Vector3.new(math.abs(dir.Z), 0, math.abs(dir.X))
		local reach = INNER
		local covered = false
		if corridor then
			-- Only the end of each arm shows the outer wall; a filled arm hides it.
			reach = corridor.halfWidth
			for filledSide in corridor.filled do
				if corridor.rotate(filledSide) == side then
					covered = true
				end
			end
		end
		if not covered then
			run(
				parent,
				world,
				dir * INNER - perp * reach,
				dir * INNER + perp * reach,
				-dir,
				openings[side] == true,
				not corridor and wainscot or nil
			)
		end
	end
	if not corridor then
		return
	end

	-- Closet faces and arm fills, in the room's own frame. A face lining an
	-- open arm gets trim; where it meets the junction it wraps the corner.
	local h = corridor.halfWidth
	local filled = corridor.filled
	local armX = function(sx)
		return sx < 0 and "W" or "E"
	end
	local armZ = function(sz)
		return sz < 0 and "N" or "S"
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			-- The face along z lines the north or south arm.
			if not filled[armZ(sz)] then
				local wrap = filled[armX(sx)] and 0 or T.BaseboardDepth
				run(
					parent,
					roomCF,
					Vector3.new(sx * h, 0, sz * (h - wrap)),
					Vector3.new(sx * h, 0, sz * INNER),
					Vector3.new(-sx, 0, 0),
					false
				)
			end
			-- The face along x lines the west or east arm.
			if not filled[armX(sx)] then
				local wrap = filled[armZ(sz)] and 0 or T.BaseboardDepth
				run(
					parent,
					roomCF,
					Vector3.new(sx * (h - wrap), 0, sz * h),
					Vector3.new(sx * INNER, 0, sz * h),
					Vector3.new(0, 0, -sz),
					false
				)
			end
		end
	end
	for side in filled do
		local dir = ({
			N = Vector3.new(0, 0, -1),
			S = Vector3.new(0, 0, 1),
			W = Vector3.new(-1, 0, 0),
			E = Vector3.new(1, 0, 0),
		})[side]
		local perp = Vector3.new(math.abs(dir.Z), 0, math.abs(dir.X))
		run(parent, roomCF, dir * h - perp * h, dir * h + perp * h, -dir, false)
	end
end

-- The casing around a doorway on one wall face: two jambs and a head.
-- `face` is the wall face's centre at floor level, LookVector into the room.
local function casing(parent, face: CFrame, tagPart: (BasePart?) -> ())
	local color, material = paint()
	local w, d = T.CasingWidth, T.CasingDepth
	local function piece(name, x, y, sizeX, sizeY)
		local p = PropFactory.part(
			parent,
			name,
			Vector3.new(sizeX, sizeY, d),
			face * CFrame.new(x, y, -d / 2),
			color,
			material,
			NO_BLOCK
		)
		tagPart(p)
	end
	piece("Casing", -(DOOR_W / 2 + w / 2), (DOOR_H + w) / 2, w, DOOR_H + w)
	piece("Casing", DOOR_W / 2 + w / 2, (DOOR_H + w) / 2, w, DOOR_H + w)
	piece("Casing", 0, DOOR_H + w / 2, DOOR_W + 2 * w, w)
end

-- The casing around the exit door, which never flips.
function Trim.exitCasing(parent, face: CFrame)
	casing(parent, face, function() end)
end

-- A skin over part of a wall face (face-local x and y ranges), in the same
-- surface as the wall.
local function skin(parent, face: CFrame, x0, x1, y0, y1, surface): BasePart
	return PropFactory.part(
		parent,
		"WallSkin",
		Vector3.new(x1 - x0, y1 - y0, SKIN_DEPTH),
		face * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, -SKIN_DEPTH),
		surface.color,
		surface.material,
		{ collide = false, query = false, castShadow = false, variant = surface.variant }
	)
end

-- Trim that flips with a seam. `faces` are the two rooms' wall faces at the
-- seam (centre at floor level, LookVector into each room, with the room
-- model to parent to, its wall `surface`: color, material, variant, its
-- `wainscot` surface if it has one, and optionally the `span` of wall face
-- its skin covers, { from, to } across the face from the doorway's centre;
-- a 40x40 cell's whole wall by default); `through` is the unit vector from
-- room A to room B.
function Trim.seam(seam, faces, midpoint: Vector3, through: Vector3)
	local function tagger(role: string)
		return function(p: BasePart?)
			if not p then
				return
			end
			p:SetAttribute(Attr.SeamTrim, seam.id)
			p:SetAttribute(Attr.SeamTrimRole, role)
			-- The truth everyone starts from; clients flip it for a divergence.
			local shown = (role == "door") == (seam.connected == true)
			p.Transparency = shown and 0 or 1
		end
	end
	local asWall, asDoor = tagger("wall"), tagger("door")
	local color, material = wood()
	for _, f in faces do
		-- The baseboard across the seam, joining the two either side.
		local right = f.face.RightVector
		asWall(
			segment(
				f.parent,
				"Baseboard",
				CFrame.identity,
				f.face.Position - right * EDGE,
				f.face.Position + right * EDGE,
				f.face.LookVector,
				0,
				T.BaseboardHeight,
				T.BaseboardDepth,
				color,
				material
			)
		)
		if f.wainscot then
			local panel, rail = wainscotStrip(
				f.parent,
				CFrame.identity,
				f.face.Position - right * EDGE,
				f.face.Position + right * EDGE,
				f.face.LookVector,
				f.wainscot
			)
			asWall(panel)
			asWall(rail)
		end
		-- (No casing round a hidden door on its room's side.)
		if not f.hidden then
			casing(f.parent, f.face, asDoor)
		end
		-- The wall surface: whole while it's a wall, around the opening while
		-- it's a doorway.
		local half = DOOR_W / 2
		local s0, s1 = f.span and f.span[1] or -INNER, f.span and f.span[2] or INNER
		asWall(skin(f.parent, f.face, s0, s1, 0, HEIGHT, f.surface))
		asDoor(skin(f.parent, f.face, s0, -half, 0, HEIGHT, f.surface))
		asDoor(skin(f.parent, f.face, half, s1, 0, HEIGHT, f.surface))
		asDoor(skin(f.parent, f.face, -half, half, DOOR_H, HEIGHT, f.surface))
	end
	-- Lining for the sides and top of the opening, through both wall layers.
	local paintColor, paintMaterial = paint()
	local frame = CFrame.lookAt(midpoint, midpoint + through)
	local depth = 2 * WALL
	local l = T.LiningDepth
	for _, x in { -(DOOR_W / 2 - l / 2), DOOR_W / 2 - l / 2 } do
		asDoor(
			PropFactory.part(
				faces[1].parent,
				"Lining",
				Vector3.new(l, DOOR_H, depth),
				frame * CFrame.new(x, DOOR_H / 2, 0),
				paintColor,
				paintMaterial,
				NO_BLOCK
			)
		)
	end
	asDoor(
		PropFactory.part(
			faces[1].parent,
			"Lining",
			Vector3.new(DOOR_W, l, depth),
			frame * CFrame.new(0, DOOR_H - l / 2, 0),
			paintColor,
			paintMaterial,
			NO_BLOCK
		)
	)
end

return Trim
