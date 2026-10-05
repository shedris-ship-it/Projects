-- The house follows the squad (owner, 2026-10-05; docs/plans/level-design.md
-- section 5.2): a solo player never gets a 24-room house, four get the
-- biggest. A run's mansion and lock-planner configs are copies of
-- Config.Mansion and Config.Progression with the squad's room count, number
-- of regions and heirlooms put over them (Config.Mansion.BySquad). Pure.

local HouseSize = {}

-- A squad size inside the table's range (1 to its last entry).
function HouseSize.clamp(squad: number?, bySquad): number
	return math.clamp(math.floor(squad or #bySquad), 1, #bySquad)
end

-- The run's configs for a squad: (mansion config, progression config).
function HouseSize.config(mansion, progression, squad: number?)
	local size = mansion.BySquad[HouseSize.clamp(squad, mansion.BySquad)]
	local m = table.clone(mansion)
	m.RoomCount = size.rooms
	for key, value in size.mansion or {} do
		m[key] = value
	end
	local p = table.clone(progression)
	p.Regions = { { upTo = math.huge, count = size.regions } }
	p.FinaleItems = size.heirlooms
	return m, p
end

return HouseSize
