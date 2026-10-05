-- A combination padlock on a door (docs/plans/gameplay-rework.md section 7):
-- tried, it opens in front of you; its code comes from whatever made its
-- token (the home computer prints it). A wrong pull rattles (noise). The
-- rules are Logic/Puzzles/Padlock; Services/PuzzleService runs it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Padlock = require(Shared.Logic.Puzzles.Padlock)
local Sfx = require(Shared.Lib.Sfx)

local Kind = {
	label = "Padlock",
	done = "It's open.",
}

-- Each padlocked door gets a padlock with the code its source prints (the
-- session that made its token: `source.padlock`).
function Kind.fromLocks(service, plan)
	for seamId, lock in plan.locks do
		if lock.kind == "padlock" then
			local token = plan.tokens[lock.needs[1]]
			local source = token and service.sessions[token.producer.id]
			if source and source.padlock then
				local id = "padlock:" .. seamId
				local door = service.World.World.seams[seamId].door
				service.sessions[id] = {
					id = id,
					kind = "padlock",
					spec = source.padlock,
					state = Padlock.start(source.padlock),
					seam = seamId,
					station = door and door.slab,
				}
				service.padlocks[seamId] = id
			end
		end
	end
end

function Kind.event(service, _session, event, player: Player, position: Vector3)
	if event.kind == "rattle" then
		service.Noise:Emit(position, Config.Puzzles.RattleNoise, player, "puzzle")
		Sfx.play("DoorLatch", position, 0.5, 1.6)
	elseif event.kind == "turned" then
		Sfx.play("UIClick", position, 0.15, 1.4)
	end
end

function Kind.solved(service, session, player: Player)
	service.Locks:Unlock(session.seam, player, "The padlock springs open.")
end

return Kind
