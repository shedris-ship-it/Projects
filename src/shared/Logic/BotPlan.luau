-- The bot's next step (docs/progress/2026-10-07-loop/REPORT.md, WP1): what a
-- player who knows the plan would do next, from what the squad has, so that
-- Services/BotService can play a run end to end on the server and measure
-- it. Logic/Assist is the same reading with the hints a stuck squad gets;
-- this fills the gaps Assist leaves out (cranks, nailed chests, tools, an
-- heirloom a puzzle made but nobody has picked up, the way out) and never
-- repeats a step that failed. Pure (tests/specs/BotPlan.spec).
--
-- state = {
--   reachable = { [room] = true }      rooms the squad can get to now
--   had = { [token] = true }           on a ring, in a slot, made (codes,
--                                      power), or an heirloom held or set
--   made = { [token] = true }          a thing lying in the house to take
--   held = token?                      the heirloom in the bot's hands
--   opened = { [seamId] = true }       locks open
--   pieceOpen = { [pieceLockId] = true }
--   set = { [token] = true }           heirlooms set at the table
--   seams = { [seamId] = { a, b } }    a lock's two rooms
--   served = boolean                   the dinner is served: get out
--   blocked = { [stepKey] = true }     steps that failed: never again
-- }
-- A step: { kind, key, ... } with kind one of extract, set, take, door,
-- toolDoor, crank, piece, tool, puzzle, look.

local LockPlanner = require(script.Parent.LockPlanner)

local BotPlan = {}

local function sortedKeys(t)
	local keys = {}
	for k in t or {} do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

local function isHeirloom(token): boolean
	return token ~= nil and (token.kind == "bulky" or token.kind == "heirloom")
end

-- Every token the run can't finish without (Logic/Assist has the same rule).
-- With `opened` and `pieceOpen`, a token every lock and chest of which is
-- already open is no longer needed (a spent house key is not looked for).
function BotPlan.needed(plan, opened, pieceOpen)
	local needed = {}
	for _, token in plan.finale and plan.finale.heirlooms or {} do
		needed[token] = true
	end
	for seamId, lock in plan.locks or {} do
		if not lock.optional and not (opened and opened[seamId]) then
			for _, need in lock.needs or {} do
				needed[need] = true
			end
		end
	end
	for id, piece in plan.pieces or {} do
		if not (pieceOpen and pieceOpen[id]) then
			for _, need in piece.needs or {} do
				needed[need] = true
			end
		end
	end
	return needed
end

local function key(step)
	step.key = step.kind .. ":" .. tostring(step.seam or step.piece or step.id or step.token or "")
	return step
end

