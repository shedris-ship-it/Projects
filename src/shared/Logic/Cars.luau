-- The garage's party cars (docs/plans/lobby-rework.md, "Parties: the cars in
-- the garage"; LB2). Get in a seat and you're in that car's party; the first
-- in is the driver, who holds the tape and works the dashboard (difficulty,
-- night, friends only) and honks to leave; a countdown follows in which
-- anyone can get out; if the driver gets out, the next passenger takes the
-- wheel. Pure (tests/specs/Cars.spec); Services/CarService asks it.
--
-- A car: {
--   id, seats = { [1..n] = userId | false } (seat 1 is the wheel),
--   tape = locationId?, difficulty, night, friendsOnly,
--   party = partyId?, heldUntil = time?   (held for a Roblox party, F2-free)
--   leavingAt = time?                     (the honk's countdown ends then)
--   away = boolean                        (gone to the house)
-- }

local Cars = {}

-- cfg: { Seats, Difficulty = { name... }, Night = { name... }, Default = { difficulty, night } }
function Cars.new(id: number, cfg)
	local seats = {}
	for i = 1, cfg.Seats do
		seats[i] = false
	end
	return {
		id = id,
		seats = seats,
		tape = nil,
		difficulty = cfg.Default.difficulty,
		night = cfg.Default.night,
		friendsOnly = false,
		party = nil,
		heldUntil = nil,
		leavingAt = nil,
		away = false,
	}
end

function Cars.driver(car): number?
	return car.seats[1] or nil
end

function Cars.count(car): number
	local n = 0
	for _, who in car.seats do
		if who then
			n += 1
		end
	end
	return n
end

function Cars.seatOf(car, userId: number): number?
	for i, who in car.seats do
		if who == userId then
			return i
		end
	end
	return nil
end

-- The players in it, wheel first.
function Cars.riders(car): { number }
	local list = {}
	for _, who in car.seats do
		if who then
			table.insert(list, who)
		end
	end
	return list
end

-- Whether the car is held for a Roblox party at `now`.
function Cars.held(car, now: number): boolean
	return car.party ~= nil and car.heldUntil ~= nil and now < car.heldUntil
end

-- Whether `who` may get in: who = { userId, partyId?, friendOfDriver }.
-- Returns ok, and a reason when not: "away", "seated", "full", "held" (kept
-- for a party that isn't yours), "friends" (friends only, and you aren't the
-- driver's).
function Cars.canBoard(car, who, now: number): (boolean, string?)
	if car.away then
		return false, "away"
	end
	if Cars.seatOf(car, who.userId) then
		return false, "seated"
	end
	if Cars.count(car) >= #car.seats then
		return false, "full"
	end
	local sameParty = who.partyId ~= nil and who.partyId ~= "" and who.partyId == car.party
	if Cars.held(car, now) and not sameParty then
		return false, "held"
	end
	if car.friendsOnly and Cars.count(car) > 0 and not (who.friendOfDriver or sameParty) then
		return false, "friends"
	end
	return true, nil
end

-- Puts userId in the first free seat (the wheel first). Returns the seat.
function Cars.board(car, userId: number): number?
	for i, who in car.seats do
		if not who then
			car.seats[i] = userId
			return i
		end
	end
	return nil
end

-- Leaves the car to its defaults, empty (its tape back on the shelf).
local function reset(car, cfg)
	car.tape = nil
	car.difficulty = cfg.Default.difficulty
	car.night = cfg.Default.night
	car.friendsOnly = false
	car.leavingAt = nil
end

-- Takes userId out. Returns the moves that follow, { { userId, from, to } }:
-- when the wheel is left empty and someone is still in, the first of them
-- takes it. An empty car goes back to its defaults (and stops its
-- countdown).
function Cars.leave(car, userId: number, cfg): { { number } }
	local seat = Cars.seatOf(car, userId)
	local moves = {}
	if not seat then
		return moves
	end
	car.seats[seat] = false
	if seat == 1 then
		for i = 2, #car.seats do
			local who = car.seats[i]
			if who then
				car.seats[i] = false
				car.seats[1] = who
				table.insert(moves, { who, i, 1 })
				break
			end
		end
	end
	if Cars.count(car) == 0 then
		reset(car, cfg)
	end
	return moves
end

-- The driver changes a setting: key "difficulty" | "night" | "friendsOnly".
-- Returns ok, reason ("driver", "leaving", "value").
function Cars.set(car, userId: number, key: string, value, cfg): (boolean, string?)
	if Cars.driver(car) ~= userId then
		return false, "driver"
	end
	if car.leavingAt then
		return false, "leaving"
	end
	if key == "difficulty" and table.find(cfg.Difficulty, value) then
		car.difficulty = value
	elseif key == "night" and table.find(cfg.Night, value) then
		car.night = value
	elseif key == "friendsOnly" and type(value) == "boolean" then
		car.friendsOnly = value
	else
		return false, "value"
	end
	return true, nil
end

-- A tape brought into the car goes in the deck if there's none there.
-- Returns whether it went in.
function Cars.insertTape(car, tape: string?): boolean
	if tape and not car.tape then
		car.tape = tape
		return true
	end
	return false
end

-- The driver honks to leave. Returns ok, reason ("driver", "tape",
-- "leaving"); on ok the countdown runs to car.leavingAt.
function Cars.honk(car, userId: number, now: number, cfg): (boolean, string?)
	if Cars.driver(car) ~= userId then
		return false, "driver"
	end
	if not car.tape then
		return false, "tape"
	end
	if car.leavingAt then
		return false, "leaving"
	end
	car.leavingAt = now + cfg.Countdown
	return true, nil
end

-- Whether the countdown has run out with someone still in.
function Cars.due(car, now: number): boolean
	return car.leavingAt ~= nil and now >= car.leavingAt and Cars.count(car) > 0
end

-- The car a Roblox party is offered: the first empty one not held for
-- another party. Holds it for them until now + hold. Returns its id.
function Cars.holdFor(cars, partyId: string, now: number, hold: number): number?
	for _, car in cars do
		if car.party == partyId and Cars.held(car, now) then
			return car.id
		end
	end
	for _, car in cars do
		if not car.away and Cars.count(car) == 0 and not Cars.held(car, now) then
			car.party = partyId
			car.heldUntil = now + hold
			return car.id
		end
	end
	return nil
end

-- The first empty car at home (a squad coming back is seated in it).
function Cars.firstEmpty(cars, now: number): number?
	for _, car in cars do
		if not car.away and Cars.count(car) == 0 and not Cars.held(car, now) then
			return car.id
		end
	end
	return nil
end

-- What the sign in the rear window says, line by line, for strangers across
-- the garage: the case (or that it wants one), the difficulty and night,
-- the seats left or that it's leaving, friends only, who's in.
-- names: { [userId] = display name }; caseName: the tape's name, or nil.
function Cars.sign(car, names, caseName: string?, now: number, cfg)
	local lines = {}
	table.insert(lines, caseName and string.upper(caseName) or "NO TAPE YET")
	table.insert(lines, string.upper(car.difficulty) .. " · " .. string.upper(cfg.NightNames[car.night] or car.night))
	local left = #car.seats - Cars.count(car)
	if car.leavingAt then
		table.insert(lines, string.format("LEAVING IN %d", math.max(0, math.ceil(car.leavingAt - now))))
	elseif left == 0 then
		table.insert(lines, "FULL")
	else
		table.insert(lines, string.format("%d SEAT%s LEFT", left, left == 1 and "" or "S"))
	end
	if car.friendsOnly then
		table.insert(lines, "FRIENDS ONLY")
	elseif Cars.held(car, now) then
		table.insert(lines, "SAVED FOR A PARTY")
	end
	local riders = {}
	for _, id in Cars.riders(car) do
		table.insert(riders, names[id] or "?")
	end
	if #riders > 0 then
		table.insert(lines, table.concat(riders, ", "))
	end
	return lines
end

return Cars
