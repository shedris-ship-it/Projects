-- How a moving door, drawer, cupboard door or lid tells clients where it is
-- (R2c, the physics feel pass). The server moves the real parts at its own
-- step, which reaches other players in jumps; so while something moves the
-- server also writes a snapshot of its motion on the main part, a few times a
-- second (Config.Hands.MotionHz), and every client draws it smoothly from that
-- with the same rules (Logic/Articulation, Controllers/MotionController).
--
--   Motion     Vector3(value, velocity, server time)
--   MotionAim  Vector3(target, mode: 0 driven / 1 held / 2 free, rate)
--   Value      where it came to rest (written when it stops; Lib/Joint)

local Workspace = game:GetService("Workspace")

local MotionState = {}

MotionState.MODES = { driven = 0, held = 1, free = 2 }
MotionState.NAMES = { [0] = "driven", [1] = "held", [2] = "free" }

-- Server: write the snapshot (at most `hz` a second unless forced).
function MotionState.publish(primary: BasePart, state, hz: number, rate: number?, force: boolean?)
	local now = Workspace:GetServerTimeNow()
	local last = primary:GetAttribute("MotionAt") or 0
	if not force and now - last < 1 / hz then
		return
	end
	primary:SetAttribute("MotionAt", now)
	-- The aim first: a client reads it when Motion changes.
	primary:SetAttribute("MotionAim", Vector3.new(state.target, MotionState.MODES[state.mode] or 0, rate or state.rate))
	primary:SetAttribute("Motion", Vector3.new(state.value, state.velocity, now))
end

-- Server: it has stopped. Where it rests is written first, so a client that
-- hears "stopped" already knows where.
function MotionState.settle(primary: BasePart, value: number)
	primary:SetAttribute("Value", value)
	primary:SetAttribute("MotionAim", nil)
	primary:SetAttribute("MotionAt", nil)
	primary:SetAttribute("Motion", nil)
end

-- Client: the snapshot, or nil when it's at rest.
function MotionState.read(primary: BasePart)
	local motion = primary:GetAttribute("Motion")
	if typeof(motion) ~= "Vector3" then
		return nil
	end
	local aim = primary:GetAttribute("MotionAim")
	local aimed = typeof(aim) == "Vector3"
	return {
		value = motion.X,
		velocity = motion.Y,
		at = motion.Z,
		target = aimed and aim.X or motion.X,
		mode = MotionState.NAMES[aimed and math.round(aim.Y) or 0] or "driven",
		rate = aimed and aim.Z or nil,
	}
end

return MotionState
