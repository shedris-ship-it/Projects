-- Full-screen states: the loading screen while the house is generated, the
-- downed and Echo overlays, and waiting after extraction.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)

local Ui = require(script.Parent.Parent.Lib.Ui)

local PS = Constants.PlayerStates
local PA = Constants.PlayerAttributes

local player = Players.LocalPlayer

local Overlays = {}
Overlays.__index = Overlays

function Overlays.new(ctx)
	local self = setmetatable({ ctx = ctx }, Overlays)
	local gui = Ui.screen("ConsensusOverlays", 50, ctx.playerGui)
	self.gui = gui

	self.loading = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		Visible = false,
		Parent = gui,
	}, {
		Ui.label("THE HALFWAY HOUSE", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(700, 50),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Ui.Theme.fontType,
			TextSize = 42,
			TextColor3 = Ui.Theme.text,
		}),
		Ui.label("Your friends will see something different.", {
			Name = "Hint",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromOffset(700, 24),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 16,
			TextColor3 = Ui.Theme.textDim,
		}),
	})

	self.stateFrame = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.62, 0),
		Size = UDim2.fromOffset(520, 70),
		BackgroundColor3 = Ui.Theme.ink,
		BackgroundTransparency = 0.3,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(8), Ui.padding(10) })
	self.stateTitle = Ui.label("", {
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Ui.Theme.fontType,
		TextSize = 24,
		Parent = self.stateFrame,
	})
	self.stateText = Ui.label("", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 14,
		TextColor3 = Ui.Theme.textDim,
		Parent = self.stateFrame,
	})

	-- Bleed-out bar under the downed title: drains over Config.Run.DownedSeconds.
	self.bleed = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.new(1, -40, 0, 6),
		BackgroundColor3 = Color3.fromRGB(40, 12, 12),
		Visible = false,
		Parent = self.stateFrame,
	}, { Ui.corner(3) })
	self.bleedFill = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Ui.Theme.danger,
		Parent = self.bleed,
	}, { Ui.corner(3) })

	return self
end

function Overlays:Update()
	local state = self.ctx.state
	local phase = state:Phase()
	self.loading.Visible = phase == Constants.Phases.Generating
	local myState = state:PlayerState()
	local show, title, text = false, "", ""
	local bleeding = false
	if myState == PS.Downed then
		local downedUntil = player:GetAttribute(PA.DownedUntil)
		local left = downedUntil and math.max(0, downedUntil - Workspace:GetServerTimeNow()) or 0
		local urgent = left <= Config.Run.BleedWarnSeconds
		show, title, text =
			true,
			urgent and "YOU'RE FADING" or "YOU'RE BLEEDING OUT",
			string.format("Call for help. A teammate must hold E on you. %d s", math.ceil(left))
		bleeding = true
		local total = player:GetAttribute(PA.DownedSeconds) or Config.Run.DownedSeconds
		self.bleedFill.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
		-- The last seconds pulse.
		local pulse = urgent and (0.5 + 0.5 * math.sin(os.clock() * 10)) or 0
		self.stateTitle.TextColor3 = Ui.Theme.text:Lerp(Ui.Theme.danger, urgent and 0.5 + 0.5 * pulse or 0.35)
	elseif myState == PS.Lost and state:InRun() then
		show, title, text = true, "YOU ARE AN ECHO", "Keep talking. Ping (G) one hint a minute."
	elseif myState == PS.Extracted and state:InRun() then
		show, title, text = true, "YOU GOT OUT", "Waiting for the rest of the squad."
	end
	self.bleed.Visible = bleeding
	if not bleeding then
		self.stateTitle.TextColor3 = Ui.Theme.text
	end
	self.stateFrame.Visible = show
	self.stateTitle.Text = title
	self.stateText.Text = text
end

return Overlays
