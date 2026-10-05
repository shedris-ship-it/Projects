-- Where a room's light switch goes (R2c interactables): on the wall beside
-- the doorway you come in by, at hand height, just past the door's casing,
-- on whichever side has wall to spare before the room's corner. Pure (tests/
-- specs/SwitchSpots.spec), in plain x/z numbers so the rules are tests.
--
-- `rect` is the room's floor { x0, z0, x1, z1 }; `door` the middle of the
-- doorway on the wall's centre line { x, z }; `into` the unit direction from
-- that wall into the room { x, z }; `cfg` { DoorWidth, WallFace (centre line
-- to the room's wall face), Beside (from the door's edge to the switch),
-- Margin (from the switch to a corner) }. Returns { x, z, side } or nil.

local SwitchSpots = {}

function SwitchSpots.place(rect, door, into, cfg)
	-- Along the wall: a quarter turn from `into`.
	local tx, tz = -into.z, into.x
	local out = cfg.DoorWidth / 2 + cfg.Beside
	for _, side in { 1, -1 } do
		local x = door.x + tx * side * out + into.x * cfg.WallFace
		local z = door.z + tz * side * out + into.z * cfg.WallFace
		-- Inside the room's span along the wall, clear of the corner.
		local along = math.abs(tx) > 0.5 and x or z
		local low = math.abs(tx) > 0.5 and rect.x0 or rect.z0
		local high = math.abs(tx) > 0.5 and rect.x1 or rect.z1
		if along >= low + cfg.Margin and along <= high - cfg.Margin then
			return { x = x, z = z, side = side }
		end
	end
	return nil
end

return SwitchSpots
