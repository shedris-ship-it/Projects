-- Where The Guest stands to peek round a door frame (owner, 2026-10-03:
-- "peek from doorways"). For a doorway in a wall, each side of the wall has
-- two spots, one beside each jamb: his body hidden behind the wall, facing
-- through it, leaning sideways so his head and the hand gripping the jamb
-- show in the opening. Each spot also has a hide point further along the
-- wall that he is yanked back to when you've seen him.
--
-- Plain numbers on the floor plane. A doorway is its centre (cx, cz) and the
-- unit normal (nx, nz) of its wall, pointing from room a to room b. Spots on
-- side +1 stand in room b (watching room a); side -1 in room a.
--
-- Spots stay outside the doorway lane (|along| > Config.Level.LaneHalfWidth)
-- that the walkers (Stalker/Walker) and the furniture rules keep clear.

local PeekSpots = {}

-- cfg: { PeekLateral, PeekWallClearance, PeekHideLateral, WallThickness }
function PeekSpots.forDoorway(cx: number, cz: number, nx: number, nz: number, cfg)
	-- Along the wall: perpendicular to the normal.
	local ax, az = -nz, nx
	local spots = {}
	local depth = cfg.WallThickness + cfg.PeekWallClearance
	for _, side in { 1, -1 } do
		for _, lateral in { 1, -1 } do
			local along = lateral * cfg.PeekLateral
			local x = cx + nx * side * depth + ax * along
			local z = cz + nz * side * depth + az * along
			-- He faces through the wall, towards the other room.
			local fx, fz = -nx * side, -nz * side
			-- His right is (facing x up): Roblox right = (-fz, fx) for look (fx, fz).
			local rx, rz = -fz, fx
			-- Lean towards the opening: the doorway centre is at -along.
			local toDoorX, toDoorZ = cx + nx * side * depth - x, cz + nz * side * depth - z
			local lean = (rx * toDoorX + rz * toDoorZ) >= 0 and 1 or -1
			local hideAlong = lateral * cfg.PeekHideLateral
			table.insert(spots, {
				x = x,
				z = z,
				faceX = fx,
				faceZ = fz,
				lean = lean,
				side = side,
				along = along,
				hideX = cx + nx * side * depth + ax * hideAlong,
				hideZ = cz + nz * side * depth + az * hideAlong,
			})
		end
	end
	return spots
end

return PeekSpots
