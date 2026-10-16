-- HOUSE CALL, the arcade's first game (LB5; docs/plans/lobby-rework.md,
-- "Arcade" and "The arcade's games and scores"): the Guest's three rules as
-- a maze game. You take the family's silver from a dark house while he
-- stalks you through it:
--   1. Face him and he freezes (your torch's line, `Gaze` cells down the way
--      you face; hold the button to stand still and look).
--   2. Don't pester him: stare at him too long and he hunts.
--   3. When he hunts (that, or now and then), looking doesn't stop him:
--      break his sight, or get to a lantern (he never steps into its light).
-- Touch him and he has you. Clear the house of silver for the next, faster
-- one; three lives, one more at 10,000.
--
-- Pure and seeded, with a fixed tick (`Rate`), so a game is its seed and
-- its presses: the player's client runs and draws it (Controllers/
-- ArcadeController), anyone watching runs the same from the same presses,
-- and the server replays them for the score (Services/ArcadeService). Every
-- number here is part of the rules: change one and old replays score
-- differently (none are kept, so only games in progress would notice).

local Rng = require(script.Parent.Parent.Parent.Lib.Rng)

local HouseCall = {}

HouseCall.Rate = 20 -- ticks a second
HouseCall.MaxTicks = 20 * 60 * 20 -- a game stops at 20 minutes

-- The house, 21 x 15: # wall, . silver, o a lantern (its light: yours, never
-- his), P where you start, G his room, = its door (his only). Row 7's ends
-- run out of one side and in at the other.
HouseCall.Maze = {
	"#####################",
	"#o........#........o#",
	"#.##.####.#.####.##.#",
	"#...................#",
	"#.##.#.#######.#.##.#",
	"#....#.........#....#",
	"####.#.###=###.#.####",
	".....#.#GGGGG#.#.....",
	"####.#.#######.#.####",
	"#....#.........#....#",
	"#.##.#.#######.#.##.#",
	"#.........P.........#",
	"#.##.####.#.####.##.#",
	"#o........#........o#",
	"#####################",
}

local W, H = 21, 15
HouseCall.Width, HouseCall.Height = W, H

-- Directions: 1 up, 2 right, 3 down, 4 left (0: none).
local DX = { 0, 1, 0, -1 }
local DY = { -1, 0, 1, 0 }
local REVERSE = { 3, 4, 1, 2 }
HouseCall.DX, HouseCall.DY = DX, DY

local PLAYER_STEP = 4 -- ticks a cell: 5 cells a second
local GAZE = 7 -- cells your torch reaches
local SIGHT = 12 -- cells he sees you from in a hunt
local PESTER = 120 -- staring fills it by 2 a tick, looking away drains 1: 3 s of staring
local WARN = 20 -- ticks he stands and screams before a hunt
local LOST = 40 -- ticks out of his sight that end a hunt
local HUNT_MAX = 240 -- a hunt's longest
local LEAVE = 60 -- ticks he waits in his room at a life's start
local WANDER = 0.25 -- how often, stalking, he takes a turn at random
local READY = 40
local CAUGHT = 60
local CLEARED = 60
local SILVER = 10
local BONUS_LIFE = 10000
local HEIRLOOM_AT = { 50, 110 } -- silver taken when the family's heirloom shows
local HEIRLOOM_TICKS = 200
-- (For drawing it: Controllers/ArcadeController.)
HouseCall.PlayerStep, HouseCall.Gaze, HouseCall.Pester = PLAYER_STEP, GAZE, PESTER

local function stalkStep(level: number): number
	return math.max(4, 7 - level)
end

local function huntStep(level: number): number
	return level <= 1 and 4 or 3
end

local function huntEvery(level: number): number
	return math.max(400, 900 - 100 * (level - 1))
end

local CELLS = {}
local function index(x: number, y: number): number
	return y * W + x + 1
end
local START, DEN
for y, row in HouseCall.Maze do
	for x = 1, W do
		local c = string.sub(row, x, x)
		CELLS[index(x - 1, y - 1)] = c
		if c == "P" then
			START = { x = x - 1, y = y - 1 }
		elseif c == "=" then
			DEN = { x = x - 1, y = y } -- the room's cell under its door
		end
	end
end
HouseCall.Start, HouseCall.Den = START, DEN
HouseCall.index = index

function HouseCall.cell(x: number, y: number): string
	if y < 0 or y >= H then
		return "#"
	end
	return CELLS[index(x % W, y)]
end
local cellAt = HouseCall.cell

