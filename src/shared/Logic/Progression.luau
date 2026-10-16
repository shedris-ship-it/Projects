-- Free progression (doc section 9): Marks every run, win or lose, and
-- Clearance levels 1-50. What a run pays is Config.Pay (LB3: Marks about
-- half of before; Clearance XP as before).

local Config = require(script.Parent.Parent.Config)

local Progression = {}

Progression.MaxClearance = 50

-- One sum (Config.Pay.Marks or .Xp) over a run's result: the escape pays
-- for progress made even when the run is lost (R2c), so a squad that opened
-- half the house still gains. The family's valuables carried out of the
-- front door pay everyone in the squad (push your luck, 2026-10-11).
local function sum(weights, result, valuable: number): number
	local total = weights.base
	if result.won then
		total += weights.won
		total += math.floor(math.max(0, 100 - (result.drift or 100)) / weights.drift)
	end
	if result.extracted then
		total += weights.extracted
	end
	total += weights.region * (result.regionsOpened or 0)
	total += weights.puzzle * (result.puzzlesSolved or 0)
	total += weights.hunt * (result.survivedHunts or 0)
	total += math.max(0, result.valuables or 0) * valuable
	return total
end

-- result = { won, extracted (bool), drift, survivedHunts, regionsOpened,
-- puzzlesSolved, valuables, valuableMarks, valuableXp }.
function Progression.marksForRun(result): number
	return sum(Config.Pay.Marks, result, result.valuableMarks or 0)
end

function Progression.xpForRun(result): number
	return sum(Config.Pay.Xp, result, result.valuableXp or 0)
end

-- The day (UTC) a time falls on, for the daily double.
function Progression.day(seconds: number): number
	return math.floor(seconds / 86400)
end

-- A run's Marks with the daily double: your first escape (out of the front
-- door) on a day you haven't had it. Returns the Marks and whether this run
-- was the day's double (the profile then records `today`).
function Progression.withDaily(marks: number, result, lastDay: number, today: number): (number, boolean)
	if result.extracted and today ~= lastDay then
		return marks * Config.Pay.DailyDouble, true
	end
	return marks, false
end

function Progression.xpForLevel(level: number): number
	return 100 + 25 * (level - 1)
end

-- Total xp -> clearance level and progress into the next level.
function Progression.levelFromXp(xp: number): (number, number, number)
	local level = 1
	local remaining = xp
	while level < Progression.MaxClearance and remaining >= Progression.xpForLevel(level) do
		remaining -= Progression.xpForLevel(level)
		level += 1
	end
	return level, remaining, Progression.xpForLevel(level)
end

return Progression
