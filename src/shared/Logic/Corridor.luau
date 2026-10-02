-- Corridor rooms (docs/ART.md, Scale): closets fill the four corners of the
-- cell, leaving a plus-shaped hallway. An arm that ends at an outside wall
-- would only be a pointless dead end, so it's filled in, turning the plus
-- into a straight, L or T corridor that reads as a hallway (owner's
-- playtest, 2026-10-02). An arm stays open when it leads to another room
-- (through a doorway, or to a solid wall a phantom doorway can appear in), or
-- when it holds something that must stay: a window, a hiding spot (so the
-- validator's count holds), or the shrine of a Lantern room.
--
-- Sides here are template sides ("N", "E", "S", "W"); LevelGraph.worldSide
-- turns them into world sides.

local LevelGraph = require(script.Parent.LevelGraph)
local Props = require(script.Parent.Parent.Data.Props)

local Corridor = {}

-- The arm a local floor position is in, or nil in the junction.
function Corridor.armOf(halfWidth: number, x: number, z: number): string?
	if math.abs(x) <= halfWidth and math.abs(z) > halfWidth then
		return z < 0 and "N" or "S"
	elseif math.abs(z) <= halfWidth and math.abs(x) > halfWidth then
		return x < 0 and "W" or "E"
	end
	return nil
end

-- The arm a wall position from template data is in: an outer wall
-- ({ side, along }) is the end of that side's arm; a closet face
-- ({ x, z, face }) is in whichever arm it lines.
function Corridor.armOfWall(halfWidth: number, slot): string?
	if slot.side then
		return slot.side
	end
	return Corridor.armOf(halfWidth, slot.x, slot.z)
end

-- The template sides of the arms to fill in. room: { gx, gz, rotation,
-- lantern, role } from the layout; cells: the layout's cell lookup.
function Corridor.filledArms(template, room, cells): { [string]: boolean }
	local filled = {}
	-- Corridors never take a role; this keeps an exit door from being walled in.
	if not template.corridor or room.role then
		return filled
	end
	local h = template.corridor.halfWidth
	local keep = {}
	for _, prop in template.props do
		local kind = Props.Kinds[prop.kind]
		local arm = Corridor.armOf(h, prop.x, prop.z)
		if arm and kind and kind.hide then
			keep[arm] = true
		end
	end
	for _, decor in template.decor do
		if decor.kind == "Window" then
			local arm = Corridor.armOfWall(h, decor)
			if arm then
				keep[arm] = true
			end
		end
	end
	if room.lantern and template.shrine then
		local arm = Corridor.armOf(h, template.shrine.x, template.shrine.z)
		if arm then
			keep[arm] = true
		end
	end
	for _, side in LevelGraph.DirOrder do
		if not keep[side] and LevelGraph.isOuterSide(room, cells, LevelGraph.worldSide(side, room.rotation)) then
			filled[side] = true
		end
	end
	return filled
end

return Corridor
