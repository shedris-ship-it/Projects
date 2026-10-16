-- The diner's run records and the boards behind them (LB5; Logic/Records,
-- Logic/Leaderboard).
return function(test, check, Shared, require)
	local Leaderboard = require(Shared.Logic.Leaderboard)
	local Records = require(Shared.Logic.Records)
	local Profile = require(Shared.Logic.Profile)

	local function values(list)
		local out = {}
		for _, entry in list do
			table.insert(out, entry.value)
		end
		return table.concat(out, ",")
	end

	test("a board keeps its best few in order, ties to the older, and refuses what doesn't make it", function()
		local list = {}
		local rank
		for _, v in { 50, 30, 40, 30, 20 } do
			list, rank = Leaderboard.insert(list, { value = v, tag = v }, 3, true)
		end
		check.equal(values(list), "20,30,30", "fastest first, three kept")
		check.equal(rank, 1, "the newest was the best")
		local before = values(list)
		list, rank = Leaderboard.insert(list, { value = 35 }, 3, true)
		check.equal(rank, nil, "35 doesn't make a board of 20, 30, 30")
		check.equal(values(list), before, "unchanged")
		list, rank = Leaderboard.insert(list, { value = 30, newest = true }, 3, true)
		check.equal(rank, nil, "a tie with the last place doesn't push it off")
		check.truthy(not Leaderboard.makes(list, 30, 3, true), "makes agrees")
		check.truthy(Leaderboard.makes(list, 29, 3, true), "but 29 would")
		local high = {}
		for _, v in { 5, 9, 7 } do
			high = Leaderboard.insert(high, { value = v }, 5)
		end
		check.equal(values(high), "9,7,5", "higher first when higher is better")
	end)

	test("one entry a player: a better score replaces theirs, a worse one never does", function()
		local list = {}
		list = Leaderboard.insert(list, { value = 100, key = "1" }, 10, false, true)
		list = Leaderboard.insert(list, { value = 300, key = "2" }, 10, false, true)
		local rank
		list, rank = Leaderboard.insert(list, { value = 80, key = "1" }, 10, false, true)
		check.equal(rank, nil, "a worse score of yours is refused")
		check.equal(values(list), "300,100", "your best stays")
		list, rank = Leaderboard.insert(list, { value = 500, key = "1" }, 10, false, true)
		check.equal(rank, 1, "a better one takes the top")
		check.equal(values(list), "500,300", "and only once")
	end)

	test("a saved board is cleaned: bad entries dropped, sorted, cut to size", function()
		local list = Leaderboard.clean(
			{ { value = 3 }, "junk", { value = 0 / 0 }, { value = 1 }, { nope = 2 }, { value = 2 } },
			2,
			true
		)
		check.equal(values(list), "1,2", "the two best of the good ones")
		check.equal(#Leaderboard.clean(nil, 5), 0, "nothing saved is an empty board")
	end)

	test("only real runs count: an escape on the short night, never Studio or one an F2 command touched", function()
		local run = {
			won = true,
			extracted = 1,
			location = "HalfwayHouse",
			night = "short",
			difficulty = "Normal",
			seconds = 600,
		}
		check.truthy(Records.counts(run), "a real escape counts")
		local function why(changes)
			local copy = table.clone(run)
			for k, v in changes do
				copy[k] = v
			end
			local ok, reason = Records.counts(copy)
			return ok and "counts" or reason
		end
		check.equal(why({ studio = true }), "studio", "never from Studio")
		check.equal(why({ debugged = true }), "debug", "never with F2")
		check.equal(why({ won = false }), "lost", "only escapes")
		check.equal(why({ extracted = 0 }), "lost", "somebody got out")
		check.equal(why({ night = "full" }), "night", "the short night only, to start")
		check.equal(why({ location = "StOdileWard" }), "location", "only The Halfway House has boards so far")
		check.equal(why({ difficulty = "Easy" }), "difficulty", "Normal or Hard")
		check.equal(why({ seconds = 0 }), "time", "a time to post")
	end)

	test("a run goes on its fastest and its longest list, solo or squad by who started it", function()
		local solo = Records.lists({ difficulty = "Hard", size = 1 })
		check.equal(#solo, 2, "two lists")
		check.equal(solo[1].board, "Records_Hard_FastSolo", "fastest solo on the specials board")
		check.truthy(solo[1].low, "fastest: lower is better")
		check.equal(solo[2].board, "Records_Hard_LongSolo", "and the longest solo")
		check.truthy(not solo[2].low, "longest: higher is better")
		local squad = Records.lists({ difficulty = "Normal", size = 3 })
		check.equal(squad[1].board, "Records_Normal_FastSquad", "a squad's fastest on the menu board")
		check.equal(squad[2].board, "Records_Normal_LongSquad", "and its longest")
		local entry = Records.entry({ seconds = 724.36, names = { "Alex", "Sam", "Jo" }, size = 3, at = 5 })
		check.equal(entry.value, 7244, "tenths of a second")
		check.equal(entry.size, 3, "the squad's size")
		check.equal(#entry.names, 3, "every name")
	end)

	test("times and lines read as the boards show them", function()
		check.equal(Records.clock(7244), "12:04", "minutes and seconds")
		check.equal(Records.clock(37290), "1:02:09", "past an hour")
		check.equal(Records.line(nil, true), "--:--", "an empty place")
		check.equal(Records.line({ value = 7244, names = { "Alex" }, size = 1 }, true), "12:04  ALEX", "solo")
		check.equal(
			Records.line({ value = 11210, names = { "Alex", "Sam" }, size = 2 }, false),
			"18:41  x2  ALEX, SAM",
			"a squad"
		)
	end)

	test("weeks start again on Monday at midnight UTC", function()
		local monday = 1760918400 -- Monday 20 October 2025, 00:00 UTC
		local week = Leaderboard.week(monday)
		check.equal(Leaderboard.week(monday - 1), week - 1, "Sunday night is last week")
		check.equal(Leaderboard.week(monday + 7 * 86400 - 1), week, "the whole week")
		check.equal(Leaderboard.week(monday + 7 * 86400), week + 1, "next Monday a new one")
	end)

	test("version 5 (LB5): a profile gains the day of its last free arcade play", function()
		local data = Profile.reconcile({ Version = 4, Marks = 10 })
		check.equal(data.Version, Profile.Version, "upgraded")
		check.equal(data.ArcadeFreeDay, 0, "no free play used yet")
		check.equal(data.Marks, 10, "kept")
		check.equal(Profile.reconcile({ ArcadeFreeDay = -3 }).ArcadeFreeDay, 0, "clamped")
	end)
end
