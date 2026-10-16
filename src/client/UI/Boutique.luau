-- The boutique (LB3; docs/plans/lobby-rework.md, "Boutique"; Services/
-- ShopService). The fitting room: a swing tag of a card beside you while the
-- camera faces you (a mirror's view); flip each slot through the free set
-- and the racks, see it on you, buy it right there for Marks; Done (Space)
-- keeps on what's yours. The till: Marks for Robux, for you or a friend
-- here (a wrapped gift). The starter pack's slip, once, after your first
-- run. Gifts: a note when one's waiting at your feet, and what it was.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Closet = require(Shared.Logic.Closet)
local Net = require(Shared.Net)
local Products = require(Shared.Data.Products)
local Wardrobe = require(Shared.Data.Wardrobe)

local Ui = require(script.Parent.Parent.Lib.Ui)

local player = Players.LocalPlayer

local Boutique = {}
Boutique.__index = Boutique

local SLOTS = {
	{ slot = "Top", label = "TOP" },
	{ slot = "Bottom", label = "BOTTOMS" },
	{ slot = "Shoes", label = "SHOES" },
}
local CARD_W, CARD_H = 360, 500
local TILL_W, TILL_H = 380, 420

-- 1500 -> "1,500".
local function money(n: number): string
	local s = tostring(math.floor(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	return (string.gsub(out, "^,", ""))
end

function Boutique.new(ctx)
	local self = setmetatable({ ctx = ctx, state = nil, till = nil, forIndex = 0 }, Boutique)
	local gui = Ui.screen("ConsensusBoutique", 13, ctx.playerGui)
	gui.Enabled = false
	self.gui = gui
	self:_buildCard(gui)
	self:_buildTill(gui)
	self:_buildStarter(gui)

	Net.get("ShopState").OnClientEvent:Connect(function(state)
		self:_state(state)
	end)
	Net.get("ShopTill").OnClientEvent:Connect(function(data)
		self:OpenTill(data and data.marks)
	end)
	Net.get("StarterOffer").OnClientEvent:Connect(function(offer)
		self:_offer(offer)
	end)
	Net.get("GiftArrived").OnClientEvent:Connect(function(gift)
		if gift.opened then
			ctx.ui:Toast(string.format("%s gave you %s.", gift.from, gift.what), "good")
		else
			ctx.ui:Toast(string.format("%s sent you a gift: it's at your feet, wrapped.", gift.from), "info")
		end
	end)
	return self
end

-- The fitting room's card ------------------------------------------------------------------

function Boutique:_buildCard(gui: ScreenGui)
	local root = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -36, 0.5, 0),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	Ui.fit(root, CARD_W + 60, CARD_H + 60)
	Ui.modal(root)
	self.card = root
	local holder, sheet = Ui.paper("Sheet", { Size = UDim2.fromScale(1, 1), Rotation = 1.2, Parent = root })
	Ui.tape(holder, UDim2.new(0.5, 0, 0, -6), 3, 90)
	local pad = Ui.new("Frame", {
		Position = UDim2.fromOffset(30, 28),
		Size = UDim2.new(1, -60, 1, -50),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = sheet,
	})
	Ui.typed("FITTING ROOM", { Size = UDim2.new(1, 0, 0, 24), TextSize = 21, ZIndex = 3, Parent = pad })
	self.marks = Ui.typed("", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 15,
		TextColor3 = Ui.Theme.typeDim,
		ZIndex = 3,
		Parent = pad,
	})
	self.rows = {}
	for i, spec in SLOTS do
		local y = 64 + (i - 1) * 112
		Ui.typed(spec.label, {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 18),
			TextSize = 13,
			TextColor3 = Ui.Theme.typeDim,
			ZIndex = 3,
			Parent = pad,
		})
		local row = { slot = spec.slot }
		Ui.paperButton("<", {
			Position = UDim2.fromOffset(0, y + 20),
			Size = UDim2.fromOffset(36, 32),
			TextSize = 20,
			ZIndex = 3,
			Parent = pad,
		}, function()
			self:_flip(spec.slot, -1)
		end)
		Ui.paperButton(">", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, y + 20),
			Size = UDim2.fromOffset(36, 32),
			TextSize = 20,
			ZIndex = 3,
			Parent = pad,
		}, function()
			self:_flip(spec.slot, 1)
		end)
		row.name = Ui.typed("", {
			Position = UDim2.fromOffset(42, y + 22),
			Size = UDim2.new(1, -84, 0, 28),
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
			Parent = pad,
		})
		row.status = Ui.hand("", {
			Position = UDim2.fromOffset(0, y + 58),
			Size = UDim2.new(1, -120, 0, 30),
			TextSize = 21,
			ZIndex = 3,
			Parent = pad,
		})
		row.buy = Ui.paperButton("BUY", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, y + 58),
			Size = UDim2.fromOffset(110, 30),
			TextSize = 17,
			TextColor3 = Ui.Theme.red,
			ZIndex = 3,
			Parent = pad,
		}, function()
			self:_buy(spec.slot)
		end)
		Ui.new("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Ui.Theme.red,
			Thickness = 1.5,
			Transparency = 0.35,
			Parent = row.buy,
		})
		self.rows[spec.slot] = row
	end
	self.getMarks = Ui.paperButton("Get Marks", {
		Position = UDim2.new(0, 0, 1, -40),
		Size = UDim2.fromOffset(120, 32),
		TextSize = 15,
		ZIndex = 3,
		Parent = pad,
	}, function()
		self:OpenTill()
	end)
	Ui.paperButton("Done  (Space)", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 1, -40),
		Size = UDim2.fromOffset(140, 32),
		TextSize = 15,
		ZIndex = 3,
		Parent = pad,
	}, function()
		Net.get("ShopDone"):FireServer()
	end)
