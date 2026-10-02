-- The Deliberation Table (doc section 2, "Verdict"). Anyone at the table can
-- call a deliberation; every living Witness votes from wherever they are.
-- Pairs must agree unanimously; bigger squads carry a majority after 90
-- seconds. A wrong verdict spikes Drift and sets the stalker loose.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Anomalies = require(Shared.Data.Anomalies)
local Verdict = require(Shared.Logic.Verdict)
local Net = require(Shared.Net)
local Signal = require(Shared.Lib.Signal)

local VerdictService = {
	Decided = Signal.new(), -- (anomalyId, correct)
}

function VerdictService:Init(services)
	self.services = services
	self.PlayerState = services.PlayerStateService
	self.session = nil
	self.lastFailed = -math.huge
	self.enabled = false
end

function VerdictService:Start()
	self.services.WorldService.Built:Connect(function(world)
		local tableModel = world.deliberationTable
		if not tableModel then
			return
		end
		local top = tableModel:IsA("BasePart") and tableModel or tableModel:FindFirstChild("Top")
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DeliberatePrompt"
		prompt.ActionText = "Call deliberation"
		prompt.ObjectText = "Deliberation Table"
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = top or tableModel:FindFirstChildWhichIsA("BasePart")
		prompt.Triggered:Connect(function(player)
			self:Open(player)
		end)
		self.prompt = prompt
	end)
	Net.onServer("CastVote", { interval = 0.3, types = { "string" } }, function(player, anomalyId)
		self:Vote(player, anomalyId)
	end)
	RunService.Heartbeat:Connect(function()
		if self.session then
			self:_evaluate()
		end
	end)
end

function VerdictService:SetEnabled(enabled: boolean)
	self.enabled = enabled
	if not enabled and self.session then
		self:_close("cancelled")
	end
end

local function notifyAll(text, kind)
	Net.get("Notify"):FireAllClients(text, kind)
end

function VerdictService:Open(player: Player)
	if not self.enabled or self.session or not self.PlayerState:CanAct(player) then
		return
	end
	local remaining = Config.Social.VerdictRetryCooldown - (os.clock() - self.lastFailed)
	if remaining > 0 then
		Net.get("Notify"):FireClient(
			player,
			string.format("The squad needs %d more seconds before trying again.", math.ceil(remaining)),
			"warning"
		)
		return
	end
	local voters = {}
	for _, p in self.PlayerState:LivingPlayers() do
		voters[p] = true
	end
	self.session = {
		opened = os.clock(),
		openedBy = player.DisplayName,
		voters = voters,
		votes = {},
	}
	notifyAll(player.DisplayName .. " called a deliberation. Name the anomaly.", "verdict")
	self:_broadcast()
end

function VerdictService:Vote(player: Player, anomalyId)
	local session = self.session
	if not session or not session.voters[player] then
		return
	end
	if type(anomalyId) ~= "string" or not Anomalies.ById[anomalyId] then
		return
	end
	session.votes[player.UserId] = anomalyId
	self:_broadcast()
	self:_evaluate()
end

function VerdictService:_evaluate()
	local session = self.session
	-- Lost or departed Witnesses stop counting.
	for voter in session.voters do
		if not voter.Parent or (not self.PlayerState:IsActive(voter) and self.PlayerState:State(voter) ~= "Downed") then
			session.voters[voter] = nil
			session.votes[voter.UserId] = nil
		end
	end
	local voterCount = 0
	for _ in session.voters do
		voterCount += 1
	end
	local elapsed = os.clock() - session.opened
	local status, choice = Verdict.evaluate(session.votes, voterCount, elapsed, Config.Social)
	if status == "decided" then
		self:_close("decided", choice)
	elseif status == "deadlock" then
		self:_close("deadlock")
	elseif math.floor(elapsed) ~= session.lastBroadcastSecond then
		session.lastBroadcastSecond = math.floor(elapsed)
		self:_broadcast()
	end
end

function VerdictService:_close(reason: string, choice: string?)
	self.session = nil
	if reason == "decided" then
		local correct = self.services.AnomalyService:Anomaly().id == choice
		Net.get("VerdictState")
			:FireAllClients({ active = false, result = correct and "correct" or "wrong", choice = choice })
		if not correct then
			self.lastFailed = os.clock()
		end
		self.Decided:Fire(choice, correct)
	else
		self.lastFailed = os.clock()
		Net.get("VerdictState"):FireAllClients({ active = false, result = reason })
		if reason == "deadlock" then
			notifyAll("The squad couldn't agree. The house keeps drifting.", "warning")
		end
	end
end

function VerdictService:_broadcast(player: Player?)
	local session = self.session
	if not session then
		return
	end
	local votes = {}
	for voter in session.voters do
		local choice = session.votes[voter.UserId]
		table.insert(votes, { name = voter.DisplayName, userId = voter.UserId, choice = choice })
	end
	table.sort(votes, function(a, b)
		return a.userId < b.userId
	end)
	local elapsed = os.clock() - session.opened
	local payload = {
		active = true,
		openedBy = session.openedBy,
		votes = votes,
		elapsed = elapsed,
		window = Config.Social.VerdictWindow,
		majorityAfter = Config.Social.VerdictMajorityAfter,
		suspects = self.services.CaseBoardService:Suspects(),
	}
	if player then
		Net.get("VerdictState"):FireClient(player, payload)
	else
		Net.get("VerdictState"):FireAllClients(payload)
	end
end

function VerdictService:SyncPlayer(player: Player)
	if self.session then
		self:_broadcast(player)
	end
end

function VerdictService:Reset()
	self.session = nil
	self.lastFailed = -math.huge
	self.enabled = false
end

return VerdictService
