-- Full-screen states: the loading screen while the house is generated, the
-- downed and Echo overlays, and waiting after extraction. In the 1988
-- interface (V7) each night opens on a title card, like a film's ("THE
-- HALFWAY HOUSE", a hairline, the hour): over black while the house is
-- built, then alone over the house as the black lifts; the states are typed
-- lines and subtitles, no boxes.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)

local Ui = require(script.Parent.Parent.Lib.Ui)

local PS = Constants.PlayerStates
local PA = Constants.PlayerAttributes
local RS = Constants.RunState

-- How long the title card stays over the house, then fades (seconds).
local CARD_HOLD = 3.4
local CARD_FADE = 1.6
local BLACK_FADE = 1.4

-- A film title's spaced capitals: "THE HALFWAY HOUSE" -> "T H E   H A L ...".
local function spaced(text: string): string
	local words = {}
	for word in string.gmatch(string.upper(text), "%S+") do
		table.insert(words, (string.gsub(word, "(.)", "%1 "):sub(1, -2)))
	end
	return table.concat(words, "     ")
end

-- The hour the night begins, read from the run's seed: between one and
-- three in the morning, the same for the whole squad.
local function hourOf(seed: number?): string
	local n = math.floor(math.abs(seed or 0))
	return string.format("%d:%02d AM", 1 + n % 3, math.floor(n / 3) % 60)
end

local player = Players.LocalPlayer

local Overlays = {}
Overlays.__index = Overlays

function Overlays.new(ctx)
	local self = setmetatable({ ctx = ctx }, Overlays)
	local gui = Ui.screen("ConsensusOverlays", 50, ctx.playerGui)
	self.gui = gui

	-- Black while the house is built; it lifts off the title card.
	self.loading = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		Visible = false,
		Parent = gui,
	})
	-- The title card.
	local card = Ui.new("CanvasGroup", {
		Name = "TitleCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.fromOffset(900, 170),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	self.cardTitle = Ui.label(spaced("The Halfway House"), {
		Size = UDim2.new(1, 0, 0, 52),
		FontFace = Ui.Fonts.title,
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(236, 228, 210),
		Parent = card,
	})
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(220, 1),
		BackgroundColor3 = Ui.Theme.accent,
		BackgroundTransparency = 0.2,
		Parent = card,
	})
	self.cardTime = Ui.label("", {
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Ui.Theme.textDim,
		Parent = card,
	})
	self.cardHint = Ui.subtitle("Your friends will see something different.", {
		Position = UDim2.fromOffset(0, 124),
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 17,
		TextColor3 = Color3.fromRGB(150, 144, 132),
		TextStrokeTransparency = 1,
		Parent = card,
	})
	self.card = card
	self.wasLoading = false

	self.stateFrame = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.62, 0),
		Size = UDim2.fromOffset(640, 86),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	self.stateTitle = Ui.label("", {
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 28,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.5,
		Parent = self.stateFrame,
	})
	self.stateText = Ui.subtitle("", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 44),
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 18,
		TextColor3 = Ui.Theme.textDim,
		Parent = self.stateFrame,
	})

	-- Bleed-out hairline under the downed title: drains over Config.Run.DownedSeconds.
	self.bleed = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(320, 2),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Visible = false,
		Parent = self.stateFrame,
	})
	self.bleedFill = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Ui.Theme.danger,
		Parent = self.bleed,
	})
	-- Someone holding E on you: their hairline fills under the bleed's.
	self.revive = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 10),
		Size = UDim2.fromOffset(320, 2),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Visible = false,
		Parent = self.stateFrame,
	})
	self.reviveFill = Ui.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Ui.Theme.good,
		Parent = self.revive,
	})

	return self
end

-- The card's words for this night.
function Overlays:_cardText()
	local state = self.ctx.state
	local lobby = state.lobby
	local name = lobby and lobby.location and lobby.location.name or "The Halfway House"
	self.cardTitle.Text = spaced(name)
	self.cardTime.Text = hourOf(state:Run(RS.Seed))
end

-- The title card over the house: in, a while, out (also F2 `ui title`).
function Overlays:TitleCard()
	self:_cardText()
	self.cardHint.Visible = false
	self.card.Visible = true
	self.cardToken = (self.cardToken or 0) + 1
	local token = self.cardToken
	Ui.tween(self.card, 0.8, { GroupTransparency = 0 })
	task.delay(CARD_HOLD, function()
		if self.cardToken == token then
			Ui.tween(self.card, CARD_FADE, { GroupTransparency = 1 })
			task.delay(CARD_FADE, function()
				if self.cardToken == token then
					self.card.Visible = false
				end
			end)
		end
	end)
end

function Overlays:Update()
	local state = self.ctx.state
	local phase = state:Phase()
	local loading = phase == Constants.Phases.Generating
	if loading and not self.wasLoading then
		-- Black, the card on it.
		self.cardToken = (self.cardToken or 0) + 1
		self:_cardText()
		self.cardHint.Visible = true
		self.loading.BackgroundTransparency = 0
		self.loading.Visible = true
		self.card.Visible = true
		self.card.GroupTransparency = 0
	elseif not loading and self.wasLoading then
		-- The house is ready: the black lifts and the card stays a while.
		Ui.tween(self.loading, BLACK_FADE, { BackgroundTransparency = 1 })
		task.delay(BLACK_FADE, function()
			if self.loading.BackgroundTransparency >= 0.99 then
				self.loading.Visible = false
			end
		end)
		self.cardHint.Visible = false
		self:TitleCard()
	end
	self.wasLoading = loading
	local myState = state:PlayerState()
	local show, title, text = false, "", ""
	local bleeding = false
	local reviving = false
	if myState == PS.Downed then
		local downedUntil = player:GetAttribute(PA.DownedUntil)
		local left = downedUntil and math.max(0, downedUntil - Workspace:GetServerTimeNow()) or 0
		local urgent = left <= Config.Run.BleedWarnSeconds
		local others = 0
		for _, other in Players:GetPlayers() do
			local s = other:GetAttribute(PA.State)
			if other ~= player and (s == PS.Active or s == PS.Downed) then
				others += 1
			end
		end
		local solo = others == 0
		show, title, text =
			true,
			urgent and "YOU'RE FADING" or "YOU'RE BLEEDING OUT",
			string.format(
				solo and "Crawl to a lit lantern or a hiding place. %d s"
					or "Call for help: a teammate holds E on you. Or crawl to a lit lantern or a hiding place. %d s",
				math.ceil(left)
			)
		bleeding = true
		local rescuer = player:GetAttribute(PA.RevivedBy)
		local since = player:GetAttribute(PA.ReviveSince)
		if typeof(rescuer) == "string" and typeof(since) == "number" then
			reviving = true
			title = string.upper(rescuer) .. " IS PULLING YOU UP"
			local share = (Workspace:GetServerTimeNow() - since) / Config.Run.ReviveHoldSeconds
			self.reviveFill.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
		end
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
	self.revive.Visible = reviving
	if not bleeding then
		self.stateTitle.TextColor3 = Ui.Theme.text
	end
	self.stateFrame.Visible = show
	self.stateTitle.Text = title
	self.stateText.Text = text
end

return Overlays
