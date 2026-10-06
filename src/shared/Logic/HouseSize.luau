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
-- `extra` adds regions (Hard). The mansion's own copy carries the squad
-- size and the number of regions, for its wings (Logic/Wings).
function HouseSize.config(mansion, progression, squad: number?, extra: number?, profile: string?)
	local clamped = HouseSize.clamp(squad, mansion.BySquad)
	local size = mansion.BySquad[clamped]
	-- A profile (the short night, Config.Mansion.Profiles) lays its fields
	-- over the squad's entry; a field it leaves out stays the squad's.
	local overlay = profile and mansion.Profiles and mansion.Profiles[profile]
	if overlay then
		local merged = table.clone(size)
		for key, value in overlay do
			if key == "mansion" and size.mansion then
				local knobs = table.clone(size.mansion)
				for k, v in value do
					knobs[k] = v
				end
				merged.mansion = knobs
			else
				merged[key] = value
			end
		end
		size = merged
	end
	local regions = size.regions + (extra or 0)
	local m = table.clone(mansion)
	m.RoomCount = size.rooms
	m.Squad = clamped
	m.Regions = regions
	for key, value in size.mansion or {} do
		m[key] = value
	end
	-- Which of the cellar and the attic the squad's house has (section 10.3).
	if size.storeys and mansion.Storeys then
		local s = table.clone(mansion.Storeys)
		s.Cellar = table.clone(s.Cellar)
		s.Attic = table.clone(s.Attic)
		s.Cellar.Chance = size.storeys.cellar
		s.Attic.Chance = size.storeys.attic
		s.OnlyOne = size.storeys.onlyOne == true
		m.Storeys = s
	end
	local p = table.clone(progression)
	p.Regions = { { upTo = math.huge, count = regions } }
	p.FinaleItems = size.heirlooms
	p.Pockets = size.pockets
	p.WingSteps = size.wingSteps
	p.MaxTools = size.maxTools or progression.MaxTools
	if size.flavours then
		p.Flavours = table.clone(progression.Flavours)
		for kind, weight in size.flavours do
			p.Flavours[kind] = weight
		end
	end
	return m, p
end

return HouseSize
