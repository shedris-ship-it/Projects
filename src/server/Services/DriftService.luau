-- Owns the run's DriftModel and publishes it on ReplicatedStorage.RunState so
-- clients can drive effects from it. Drift is never shown as a bar (doc
-- section 8); the world shows it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Signal = require(Shared.Lib.Signal)
local DriftModel = require(Shared.Logic.DriftModel)

local RS = Constants.RunState

local DriftService = {
	Changed = Signal.new(),
	StateChanged = Signal.new(),
	Collapsed = Signal.new(),
}

function DriftService:Init(services)
	self.PlayerState = services.PlayerStateService
	self.model = nil
	self.running = false
	self.lastState = nil
end

function DriftService:Start()
	local runState = ReplicatedStorage:WaitForChild("RunState")
	self.runState = runState
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		if not self.running then
			return
		end
		accumulator += dt
		if accumulator >= 1 then
			self.model:Tick(accumulator, self.PlayerState:IsolatedCount())
			accumulator = 0
			self:_publish()
		end
	end)
end

function DriftService:Begin(difficulty)
	self.model = DriftModel.new(Config.Drift, difficulty.DriftMultiplier)
	self.running = true
	self.lastState = nil
	self.collapsed = false
	self:_publish()
end

function DriftService:Stop()
	self.running = false
end

function DriftService:Value(): number
	return self.model and self.model.value or 0
end

function DriftService:StateName(): string
	return self.model and (self.model:State()) or "Calm"
end

function DriftService:Apply(eventName: string): number
	if not self.model or not self.running then
		return 0
	end
	local applied = self.model:Apply(eventName, os.clock())
	self:_publish()
	return applied
end

function DriftService:Set(value: number)
	if self.model then
		self.model:Set(value)
		self:_publish()
	end
end

function DriftService:Sources()
	return self.model and self.model.sources or {}
end

function DriftService:_publish()
	local value = self.model.value
	local stateName = self.model:State()
	self.runState:SetAttribute(RS.Drift, math.floor(value * 10 + 0.5) / 10)
	self.runState:SetAttribute(RS.DriftState, stateName)
	self.Changed:Fire(value)
	if stateName ~= self.lastState then
		self.lastState = stateName
		self.StateChanged:Fire(stateName)
	end
	if self.model:IsCollapsed() and not self.collapsed and self.running then
		self.collapsed = true
		self.Collapsed:Fire()
	end
end

return DriftService
