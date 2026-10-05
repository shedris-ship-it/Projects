-- The home computer (docs/plans/gameplay-rework.md section 7): a password
-- hack, the Fallout terminal the owner liked ("a fun simple concept made
-- procedural"). The screen is a memory dump of junk characters with words
-- in it, one of them the password. Pick a word: wrong, and the screen says
-- how many of its letters are the password's, in the same places
-- ("Likeness=2"); four tries, then the machine locks you out for a while
-- (a loud beep) with the same password. A matched pair of brackets in the
-- junk ("(..)", "[..]") removes a wrong word, or now and then gives your
-- tries back. Solved, the printer prints the padlock's code.
--
-- Pure (tests/specs/Terminal.spec): generate makes the screen from a seed and
-- only keeps sets a careful player can always crack within four tries
-- (minimax over the likeness answers). The password stays on the server:
-- clients get `view` and the public state.

local Words = require(script.Parent.Parent.Parent.Data.Words)

local Terminal = {}

Terminal.Tries = 4
Terminal.Rows = 16 -- per column
Terminal.Columns = 2
Terminal.Width = 12 -- characters a row
Terminal.LockoutSeconds = 15

local JUNK = { "!", "@", "#", "$", "%", "^", "&", "*", "-", "_", "=", "+", "|", ";", ":", "'", '"', ",", ".", "?", "/" }
local BRACKETS = { { "(", ")" }, { "[", "]" }, { "{", "}" }, { "<", ">" } }

-- Letters of `a` matching `b` in the same places.
function Terminal.likeness(a: string, b: string): number
	local n = 0
	for i = 1, math.min(#a, #b) do
		if string.byte(a, i) == string.byte(b, i) then
			n += 1
		end
	end
	return n
end

-- Can a careful player always find the password among `candidates` within
-- `tries`, guessing any word on the screen (minimax over the answers)?
function Terminal.solvableWithin(words: { string }, candidates: { string }, tries: number): boolean
	if #candidates == 0 then
		return true
	end
	if tries <= 0 then
		return false
	end
	if #candidates == 1 then
		return true
	end
	if tries == 1 then
		return false
	end
	for _, guess in words do
		local parts = {}
		for _, candidate in candidates do
			if candidate ~= guess then
				local likeness = Terminal.likeness(guess, candidate)
				parts[likeness] = parts[likeness] or {}
				table.insert(parts[likeness], candidate)
			end
		end
		local good = true
		for _, part in parts do
			if #part == #candidates or not Terminal.solvableWithin(words, part, tries - 1) then
				good = false
				break
			end
		end
		if good then
			return true
		end
	end
	return false
end

-- The words for a screen: the password, a few that share a lot with it, and
-- the rest spread out. nil if none of the tries could be cracked in time.
local function pickWords(rng, length: number, count: number): ({ string }?, string?)
	local list = Words[length]
	for _ = 1, 30 do
		local pool = rng:Shuffle(table.clone(list))
		local answer = pool[1]
		local close, rest = {}, {}
		for i = 2, #pool do
			local word = pool[i]
			table.insert(Terminal.likeness(answer, word) >= 2 and close or rest, word)
		end
		local words = { answer }
		local closeCount = math.min(#close, math.ceil(count / 3))
		for i = 1, closeCount do
			table.insert(words, close[i])
		end
		for _, word in rest do
			if #words >= count then
				break
			end
			table.insert(words, word)
		end
		for i = closeCount + 1, #close do
			if #words >= count then
				break
			end
			table.insert(words, close[i])
		end
		if #words == count and Terminal.solvableWithin(words, words, Terminal.Tries) then
			return rng:Shuffle(words), answer
		end
	end
	return nil, nil
end

local function junk(rng): string
	return JUNK[rng:NextInteger(1, #JUNK)]
end

-- ctx: { length?, count? }. Returns the spec; `spec.answer` never leaves the server.
function Terminal.generate(rng, ctx)
	ctx = ctx or {}
	local length = ctx.length or ({ 5, 6, 6, 7, 7, 8 })[rng:NextInteger(1, 6)]
	local count = ctx.count or rng:NextInteger(10, 13)
	local words, answer = pickWords(rng, length, count)
	while not words do
		-- Too few words that can be told apart: fewer of them.
		count -= 1
		words, answer = pickWords(rng, length, count)
	end
	-- The dump: rows of junk, one word to a row at most.
	local rowCount = Terminal.Rows * Terminal.Columns
	local rows = {}
	for r = 1, rowCount do
		local chars = {}
		for c = 1, Terminal.Width do
			chars[c] = junk(rng)
		end
		rows[r] = chars
	end
	local spans = {}
	local free = {}
	for r = 1, rowCount do
		table.insert(free, r)
	end
	rng:Shuffle(free)
	for i, word in words do
		local row = free[i]
		local col = rng:NextInteger(1, Terminal.Width - length + 1)
		for k = 1, length do
			rows[row][col + k - 1] = string.sub(word, k, k)
		end
		table.insert(spans, { kind = "word", row = row, col = col, length = length, word = word })
	end
	-- Brackets in rows with no word: each pair removes a dud, one in four gives
	-- your tries back.
	local brackets = {}
	local pairsWanted = rng:NextInteger(3, 5)
	for i = #words + 1, math.min(#free, #words + pairsWanted) do
		local row = free[i]
		local inner = rng:NextInteger(1, 5)
		local col = rng:NextInteger(1, Terminal.Width - inner - 1)
		local kind = BRACKETS[rng:NextInteger(1, #BRACKETS)]
		rows[row][col] = kind[1]
		rows[row][col + inner + 1] = kind[2]
		local effect = (#brackets == 0 and rng:Chance(0.35)) and "reset" or "dud"
		table.insert(brackets, effect)
		table.insert(spans, { kind = "bracket", row = row, col = col, length = inner + 2, index = #brackets })
	end
	local lines = {}
	local base = rng:NextInteger(0xF000, 0xF800)
	for r = 1, rowCount do
		lines[r] = {
			address = string.format("0x%04X", base + (r - 1) * Terminal.Width),
			text = table.concat(rows[r]),
		}
	end
	-- The order duds go in when brackets are found (fixed now, so step is pure).
	local duds = {}
	for _, word in words do
		if word ~= answer then
			table.insert(duds, word)
		end
	end
	rng:Shuffle(duds)
	return {
		length = length,
		words = words,
		answer = answer,
		lines = lines,
		spans = spans,
		brackets = brackets,
		duds = duds,
	}
end

-- What a client may see: the screen, never the answer.
function Terminal.view(spec)
	return { length = spec.length, lines = spec.lines, spans = spec.spans, tries = Terminal.Tries }
end

function Terminal.start(_spec)
	return { tries = Terminal.Tries, removed = {}, used = {}, log = {}, lockedUntil = 0, solved = false }
end

local function say(state, ...)
	for _, line in { ... } do
		table.insert(state.log, line)
	end
	while #state.log > 14 do
		table.remove(state.log, 1)
	end
end

-- input: { kind = "word", word, now } or { kind = "bracket", index, now }.
-- Changes `state`, returns it and what happened: { kind = "likeness" |
-- "dud" | "reset" | "lockout" | "solved" | "refused", ... }.
function Terminal.step(spec, state, input)
	if state.solved then
		return state, {}
	end
	local now = input.now or 0
	if now < state.lockedUntil then
		return state, { { kind = "refused", reason = "locked" } }
	end
	if input.kind == "word" then
		local word = input.word
		if type(word) ~= "string" or not table.find(spec.words, word) or state.removed[word] then
			return state, { { kind = "refused", reason = "no such word" } }
		end
		if word == spec.answer then
			state.solved = true
			say(state, ">" .. word, ">Exact match!", ">Please wait", ">while system", ">is accessed.")
			return state, { { kind = "solved" } }
		end
		local likeness = Terminal.likeness(word, spec.answer)
		state.tries -= 1
		say(state, ">" .. word, ">Entry denied.", ">Likeness=" .. likeness)
		local events = { { kind = "likeness", word = word, likeness = likeness } }
		if state.tries <= 0 then
			state.tries = Terminal.Tries
			state.lockedUntil = now + Terminal.LockoutSeconds
			say(state, ">TERMINAL LOCKED", ">Please wait.")
			table.insert(events, { kind = "lockout", untilTime = state.lockedUntil })
		end
		return state, events
	elseif input.kind == "bracket" then
		local index = input.index
		local effect = type(index) == "number" and spec.brackets[index]
		if not effect or state.used[index] then
			return state, { { kind = "refused", reason = "no such bracket" } }
		end
		state.used[index] = true
		if effect == "reset" then
			state.tries = Terminal.Tries
			say(state, ">Tries reset.")
			return state, { { kind = "reset" } }
		end
		for _, word in spec.duds do
			if not state.removed[word] then
				state.removed[word] = true
				say(state, ">Dud removed.")
				return state, { { kind = "dud", word = word } }
			end
		end
		say(state, ">No duds left.")
		return state, { { kind = "dud" } }
	end
	return state, { { kind = "refused", reason = "unknown input" } }
end

function Terminal.solved(state): boolean
	return state.solved == true
end

-- What its operator's screen may show of the state (never the answer).
function Terminal.public(state, now: number)
	return {
		tries = state.tries,
		removed = state.removed,
		used = state.used,
		log = state.log,
		lockedFor = math.max(0, state.lockedUntil - now),
		solved = state.solved,
	}
end

-- A click from the screen, as an input for `step` (nil if it isn't one).
function Terminal.parse(action: string, word: string?, a: number?, _b: number?, now: number)
	if action == "word" and type(word) == "string" and #word <= 12 then
		return { kind = "word", word = word, now = now }
	elseif action == "bracket" and type(a) == "number" then
		return { kind = "bracket", index = a, now = now }
	end
	return nil
end

-- F2 `solve`: as if the right word were clicked.
function Terminal.solve(spec, state, now: number)
	return Terminal.step(spec, state, { kind = "word", word = spec.answer, now = now })
end

return Terminal
