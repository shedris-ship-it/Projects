-- The party car's dashboard (LB2; docs/plans/lobby-rework.md, "Parties":
-- Services/CarService): while you're in a car, a trip sheet clipped to the
-- dash. Everyone sees the car, who's in it and its tape; the driver works
-- it: the difficulty, the night, friends only, and the horn. Anyone can get
-- out (Space works too), the countdown included. Also the receipt slip when
-- you're back in your car after a run, and the payphone's invite prompt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)

local Ui = require(script.Parent.Parent.Lib.Ui)

local player = Players.LocalPlayer
local PA = Constants.PlayerAttributes
local C = Config.Cars

local Dashboard = {}
Dashboard.__index = Dashboard

local WIDTH, HEIGHT = 600, 210

local function nextOf(list, value)
	local i = table.find(list, value) or 0
	return list[i % #list + 1]
end

function Dashboard.new(ctx)
	local self = setmetatable({ ctx = ctx, car = nil, receiptUntil = 0 }, Dashboard)
	local gui = Ui.screen("ConsensusDashboard", 12, ctx.playerGui)
	gui.Enabled = false
	self.gui = gui
	local root = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Ui.fit(root, WIDTH + 30, HEIGHT + 30)
	self.root = root
	-- A trip sheet torn off a pad, clipped to the dash.
	local holder, sheet = Ui.paper("Slip", {
		Size = UDim2.fromScale(1, 1),
		Rotation = -0.6,
		Parent = root,
	})
	Ui.tape(holder, UDim2.new(0.5, -40, 0, -10), -2, 80)
	local pad = Ui.new("Frame", {
		Position = UDim2.fromOffset(26, 16),
		Size = UDim2.new(1, -52, 1, -30),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = sheet,
	})
	self.title = Ui.typed("", {
		Size = UDim2.new(1, -150, 0, 22),
		TextSize = 17,
		ZIndex = 3,
		Parent = pad,
	})
	self.riders = Ui.typed("", {
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 13,
		TextColor3 = Ui.Theme.typeDim,
		ZIndex = 3,
		Parent = pad,
	})
	self.tape = Ui.typed("", {
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		ZIndex = 3,
		Parent = pad,
	})
	-- The driver's switches.
	local function switch(x: number, w: number, onClick)
		return Ui.paperButton("", {
			Position = UDim2.fromOffset(x, 74),
			Size = UDim2.fromOffset(w, 30),
			TextSize = 16,
			ZIndex = 3,
			Parent = pad,
		}, onClick)
	end
	self.difficulty = switch(0, 150, function()
		if self.car then
			Net.get("CarSet"):FireServer("difficulty", nextOf(C.Difficulty, self.car.difficulty))
		end
	end)
	self.night = switch(156, 170, function()
		if self.car then
			Net.get("CarSet"):FireServer("night", nextOf(C.Night, self.car.night))
		end
	end)
	self.friends = switch(332, 180, function()
		if self.car then
			Net.get("CarSet"):FireServer("friendsOnly", self.car.friendsOnly and "false" or "true")
		end
	end)
	-- The horn: a rubber stamp's red.
	self.honk = Ui.paperButton("HONK", {
		Position = UDim2.fromOffset(0, 116),
		Size = UDim2.fromOffset(150, 40),
		TextSize = 24,
		TextColor3 = Ui.Theme.red,
		ZIndex = 3,
		Parent = pad,
	}, function()
		Net.get("CarHonk"):FireServer()
	end)
	Ui.new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Ui.Theme.red,
		Thickness = 2,
		Transparency = 0.3,
		Parent = self.honk,
	})
	self.status = Ui.hand("", {
		Position = UDim2.fromOffset(160, 114),
		Size = UDim2.new(1, -300, 0, 44),
		TextSize = 20,
		LineHeight = 0.95,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
		Parent = pad,
	})
	self.out = Ui.paperButton("Get out  (Space)", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 120),
		Size = UDim2.fromOffset(130, 30),
		TextSize = 15,
		ZIndex = 3,
		Parent = pad,
	}, function()
		Net.get("CarGetOut"):FireServer()
	end)

	-- The receipt, back in your car after a run: typed on a slip, taped on.
	local slip, slipSheet = Ui.paper("Slip", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -30, 1, -30),
		Size = UDim2.fromOffset(260, 120),
		Rotation = 2.5,
		Visible = false,
		Parent = gui,
	})
	Ui.tape(slip, UDim2.new(0, 10, 0, -8), -24, 60)
	self.receipt = slip
	self.receiptText = Ui.typed("", {
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -40, 1, -24),
		TextSize = 15,
		LineHeight = 1.15,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
		Parent = slipSheet,
	})

	Net.get("CarState").OnClientEvent:Connect(function(state)
		self.car = state
		self:Render()
	end)
	Net.get("Receipt").OnClientEvent:Connect(function(data)
		self:ShowReceipt(data)
	end)
	-- The payphone (Services/CarService): Roblox's own invite-a-friend.
	Net.get("PromptInvite").OnClientEvent:Connect(function()
		task.spawn(function()
			local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
			if ok and can then
				pcall(SocialService.PromptGameInvite, SocialService, player)
			else
				ctx.ui:Toast("No answer: invites aren't open here.", "info")
			end
		end)
	end)
	player:GetAttributeChangedSignal(PA.Car):Connect(function()
		if player:GetAttribute(PA.Car) == nil then
			self.car = nil
		end
		self:Render()
	end)
	self:Render()
	return self