local function playerOpen(c: string): boolean
	return c == "." or c == "o" or c == "P"
end

local function guestOpen(c: string): boolean
	return c == "." or c == "P" or c == "=" or c == "G"
end

local function stepFrom(x: number, y: number, dir: number): (number, number)
	return (x + DX[dir]) % W, y + DY[dir]
end

-- Whether (tx, ty) is down a straight, clear line from (x, y), within range.
local function sees(x: number, y: number, dir: number, tx: number, ty: number, range: number): boolean
	for _ = 1, range do
		x, y = stepFrom(x, y, dir)
		if x == tx and y == ty then
			return true
		end
		local c = cellAt(x, y)
		if c == "#" or c == "=" then
			return false
		end
	end
	return false
end

-- Inputs: the stick's direction, plus 8 while the button is held.
function HouseCall.encode(stick: number, look: boolean): number
	return stick + (look and 8 or 0)
end

function HouseCall.decode(value: number): (number, boolean)
	return value % 8, value >= 8
end

local function fillSilver(s)
	s.silver = {}
	s.left = 0
	for i, c in CELLS do
		if c == "." then
			s.silver[i] = true
			s.left += 1
		end
	end
	s.taken = 0
	s.heirloom = 0
end

local function say(s, message: string, ticks: number)
	s.message = message
	s.messageUntil = s.tick + ticks
end

-- Everyone back where a life starts: you at the start, him in his room.
local function placeAll(s)
	s.player = { x = START.x, y = START.y, px = START.x, py = START.y, dir = 0, face = 4, wait = 0 }
	s.guest = { x = DEN.x, y = DEN.y, px = DEN.x, py = DEN.y, dir = 1, wait = LEAVE, step = LEAVE }
	s.hunt = nil
	s.pester = 0
	s.seen = false
	s.nextHunt = s.tick + huntEvery(s.level)
	s.heirloom = 0
	s.pause = READY
	say(s, "ready", READY)
end

function HouseCall.new(seed: number)
	local s = {
		seed = seed,
		rng = Rng.new(seed),
		tick = 0,
		input = 0,
		score = 0,
		lives = 3,
		level = 1,
		bonusLife = false,
		over = false,
		after = nil,
	}
	fillSilver(s)
	placeAll(s)
	return s
end

