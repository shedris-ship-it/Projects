-- The lobby mall's weather and power between runs (Data/Mall; the owner's
-- picks of 2026-10-15). Now and then the storm strikes over the mall: a
-- strike marked `hub`, which Controllers/WeatherController flashes through
-- the skylight and the main doors for those in the hub, with its thunder.
-- Every few minutes the investigators' generator coughs and everything on
-- its power browns out (RunState MallBrownout, a server time;
-- Controllers/MallController draws it the same for everyone). Looks and
-- sound only: nothing in the rules reads either.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Rng = require(Shared.Lib.Rng)
local Storm = require(Shared.Logic.Storm)

local RS = Constants.RunState
local Phases = Constants.Phases

local MallService = {}

function MallService:Init(services)
	self.services = services
end

function MallService:Start()
	-- Cosmetic timing, not the run's: a seed of its own.
	self.rng = Rng.new(os.time() % 2147483646 + 1)
	local runState = ReplicatedStorage:WaitForChild("RunState")
	local cfg = Config.Mall
	local nextStrike = os.clock() + self.rng:NextNumber(cfg.Storm.Every[1], cfg.Storm.Every[2])
	local nextBrownout = os.clock() + self.rng:NextNumber(cfg.Brownout.Every[1], cfg.Brownout.Every[2])
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			-- The storm over the mall only while it's the hub here: a run's own
			-- storm is WeatherService's (in Studio a server is both).
			local hub = runState:GetAttribute(RS.Phase) == Phases.Lobby
			local places = self.services.PlaceService
			local waitingRoom = places ~= nil and places:IsRun() -- only the garage: no skylight
			if now >= nextStrike then
				if hub and not waitingRoom then
					self:StrikeNow()
				end
				nextStrike = now + self.rng:NextNumber(cfg.Storm.Every[1], cfg.Storm.Every[2])
			end
			if now >= nextBrownout then
				self:BrownoutNow()
				nextBrownout = now + self.rng:NextNumber(cfg.Brownout.Every[1], cfg.Brownout.Every[2])
			end
		end
	end)
end

-- A strike over the mall now (also F2 `mallstrike`).
function MallService:StrikeNow()
	local strike = Storm.strike(self.rng, Storm.Thunder, Config.Storm)
	strike.hub = true
	strike.volume *= Config.Mall.Storm.Volume
	Net.get("Lightning"):FireAllClients(strike)
end

-- The generator browns out now (also F2 `brownout`).
function MallService:BrownoutNow()
	ReplicatedStorage.RunState:SetAttribute(RS.MallBrownout, Workspace:GetServerTimeNow())
end

return MallService
