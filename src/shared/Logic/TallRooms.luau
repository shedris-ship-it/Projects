-- The mansion's double-height rooms (docs/plans/mansion-generation.md): the
-- grand hall, with a gallery round three walls and a staircase up the middle,
-- and the dog-leg stairwells. Their shape lives here so that what
-- World/MansionBuilder builds and what The Guest and the bot walk
-- (Logic/NavGraph) can't drift apart.
--
-- Coordinates are in the room's own frame: x east, z south, origin at the
-- middle of the ground floor, y up from the ground floor. `inner` is the half
-- extents of the walls' inner faces. Pure: no engine calls.

local TallRooms = {}

TallRooms.Hall = {
	Gallery = 8, -- depth of the gallery along the north, east and west walls
	StairHalf = 5, -- half the staircase's width
	StairFoot = 5.5, -- z of the bottom step; it rises north to the gallery
	Rail = 3.2, -- railing height
}

TallRooms.Stairwell = {
	Landing = 8, -- depth of the half landing (north end) and the upper landing (south end)
}

-- "hall", "stair", or nil for a room on one storey.
function TallRooms.kindOf(room): string?
	if not room.tall then
		return nil
	end
	return room.kind == "stair" and "stair" or "hall"
end

-- The hall's numbers: the gallery's floor height and its open edges.
function TallRooms.hall(inner, pitch: number)
	local H = TallRooms.Hall
	return { top = pitch, edgeZ = -inner.z + H.Gallery, edgeX = inner.x - H.Gallery }
end

-- A stairwell's numbers. Flight one climbs the west half from the upper
-- landing's edge to the half landing; flight two comes back up the east half.
function TallRooms.stairwell(inner, pitch: number)
	local landing = TallRooms.Stairwell.Landing
	local width = inner.x - 0.5
	return {
		half = pitch / 2,
		landingZ = -inner.z + landing, -- the half landing's edge
		upperZ = inner.z - landing, -- the upper landing's edge
		width = width,
		flightX = width / 2 + 0.5, -- each flight's middle, either side of the spine wall
	}
end

-- Where you can stand on a storey (not on a stair, not over the void):
--   hall:  downstairs anywhere but the staircase; upstairs only the gallery
--   stair: each storey's entry landing over the south end
function TallRooms.standable(kind: string, inner, pitch: number, storey: number, lx: number, lz: number): boolean
	if math.abs(lx) > inner.x or math.abs(lz) > inner.z then
		return false
	end
	if kind == "hall" then
		local h = TallRooms.hall(inner, pitch)
		if storey == 0 then
			local onStair = math.abs(lx) <= TallRooms.Hall.StairHalf + 0.3
				and lz >= h.edgeZ
				and lz <= TallRooms.Hall.StairFoot
			return not onStair
		end
		return lz <= h.edgeZ or math.abs(lx) >= h.edgeX
	end
	local s = TallRooms.stairwell(inner, pitch)
	return lz >= s.upperZ
end

-- The room's walk shape for Logic/NavGraph:
--   nodes:  { x, y, z, region } (region "ground", "gallery", "landing" or "upper")
--   links:  { a, b, stair? } between node indices; a stair link climbs a flight
--   attach: per storey (0 its lowest), more links { a, b } (walkable too)
--           that a doorway on that storey joins, at the nearest point along
--           one of them
--   climbs: per storey up from the lowest, the nodes from the bottom of that
--           way up to its top, in order
-- Every point keeps clear of the staircase, the railings and of furniture
-- standing in the wall band (Config.Level.BandDepth). Heights are from the
-- room's lowest storey; a stairwell climbs `storeys` storeys (2 unless set).
function TallRooms.walk(kind: string, inner, pitch: number, storeys: number?)
	local nodes, links = {}, {}
	local function node(x: number, y: number, z: number, region: string): number
		table.insert(nodes, { x = x, y = y, z = z, region = region })
		return #nodes
	end
	local function link(a: number, b: number, stair: boolean?)
		table.insert(links, { a = a, b = b, stair = stair })
		return #links
	end
	if kind == "hall" then
		local H = TallRooms.Hall
		local h = TallRooms.hall(inner, pitch)
		-- Downstairs: a ring round the staircase, out of the wall band.
		local ringX = H.StairHalf + 3.5
		local frontZ = H.StairFoot + 3
		local nearFront = inner.z - 9.2
		local back = -inner.z + H.Gallery / 2 -- under the north gallery, behind the stair's top
		local front = node(0, 0, frontZ, "ground")
		local frontW, frontE = node(-ringX, 0, frontZ, "ground"), node(ringX, 0, frontZ, "ground")
		local cornerW, cornerE = node(-ringX, 0, nearFront, "ground"), node(ringX, 0, nearFront, "ground")
		local backW, backE = node(-ringX, 0, back, "ground"), node(ringX, 0, back, "ground")
		local backMid = node(0, 0, back, "ground")
		link(front, frontW)
		link(front, frontE)
		-- Upstairs: the gallery's middle line, and the top of the staircase.
		local line = -inner.z + H.Gallery / 2
		local side = inner.x - H.Gallery / 2
		local top = node(0, pitch, h.edgeZ - 1.5, "gallery")
		local north = node(0, pitch, line, "gallery")
		local northW, northE = node(-side, pitch, line, "gallery"), node(side, pitch, line, "gallery")
		local southW, southE = node(-side, pitch, inner.z - 4, "gallery"), node(side, pitch, inner.z - 4, "gallery")
		link(front, top, true)
		link(top, north)
		return {
			nodes = nodes,
			links = links,
			attach = {
				[0] = {
					{ frontW, cornerW },
					{ frontE, cornerE },
					{ frontW, backW },
					{ frontE, backE },
					{ backW, backMid },
					{ backE, backMid },
				},
				[1] = {
					{ north, northW },
					{ north, northE },
					{ northW, southW },
					{ northE, southE },
				},
			},
			climbs = { { front, top } },
		}
	end
	-- A stairwell: one dog-leg a storey, stacked (the back stairs may run
	-- from the cellar to the attic; docs/plans/level-design.md section 10.2).
	-- Each storey's entry is the landing over the south end; its flight one
	-- climbs the west half to a half landing, flight two comes back up the
	-- east half to the next storey's entry.
	local s = TallRooms.stairwell(inner, pitch)
	local entryZ = (s.upperZ + inner.z) / 2
	local landingMid = (s.landingZ - inner.z) / 2
	local count = storeys or 2
	local entry = node(0, 0, entryZ, "ground")
	local foot = node(-s.flightX, 0, entryZ, "ground")
	local entryE = node(s.flightX, 0, entryZ, "ground")
	local attach = { [0] = { { entry, foot }, { entry, entryE } } }
	local climbs = {}
	for k = 0, count - 2 do
		local y = k * pitch
		local landingW = node(-s.flightX, y + s.half, landingMid, "landing")
		local landingE = node(s.flightX, y + s.half, landingMid, "landing")
		-- The next storey's entry: where flight two arrives, its middle, and
		-- the foot of the flight up from it.
		local topE = node(s.flightX, y + pitch, entryZ, "upper")
		local upper = node(0, y + pitch, entryZ, "upper")
		local upperW = node(-s.flightX, y + pitch, entryZ, "upper")
		link(foot, landingW, true)
		link(landingW, landingE)
		link(landingE, topE, true)
		attach[k + 1] = { { upper, topE }, { upper, upperW } }
		table.insert(climbs, { foot, landingW, landingE, topE })
		foot = upperW
	end
	return {
		nodes = nodes,
		links = links,
		attach = attach,
		climbs = climbs,
	}
end

return TallRooms
