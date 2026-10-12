-- The storm that builds (the visual rework V2; Logic/Storm): still and foggy
-- at first, rain by the middle of the night, thunder and lightning late,
-- and always in the dinner's run out and the Reckoning. The server decides
-- the stage (RunState Storm) and every strike, from the run's own seed, so
-- everyone sees the same flash at the same moment and hears the same
-- thunder (shared, like the house's decay: docs/ART.md rule 6). Looks and
-- sound only: nothing in the rules reads it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Storm = require(Shared.Logic.Storm)

local RS = Constants.RunState
local Phases = Constants.Phases

local WeatherService = {}

function WeatherService:Init(services)
	self.Orchestrator = services.RunOrchestrator
end

function WeatherService:Start()
	local runState = ReplicatedStorage:WaitForChild("RunState")
	local lightning = Net.get("Lightning")
	local run, rng, nextStrike = nil, nil, nil
	task.spawn(function()
		while true do
			task.wait(1)
			local phase = runState:GetAttribute(RS.Phase)
			local inRun = phase == Phases.Arrival
				or phase == Phases.Investigation
				or phase == Phases.Resolution
				or phase == Phases.Extraction
			if not inRun then
				run, rng, nextStrike = nil, nil, nil
				if runState:GetAttribute(RS.Storm) ~= nil then
					runState:SetAttribute(RS.Storm, nil)
				end
				continue
			end
			-- A new run: its own fork of the seed.
			local current = self.Orchestrator.run
			if current and current ~= run then
				run = current
				rng = current.rng:Fork("weather")
				nextStrike = nil
			end
			if not rng then
				continue
			end
			local finale = phase == Phases.Extraction or runState:GetAttribute(RS.Reckoning) == true
			local dread = runState:GetAttribute(RS.Dread) or runState:GetAttribute(RS.Drift) or 0
			local stage = self.forced or Storm.stage(dread, finale, Config.Storm)
			if runState:GetAttribute(RS.Storm) ~= stage then
				runState:SetAttribute(RS.Storm, stage)
				nextStrike = nil
			end
			local now = os.clock()
			if not nextStrike then
				local gap = Storm.nextIn(rng, stage, Config.Storm)
				nextStrike = gap and now + gap or nil
			elseif now >= nextStrike then
				lightning:FireAllClients(Storm.strike(rng, stage, Config.Storm))
				local gap = Storm.nextIn(rng, stage, Config.Storm)
				nextStrike = gap and now + gap or nil
			end
		end
	end)
end

-- F2 `storm [0|1|2|strike]` (Services/DebugService): a strike now, for testing.
function WeatherService:StrikeNow(stage: number?)
	local current = self.Orchestrator.run
	local rng = current and current.rng:Fork("weather-debug" .. os.clock()) or nil
	if not rng then
		return false
	end
	Net.get("Lightning"):FireAllClients(Storm.strike(rng, stage or Storm.Thunder, Config.Storm))
	return true
end

return WeatherService
