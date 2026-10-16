-- The hub panel: the case, how a squad leaves (LB2: rent a tape, get in a
-- car, the driver honks; UI/Dashboard is the car's), who's where, and the
-- player's progress. In the 1988 interface (V7): a manila case folder,
-- typed on, its label taped on.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Build)
local Constants = require(Shared.Constants)

local Ui = require(script.Parent.Parent.Lib.Ui)

local player = Players.LocalPlayer

local Lobby = {}
Lobby.__index = Lobby

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
	-- How a squad leaves (LB2): three steps, typed, the one you're on
	-- ticked in pen.
	self.steps = Ui.typed("", {
		Position = UDim2.fromOffset(0, 204),
		Size = UDim2.new(1, 0, 0, 92),
		TextSize = 15,
		LineHeight = 1.25,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	})
	self.note = Ui.hand("", {
		Position = UDim2.fromOffset(0, 300),
		Size = UDim2.new(1, 0, 0, 108),
		TextSize = 21,
		LineHeight = 0.95,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	})
	Ui.typed("WHO'S HERE", {
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
	local tape = player:GetAttribute(Constants.PlayerAttributes.Tape)
	local inCar = player:GetAttribute(Constants.PlayerAttributes.Car) ~= nil
	if lobby then
		self.contract.Text = string.format("Case: %s\n%s", lobby.location.name, lobby.location.blurb)
		local function step(done: boolean, text: string)
			return (done and "[x]  " or "[  ]  ") .. text
		end
		self.steps.Text = table.concat({
			step(tape ~= nil or inCar, "Rent the case in the video store."),
			step(inCar, "Take it to a car in the garage. Get in."),
			step(false, "The driver honks. The car takes you there."),
		}, "\n")
		self.note.Text = inCar and "Your car's dashboard: the difficulty, the night, friends only, the horn."
			or "Your friends can ride with you: one car seats four. The payphone in the garage calls more."
		local lines = {}
		for _, p in lobby.players do
			local here = p.state == Constants.PlayerStates.Lobby or p.state == nil
			table.insert(
				lines,
				string.format(
					"%s  ·  %s",
					p.name,
					here and (p.car and ("in " .. p.car) or "in the mall") or "in the house"
				)
			)
		end
		self.squad.Text = table.concat(lines, "\n")
	end
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
	-- (Put away in the boutique's fitting room: its card is the one to read.)
	local trying = player:GetAttribute(Constants.PlayerAttributes.Trying) ~= nil
	self.gui.Enabled = inLobby and not trying
end

return Lobby
