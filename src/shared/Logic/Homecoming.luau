-- What a run server sends back with a squad (docs/plans/lobby-rework.md,
-- "Coming back": the squad lands in the same lobby server, in a car again,
-- still a party, the tape still in it, the run's Marks on a typed receipt
-- slip). It rides in the teleport's data, which passes through the client,
-- so it only ever seats a squad and shows a receipt: nothing in it is
-- granted (the Marks were saved by the run server). Pure (tests/specs/
-- Homecoming.spec); Services/PlaceService writes it, Services/CarService
-- reads it.

local Homecoming = {}

Homecoming.Version = 1

local MAX_SQUAD = 8
local MAX_MARKS = 100000

-- token: the run's id (its squad is seated together by it); car = { tape,
-- difficulty, night }; squad: userIds; receipts: { [userId] = marks }.
-- (Teleport data is JSON: string keys only.)
function Homecoming.make(token: string, car, squad: { number }, receipts)
	local ids, slips = {}, {}
	for _, id in squad do
		if type(id) == "number" and #ids < MAX_SQUAD then
			table.insert(ids, id)
			local marks = receipts and receipts[id]
			if type(marks) == "number" then
				slips[tostring(id)] = math.floor(marks)
			end
		end
	end
	return {
		v = Homecoming.Version,
		token = token,
		tape = car.tape,
		difficulty = car.difficulty,
		night = car.night,
		squad = ids,
		receipts = slips,
	}
end

-- Read back on arrival, field by field; nil if it isn't one. known = {
-- difficulty = { [name] = true }, location = { [id] = true }, night = {
-- [name] = true } }.
function Homecoming.read(raw, known)
	if type(raw) ~= "table" or raw.v ~= Homecoming.Version then
		return nil
	end
	if type(raw.token) ~= "string" or #raw.token == 0 or #raw.token > 64 then
		return nil
	end
	local squad = {}
	if type(raw.squad) == "table" then
		for i, id in raw.squad do
			if i > MAX_SQUAD then
				break
			end
			if type(id) == "number" and id == math.floor(id) then
				table.insert(squad, id)
			end
		end
	end
	if #squad == 0 then
		return nil
	end
	local receipts = {}
	if type(raw.receipts) == "table" then
		for key, marks in raw.receipts do
			local id = tonumber(key)
			if id and table.find(squad, id) and type(marks) == "number" then
				receipts[id] = math.clamp(math.floor(marks), 0, MAX_MARKS)
			end
		end
	end
	local function pick(value, names)
		return (type(value) == "string" and names and names[value]) and value or nil
	end
	return {
		token = raw.token,
		tape = pick(raw.tape, known.location),
		difficulty = pick(raw.difficulty, known.difficulty),
		night = pick(raw.night, known.night),
		squad = squad,
		receipts = receipts,
	}
end

return Homecoming
