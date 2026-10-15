-- The hub panel: contract, difficulty, tool choice, ready-up, squad, and
-- the player's progress. In the 1988 interface (V7): a manila case folder,
-- typed on, its label taped on, READY a rubber stamp.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Build)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)

local Ui = require(script.Parent.Parent.Lib.Ui)

local player = Players.LocalPlayer

local Lobby = {}
Lobby.__index = Lobby

-- The Night button (Config.Run.Night, Config.Mansion.Profiles).
local NIGHT_LABELS = {
	short = "Night: Short (15 min)",
	full = "Night: Full house",
}

-- The folder, laid out at this size (Ui.fit shrinks it on a small screen).
local WIDTH, HEIGHT = 430, 570
local INSET = 30

function Lobby.new(ctx)
	local self = setmetatable({ ctx = ctx }, Lobby)
	local gui = Ui.screen("ConsensusLobby", 10, ctx.playerGui)
	self.gui = gui
	local root = Ui.new("Frame", {
		Position = UDim2.fromOffset(28, 22),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Ui.fit(root, WIDTH + 40, HEIGHT + 40)
	-- A manila case folder, stood on end (its paper is drawn landscape).
	Ui.paper("Folder", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(HEIGHT, WIDTH),
		Rotation = 89.2,
		ZIndex = 1,
		Parent = root,
	})
	local panel = Ui.new("Frame", {
		Position = UDim2.fromOffset(INSET, INSET - 4),
		Size = UDim2.new(1, -INSET * 2, 1, -INSET * 2 + 4),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = root,
	})
	-- The case's label, typed on a slip and taped on.
	local labelHolder, labelSheet = Ui.paper("Slip", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 6, 0, -6),
		Size = UDim2.fromOffset(196, 56),
		Rotation = 1.6,
		Parent = panel,
	}, false)
	Ui.typed("CASE 88-0412\nTHE HALFWAY HOUSE", {
		Position = UDim2.fromOffset(14, 9),
		Size = UDim2.new(1, -24, 1, -14),
		TextSize = 13,
		LineHeight = 1.1,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
		Parent = labelSheet,
	})
	Ui.tape(labelHolder, UDim2.new(0, 4, 0, 6), -38, 60)
	Ui.title("Consensus", {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 46),
		FontFace = Ui.Fonts.titleBold,
		TextSize = 44,
		Parent = panel,
	})
	Ui.typed("A table laid for something already inside. Set its places, then run.", {
		Position = UDim2.fromOffset(0, 98),
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 13,
		TextColor3 = Ui.Theme.typeDim,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	})
	Ui.rule(panel, 138, Ui.Theme.type, 0.55)

	self.contract = Ui.typed("", {
		Position = UDim2.fromOffset(0, 146),
		Size = UDim2.new(1, 0, 0, 52),
		TextSize = 14,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	})
	local function choice(y: number, onClick)
		return Ui.paperButton("", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 28),
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = panel,
		}, onClick)
	end
	self.difficultyButton = choice(204, function()
		local lobby = ctx.state.lobby
		local current = lobby and lobby.difficulty or "Normal"
		Net.get("SetDifficulty"):FireServer(current == "Normal" and "Hard" or "Normal")
	end)
	-- The length of the night (WP8): a short one by default (about 15
	-- minutes: two wings, two heirlooms; Config.Run.Night), or the squad's
	-- whole house.
	self.nightButton = choice(234, function()
		local lobby = ctx.state.lobby
		local current = lobby and lobby.night or "short"
		Net.get("SetNight"):FireServer(current == "full" and "short" or "full")
	end)

	-- What the difficulty means (it ran off the button, mid-word), else a tip.
	self.note = Ui.hand("Tools are found in the house: look on tables, desks and dressers.", {
		Position = UDim2.fromOffset(0, 266),
		Size = UDim2.new(1, 0, 0, 48),
		TextSize = 22,
		LineHeight = 0.95,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	})

	-- Ready: a rubber stamp once you are.
	self.readyButton = Ui.paperButton("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 320),
		Size = UDim2.new(1, 0, 0, 46),
		TextSize = 24,
		Parent = panel,
	}, function()
		Net.get("SetReady"):FireServer(not player:GetAttribute(Constants.PlayerAttributes.Ready))
	end)
	self.readyStroke = Ui.new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Ui.Theme.red,
		Thickness = 3,
		Transparency = 1,
		Parent = self.readyButton,
	})
	Ui.corner(4).Parent = self.readyButton
	self.countdown = Ui.hand("", {
		Position = UDim2.fromOffset(0, 370),
		Size = UDim2.new(1, 0, 0, 42),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 21,
		LineHeight = 0.95,
		TextColor3 = Ui.Theme.red,
		Parent = panel,
	})
	Ui.typed("SQUAD", {
		Position = UDim2.fromOffset(0, 414),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		Parent = panel,
	})
	Ui.rule(panel, 432, Ui.Theme.type, 0.6)
	self.squad = Ui.typed("", {
		Position = UDim2.fromOffset(0, 436),
		Size = UDim2.new(1, 0, 0, 62),
		TextSize = 14,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	})
	self.profile = Ui.typed("", {
		Position = UDim2.new(0, 0, 1, -34),
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 12,
		TextColor3 = Ui.Theme.typeDim,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Parent = panel,
	})
	-- Which build is running, so a half-synced place is easy to spot.
	Ui.label("build " .. Build.id, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -14),
		Size = UDim2.fromOffset(300, 16),
		TextSize = 12,
		TextColor3 = Ui.Theme.textDim,
		TextStrokeTransparency = 0.7,
		Parent = gui,
	})
	Ui.button("Settings & how to play", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 24),
		Size = UDim2.fromOffset(250, 38),
		TextSize = 16,
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
	self:Render()
	return self
end

function Lobby:Render()
	local state = self.ctx.state
	local lobby = state.lobby
	if lobby then
		self.contract.Text = string.format("Contract: %s\n%s", lobby.location.name, lobby.location.blurb)
		self.difficultyButton.Text = "Difficulty:  " .. lobby.difficulty .. "  >"
		self.note.Text = lobby.difficulty == "Hard"
				and "Hard: uneasy from the start, more wings, quicker hunts, and two downs and you're out."
			or "Tools are found in the house: look on tables, desks and dressers."
		self.nightButton.Text = (lobby.night == "full" and NIGHT_LABELS.full or NIGHT_LABELS.short) .. "  >"
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
	self.readyButton.Text = ready and "READY" or "Mark me ready  >"
	self.readyButton.TextColor3 = ready and Ui.Theme.red or Ui.Theme.type
	self.readyButton.Rotation = ready and -3 or 0
	-- (A stamp's box hugs its word.)
	self.readyButton.Size = ready and UDim2.fromOffset(170, 48) or UDim2.new(1, 0, 0, 46)
	self.readyButton.TextSize = ready and 30 or 24
	self.readyStroke.Transparency = ready and 0.2 or 1
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
		local waiting = state:Run(Constants.RunState.LobbyWaiting)
		local startsAt = state:Run(Constants.RunState.LobbyStartsAt)
		if countdown then
			self.countdown.Text = string.format("Entering the house in %d...", countdown)
		elseif waiting and startsAt then
			-- A majority is ready: the rest have this long, then stay behind.
			local left = math.max(0, startsAt - workspace:GetServerTimeNow())
			self.countdown.Text =
				string.format("Waiting for %s · going in without them in %d s", waiting, math.ceil(left))
		else
			self.countdown.Text = "Everyone ready, or half of you for thirty seconds."
		end
	end
end

return Lobby
