-- Full-screen states: the loading screen while the house is generated, the
-- downed and Echo overlays, waiting after extraction, and Witness Camera
-- photos.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)

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

	self.photo = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -30, 0.45, 0),
		Size = UDim2.fromOffset(260, 210),
		BackgroundColor3 = Color3.fromRGB(240, 236, 226),
		Rotation = 3,
		Visible = false,
		Parent = gui,
	}, { Ui.padding(12) })
	Ui.new(
		"Frame",
		{ Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = Color3.fromRGB(30, 28, 30), Parent = self.photo }
	)
	self.photoLabel = Ui.label("", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Ui.Theme.fontType,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(210, 200, 180),
		Parent = self.photo,
	})
	self.photoCaption = Ui.label("", {
		Position = UDim2.fromOffset(0, 124),
		Size = UDim2.new(1, 0, 0, 60),
		Font = Ui.Theme.fontType,
		TextSize = 14,
		TextColor3 = Ui.Theme.ink,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = self.photo,
	})
	Net.get("PhotoResult").OnClientEvent:Connect(function(result)
		self.photoLabel.Text = result.label or ""
		self.photoCaption.Text = result.caption or ""
		self.photo.Visible = true
		self.photoToken = (self.photoToken or 0) + 1
		local token = self.photoToken
		task.delay(6, function()
			if self.photoToken == token then
				self.photo.Visible = false
			end
		end)
	end)
	return self
end

function Overlays:Update()
	local state = self.ctx.state
	local phase = state:Phase()
	self.loading.Visible = phase == Constants.Phases.Generating
	local myState = state:PlayerState()
	local show, title, text = false, "", ""
	if myState == PS.Downed then
		local downedUntil = player:GetAttribute(PA.DownedUntil)
		local left = downedUntil and math.max(0, downedUntil - Workspace:GetServerTimeNow()) or 0
		show, title, text =
			true, "YOU'RE DOWN", string.format("A teammate can pull you up. %d seconds.", math.ceil(left))
	elseif myState == PS.Lost and state:InRun() then
		show, title, text = true, "YOU ARE AN ECHO", "Keep talking. Ping (G) one hint a minute."
	elseif myState == PS.Extracted and state:InRun() then
		show, title, text = true, "YOU GOT OUT", "Waiting for the rest of the squad."
	end
	self.stateFrame.Visible = show
	self.stateTitle.Text = title
	self.stateText.Text = text
end

return Overlays
