-- The lobby's other wares (LB4; Services/ShopService, Logic/Catalog): the
-- electronics counter's torches and the garage's pegboard of car bits, each
-- a card in the 1988 paper interface with the thing itself turning on it.
-- The counter: flip through the looks, buy one for Marks, carry one (it
-- goes into the run with you). The pegboard: your car as the lobby will see
-- it when you drive (World/CarDress on a copy of a garage car), its paint,
-- each bit on or off, its radio station. Walk away and the card goes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarBits = require(Shared.Data.CarBits)
local CarDress = require(Shared.World.CarDress)
local Catalog = require(Shared.Logic.Catalog)
local Net = require(Shared.Net)
local ToolModel = require(Shared.World.ToolModel)
local TorchLooks = require(Shared.Data.TorchLooks)

local Ui = require(script.Parent.Parent.Lib.Ui)

local player = Players.LocalPlayer

local Wares = {}
Wares.__index = Wares

local CARD_W, CARD_H = 420, 700 -- (the pegboard's: a paint, five bits and a station)
local LEAVE = 14 -- studs from where you opened it: walked away

local function money(n: number): string
	local s = tostring(math.floor(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	return (string.gsub(out, "^,", ""))
end

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Wares.new(ctx)
	local self = setmetatable({ ctx = ctx, state = nil, look = nil, paint = nil, radio = nil, spin = 0 }, Wares)
	local gui = Ui.screen("ConsensusWares", 13, ctx.playerGui)
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
	local holder, sheet = Ui.paper("Sheet", { Size = UDim2.fromScale(1, 1), Rotation = -0.8, Parent = holderRoot })
	Ui.tape(holder, UDim2.new(0.5, 0, 0, -6), 2, 90)
	local pad = Ui.new("Frame", {
		Position = UDim2.fromOffset(28, 26),
		Size = UDim2.new(1, -56, 1, -46),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = sheet,
	})
	self.pad = pad
	self.title = Ui.typed("", { Size = UDim2.new(1, 0, 0, 24), TextSize = 20, ZIndex = 3, Parent = pad })
	self.marks = Ui.typed("", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 15,
		TextColor3 = Ui.Theme.typeDim,
		ZIndex = 3,
		Parent = pad,
	})
	-- The thing itself, turning.
	self.view = Ui.new("ViewportFrame", {
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundColor3 = Color3.fromRGB(40, 38, 36),
		BackgroundTransparency = 0.15,
		Ambient = Color3.fromRGB(150, 146, 140),
		LightColor = Color3.fromRGB(255, 244, 226),
		LightDirection = Vector3.new(-0.5, -0.7, -0.5),
		ZIndex = 3,
		Parent = pad,
	})
	self.camera = Instance.new("Camera")
	self.camera.FieldOfView = 30
	self.camera.Parent = self.view
	self.view.CurrentCamera = self.camera
	self.rows = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, 212),
		Size = UDim2.new(1, 0, 1, -256),
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
	Net.get("WareState").OnClientEvent:Connect(function(state)
		self:_open(state)
	end)
	RunService.RenderStepped:Connect(function(dt)
		self:_turn(dt)
	end)
	return self
end

function Wares:_open(state)
	local first = self.state == nil or self.state.which ~= state.which
	self.state = state
	local set = {}
	for kind, ids in state.owned do
		set[kind] = {}
		for _, id in ids do
			set[kind][id] = true
		end
	end
	state.ownedSet = set
	if first then
		local r = root()
		self.at = r and r.Position
		self.look = state.torch
		self.paint = state.car.paint
		self.radio = state.car.radio
		self.shown = nil
	end
	self:_render()
	self.gui.Enabled = true
end

function Wares:Close()
	self.state = nil
	self.gui.Enabled = false
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
	Ui.dismissed()
end

local function clearRows(rows: Frame)
	for _, child in rows:GetChildren() do
		child:Destroy()
	end
end

-- One line: a label, a note in pen, and a button (or none).
local function line(rows: Frame, y: number, label: string, note: string, noteColor: Color3, button: string?, onClick)
	Ui.typed(label, {
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, -120, 0, 20),
		TextSize = 15,
		ZIndex = 3,
		Parent = rows,
	})
	Ui.hand(note, {
		Position = UDim2.fromOffset(0, y + 20),
		Size = UDim2.new(1, -120, 0, 22),
		TextSize = 19,
		TextColor3 = noteColor,
		ZIndex = 3,
		Parent = rows,
	})
	if button then
		local b = Ui.paperButton(button, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, y + 6),
			Size = UDim2.fromOffset(110, 30),
			TextSize = 15,
			TextColor3 = button == "BUY" and Ui.Theme.red or Ui.Theme.type,
			ZIndex = 3,
			Parent = rows,
		}, onClick)
		if button == "BUY" then
			Ui.new("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Ui.Theme.red,
				Thickness = 1.5,
				Transparency = 0.35,
				Parent = b,
			})
		end
	end
end

