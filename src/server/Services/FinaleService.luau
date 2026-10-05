-- The dinner, the escape's finale (docs/plans/gameplay-rework.md section 6):
-- the heirlooms laid at the dining table for The Guest; when the last is set
-- he takes his place, the final hunt starts and the front door opens.

local FinaleService = {}

function FinaleService:Init(services)
	self.services = services
	self.plan = nil
end

function FinaleService:Start() end

function FinaleService:Begin(plan)
	self.plan = plan
	self.served = false
end

-- Serve the dinner now (the last heirloom set, or F2 `resolve`).
function FinaleService:Serve()
	if not self.plan or self.served then
		return
	end
	self.served = true
	self.services.RunOrchestrator:BeginEscape()
end

return FinaleService
