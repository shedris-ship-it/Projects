-- Owns the run's DriftModel and publishes it on ReplicatedStorage.RunState so
-- clients can drive effects from it. Drift is never shown as a bar (doc
-- section 8); the world shows it.
--
-- Also publishes Dread (Logic/Dread): Drift or the act's floor, whichever is
-- worse, which is what every escalation clients draw reads since the owner's
-- audit (2026-10-06). Stalker/Director tells it the act.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Signal = require(Shared.Lib.Signal)
local Dread = require(Shared.Logic.Dread)
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
	self.difficulty = nil
	self.act = 1
	self.actSince = nil
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
			self.model:Tick(accumulator, self.PlayerState:IsolatedCount(), self:Stalled())
			accumulator = 0
			self:_publish()
		end
	end)
end

function DriftService:Begin(difficulty)
	self.model = DriftModel.new(Config.Drift, difficulty.DriftMultiplier)
	self.difficulty = difficulty
	self.act = 1
	self.actSince = os.clock()
	self.running = true
	self.lastState = nil
	self.collapsed = false
	self.lastProgress = os.clock()
	self:_publish()
end

-- No progress for a while (Config.Drift.StallGraceSeconds): the house grows
-- restless (DriftModel:Tick).
function DriftService:Stalled(): boolean
	return self.lastProgress ~= nil and os.clock() - self.lastProgress >= Config.Drift.StallGraceSeconds
end

-- Seconds since the last progress (Logic/Assist reads it).
function DriftService:SinceProgress(): number
	return self.lastProgress and os.clock() - self.lastProgress or 0
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
	if Config.Drift.ProgressEvents[eventName] then
		self.lastProgress = os.clock()
	end
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

-- The run's act (Stalker/Director): Dread's floor rises with it.
function DriftService:SetAct(act: number)
	if act ~= self.act then
		-- The new act's floor eases in from where Dread already is (Logic/Dread).
		self.actFrom = self:Dread()
		self.act = act
		self.actSince = os.clock()
		if self.running then
			self:_publish()
		end
	end
end

-- How bad the house is right now (Logic/Dread).
function DriftService:Dread(): number
	if not self.model or not self.running then
		return 0
	end
	local since = self.actSince and os.clock() - self.actSince or math.huge
	return Dread.value(self.model.value, self.act, since, Config.Pacing, self.difficulty, self.actFrom)
end

function DriftService:DreadStateName(): string
	return (DriftModel.stateFor(Config.Drift, self:Dread()))
end

function DriftService:_publish()
	local value = self.model.value
	local stateName = self.model:State()
	self.runState:SetAttribute(RS.Drift, math.floor(value * 10 + 0.5) / 10)
	self.runState:SetAttribute(RS.DriftState, stateName)
	local dread = self:Dread()
	self.runState:SetAttribute(RS.Dread, math.floor(dread * 10 + 0.5) / 10)
	self.runState:SetAttribute(RS.DreadState, (DriftModel.stateFor(Config.Drift, dread)))
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
