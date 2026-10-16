-- The arcade's coin card (LB5; Services/ArcadeService, Logic/Arcade/Credits):
-- shown at a cabinet when there's nothing to play with (no pass, today's
-- free play used, no plays bought). A play for Marks, priced so Robux is the
-- better deal, or plays for Robux (Roblox's own prompt; "coming soon" until
-- the owner makes the products). Walk away and it goes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local Ui = require(script.Parent.Parent.Lib.Ui)

local player = Players.LocalPlayer

local Arcade = {}
Arcade.__index = Arcade

local CARD_W, CARD_H = 380, 400
local LEAVE = 12 -- studs from where it opened: walked away

local function money(n: number): string
	local s = tostring(math.floor(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	return (string.gsub(out, "^,", ""))
end

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Arcade.new(ctx)
	local self = setmetatable({ ctx = ctx, state = nil }, Arcade)
	local gui = Ui.screen("ConsensusArcade", 13, ctx.playerGui)
	gui.Enabled = false
	self.gui = gui
	local holderRoot = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -36, 0.5, 0),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Ui.fit(holderRoot, CARD_W + 60, CARD_H + 60)
	Ui.modal(holderRoot)
	local holder, sheet = Ui.paper("Sheet", { Size = UDim2.fromScale(1, 1), Rotation = 1, Parent = holderRoot })
	Ui.tape(holder, UDim2.new(0.5, 0, 0, -6), -2, 90)
	local pad = Ui.new("Frame", {
		Position = UDim2.fromOffset(28, 26),
		Size = UDim2.new(1, -56, 1, -46),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = sheet,
	})
	self.pad = pad
	Ui.typed("HOUSE CALL: INSERT COIN", { Size = UDim2.new(1, 0, 0, 24), TextSize = 20, ZIndex = 3, Parent = pad })
	self.note = Ui.hand("", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 18,
		TextWrapped = true,
		TextColor3 = Ui.Theme.pen,
		ZIndex = 3,
		Parent = pad,
	})
	self.marks = Ui.typed("", {
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 15,
		TextColor3 = Ui.Theme.typeDim,
		ZIndex = 3,
		Parent = pad,
	})
	self.rows = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.new(1, 0, 1, -150),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = pad,
	})
	Ui.paperButton("Close", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 1, -36),
		Size = UDim2.fromOffset(110, 32),
		TextSize = 15,
		ZIndex = 3,
		Parent = pad,
	}, function()
		self:Close()
	end)
	Net.get("ArcadeCoin").OnClientEvent:Connect(function(state)
		self:_open(state)
	end)
	-- (Playing: the card's done its job.)
	Net.get("ArcadeStart").OnClientEvent:Connect(function()
		self:Close()
	end)
	return self
end

function Arcade:_row(y: number, label: string, button: string?, enabled: boolean, onClick: (() -> ())?)
	Ui.typed(label, {
		Position = UDim2.fromOffset(0, y + 6),
		Size = UDim2.new(1, -130, 0, 22),
		TextSize = 15,
		ZIndex = 3,
		Parent = self.rows,
	})
	if button then
		Ui.paperButton(button, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, y),
			Size = UDim2.fromOffset(120, 32),
			TextSize = 14,
			TextColor3 = enabled and Ui.Theme.red or Ui.Theme.typeDim,
			ZIndex = 3,
			Parent = self.rows,
		}, enabled and onClick or nil)
	end
end

function Arcade:_open(state)
	self.state = state
	local r = root()
	self.at = r and r.Position
	for _, child in self.rows:GetChildren() do
		child:Destroy()
	end
	self.note.Text = "Today's free play is used: another at midnight UTC."
	self.marks.Text = string.format("Your Marks: %s", money(state.marks or 0))
	local short = (state.marks or 0) < state.price
	self:_row(
		0,
		string.format("One play: %s Marks", money(state.price)),
		short and "NOT ENOUGH" or "PLAY",
		not short,
		function()
			Net.get("ArcadePay"):FireServer(state.index, "marks")
		end
	)
	local y = 50
	for _, item in state.robux do
		local label = string.format("%s: %d Robux", item.label, item.robux)
		self:_row(y, label, item.can and "BUY" or "SOON", item.can, function()
			Net.get("ArcadePay"):FireServer(state.index, item.name)
			self:Close()
		end)
		y += 44
	end
	self.gui.Enabled = true
end

function Arcade:Close()
	self.state = nil
	self.gui.Enabled = false
	Ui.dismissed()
end

function Arcade:Update()
	if not self.state then
		return
	end
	local r = root()
	if not r or not self.at or (r.Position - self.at).Magnitude > LEAVE then
		self:Close()
	end
end

return Arcade
