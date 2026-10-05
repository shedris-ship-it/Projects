-- The escape's puzzles (docs/plans/gameplay-rework.md section 7): the home
-- computer and the padlock its printout opens (R2a), the breaker, the safe
-- and the music box later (R2b). Each puzzle's rules are a pure module
-- (Logic/Puzzles/*); this places its station, runs it for one operator at a
-- time and keeps the answer on the server.

local PuzzleService = {}

function PuzzleService:Init(services)
	self.services = services
	self.plan = nil
end

function PuzzleService:Start() end

function PuzzleService:Begin(plan, _rng)
	self.plan = plan
end

-- A player tried a padlocked door: open its padlock for them. False when
-- there's no padlock to open (LockService rattles it instead).
function PuzzleService:OpenPadlock(_player: Player, _seamId: string): boolean
	return false
end

return PuzzleService
