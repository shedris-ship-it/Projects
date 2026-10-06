-- Which corridor gets which landmark (docs/plans/level-design.md section 4,
-- L3.6): every hallway and corridor of the mansion (not a stair, not a
-- servants' passage) gets one, each different from the others while there
-- are kinds to go round (Data/Landmarks), starting from the house's seed.
-- Pure and without a random stream of its own, so Logic/RoomPurpose and the
-- run (Services/LandmarkService) always agree.

local Kinds = require(script.Parent.Parent.Data.Landmarks)

local Landmarks = {}

Landmarks.ById = {}
for _, kind in Kinds do
	Landmarks.ById[kind.id] = kind
end

-- { { room = id, kind = Data/Landmarks entry } }, by room id.
function Landmarks.plan(layout, templatesById)
	if layout.mode ~= "Mansion" then
		return {}
	end
	local rooms = {}
	for _, room in layout.rooms do
		local template = templatesById[room.template]
		local corridor = room.corridor == true or (template ~= nil and template.family == "corridor")
		if corridor and room.kind ~= "stair" and room.kind ~= "passage" and not room.tall then
			table.insert(rooms, room.id)
		end
	end
	table.sort(rooms)
	local start = (layout.houseSeed or layout.seed or 0) % #Kinds
	local out = {}
	for i, id in rooms do
		table.insert(out, { room = id, kind = Kinds[(start + i - 1) % #Kinds + 1] })
	end
	return out
end

return Landmarks
