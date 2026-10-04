-- The hub panel: contract, difficulty, tool choice, ready-up, squad, and
-- the player's progress.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)

local Ui = require(script.Parent.Parent.Lib.Ui)

local player = Players.LocalPlayer

local Lobby = {}
Lobby.__index = Lobby

function Lobby.new(ctx)
	local self = setmetatable({ ctx = ctx }, Lobby)
	local gui = Ui.screen("ConsensusLobby", 10, ctx.playerGui)
	self.gui = gui
	local panel = Ui.new("Frame", {
		Position = UDim2.fromOffset(24, 24),
		Size = UDim2.fromOffset(380, 440),
		BackgroundColor3 = Ui.Theme.panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, { Ui.corner(10), Ui.stroke(Ui.Theme.accent, 1, 0.5), Ui.padding(16) })
	Ui.label("CONSENSUS", {
		Size = UDim2.new(1, 0, 0, 40),
		Font = Ui.Theme.fontType,
		TextSize = 38,
		TextColor3 = Ui.Theme.accent,
		Parent = panel,
	})
	Ui.label("Reality only holds when two of you agree on it.", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 13,
		TextColor3 = Ui.Theme.textDim,
		Parent = panel,
	})

	self.contract = Ui.label(
		"",
		{ Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 40), TextSize = 14, Parent = panel }
	)
	self.difficultyButton = Ui.button(
		"Difficulty: Normal",
		{ Position = UDim2.fromOffset(0, 114), Size = UDim2.new(1, 0, 0, 34), TextSize = 14, Parent = panel },
		function()
			local lobby = ctx.state.lobby
			local current = lobby and lobby.difficulty or "Normal"
			Net.get("SetDifficulty"):FireServer(current == "Normal" and "Hard" or "Normal")
		end
	)

	Ui.label("Tools are found in the house: look on tables, desks and dressers.", {
		Position = UDim2.fromOffset(0, 158),
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 13,
		TextColor3 = Ui.Theme.textDim,
		Parent = panel,
	})

	self.readyButton = Ui.button(
		"Ready",
		{ Position = UDim2.fromOffset(0, 202), Size = UDim2.new(1, 0, 0, 44), TextSize = 18, Parent = panel },
		function()
			Net.get("SetReady"):FireServer(not player:GetAttribute(Constants.PlayerAttributes.Ready))
		end
	)
	self.countdown = Ui.label("", {
		Position = UDim2.fromOffset(0, 250),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 15,
		TextColor3 = Ui.Theme.accent,
		Parent = panel,
	})
	Ui.label("Squad", {
		Position = UDim2.fromOffset(0, 282),
		Size = UDim2.new(1, 0, 0, 18),
		Font = Ui.Theme.fontBold,
		TextSize = 14,
		Parent = panel,
	})
	self.squad = Ui.label("", {
		Position = UDim2.fromOffset(0, 302),
		Size = UDim2.new(1, 0, 0, 80),
		TextSize = 13,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	})
	self.profile = Ui.label("", {
		Position = UDim2.new(0, 0, 1, -40),
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 13,
		TextColor3 = Ui.Theme.textDim,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Parent = panel,
	})
	Ui.button("Settings & how to play", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 24),
		Size = UDim2.fromOffset(210, 36),
		TextSize = 14,
		Parent = gui,
	}, function()
		ctx.ui:ToggleSettings()
	end)

	ctx.state.LobbyChanged:Connect(function()
		self:Render()
	end)
	ctx.state.ProfileChanged:Connect(function()
		self:Render()
	end)
	ctx.state.AttributeChanged:Connect(function()
		self:Render()
	end)
	return self
end

function Lobby:Render()
	local state = self.ctx.state
	local lobby = state.lobby
	if lobby then
		self.contract.Text = string.format("Contract: %s\n%s", lobby.location.name, lobby.location.blurb)
		self.difficultyButton.Text = "Difficulty: "
			.. lobby.difficulty
			.. (lobby.difficulty == "Hard" and "  (faster Drift, more red herrings)" or "")
		local lines = {}
		for _, p in lobby.players do
			local status = p.state == Constants.PlayerStates.Lobby or p.state == nil
			table.insert(
				lines,
				string.format("%s  ·  %s", p.name, status and (p.ready and "READY" or "not ready") or "in the house")
			)
		end
		self.squad.Text = table.concat(lines, "\n")
	end
	local ready = player:GetAttribute(Constants.PlayerAttributes.Ready) == true
	self.readyButton.Text = ready and "Ready! (click to cancel)" or "Ready"
	self.readyButton.BackgroundColor3 = ready and Ui.Theme.good or Ui.Theme.panelLight
	local profile = state.profile
	if profile then
		self.profile.Text = string.format(
			"Clearance %d (%d/%d)  ·  %d Marks  ·  %d runs, %d won%s",
			profile.clearance,
			profile.xpInto,
			profile.xpNeeded,
			profile.marks,
			profile.runs,
			profile.wins,
			profile.saved and "" or "  ·  progress not saved here"
		)
	end
end

function Lobby:Update()
	local state = self.ctx.state
	local inLobby = state:Phase() == Constants.Phases.Lobby and state:PlayerState() == Constants.PlayerStates.Lobby
	self.gui.Enabled = inLobby
	if inLobby then
		local countdown = state:Run(Constants.RunState.LobbyCountdown)
		self.countdown.Text = countdown and string.format("Entering the house in %d…", countdown)
			or "Everyone in the hub must be ready."
	end
end

return Lobby
