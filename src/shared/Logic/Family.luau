-- The family who lived here (docs/plans/level-design.md section 11, L3.1).
-- Made a run from the seed and the house (who lives here follows the rooms
-- it has), so it's the same for everyone and in every test. Pure (tests/
-- specs/Family.spec).
--
-- What it decides:
--   * who lives here: Mom and Dad, one or two children, Grandma when there's
--     a room for her, the housekeeper when there's a kitchen;
--   * whose each room is, and whose each heirloom kind was;
--   * each member's charm (a mark, Data/Marks), and so the marks on the
--     doors: the door into a part of the house carries the charm of whoever
--     owns most of the rooms behind it (Family.markDoors). Behind the
--     scissors door are Grandma's rooms.
--
--   family = {
--     surname,
--     members = { { id, name, sign, mark, voice, rooms = { room ids } } },
--     byId = { [member id] = member },
--     roomOwner = { [room id] = member id },
--     markOwner = { [mark id] = member id },
--   }

local FamilyData = require(script.Parent.Parent.Data.Family)
local Marks = require(script.Parent.Parent.Data.Marks)

local Family = {}

local function has(list: { string }?, value: string): boolean
	return list ~= nil and table.find(list, value) ~= nil
end

-- A run's family for this house.
function Family.make(rng, layout)
	local templateCount = {}
	local roomIds = {}
	for _, room in layout.rooms do
		templateCount[room.template] = (templateCount[room.template] or 0) + 1
		table.insert(roomIds, room.id)
	end
	table.sort(roomIds)
	local byRoom = {}
	for _, room in layout.rooms do
		byRoom[room.id] = room
	end
	local function present(entry): boolean
		if not entry.needs then
			return true
		end
		for _, template in entry.needs do
			if templateCount[template] then
				return true
			end
		end
		return false
	end

	-- Who lives here. A son as well as a daughter when there are two rooms
	-- for children, or by chance.
	local kidsRooms = (templateCount.kids_bedroom or 0) + (templateCount.playroom or 0) + (templateCount.nursery or 0)
	local family = {
		surname = rng:Pick(FamilyData.Surnames),
		members = {},
		byId = {},
		roomOwner = {},
		markOwner = {},
	}
	local usedMarks = {}
	for _, entry in FamilyData.Members do
		local lives = present(entry)
		if entry.id == "son" then
			lives = lives and (kidsRooms >= 2 or rng:Chance(FamilyData.SecondChild))
		end
		if lives then
			local name = rng:Pick(entry.names)
			local member = {
				id = entry.id,
				name = name,
				sign = entry.calls or (entry.formal and ("Mrs. " .. name)) or name,
				voice = entry.voice,
				heirlooms = entry.heirlooms,
				rooms = {},
			}
			-- Their charm: the first of theirs nobody has, else any free mark.
			for _, mark in entry.marks do
				if not usedMarks[mark] then
					member.mark = mark
					break
				end
			end
			if not member.mark then
				for _, mark in Marks.Ids do
					if not usedMarks[mark] then
						member.mark = mark
						break
					end
				end
			end
			if member.mark then
				usedMarks[member.mark] = true
				family.markOwner[member.mark] = member.id
			end
			table.insert(family.members, member)
			family.byId[member.id] = member
		end
	end

	-- Whose each room is: of those it could belong to, whoever has fewest so
	-- far (a child each to a bedroom), then by the list's order.
	for _, id in roomIds do
		local template = byRoom[id].template
		local best = nil
		for _, entry in FamilyData.Members do
			local member = family.byId[entry.id]
			if member and has(entry.rooms, template) then
				if best == nil or #member.rooms < #best.rooms then
					best = member
				end
			end
		end
		if best then
			family.roomOwner[id] = best.id
			table.insert(best.rooms, id)
		end
	end
	return family
end

-- Who an heirloom kind (Items.Heirlooms id) belonged to: the first member
-- living here who had one, else Mom or Dad.
function Family.heirloomOwner(family, kind: string)
	for _, member in family.members do
		if has(member.heirlooms, kind) then
			return member
		end
	end
	return family.byId.mom or family.byId.dad or family.members[1]
end

-- "Dad's", "Heather's", "Mrs. Novak's".
function Family.possessive(member): string
	return member.sign .. "'s"
end

-- Who writes a note about something of `owner`'s (a member, or nil): most
-- often its owner, else anyone in the family.
function Family.writer(rng, family, owner)
	return rng:WeightedPick(family.members, function(member)
		return member == owner and 3 or 1
	end)
end

-- The charms on the doors (and on what opens each): the door into a region
-- carries the charm of whoever owns most of the rooms behind it, if nobody's
-- door has it yet; else another owner's there, else any free mark (no two
-- doors share one). `label(kindId, markName, count)` names a token
-- (LockPlanner.label). Changes the plan's marks and labels only.
function Family.markDoors(family, plan, label: (string, string, number?) -> string)
	local used = {}
	local order = {}
	for _, member in family.members do
		order[member.id] = #order + 1
	end
	for _, r in plan.order do
		local gate = plan.regions[r].gate
		local lock = gate and plan.locks[gate]
		if lock and lock.needs then
			local counts = {}
			for _, id in plan.regions[r].rooms do
				local owner = family.roomOwner[id]
				if owner then
					counts[owner] = (counts[owner] or 0) + 1
				end
			end
			local owners = {}
			for id in counts do
				table.insert(owners, id)
			end
			table.sort(owners, function(a, b)
				if counts[a] ~= counts[b] then
					return counts[a] > counts[b]
				end
				return order[a] < order[b]
			end)
			local mark = nil
			for _, id in owners do
				local charm = family.byId[id].mark
				if charm and not used[charm] then
					mark = charm
					break
				end
			end
			-- Nobody behind it has a charm free: one nobody in the family
			-- carries, else anyone's still unused.
			if not mark then
				for _, id in Marks.Ids do
					if not used[id] and not family.markOwner[id] then
						mark = id
						break
					end
				end
			end
			if not mark then
				for _, id in Marks.Ids do
					if not used[id] then
						mark = id
						break
					end
				end
			end
			mark = mark or lock.mark
			used[mark] = true
			lock.mark = mark
			for _, need in lock.needs do
				local token = plan.tokens[need]
				token.mark = mark
				token.label = label(lock.kind, Marks.ById[mark].name, #lock.needs > 1 and #lock.needs or nil)
			end
		end
	end
	-- A house key of its own (section 11, L3.2: no gate to share) carries the
	-- housekeeper's charm, if no door has it, else one nobody's door has.
	local ids = {}
	for id in plan.tokens do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local token = plan.tokens[id]
		if token.house then
			local housekeeper = family.byId.housekeeper
			local mark = housekeeper and housekeeper.mark
			if not mark or used[mark] then
				mark = nil
				for _, other in Marks.Ids do
					if not used[other] then
						mark = other
						break
					end
				end
			end
			if mark then
				used[mark] = true
				token.mark = mark
				token.label = label("key", Marks.ById[mark].name)
			end
		end
	end
	-- Side rooms carry their house key's mark.
	for _, lock in plan.locks do
		if lock.pocket then
			lock.mark = plan.tokens[lock.needs[1]].mark
		end
	end
end

return Family