-- A copy to go back to (a watcher's late press: HouseCall.runner).
function HouseCall.clone(s)
	local c = table.clone(s)
	c.rng = setmetatable(table.clone(s.rng), getmetatable(s.rng))
	c.silver = table.clone(s.silver)
	c.player = table.clone(s.player)
	c.guest = table.clone(s.guest)
	c.hunt = s.hunt and table.clone(s.hunt)
	return c
end

local function addScore(s, points: number)
	local before = s.score
	s.score += points
	if not s.bonusLife and before < BONUS_LIFE and s.score >= BONUS_LIFE then
		s.bonusLife = true
		s.lives += 1
	end
end

local function movePlayer(s, stick: number, look: boolean)
	local p = s.player
	p.moved = false
	if p.wait > 0 then
		p.wait -= 1
		if p.wait > 0 then
			return
		end
	end
	p.px, p.py = p.x, p.y
	if look then
		-- (Standing still and looking: the stick only turns you.)
		if stick ~= 0 then
			p.face = stick
		end
		p.dir = 0
		return
	end
	local dir = 0
	if stick ~= 0 and playerOpen(cellAt(stepFrom(p.x, p.y, stick))) then
		dir = stick
	elseif p.dir ~= 0 and playerOpen(cellAt(stepFrom(p.x, p.y, p.dir))) then
		dir = p.dir
	end
	if dir == 0 then
		p.dir = 0
		if stick ~= 0 then
			p.face = stick
		end
		return
	end
	p.dir, p.face = dir, dir
	p.x, p.y = stepFrom(p.x, p.y, dir)
	p.wait = PLAYER_STEP
	p.moved = true
end

local function collect(s)
	local p = s.player
	if not p.moved then
		return
	end
	local i = index(p.x, p.y)
	if s.silver[i] then
		s.silver[i] = nil
		s.left -= 1
		s.taken += 1
		addScore(s, SILVER)
		if table.find(HEIRLOOM_AT, s.taken) then
			s.heirloom = HEIRLOOM_TICKS
		end
	end
	if s.heirloom > 0 and p.x == START.x and p.y == START.y then
		s.heirloom = 0
		addScore(s, 100 * s.level)
		say(s, "heirloom", 30)
	end
	if s.left == 0 then
		addScore(s, 500 * s.level)
		s.hunt = nil
		s.pause = CLEARED
		s.after = "next"
		say(s, "cleared", CLEARED)
	end
end

-- Distances to (tx, ty) through his way round the house.
local function field(tx: number, ty: number)
	local dist = { [index(tx, ty)] = 0 }
	local queue = { tx, ty }
	local head = 1
	while head < #queue do
		local x, y = queue[head], queue[head + 1]
		head += 2
		local d = dist[index(x, y)] + 1
		for dir = 1, 4 do
			local nx, ny = stepFrom(x, y, dir)
			local i = index(nx, ny)
			if dist[i] == nil and guestOpen(cellAt(nx, ny)) then
				dist[i] = d
				table.insert(queue, nx)
				table.insert(queue, ny)
			end
		end
	end
	return dist
end

local function startHunt(s)
	local p = s.player
	s.hunt = { phase = "warn", t = WARN, age = 0, lost = 0, seenX = p.x, seenY = p.y }
	s.pester = 0
	say(s, "hunt", WARN + 20)
end

local function endHunt(s)
	s.hunt = nil
	s.pester = 0
	s.nextHunt = s.tick + huntEvery(s.level)
	addScore(s, 100)
	say(s, "survived", 30)
end

local function guestSees(s): boolean
	local p, g = s.player, s.guest
	if p.x == g.x and p.y == g.y then
		return true
	end
	for dir = 1, 4 do
		if sees(g.x, g.y, dir, p.x, p.y, SIGHT) then
			return true
		end
	end
	return false
end

local function updateHunt(s)
	local h = s.hunt
	if not h then
		local g = s.guest
		local out = cellAt(g.x, g.y) ~= "G"
		if s.seen then
			s.pester += 2
		else
			s.pester = math.max(0, s.pester - 1)
		end
		if s.pester >= PESTER or (out and s.tick >= s.nextHunt) then
			startHunt(s)
		end
		return
	end
	h.age += 1
	if h.phase == "warn" then
		h.t -= 1
		if h.t <= 0 then
			h.phase = "chase"
		end
		return
	end
	if guestSees(s) then
		h.seenX, h.seenY = s.player.x, s.player.y
		h.lost = 0
	else
		h.lost += 1
	end
	if h.lost >= LOST or h.age >= HUNT_MAX then
		endHunt(s)
	end
end

local function moveGuest(s)
	local g = s.guest
	g.moved = false
	-- (Seen, he holds still, mid-step too; and while he screams.)
	local frozen = s.seen or (s.hunt ~= nil and s.hunt.phase == "warn")
	if g.wait > 0 then
		if frozen then
			return
		end
		g.wait -= 1
		if g.wait > 0 then
			return
		end
	end
	if frozen then
		return
	end
	g.px, g.py = g.x, g.y
	local h = s.hunt
	local p = s.player
	local tx, ty = p.x, p.y
	if h then
		tx, ty = h.seenX, h.seenY
	end
	local dist = field(tx, ty)
	local here = dist[index(g.x, g.y)] or math.huge
	local options = {}
	for dir = 1, 4 do
		local nx, ny = stepFrom(g.x, g.y, dir)
		if guestOpen(cellAt(nx, ny)) then
			table.insert(options, dir)
		end
	end
	if #options == 0 then
		return
	end
	local choices = options
	if not h then
		-- (Stalking, he doesn't turn back unless the way ends.)
		local forward = {}
		for _, dir in options do
			if dir ~= REVERSE[g.dir] then
				table.insert(forward, dir)
			end
		end
		if #forward > 0 then
			choices = forward
		end
	end
	local pick
	if not h and #choices > 1 and s.rng:Chance(WANDER) then
		pick = s.rng:Pick(choices)
	else
		local best = math.huge
		for _, dir in choices do
			local d = dist[index(stepFrom(g.x, g.y, dir))] or math.huge
			if d < best then
				best, pick = d, dir
			end
		end
		-- (Hunting, by the light he can't step into: he waits at its edge.)
		if h and best >= here then
			return
		end
	end
	if not pick then
		return
	end
	g.dir = pick
	g.x, g.y = stepFrom(g.x, g.y, pick)
	g.step = h and huntStep(s.level) or stalkStep(s.level)
	g.wait = g.step
	g.moved = true
end

local function checkCatch(s)
	local p, g = s.player, s.guest
	local same = p.x == g.x and p.y == g.y
	local crossed = p.moved and g.moved and p.px == g.x and p.py == g.y and g.px == p.x and g.py == p.y
	if same or crossed then
		s.lives -= 1
		s.hunt = nil
		s.pause = CAUGHT
		s.after = s.lives > 0 and "reset" or "over"
		say(s, "caught", CAUGHT)
	end
end

local function finishPause(s)
	local after = s.after
	s.after = nil
	if after == "reset" then
		placeAll(s)
	elseif after == "next" then
		s.level += 1
		fillSilver(s)
		placeAll(s)
	elseif after == "over" then
		s.over = true
		say(s, "over", math.huge)
	end
end

-- One tick with this input (HouseCall.encode).
function HouseCall.step(s, input: number)
	if s.over then
		return
	end
	s.tick += 1
	s.input = input
	if s.message and s.tick >= s.messageUntil then
		s.message = nil
	end
	if s.pause > 0 then
		s.pause -= 1
		if s.pause == 0 then
			finishPause(s)
		end
		return
	end
	if s.heirloom > 0 then
		s.heirloom -= 1
	end
	local stick, look = HouseCall.decode(input)
	movePlayer(s, stick, look)
	collect(s)
	if s.pause > 0 then
		return
	end
	local p, g = s.player, s.guest
	s.seen = s.hunt == nil and sees(p.x, p.y, p.face, g.x, g.y, GAZE)
	updateHunt(s)
	moveGuest(s)
	checkCatch(s)
	if s.tick >= HouseCall.MaxTicks and not s.over then
		s.over = true
		say(s, "over", math.huge)
	end
end

-- Whether a list of presses is well formed: { tick, value, tick, value, ... }
-- with ticks whole, in order, from `after` (the last one before them) on,
-- and every value one the stick and button can make.
function HouseCall.valid(events, after: number?): boolean
	if type(events) ~= "table" or #events % 2 ~= 0 then
		return false
	end
	local last = after or 0
	for i = 1, #events, 2 do
		local t, v = events[i], events[i + 1]
		if type(t) ~= "number" or type(v) ~= "number" then
			return false
		end
		if t ~= math.floor(t) or t < last or t < 1 or t > HouseCall.MaxTicks then
			return false
		end
		if v ~= math.floor(v) or v < 0 or v > 12 or (v > 4 and v < 8) then
			return false
		end
		last = t
	end
	return true
end

-- A game run from its presses as they come, able to go back for a late one
-- (someone watching gets them a moment after they're pressed). Keeps a copy
-- every SNAP ticks to go back to.
local SNAP = 100
local Runner = {}
Runner.__index = Runner

function HouseCall.runner(seed: number)
	local state = HouseCall.new(seed)
	return setmetatable(
		{ seed = seed, events = {}, state = state, snaps = { [0] = HouseCall.clone(state) }, ptr = 1 },
		Runner
	)
end

-- Adds presses (a flat list, as HouseCall.valid takes).
function Runner:feed(events)
	for i = 1, #events, 2 do
		local t = events[i]
		table.insert(self.events, { t = t, v = events[i + 1] })
		-- (Already played past it: go back to before it.)
		if t <= self.state.tick then
			self.rewind = math.min(self.rewind or math.huge, t)
		end
	end
end

function Runner:_rewind()
	local to = self.rewind
	self.rewind = nil
	local best = 0
	for t in self.snaps do
		if t < to and t > best then
			best = t
		end
	end
	for t in self.snaps do
		if t > best then
			self.snaps[t] = nil
		end
	end
	self.state = HouseCall.clone(self.snaps[best])
	self.ptr = 1
	while self.events[self.ptr] and self.events[self.ptr].t <= best do
		self.ptr += 1
	end
end

-- Plays on to `tick` (or the game's end).
function Runner:advance(tick: number)
	if self.rewind then
		self:_rewind()
	end
	local s = self.state
	while s.tick < tick and not s.over do
		local t = s.tick + 1
		local input = s.input
		while self.events[self.ptr] and self.events[self.ptr].t <= t do
			input = self.events[self.ptr].v
			self.ptr += 1
		end
		HouseCall.step(s, input)
		if s.tick % SNAP == 0 then
			self.snaps[s.tick] = HouseCall.clone(s)
		end
	end
	return s
end

-- A whole game from its seed and presses, up to `ticks` (the server's check).
function HouseCall.run(seed: number, events, ticks: number)
	local runner = HouseCall.runner(seed)
	runner:feed(events)
	return runner:advance(ticks)
end

return HouseCall
