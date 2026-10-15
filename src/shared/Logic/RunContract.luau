-- What a lobby tells the reserved server it sends a squad to
-- (docs/plans/lobby-rework.md, "Lobby to run"). It travels through
-- MemoryStore, written and read by servers only: teleport data passes
-- through the client, so it's never trusted for this.

local RunContract = {}

RunContract.Version = 1

local MAX_SQUAD = 8 -- more than any squad (Config.Run.MaxPlayers); a bound on what's read back

-- userIds: the squad; settings = { difficulty, location, night }; now: os.time().
function RunContract.make(userIds: { number }, settings, now: number)
	local squad = {}
	for _, id in userIds do
		if type(id) == "number" and #squad < MAX_SQUAD then
			table.insert(squad, id)
		end
	end
	return {
		v = RunContract.Version,
		squad = squad,
		difficulty = settings.difficulty,
		location = settings.location,
		night = settings.night,
		made = now,
	}
end

-- A contract read back, checked field by field; nil if it isn't one.
-- known = { difficulty = { [name] = true }, location = { [id] = true } }:
-- names this build doesn't know fall back to nil, and the run uses its
-- defaults for them.
function RunContract.read(raw, known)
	if type(raw) ~= "table" or raw.v ~= RunContract.Version or type(raw.squad) ~= "table" then
		return nil
	end
	local squad = {}
	for i, id in raw.squad do
		if i > MAX_SQUAD then
			break
		end
		if type(id) == "number" and id == math.floor(id) then
			table.insert(squad, id)
		end
	end
	if #squad == 0 then
		return nil
	end
	local function pick(value, names)
		return (type(value) == "string" and names and names[value]) and value or nil
	end
	return {
		squad = squad,
		difficulty = pick(raw.difficulty, known and known.difficulty),
		location = pick(raw.location, known and known.location),
		night = type(raw.night) == "string" and raw.night or nil,
		made = type(raw.made) == "number" and raw.made or 0,
	}
end

-- Whether a player belongs to the contract's squad.
function RunContract.expects(contract, userId: number): boolean
	return table.find(contract.squad, userId) ~= nil
end

-- How many of the squad are here (userIds of the players in the server).
function RunContract.arrived(contract, present: { number }): number
	local count = 0
	for _, id in contract.squad do
		if table.find(present, id) then
			count += 1
		end
	end
	return count
end

return RunContract