end

function Boutique:_flip(slot: string, step: number)
	local state = self.state
	if not state then
		return
	end
	local id = Closet.step(slot, state.outfit[slot], step)
	if id then
		state.outfit[slot] = id -- (shown at once; the server dresses you)
		self:_render()
		Net.get("ShopTry"):FireServer(id)
	end
end

function Boutique:_buy(slot: string)
	local state = self.state
	local id = state and state.outfit[slot]
	if id then
		Net.get("ShopBuy"):FireServer(id)
	end
end

function Boutique:_state(state)
	local was = self.state ~= nil
	self.state = state
	if state then
		local set = {}
		for _, id in state.owned do
			set[id] = true
		end
		state.ownedSet = set
		if not was then
			self:_enter()
		end
		self:_render()
	elseif was then
		self:_leave()
	end
	self:_visibility()
end

function Boutique:_render()
	local state = self.state
	if not state then
		return
	end
	self.marks.Text = string.format("Your Marks: %s", money(state.marks or 0))
	for _, spec in SLOTS do
		local row = self.rows[spec.slot]
		local id = state.outfit[spec.slot]
		local garment = id and Wardrobe.Garments[id]
		row.name.Text = garment and garment.name or "--"
		local owned = id and state.ownedSet[id]
		local price = id and Closet.price(id)
		if not garment then
			row.status.Text = ""
			row.buy.Visible = false
		elseif owned then
			row.status.Text = garment.free and "Everyone's. On you." or "Yours. On you."
			row.status.TextColor3 = Ui.Theme.goodInk
			row.buy.Visible = false
		else
			local short = (state.marks or 0) < (price or 0)
			row.status.Text = string.format("%s Marks%s", money(price or 0), short and ": not enough yet" or "")
			row.status.TextColor3 = short and Ui.Theme.red or Ui.Theme.pen
			row.buy.Visible = not short
		end
	end
end