-- A row that flips through a kind (< name >), its state, and BUY or USE.
function Wares:_flipper(
	y: number,
	kind: string,
	current: string,
	using: string,
	onFlip,
	useLabel: string,
	usingNote: string
)
	local rows = self.rows
	local item = Catalog.item(kind, current)
	Ui.paperButton("<", {
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(34, 30),
		TextSize = 19,
		ZIndex = 3,
		Parent = rows,
	}, function()
		onFlip(-1)
	end)
	Ui.paperButton(">", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, y),
		Size = UDim2.fromOffset(34, 30),
		TextSize = 19,
		ZIndex = 3,
		Parent = rows,
	}, function()
		onFlip(1)
	end)
	Ui.typed(item and item.name or "--", {
		Position = UDim2.fromOffset(40, y + 3),
		Size = UDim2.new(1, -80, 0, 24),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Parent = rows,
	})
	local owned = self.state.ownedSet[kind][current]
	local which = self.state.which
	if owned and current == using then
		line(rows, y + 34, "", usingNote, Ui.Theme.goodInk, nil, nil)
	elseif owned then
		line(rows, y + 34, "", item.free and "Everyone's." or "Yours.", Ui.Theme.goodInk, useLabel, function()
			Net.get("WareUse"):FireServer(kind, current, true, which)
		end)
	else
		local price = Catalog.price(kind, current) or 0
		local short = (self.state.marks or 0) < price
		line(
			rows,
			y + 34,
			"",
			string.format("%s Marks%s", money(price), short and ": not enough yet" or ""),
			short and Ui.Theme.red or Ui.Theme.pen,
			not short and "BUY" or nil,
			function()
				Net.get("WareBuy"):FireServer(kind, current, which)
			end
		)
	end
end

local function step(order: { string }, id: string, by: number): string
	local i = table.find(order, id) or 1
	return order[(i - 1 + by) % #order + 1]
end

function Wares:_render()
	local state = self.state
	if not state then
		return
	end
	self.marks.Text = string.format("Your Marks: %s", money(state.marks or 0))
	clearRows(self.rows)
	if state.which == "counter" then
		self.title.Text = "ELECTRONICS · TORCHES"
		self:_flipper(0, "torch", self.look, state.torch, function(by)
			self.look = step(TorchLooks.Order, self.look, by)
			self:_render()
		end, "CARRY", "Yours. You carry it.")
		Ui.hand("Looks only: the same beam, the same switch, the same grip. Your squad sees the one you carry.", {
			Position = UDim2.fromOffset(0, 96),
			Size = UDim2.new(1, 0, 0, 70),
			TextSize = 18,
			TextColor3 = Ui.Theme.typeDim,
			LineHeight = 0.95,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 3,
			Parent = self.rows,
		})
		self:_show("torch:" .. self.look)
	else
		self.title.Text = "THE PEGBOARD · CAR BITS"
		self:_flipper(0, "paint", self.paint, state.car.paint, function(by)
			self.paint = step(CarBits.PaintOrder, self.paint, by)
			self:_render()
		end, "PAINT", "On your car.")
		local y = 72
		for _, id in CarBits.BitOrder do
			local item = CarBits.Bits[id]
			local owned = state.ownedSet.carbit[id]
			local on = state.car.bits[id] == true
			if owned then
				line(
					self.rows,
					y,
					item.name,
					on and "On your car." or "Yours.",
					Ui.Theme.goodInk,
					on and "TAKE OFF" or "FIT",
					function()
						Net.get("WareUse"):FireServer("carbit", id, not on, "pegboard")
					end
				)
			else
				local short = (state.marks or 0) < item.price
				line(
					self.rows,
					y,
					item.name,
					string.format("%s Marks%s", money(item.price), short and ": not enough yet" or ""),
					short and Ui.Theme.red or Ui.Theme.pen,
					not short and "BUY" or nil,
					function()
						Net.get("WareBuy"):FireServer("carbit", id, "pegboard")
					end
				)
			end
			y += 46
		end
		self:_flipper(y + 6, "radio", self.radio, state.car.radio, function(by)
			self.radio = step(CarBits.RadioOrder, self.radio, by)
			self:_render()
		end, "TUNE", "On your radio.")
		-- Your car as you'd drive it, in the paint you're looking at.
		local bits, ids = {}, {}
		for id, on in state.car.bits do
			bits[id] = on
			table.insert(ids, id)
		end
		table.sort(ids)
		self.preview = { paint = self.paint, bits = bits, radio = self.radio }
		self:_show("car:" .. self.paint .. ":" .. table.concat(ids, ","))
	end
end

-- What turns in the window: a torch look, or your car (a copy of a garage
-- car in your bits). Built again only when it changes.
function Wares:_show(key: string)
	if self.shown == key and self.model then
		return
	end
	self.shown = key
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
	local model
	if string.sub(key, 1, 6) == "torch:" then
		model = ToolModel.torch(self.look)
		model.Parent = self.view
		local _, size = model:GetBoundingBox()
		self.distance = size.Magnitude * 2.4
	else
		local lobby = Workspace:FindFirstChild("ConsensusLobby")
		local cars = lobby and lobby:FindFirstChild("Cars")
		local source = cars and cars:FindFirstChild("Car1")
		if not source then
			return
		end
		model = Instance.new("Model")
		model.Name = "Preview"
		for _, child in source:GetChildren() do
			if child:IsA("BasePart") and child.Name ~= "Sign" and not child:IsA("Seat") then
				local copy = child:Clone()
				for _, d in copy:GetDescendants() do
					if not (d:IsA("SurfaceAppearance") or d:IsA("SpecialMesh")) then
						d:Destroy()
					end
				end
				copy.Parent = model
			end
		end
		model.PrimaryPart = model:FindFirstChild("Body") :: BasePart?
		model.Parent = self.view
		CarDress.dress(model, self.preview)
		self.distance = 24
	end
	self.model = model
	self.spin = 0
end

function Wares:_turn(dt: number)
	if not self.state then
		return
	end
	-- Walked away: put down.
	local r = root()
	if not r or (self.at and (r.Position - self.at).Magnitude > LEAVE) or self.ctx.state:InRun() then
		self:Close()
		return
	end
	local model = self.model
	if not model or not model.PrimaryPart then
		return
	end
	self.spin += dt * 0.5
	local centre = model:GetBoundingBox().Position
	local eye = centre + Vector3.new(math.sin(self.spin), 0.45, math.cos(self.spin)) * self.distance
	self.camera.CFrame = CFrame.lookAt(eye, centre)
end

return Wares
