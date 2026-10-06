-- Noise events the stalker can hear (doc section 5, "Hearing"). Anything that
-- makes a sound a hunter should react to calls Emit; the stalker drains the
-- queue each perception tick. Voice and typed lines count (Services/ChatService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Lib.Signal)

local NoiseService = {
	Emitted = Signal.new(),
}

local queue = {}

-- kind: "sprint", "walk", "click", "door", "slam", "gasp", "breath", "item", "jump", "tool", "lure",
-- "voice", "speech"
-- Places that drown out footsteps (a washing machine running: Services/
-- InteractService): a step inside one carries only `factor` as far.
local masks = {} -- key -> { position, radius, factor }
local STEPS = { walk = true, sprint = true, jump = true }

function NoiseService:Mask(key: any, position: Vector3, radius: number, factor: number)
	masks[key] = { position = position, radius = radius, factor = factor }
end

function NoiseService:Unmask(key: any)
	masks[key] = nil
end

function NoiseService:Emit(position: Vector3, radius: number, source: Player?, kind: string)
	if STEPS[kind] then
		for _, mask in masks do
			if (position - mask.position).Magnitude <= mask.radius then
				radius *= mask.factor
				break
			end
		end
	end
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
	table.clear(masks)
end

return NoiseService
