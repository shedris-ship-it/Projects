-- Noise events the stalker can hear (doc section 5, "Hearing"). Anything that
-- makes a sound a hunter should react to calls Emit; the stalker drains the
-- queue each perception tick. Microphone loudness is deliberately not used.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Lib.Signal)

local NoiseService = {
	Emitted = Signal.new(),
}

local queue = {}

-- kind: "sprint", "door", "slam", "gasp", "breath", "item", "jump", "tool", "lure"
function NoiseService:Emit(position: Vector3, radius: number, source: Player?, kind: string)
	local event = { position = position, radius = radius, source = source, kind = kind, t = os.clock() }
	table.insert(queue, event)
	if #queue > 64 then
		table.remove(queue, 1)
	end
	self.Emitted:Fire(event)
end

-- Return and clear everything emitted since the last drain.
function NoiseService:Drain(): { any }
	local events = queue
	queue = {}
	return events
end

function NoiseService:Clear()
	queue = {}
end

return NoiseService
