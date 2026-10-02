-- Run events for tuning (doc section 12, "Metrics to instrument"). Prints a
-- compact log line with the run seed, and forwards to Roblox's
-- AnalyticsService custom events where available. Named Telemetry so it
-- doesn't collide with the AnalyticsService Roblox service.

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")

local Telemetry = {
	seed = nil,
}

function Telemetry:SetRun(seed: number?)
	self.seed = seed
end

-- data must be JSON-encodable.
function Telemetry:Log(event: string, data, player: Player?)
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data or {})
	print(string.format("[Consensus:event] %s seed=%s %s", event, tostring(self.seed), ok and encoded or "{}"))
	if player then
		pcall(function()
			(AnalyticsService :: any):LogCustomEvent(player, event, 1)
		end)
	end
end

return Telemetry