function BotPlan.next(plan, state)
	if not plan or not plan.tokens then
		return nil
	end
	local reachable, had, made = state.reachable or {}, state.had or {}, state.made or {}
	local opened, pieceOpen, set = state.opened or {}, state.pieceOpen or {}, state.set or {}
	local seams, blocked = state.seams or {}, state.blocked or {}
	local function offer(step)
		key(step)
		if blocked[step.key] then
			return nil
		end
		return step
	end
	-- 1. The dinner is served: out of the front door.
	if state.served then
		return offer({ kind = "extract" })
	end
	-- 2. An heirloom in hand: to its place.
	if state.held and isHeirloom(plan.tokens[state.held]) and not set[state.held] then
		local step = offer({ kind = "set", token = state.held })
		if step then
			return step
		end
	end
	-- 3. A thing made and lying there (a key on a rack, an heirloom a puzzle
	-- gave up): take it.
	for _, id in sortedKeys(made) do
		if made[id] and not had[id] then
			local step = offer({ kind = "take", token = id })
			if step then
				return step
			end
		end
	end
	-- 4. A door they can open with what they hold (a power door opens itself
	-- when its breaker is solved; an optional one is never the bot's business).
	for _, seamId in sortedKeys(plan.locks) do
		local lock = plan.locks[seamId]
		local seam = seams[seamId]
		if seam and not opened[seamId] and lock.needs and not lock.optional and lock.kind ~= "power" then
			local ready = true
			for _, need in lock.needs do
				ready = ready and had[need] == true
			end
			if ready and (reachable[seam.a] or reachable[seam.b]) then
				local near = reachable[seam.a] and seam.a or seam.b
				local tool = lock.kind == "boards" or lock.kind == "chain"
				local step = offer({
					kind = tool and "toolDoor" or "door",
					seam = seamId,
					room = near,
					lockKind = lock.kind,
					token = lock.needs[1],
				})
				if step then
					return step
				end
			end
		end
	end
	-- 5. A crank door worked from its outer side.
	for _, seamId in sortedKeys(plan.locks) do
		local lock = plan.locks[seamId]
		local seam = seams[seamId]
		if seam and not opened[seamId] and lock.side and not lock.needs and lock.kind ~= "bolt" then
			if reachable[lock.side] then
				local step = offer({ kind = "crank", seam = seamId, room = lock.side })
				if step then
					return step
				end
			end
		end
	end
	-- 6. A chest nailed or chained shut, with its tool in hand.
	for _, id in sortedKeys(plan.pieces) do
		local piece = plan.pieces[id]
		if not pieceOpen[id] and reachable[piece.room] then
			local ready = true
			for _, need in piece.needs or {} do
				ready = ready and had[need] == true
			end
			if ready then
				local step =
					offer({ kind = "piece", piece = id, room = piece.room, token = piece.needs and piece.needs[1] })
				if step then
					return step
				end
			end
		end
	end
	-- 7. Something still needed, kept or made in a room they can reach:
	-- keys, codes and tools first, heirlooms after.
	local needed = BotPlan.needed(plan, opened, pieceOpen)
	local function wanted(id, token)
		if had[id] or not needed[id] then
			return false
		end
		local pieceId = token.producer.piece
		if pieceId and plan.pieces and plan.pieces[pieceId] and not pieceOpen[pieceId] then
			return false
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
			if (pass == 1) == not isHeirloom(token) and wanted(id, token) then
				local producer = token.producer
				local step
				if producer.kind == "puzzle" then
					local puzzle = plan.puzzles and plan.puzzles[producer.id]
					step = offer({
						kind = "puzzle",
						id = producer.id,
						puzzle = puzzle and puzzle.kind or "puzzle",
						room = LockPlanner.tokenRoom(plan, token),
						token = id,
					})
				elseif token.kind == "tool" then
					step = offer({ kind = "tool", token = id, tool = token.tool, room = producer.room })
				else
					step = offer({ kind = "look", token = id, room = producer.room })
				end
				if step then
					return step
				end
			end
		end
	end
	return nil
end

-- Walk a plan the way the bot would, with the house's rules simplified (for
-- the spec and F2 `botrun plan`): every step taken in order, and whether
-- the table got set. `seams` is { [seamId] = { a, b } }; `startRooms` is
-- region 0. Bolts open from their inside as reach grows (the solver's rule).
function BotPlan.walk(plan, seams, startRooms, maxSteps: number?)
	local state = {
		reachable = {},
		had = {},
		made = {},
		held = nil,
		opened = {},
		pieceOpen = {},
		set = {},
		seams = seams,
		served = false,
		blocked = {},
	}
	local function regionRooms(room)
		local region = plan.regions and plan.roomRegion and plan.regions[plan.roomRegion[room]]
		return region and region.rooms or {}
	end
	-- A region's rooms come with it, except a pocket (a side room behind the
	-- house key, plan.pockets) until its own door is opened.
	local function reach(room)
		state.reachable[room] = true
		for _, r in regionRooms(room) do
			local pocket = plan.pockets and plan.pockets[r]
			if not pocket or state.opened[pocket.seam] then
				state.reachable[r] = true
			end
		end
	end
	local function expand()
		local changed = true
		while changed do
			changed = false
			for seamId, lock in plan.locks do
				local seam = seams[seamId]
				if seam and not state.opened[seamId] and lock.kind == "bolt" and state.reachable[lock.side] then
					state.opened[seamId] = true
					changed = true
					reach(seam.a)
					reach(seam.b)
				end
			end
		end
	end
	for _, room in startRooms do
		-- (A pocket in the start region still waits for the house key.)
		local pocket = plan.pockets and plan.pockets[room]
		if not pocket then
			state.reachable[room] = true
		end
	end
	expand()
	local steps = {}
	local heirlooms = {}
	for _, token in plan.finale and plan.finale.heirlooms or {} do
		heirlooms[token] = true
	end
	for _ = 1, maxSteps or 80 do
		local step = BotPlan.next(plan, state)
		if not step then
			break
		end
		table.insert(steps, step)
		if step.kind == "extract" then
			state.extracted = true
			break
		elseif step.kind == "set" then
			state.set[step.token] = true
			state.held = nil
			local left = 0
			for token in heirlooms do
				if not state.set[token] then
					left += 1
				end
			end
			state.served = left == 0
		elseif step.kind == "take" then
			state.made[step.token] = nil
			state.had[step.token] = true
			if heirlooms[step.token] then
				state.held = step.token
			end
		elseif step.kind == "door" or step.kind == "toolDoor" or step.kind == "crank" then
			state.opened[step.seam] = true
			local seam = seams[step.seam]
			reach(seam.a)
			reach(seam.b)
			expand()
		elseif step.kind == "piece" then
			state.pieceOpen[step.piece] = true
		elseif step.kind == "tool" or step.kind == "look" then
			if heirlooms[step.token] then
				state.made[step.token] = true -- lying there now: taken next
			else
				state.had[step.token] = true
			end
		elseif step.kind == "puzzle" then
			if heirlooms[step.token] then
				state.made[step.token] = true
			else
				state.had[step.token] = true
			end
			-- A power door opens itself once its breaker is solved.
			for seamId, lock in plan.locks do
				if lock.kind == "power" and lock.needs and lock.needs[1] == step.token then
					state.opened[seamId] = true
					local seam = seams[seamId]
					if seam then
						reach(seam.a)
						reach(seam.b)
					end
				end
			end
			expand()
		end
	end
	local tableSet = true
	for token in heirlooms do
		tableSet = tableSet and state.set[token] == true
	end
	return steps, tableSet, state
end

return BotPlan
