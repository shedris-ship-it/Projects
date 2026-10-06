-- The run in numbers (Logic/RunStats): silence, tier time, hunts and how
-- they ended, as the F2 overlay and the Dossier report them.
return function(test, check, Shared, require)
	local RunStats = require(Shared.Logic.RunStats)
	local cfg = { SilentSeconds = 60 }

	test("silence is the time between beats; only stretches of a minute count as silent minutes", function()
		local s = RunStats.new(0, cfg)
		s:Beat(30, "scare", "knock") -- 30 s: not silent
		s:Beat(150, "scare", "steps") -- 120 s: silent
		s:Beat(170, "sighting")
		local sum = s:Summary(260) -- 90 s of quiet going on now
		check.equal(sum.silentLongest, 120, "longest stretch")
		check.equal(sum.silentTotal, 210, "120 + the 90 going on")
		check.equal(sum.silentNow, 90, "quiet now")
		check.equal(s:Summary(200).silentTotal, 120, "a 30 s quiet does not count")
	end)

	test("the tier score is time-weighted from his arrival", function()
		local s = RunStats.new(0, cfg)
		s:Tick(50, 0, false) -- before arrival: nothing counted
		s:Arrived(90)
		for t = 91, 150 do
			s:Tick(t, 1, false)
		end
		for t = 151, 210 do
			s:Tick(t, 3, t % 2 == 0)
		end
		local sum = s:Summary(210)
		check.near(sum.tierScore, 2, 0.01, "half at tier 1, half at tier 3")
		check.near(sum.highTierShare, 0.5, 0.01, "half the time high")
		check.equal(sum.tierSeconds[1], 60, "tier 1 seconds")
		check.equal(sum.tierSeconds[3], 60, "tier 3 seconds")
		check.atLeast(sum.freezes, 29, "frozen on and off")
		check.near(sum.freezeSeconds, 30, 1, "half of the tier 3 time frozen")
	end)

	test("hunts record why they came and how they ended; catches land on the hunt going on", function()
		local s = RunStats.new(0, cfg)
		s:HuntBegan(300, "region 1")
		s:Catch(320, "Ann", "hunt")
		s:HuntEnded(360, "survived")
		s:HuntBegan(600, "act 2")
		s:StareDown(610, true)
		s:HuntEnded(620, "stared down")
		s:FalseAlarm(800)
		s:HuntBegan(900, "final")
		local sum = s:Summary(950)
		check.equal(#sum.hunts, 3, "three hunts")
		check.equal(sum.hunts[1].how, "survived", "first ended")
		check.equal(sum.hunts[1].catches, 1, "one caught in the first")
		check.equal(sum.hunts[1].seconds, 60, "first lasted a minute")
		check.equal(sum.hunts[2].how, "stared down", "second stared down")
		check.equal(sum.hunts[3].how, "going on", "the final is still on")
		check.equal(sum.falseAlarms, 1, "one false alarm")
		check.equal(sum.stareDowns, 1, "one stare-down")
		check.equal(sum.catches, 1, "one catch in all")
		local lines = RunStats.lines(sum)
		check.truthy(#lines >= 6, "lines for the Dossier")
		check.truthy(string.find(lines[1], "act 1", 1, true), "the first line names the act")
		check.equal(#RunStats.overlay(sum), 3, "three overlay lines")
	end)

	test("progress: the first step and the time since the last", function()
		local s = RunStats.new(100, cfg)
		check.equal(s:Summary(400).firstProgressAt, nil, "none yet")
		check.equal(s:Summary(400).sinceProgress, 300, "since the start")
		s:Progress(340, "lock")
		s:Progress(500, "found")
		local sum = s:Summary(560)
		check.equal(sum.firstProgressAt, 240, "the first, from the start of the run")
		check.equal(sum.sinceProgress, 60, "since the last")
		check.equal(sum.progress, 2, "two steps")
		check.equal(sum.scareTotal, 0, "no scares")
		s:Scare(561, "knock")
		s:Scare(562, "knock")
		s:Scare(563, "flicker")
		local sorted = s:Summary(570).scares
		check.equal(sorted[1].id, "knock", "most played first")
		check.equal(sorted[1].count, 2, "twice")
	end)
end