end

function Dashboard:ShowReceipt(data)
	local lines = { "RECEIPT", string.rep("-", 22) }
	if data.case then
		table.insert(lines, string.upper(data.case))
	end
	table.insert(lines, string.format("MARKS        +%d", data.marks or 0))
	table.insert(lines, "THANK YOU, COME AGAIN")
	self.receiptText.Text = table.concat(lines, "\n")
	self.receiptUntil = os.clock() + C.ReceiptSeconds
	self.receipt.Visible = true
	self.gui.Enabled = true
end

function Dashboard:Render()
	local car = self.car
	local inCar = car ~= nil and player:GetAttribute(PA.Car) ~= nil
	self.root.Visible = inCar
	self.gui.Enabled = inCar or self.receipt.Visible
	if not inCar then
		return
	end
	self.title.Text = string.upper(car.name)
	local riders = {}
	for i, name in car.riders do
		if name then
			table.insert(riders, i == 1 and (name .. " (driving)") or name)
		else
			table.insert(riders, "--")
		end
	end
	self.riders.Text = table.concat(riders, "  ·  ")
	self.tape.Text = car.tape and ("Tape: " .. car.tape) or "No tape in the deck: rent one in the video store."
	local driver = car.driver == true
	local leaving = car.leavingIn ~= nil
	for _, button in { self.difficulty, self.night, self.friends, self.honk } do
		button.Visible = driver
		button.Active = driver and not leaving
	end
	self.difficulty.Text = car.difficulty .. "  >"
	self.night.Text = string.upper(string.sub(car.nightName, 1, 1)) .. string.sub(car.nightName, 2) .. "  >"
	self.friends.Text = (car.friendsOnly and "Friends only: on" or "Friends only: off") .. "  >"
	if leaving then
		self.status.Text = string.format("Leaving in %d... get out to stay.", car.leavingIn)
		self.status.TextColor3 = Ui.Theme.red
		self.status.Position = UDim2.fromOffset(driver and 160 or 0, 114)
	elseif driver then
		self.status.Text = car.tape and "Honk when your squad's in." or "Rent a tape first."
		self.status.TextColor3 = Ui.Theme.type
		self.status.Position = UDim2.fromOffset(160, 114)
	else
		local who = car.riders[1] or "The driver"
		self.status.Text =
			string.format("%s is driving: they'll honk to go. %s · %s", who, car.difficulty, car.nightName)
		self.status.TextColor3 = Ui.Theme.type
		self.status.Position = UDim2.fromOffset(0, 80)
	end
	self.status.Size = driver and UDim2.new(1, -300, 0, 44) or UDim2.new(1, -140, 0, 70)
end

function Dashboard:Update()
	-- (A run played in place ends with the Dossier over the car: the slip
	-- waits for it to be closed.)
	local dossier = self.ctx.ui.components.Dossier
	if self.receipt.Visible and dossier and dossier.gui.Enabled then
		self.receiptUntil = os.clock() + C.ReceiptSeconds
	end
	if self.receipt.Visible and os.clock() > self.receiptUntil then
		self.receipt.Visible = false
		self:Render()
	end
	-- (Out of the hub, the dashboard's gone.)
	local state = self.ctx.state
	if state:Phase() ~= Constants.Phases.Lobby and self.root.Visible then
		self.root.Visible = false
	end
end

return Dashboard
