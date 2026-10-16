-- The arcade (LB5): HOUSE CALL's rules (Logic/Arcade/HouseCall) and paying
-- for a play (Logic/Arcade/Credits).
return function(test, check, Shared, require)
	local HouseCall = require(Shared.Logic.Arcade.HouseCall)
	local Credits = require(Shared.Logic.Arcade.Credits)

	local W, H = HouseCall.Width, HouseCall.Height
	local cell = HouseCall.cell

	local function playerOpen(c)
		return c == "." or c == "o" or c == "P"
	end

	-- Breadth-first from (x, y) through your way round the house: the first
	-- step toward the nearest cell `want` accepts, or 0.
	local function toward(x, y, want)
		local first = { [HouseCall.index(x, y)] = 0 }
		local queue = { { x, y } }
		local head = 1
		while queue[head] do
			local cx, cy = queue[head][1], queue[head][2]
			head += 1
			local i = HouseCall.index(cx, cy)
			if first[i] ~= 0 and want(cx, cy) then
				return first[i]
			end
			for dir = 1, 4 do
				local nx, ny = (cx + HouseCall.DX[dir]) % W, cy + HouseCall.DY[dir]
				local j = HouseCall.index(nx, ny)
				if first[j] == nil and playerOpen(cell(nx, ny)) then
					first[j] = first[i] == 0 and dir or first[i]
					table.insert(queue, { nx, ny })
				end
			end
		end
		return 0
	end

	-- A fair player: takes the nearest silver; when he's coming straight at
	-- them, stops and looks at him (not for long); when he hunts, runs for a
	-- lantern. Returns its presses as the cabinet would send them.
	local function play(seed, maxTicks)
		local s = HouseCall.new(seed)
		local events = {}
		local last = -1
		local looking = 0
		while not s.over and s.tick < maxTicks do
			local p, g = s.player, s.guest
			local stick, look = 0, false
			if s.hunt then
				stick = toward(p.x, p.y, function(x, y)
					return cell(x, y) == "o"
				end)
				if cell(p.x, p.y) == "o" then
					stick, look = 0, true
				end
			else
				stick = toward(p.x, p.y, function(x, y)
					return s.silver[HouseCall.index(x, y)] == true
				end)
				-- Him in line within 4: look at him a moment.
				for dir = 1, 4 do
					local x, y = p.x, p.y
					for _ = 1, 4 do
						x, y = (x + HouseCall.DX[dir]) % W, y + HouseCall.DY[dir]
						if not playerOpen(cell(x, y)) then
							break
						end
						if x == g.x and y == g.y and looking < 40 then
							stick, look = dir, true
						end
					end
				end
				looking = look and looking + 1 or math.max(0, looking - 1)
			end
			local value = HouseCall.encode(stick, look)
			if value ~= last then
				table.insert(events, s.tick + 1)
				table.insert(events, value)
				last = value
			end
			HouseCall.step(s, value)
		end
		return s, events
	end

	test("the house: every bit of silver and every lantern can be reached from the start", function()
		check.equal(#HouseCall.Maze, H, "15 rows")
		local silver, lanterns = 0, 0
		for y, row in HouseCall.Maze do
			check.equal(#row, W, "row " .. y .. " is 21 across")
		end
		local start = HouseCall.Start
		for y = 0, H - 1 do
			for x = 0, W - 1 do
				local c = cell(x, y)
				if c == "." or c == "o" then
					if c == "." then
						silver += 1
					else
						lanterns += 1
					end
					local found = toward(start.x, start.y, function(tx, ty)
						return tx == x and ty == y
					end)
					check.truthy(found ~= 0, string.format("(%d, %d) reachable", x, y))
				end
			end
		end
		check.equal(lanterns, 4, "a lantern in each corner")
		check.atLeast(silver, 120, "plenty of silver")
		check.equal(cell(HouseCall.Den.x, HouseCall.Den.y), "G", "he starts in his room")
		check.equal(cell(HouseCall.Den.x, HouseCall.Den.y - 1), "=", "under its door")
	end)

	test("a game is its seed and its presses: a replay scores the same", function()
		for _, seed in { 1, 77, 4242 } do
			local s, events = play(seed, 6000)
			check.truthy(HouseCall.valid(events), "the presses are well formed")
			local again = HouseCall.run(seed, events, s.tick)
			check.equal(again.score, s.score, "seed " .. seed .. ": the same score")
			check.equal(again.lives, s.lives, "the same lives")
			check.equal(again.level, s.level, "the same house")
			check.equal(again.guest.x * 100 + again.guest.y, s.guest.x * 100 + s.guest.y, "him in the same place")
		end
	end)

	test("face him and he freezes; stare too long and he hunts", function()
		local s = HouseCall.new(5)
		for _ = 1, 40 do
			HouseCall.step(s, 0) -- (the READY pause)
		end
		-- Him three cells to your left on the start's row, you looking left.
		s.guest.x, s.guest.y, s.guest.wait, s.guest.dir = s.player.x - 3, s.player.y, 0, 2
		local gx = s.guest.x
		local look = HouseCall.encode(4, true)
		local hunted
		for t = 1, 70 do
			HouseCall.step(s, look)
			if s.hunt and not hunted then
				hunted = t
			end
			if not s.hunt then
				check.equal(s.guest.x, gx, "frozen while you look (tick " .. t .. ")")
			end
		end
		check.truthy(hunted ~= nil, "staring made him hunt")
		check.atLeast(hunted, 55, "after about three seconds of it")
		check.atMost(hunted, 62, "not much more")
		-- In the hunt your look doesn't hold him: he comes once he's screamed.
		for _ = 1, 30 do
			HouseCall.step(s, look)
		end
		check.truthy(s.guest.x ~= gx or s.lives < 3, "the hunt moved him")
	end)

	test("a lantern's light keeps you safe in a hunt; touch him anywhere else and he has you", function()
		local s = HouseCall.new(9)
		for _ = 1, 40 do
			HouseCall.step(s, 0)
		end
		-- You on the top-left lantern, him one cell right of it, hunting.
		s.player.x, s.player.y, s.player.px, s.player.py = 1, 1, 1, 1
		s.guest.x, s.guest.y, s.guest.wait = 2, 1, 0
		s.hunt = { phase = "chase", t = 0, age = 0, lost = 0, seenX = 1, seenY = 1 }
		for _ = 1, 200 do
			HouseCall.step(s, HouseCall.encode(2, true))
		end
		check.equal(s.lives, 3, "never caught in the light")
		check.truthy(s.guest.x ~= 1 or s.guest.y ~= 1, "he never stepped into it")
		-- Step out into him: a life gone, then everyone back at the start.
		s.guest.x, s.guest.y, s.guest.wait = 3, 1, 0
		s.hunt = { phase = "chase", t = 0, age = 0, lost = 0, seenX = 1, seenY = 1 }
		local caught = false
		for _ = 1, 60 do
			HouseCall.step(s, HouseCall.encode(2, false))
			caught = caught or s.message == "caught"
		end
		check.truthy(caught, "caught")
		check.equal(s.lives, 2, "a life gone")
		for _ = 1, 120 do
			HouseCall.step(s, 0)
		end
		check.equal(s.player.x * 100 + s.player.y, HouseCall.Start.x * 100 + HouseCall.Start.y, "you back at the start")
	end)

	test("someone watching gets the presses late and still sees the same game", function()
		local s, events = play(31, 3000)
		local runner = HouseCall.runner(31)
		-- The presses arrive in batches, each a little after it was pressed.
		local i = 1
		for tick = 1, s.tick do
			while events[i] and events[i] <= tick - 12 do
				runner:feed({ events[i], events[i + 1] })
				i += 2
			end
			if tick % 7 == 0 then
				runner:advance(tick)
			end
		end
		while events[i] do
			runner:feed({ events[i], events[i + 1] })
			i += 2
		end
		local seen = runner:advance(s.tick)
		check.equal(seen.score, s.score, "the same score")
		check.equal(seen.lives, s.lives, "the same lives")
		check.equal(seen.player.x * 100 + seen.player.y, s.player.x * 100 + s.player.y, "you in the same place")
	end)

	test("presses are checked: in order, whole, ones the stick and button make", function()
		check.truthy(HouseCall.valid({ 1, 2, 5, 10, 5, 0 }), "fine")
		check.truthy(not HouseCall.valid({ 5, 2, 3, 1 }), "out of order")
		check.truthy(not HouseCall.valid({ 1, 6 }), "no such input")
		check.truthy(not HouseCall.valid({ 1.5, 2 }), "a tick is whole")
		check.truthy(not HouseCall.valid({ 1 }), "pairs")
		check.truthy(not HouseCall.valid({ 3, 1 }, 4), "after the last ones already in")
		check.truthy(not HouseCall.valid({ HouseCall.MaxTicks + 1, 1 }), "past a game's end")
		check.truthy(not HouseCall.valid({ 0, 1 }), "from tick 1")
	end)

	test("a fair player's games end, and score", function()
		local total = 0
		for _, seed in { 2, 3, 4, 5, 6, 7 } do
			local s = play(seed, HouseCall.MaxTicks)
			check.truthy(s.over, "seed " .. seed .. " ends")
			check.atLeast(s.score, 500, "seed " .. seed .. " scores")
			total += s.score
		end
		check.atMost(total / 6, 60000, "but not without end")
	end)

	test("a play is paid by the pass, then the day's free play, then a bought play, then Marks", function()
		local data = { Marks = 250, ArcadeCredits = 1, ArcadeFreeDay = 0 }
		local today = 20000
		check.equal(Credits.how(data, today, true), "pass", "the pass first")
		check.equal(Credits.how(data, today, false), "free", "then the free play")
		check.truthy(Credits.pay(data, "free", today, 100), "paid")
		check.truthy(not Credits.pay(data, "free", today, 100), "once a day")
		check.equal(Credits.how(data, today, false), "credit", "then a play bought")
		check.truthy(Credits.pay(data, "credit", today, 100), "spent")
		check.equal(data.ArcadeCredits, 0, "none left")
		check.equal(Credits.how(data, today, false), nil, "then it's the player's choice")
		check.truthy(Credits.pay(data, "marks", today, 100), "100 Marks")
		check.truthy(Credits.pay(data, "marks", today, 100), "and again")
		check.truthy(not Credits.pay(data, "marks", today, 100), "not with 50 left")
		check.equal(data.Marks, 50, "50 left")
		check.equal(Credits.how(data, today + 1, false), "free", "a new day, a new free play")
		check.truthy(not Credits.pay(data, "pass", today, 100, false), "no pass, no free play by it")
	end)
end
