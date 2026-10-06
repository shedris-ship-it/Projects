-- Stuck-assist (the owner's audit of 2026-10-06, Finding 7: "a stalled squad
-- gets more danger but no help"; the owner's finish line: never wonder what
-- to do next for more than two minutes). When the squad has made no progress
-- for a while, the objective line gets one more sentence that points at the
-- next thing the plan wants, and a little later the lights there stutter and
-- the map rings the room. Pure (tests/specs/Assist.spec).
--
-- It reads the plan the way the solver does (Logic/LockPlanner.solve), one
-- step at a time, from what the squad has: in order,
--   set     an heirloom found and not yet set: carry it to the table
--   door    a lock the squad already holds the opener for, on a door it can
--           reach: go and open it
--   puzzle  a station in reach that makes something still needed
--   look    a room in reach where something still needed is kept
--
-- state = {
--   reachable = { [room] = true }       rooms the squad can get to now
--   had = { [token] = true }            tokens found, on a ring, held or made
--   opened = { [seamId] = true }        locks open
--   set = { [token] = true }            heirlooms set at the table
--   seams = { [seamId] = { a, b } }     a lock's two rooms
-- }

local LockPlanner = require(script.Parent.LockPlanner)

local Assist = {}

local function sortedKeys(t)
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

-- The next thing to do, or nil when nothing can be said (everything in
-- reach is done; the dinner is served).
function Assist.next(plan, state)
	if not plan or not plan.tokens then
		return nil
	end
	local had, reachable = state.had or {}, state.reachable or {}
	local opened, set, seams = state.opened or {}, state.set or {}, state.seams or {}
	-- 1. An heirloom in hand that isn't at the table yet.
	for _, token in plan.finale and plan.finale.heirlooms or {} do
		if had[token] and not set[token] then
			return { kind = "set", token = token }
		end
	end
	-- 2. A door they can open with what they hold.
	for _, seamId in sortedKeys(plan.locks) do
		local lock = plan.locks[seamId]
		local seam = seams[seamId]
		if not opened[seamId] and lock.needs and seam and not lock.optional then
			local ready = true
			for _, need in lock.needs do
				ready = ready and had[need] == true
			end
			if ready and (reachable[seam.a] or reachable[seam.b]) then
				local near = reachable[seam.a] and seam.a or seam.b
				return { kind = "door", seam = seamId, room = near, token = lock.needs[1] }
			end
		end
	end
	-- 3. Something still needed, kept or made in a room they can reach. Keys,
	-- codes and tools first (they open the house), heirlooms after. A token
	-- only an optional lock wants (the safe room's power) is never the hint.
	local needed = {}
	for _, token in plan.finale and plan.finale.heirlooms or {} do
		needed[token] = true
	end
	for _, lock in plan.locks do
		if not lock.optional then
			for _, need in lock.needs or {} do
				needed[need] = true
			end
		end
	end
	for _, piece in plan.pieces or {} do
		for _, need in piece.needs or {} do
			needed[need] = true
		end
	end
	local function wanted(id, token)
		if had[id] or not needed[id] then
			return false
		end
		-- Shut in a chest a step nailed or chained (L3.4) until its tool is held.
		local piece = token.producer.piece and plan.pieces and plan.pieces[token.producer.piece]
		for _, need in piece and piece.needs or {} do
			if not had[need] then
				return false
			end
		end
		local rooms = LockPlanner.producerRooms(plan, token)
		if #rooms == 0 then
			return false
		end
		for _, room in rooms do
			if not reachable[room] then
				return false
			end
		end
		return true
	end
	local ids = sortedKeys(plan.tokens)
	for pass = 1, 2 do
		for _, id in ids do
			local token = plan.tokens[id]
			local heirloom = token.kind == "bulky" or token.kind == "heirloom"
			if (pass == 1) == not heirloom and wanted(id, token) then
				local producer = token.producer
				if producer.kind == "puzzle" then
					local puzzle = plan.puzzles and plan.puzzles[producer.id]
					return {
						kind = "puzzle",
						room = LockPlanner.tokenRoom(plan, token),
						puzzle = puzzle and puzzle.kind or "puzzle",
						token = id,
					}
				end
				return { kind = "look", room = LockPlanner.tokenRoom(plan, token), token = id }
			end
		end
	end
	return nil
end

local STATIONS = {
	terminal = "the computer",
	breaker = "the fuse box",
	safe = "the safe",
	musicbox = "the piano",
	crank = "the crank",
	dumbwaiter = "the dumbwaiter",
	display = "the glass case",
	padlock = "the padlock",
}

-- The hint as the line says it. roomName: the room as the line names rooms
-- ("the Study"); label: the heirloom's name ("Mom's locket").
function Assist.phrase(hint, roomName: string?, label: string?): string
	if hint.kind == "set" then
		return string.format("Carry %s to its place at the table.", label or "the heirloom")
	elseif hint.kind == "door" then
		return string.format("You already hold what opens a door in %s.", roomName or "a room nearby")
	elseif hint.kind == "puzzle" then
		return string.format("Try %s in %s.", STATIONS[hint.puzzle] or "the puzzle", roomName or "a room nearby")
	end
	return string.format("Something you need is still in %s.", roomName or "a room nearby")
end

return Assist