-- In: the camera turns to face you; Space is Done.
function Boutique:_enter()
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("ConsensusFitting", Enum.RenderPriority.Camera.Value + 1, function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		-- (A mirror's view: in front of you, a little above, looking back,
		-- you on the left of the screen so the card on the right doesn't
		-- cover you; from your left, clear of the booth's wall.)
		local eye = root.CFrame * CFrame.new(-1.8, 1.4, -8.5)
		camera.CFrame = CFrame.lookAt(eye.Position, (root.CFrame * CFrame.new(-1.6, 0.2, 0)).Position)
	end)
	ContextActionService:BindActionAtPriority("ConsensusFittingDone", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Net.get("ShopDone"):FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonB)
end

function Boutique:_leave()
	pcall(function()
		RunService:UnbindFromRenderStep("ConsensusFitting")
	end)
	ContextActionService:UnbindAction("ConsensusFittingDone")
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	Ui.dismissed()
end

-- The till's card -----------------------------------------------------------------------

function Boutique:_buildTill(gui: ScreenGui)
	local root = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(TILL_W, TILL_H),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	})
	Ui.fit(root, TILL_W + 60, TILL_H + 60)
	Ui.modal(root)
	self.tillCard = root
	local holder, sheet = Ui.paper("Sheet", { Size = UDim2.fromScale(1, 1), Rotation = -1, Parent = root })
	Ui.tape(holder, UDim2.new(0.5, 0, 0, -6), -2, 90)
	local pad = Ui.new("Frame", {
		Position = UDim2.fromOffset(30, 28),
		Size = UDim2.new(1, -60, 1, -50),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = sheet,
	})
	Ui.typed("THE TILL · MARKS", { Size = UDim2.new(1, 0, 0, 24), TextSize = 21, ZIndex = 3, Parent = pad })
	self.tillMarks = Ui.typed("", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 15,
		TextColor3 = Ui.Theme.typeDim,
		ZIndex = 3,
		Parent = pad,
	})
	-- Who it's for: you, or a friend here (a wrapped gift).
	self.forButton = Ui.paperButton("", {
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 16,
		ZIndex = 3,
		Parent = pad,
	}, function()
		self.forIndex += 1
		self:_renderTill()
	end)
	self.tillRows = {}
	for i = 1, 3 do
		local y = 102 + (i - 1) * 62
		local row = {}
		row.label = Ui.typed("", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, -110, 0, 22),
			TextSize = 17,
			ZIndex = 3,
			Parent = pad,
		})
		row.price = Ui.hand("", {
			Position = UDim2.fromOffset(0, y + 24),
			Size = UDim2.new(1, -110, 0, 26),
			TextSize = 20,
			TextColor3 = Ui.Theme.pen,
			ZIndex = 3,
			Parent = pad,
		})
		row.buy = Ui.paperButton("BUY", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, y + 8),
			Size = UDim2.fromOffset(100, 32),
			TextSize = 17,
			TextColor3 = Ui.Theme.red,
			ZIndex = 3,
			Parent = pad,
		}, function()
			if row.name then
				local who = self:_forWho()
				Net.get("TillBuy"):FireServer(row.name, who and who.userId or 0)
			end
		end)
		self.tillRows[i] = row
	end
	self.tillNote = Ui.hand("", {
		Position = UDim2.fromOffset(0, 292),
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 18,
		TextColor3 = Ui.Theme.typeDim,
		LineHeight = 0.95,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
		Parent = pad,
	})
	Ui.paperButton("Close", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 1, -40),
		Size = UDim2.fromOffset(110, 32),
		TextSize = 15,
		ZIndex = 3,
		Parent = pad,
	}, function()
		self:CloseTill()
	end)
end

-- Who's here to buy for: nil is you.
function Boutique:_forWho()
	local others = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(others, { userId = other.UserId, name = other.DisplayName })
		end
	end
	local n = #others + 1
	local i = self.forIndex % n
	return i == 0 and nil or others[i]
end

