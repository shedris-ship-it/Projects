-- Free progression (doc section 9): Marks every run, win or lose, and
-- Clearance levels 1-50.

local Progression = {}

Progression.MaxClearance = 50

-- result = { won, extracted (bool), drift, survivedHunts, regionsOpened,
-- puzzlesSolved }: the escape pays for progress made even when the run is
-- lost (R2c), so a squad that opened half the house still gains.
function Progression.marksForRun(result): number
	local marks = 40
	if result.won then
		marks += 100
		marks += math.floor(math.max(0, 100 - result.drift) / 2)
	end
	if result.extracted then
		marks += 25
	end
	marks += 10 * (result.regionsOpened or 0)
	marks += 10 * (result.puzzlesSolved or 0)
	marks += 15 * (result.survivedHunts or 0)
	return marks
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
