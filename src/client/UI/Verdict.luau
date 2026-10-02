-- The Deliberation: name the anomaly. Suspects still on the Case Board are
-- highlighted; everyone sees everyone's vote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anomalies = require(Shared.Data.Anomalies)
local Net = require(Shared.Net)
local Util = require(Shared.Lib.Util)

local Ui = require(script.Parent.Parent.Lib.Ui)

local player = Players.LocalPlayer

local Verdict = {}
Verdict.__index = Verdict

function Verdict.new(ctx)
	local self = setmetatable({ ctx = ctx, session = nil, received = 0 }, Verdict)
	local gui = Ui.screen("ConsensusVerdict", 45, ctx.playerGui)
	gui.Enabled = false
	self.gui = gui
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(820, 520),
		BackgroundColor3 = Ui.Theme.panel,
		Parent = gui,
	}, { Ui.corner(10), Ui.stroke(Ui.Theme.accent, 2, 0.3), Ui.padding(18) })
	Ui.modal(panel)
	self.title = Ui.label("DELIBERATION", {
		Size = UDim2.new(1, 0, 0, 30),
		Font = Ui.Theme.fontType,
		TextSize = 28,
		TextColor3 = Ui.Theme.accent,
		Parent = panel,
	})
	self.subtitle = Ui.label("", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 14,
		TextColor3 = Ui.Theme.textDim,
		Parent = panel,
	})
	local grid = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 300),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	Ui.new("UIGridLayout", {
		CellSize = UDim2.new(0.25, -8, 0, 66),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	self.buttons = {}
	for index, anomaly in Anomalies.List do
		local button = Ui.button(
			anomaly.name,
			{ LayoutOrder = index, TextSize = 15, TextWrapped = true, Parent = grid },
			function()
				Net.get("CastVote"):FireServer(anomaly.id)
			end
		)
		self.buttons[anomaly.id] = button
	end
	self.votes = Ui.label("", {
		Position = UDim2.fromOffset(0, 372),
		Size = UDim2.new(1, 0, 0, 90),
		TextSize = 14,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	})
	self.timer = Ui.label("", {
		Position = UDim2.new(0, 0, 1, -24),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 13,
		TextColor3 = Ui.Theme.textDim,
		Parent = panel,
	})
	Net.get("VerdictState").OnClientEvent:Connect(function(state)
		self:_onState(state)
	end)
	return self
end

function Verdict:_onState(state)
	if state.active then
		self.session = state
		self.received = os.clock()
		self.gui.Enabled = true
		self.subtitle.Text = string.format(
			"%s called it. Pick the anomaly together. %s",
			state.openedBy or "Someone",
			#state.votes <= 2 and "You must agree unanimously." or "After 90 seconds a majority carries."
		)
		local suspects = {}
		for _, id in state.suspects or {} do
			suspects[id] = true
		end
		local mine = nil
		local lines = {}
		for _, vote in state.votes do
			local anomaly = vote.choice and Anomalies.ById[vote.choice]
			table.insert(lines, string.format("%s: %s", vote.name, anomaly and anomaly.name or "…"))
			if vote.userId == player.UserId then
				mine = vote.choice
			end
		end
		self.votes.Text = table.concat(lines, "\n")
		for id, button in self.buttons do
			button.BackgroundColor3 = id == mine and Ui.Theme.accent
				or (suspects[id] and Color3.fromRGB(70, 60, 48) or Ui.Theme.panelLight)
			button.TextColor3 = id == mine and Ui.Theme.ink or (suspects[id] and Ui.Theme.text or Ui.Theme.textDim)
		end
	else
		self.session = nil
		self.gui.Enabled = false
	end
end

function Verdict:Update()
	local session = self.session
	if not session then
		return
	end
	local elapsed = session.elapsed + (os.clock() - self.received)
	local left = session.window - elapsed
	local majority = session.majorityAfter - elapsed
	self.timer.Text = string.format(
		"Time left %s%s · Drift keeps climbing while you argue",
		Util.formatClock(left),
		(#session.votes >= 3 and majority > 0) and ("  ·  majority in " .. Util.formatClock(majority)) or ""
	)
end

return Verdict