function Boutique:OpenTill(marks: number?)
	local list = {}
	for name, product in Products.Products do
		if product.till then
			table.insert(list, { name = name, product = product })
		end
	end
	table.sort(list, function(a, b)
		return a.product.till < b.product.till
	end)
	self.till = { list = list, marks = marks or (self.state and self.state.marks) }
	self.forIndex = 0
	self:_renderTill()
	self:_visibility()
end

function Boutique:CloseTill()
	self.till = nil
	self:_visibility()
	Ui.dismissed()
end

function Boutique:_renderTill()
	local till = self.till
	if not till then
		return
	end
	local profile = self.ctx.state and self.ctx.state.profile
	local marks = till.marks or (profile and profile.marks) or 0
	self.tillMarks.Text = string.format("Your Marks: %s", money(marks))
	local who = self:_forWho()
	self.forButton.Text = who and string.format("For: %s (a gift)  >", who.name) or "For: me  >"
	local anyOpen = false
	for i, row in self.tillRows do
		local entry = till.list[i]
		row.name = entry and entry.name
		row.label.Text = entry and (entry.product.label or entry.name) or ""
		local open = entry ~= nil and type(entry.product.id) == "number"
		anyOpen = anyOpen or open
		row.price.Text = entry and (open and string.format("%d Robux", entry.product.robux or 0) or "Coming soon") or ""
		row.buy.Visible = open
	end
	self.tillNote.Text = anyOpen and "Bought Marks never add Clearance: that's earned in the house."
		or "The till opens soon. Runs pay Marks: about 150 for a strong escape, double on your first escape of the day."
end

-- The starter pack's slip ------------------------------------------------------------------

function Boutique:_buildStarter(gui: ScreenGui)
	local holder, sheet = Ui.paper("Slip", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(560, 190),
		Rotation = -0.8,
		Visible = false,
		ZIndex = 6,
		Parent = gui,
	})
	Ui.modal(holder)
	Ui.tape(holder, UDim2.new(0, 30, 0, 0), -30, 70)
	self.starter = holder
	self.starterText = Ui.typed("", {
		Position = UDim2.fromOffset(30, 20),
		Size = UDim2.new(1, -60, 0, 90),
		TextSize = 17,
		LineHeight = 1.15,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
		Parent = sheet,
	})
	Ui.paperButton("Yes, please", {
		Position = UDim2.new(0, 30, 1, -56),
		Size = UDim2.fromOffset(150, 34),
		TextSize = 17,
		TextColor3 = Ui.Theme.red,
		ZIndex = 3,
		Parent = sheet,
	}, function()
		Net.get("StarterAnswer"):FireServer(true)
		self.starter.Visible = false
		self:_visibility()
	end)
	Ui.paperButton("No thanks", {
		Position = UDim2.new(0, 196, 1, -56),
		Size = UDim2.fromOffset(130, 34),
		TextSize = 17,
		ZIndex = 3,
		Parent = sheet,
	}, function()
		Net.get("StarterAnswer"):FireServer(false)
		self.starter.Visible = false
		self:_visibility()
		Ui.dismissed()
	end)
end

function Boutique:_offer(offer)
	self.starterText.Text = string.format(
		"STARTER PACK  ·  %d Robux\n%s and %s Marks, once.\nThe boutique's racks are in the mall, by the fountain.",
		offer.robux or 99,
		offer.garment or "A jacket",
		money(offer.marks or 1000)
	)
	self.starter.Visible = true
	self:_visibility()
end

function Boutique:_visibility()
	self.card.Visible = self.state ~= nil
	self.tillCard.Visible = self.till ~= nil
	self.gui.Enabled = self.card.Visible or self.tillCard.Visible or self.starter.Visible
end

function Boutique:Update()
	-- (Out of the hub, out of the shop.)
	if self.till and self.ctx.state:InRun() then
		self:CloseTill()
	end
end

return Boutique
