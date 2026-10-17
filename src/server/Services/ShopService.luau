-- The boutique (LB3; docs/plans/lobby-rework.md, "Boutique"): clothes for
-- Marks, tried on first.
--
-- The fitting room: E on the changing booth stands you at it, against its
-- curtain (the camera turns to face you, UI/Boutique), or on a rack tries
-- its slot on where you stand (the booth takes one at a time). Flip through each slot, the free set and the racks
-- alike, see it on you (Services/OutfitService), and buy it right there for
-- Marks (Logic/Closet; the prices are Data/Wardrobe's, only ever the
-- server's). Done: you wear what's yours of what you have on; nothing you
-- haven't bought leaves the fitting room on you.
--
-- The till: Marks packs for Robux, for you or as a gift for anyone in this
-- lobby (Services/MonetizationService); a gift waits for its friend as a
-- wrapped box at their feet. The starter pack is offered once, after your
-- first run.
--
-- LB4's wares (Logic/Catalog): the torch's looks at the electronics
-- counter (UI/Wares: the one you carry goes into the run, PA.TorchLook)
-- and the car bits at the garage's pegboard (UI/Wares: paint, bits and a
-- radio station, shown on any car you drive, Services/CarService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Logic.Catalog)
local Closet = require(Shared.Logic.Closet)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Mall = require(Shared.Data.Mall)
local Net = require(Shared.Net)
local Products = require(Shared.Data.Products)
local Profile = require(Shared.Logic.Profile)
local PropFactory = require(Shared.World.PropFactory)
local Wardrobe = require(Shared.Data.Wardrobe)
local MallBuilder = require(script.Parent.Parent.World.MallBuilder)

local PA = Constants.PlayerAttributes
local B = Mall.Boutique

local FACES = {
	N = Vector3.new(0, 0, -1),
	S = Vector3.new(0, 0, 1),
	E = Vector3.new(1, 0, 0),
	W = Vector3.new(-1, 0, 0),
}

local ShopService = {}

function ShopService:Init(services)
	self.services = services
	self.sessions = {} -- player -> { where, outfit, before, root }
	self.booth = nil -- the player in the changing booth
	self.origin = nil
	self.boxes = {} -- player -> their wrapped gift's box, when one is out
end

-- 1500 -> "1,500".
local function money(n: number): string
	local s = tostring(math.floor(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	return (string.gsub(out, "^,", ""))
end
ShopService.money = money

local function tell(player: Player, text: string)
	Net.get("Notify"):FireClient(player, text, "info")
end

-- A product's name on a card or a toast.
local function labelOf(name: string): string
	local product = Products.Products[name] or Products.Passes[name]
	return product and product.label or name
end

-- Building ------------------------------------------------------------------------

-- The fitting room's and the till's prompts, and the cards on the racks, in
-- the boutique MallBuilder made (LobbyService calls this once the mall
-- stands). None on a run server: it builds only the garage.
function ShopService:Build(parent: Instance, origin: Vector3)
	local places = self.services.PlaceService
	if places and places:IsRun() then
		return
	end
	self.origin = origin
	local folder = Instance.new("Folder")
	folder.Name = "Boutique"
	folder.Parent = parent
	local function spot(name: string, at, action: string, object: string, onTrigger)
		local part = PropFactory.part(
			folder,
			name,
			Vector3.new(1.4, 2.4, 1.4),
			CFrame.new(origin + Vector3.new(at.x, at.y, at.z)),
			Color3.new(0, 0, 0),
			Enum.Material.SmoothPlastic,
			{ collide = false, transparency = 1, castShadow = false }
		)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = action
		prompt.ObjectText = object
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
		prompt.Triggered:Connect(onTrigger)
		return part
	end
	spot("BoothWayIn", B.booth.at, "Try on", "Fitting room", function(player)
		self:Open(player, "booth")
	end)
	for _, rack in B.racks do
		spot("Rack" .. rack.label, rack, "Try on", rack.label, function(player)
			self:Open(player, "rack", rack.slot)
		end)
	end
	spot("Till", B.till, "Pay", "Till", function(player)
		self:Till(player)
	end)
	spot("Counter", B.counter, "Look", B.counter.label, function(player)
		self:Wares(player, "counter")
	end)
	spot("Pegboard", B.pegboard, "Look", B.pegboard.label, function(player)
		self:Wares(player, "pegboard")
	end)
	-- The cards: what's new on each rack, its price in Marks.
	for _, tag in B.tags do
		local lines = { "NEW IN" }
		for _, id in tag.garments do
			local price = Closet.price(id)
			if price then
				table.insert(lines, string.format("%s  %s", string.upper(Wardrobe.Garments[id].name), money(price)))
			end
		end
		table.insert(lines, "MARKS · TRY IT ON")
		MallBuilder.sign(folder, origin, {
			text = table.concat(lines, "\n"),
			x = tag.x,
			y = tag.y,
			z = tag.z,
			w = tag.w,
			h = tag.h,
			face = tag.face,
			tilt = 1.5,
			color = { 38, 30, 26 },
			panel = { 228, 210, 176 },
			font = "PermanentMarker",
			ppi = 120,
		})
	end
	local sign = B.sign
	MallBuilder.sign(folder, origin, {
		text = sign.text,
		x = sign.x,
		y = sign.y,
		z = sign.z,
		w = sign.w,
		h = sign.h,
		face = sign.face,
		color = { 38, 30, 26 },
		panel = { 176, 140, 96 },
		font = "PermanentMarker",
		ppi = 80,
	})
end

-- The fitting room ------------------------------------------------------------------

-- Steps a player into the fitting room: in the booth, or trying `slot` on
-- where they stand at a rack (also when the booth's taken).
function ShopService:Open(player: Player, where: string, slot: string?)
	if self.sessions[player] or player:GetAttribute(PA.Car) ~= nil then
		return
	end
	local data = self.services.DataService:Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not root or not self.origin then
		return
	end
	local outfit = self.services.OutfitService:OutfitOf(player)
	local session = { where = where, outfit = table.clone(outfit), before = table.clone(outfit), root = root }
	if where == "booth" then
		local taken = self.booth and self.booth.Parent and self.sessions[self.booth]
		if taken then
			session.where = "rack"
			tell(player, "Someone's in the booth: try it on here.")
		else
			self.booth = player
			local b = B.booth
			local at = self.origin + Vector3.new(b.x, b.y, b.z)
			self.services.PlayerStateService:MarkTeleport(player)
			character:PivotTo(CFrame.lookAt(at, at + FACES[b.face]))
		end
	end
	if session.where ~= "booth" then
		-- At a rack you face the rack, and the mirror's camera would stand in
		-- it: turned to where it has room (Config.Fitting).
		local turn = self:_mirrorTurn(root)
		if turn ~= 0 then
			self.services.PlayerStateService:MarkTeleport(player)
			character:PivotTo(root.CFrame * CFrame.Angles(0, math.rad(turn), 0))
		end
	end
	-- (Standing still while you change: you leave by Done.)
	root.Anchored = true
	self.sessions[player] = session
	player:SetAttribute(PA.Trying, session.where)
	self.services.OutfitService:SetTrying(player, session.outfit)
	self:_send(player, slot)
end

-- How far each of Config.Fitting's turns leaves the mirror's camera a clear
-- line to you (three rays a line, from inside you, where nothing else is),
-- and the turn to take (Logic/Closet.mirrorTurn).
function ShopService:_mirrorTurn(root: BasePart): number
	local F = Config.Fitting
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local everyone = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(everyone, other.Character)
		end
	end
	params.FilterDescendantsInstances = everyone
	local eye = CFrame.new(F.Eye[1], F.Eye[2], F.Eye[3])
	local clear, need = {}, 0
	for i, turn in F.Turns do
		local frame = root.CFrame * CFrame.Angles(0, math.rad(turn), 0)
		local reach = math.huge
		for _, side in { -F.Width / 2, 0, F.Width / 2 } do
			-- (From your own middle, where no rack can be, towards the eye.)
			local from = (frame * CFrame.new(side, F.At[2], 0)).Position
			local to = (frame * eye * CFrame.new(side, 0, 0)).Position
			need = (to - from).Magnitude
			local hit = Workspace:Raycast(from, to - from, params)
			reach = math.min(reach, hit and hit.Distance or need)
		end
		clear[i] = reach
	end
	return Closet.mirrorTurn(F.Turns, clear, need)
end

-- What the fitting room shows: what you have on, what's yours, your Marks.
function ShopService:_send(player: Player, slot: string?)
	local session = self.sessions[player]
	local data = self.services.DataService:Get(player)
	if not session or not data then
		Net.get("ShopState"):FireClient(player, nil)
		return
	end
	local owned = {}
	for id in Wardrobe.Garments do
		if Closet.owns(data, id) then
			table.insert(owned, id)
		end
	end
	Net.get("ShopState"):FireClient(player, {
		where = session.where,
		outfit = session.outfit,
		owned = owned,
		marks = data.Marks,
		slot = slot,
	})
end

-- Tries a garment on (anything on the racks, yours or not).
function ShopService:Try(player: Player, id: string)
	local session = self.sessions[player]
	if not session or not Wardrobe.Garments[id] then
		return
	end
	session.outfit = Closet.try(session.outfit, id)
	self.services.OutfitService:SetTrying(player, session.outfit)
	self:_send(player)
end

-- Buys a garment for Marks, in the fitting room, and keeps it on.
function ShopService:Buy(player: Player, id: string)
	local session = self.sessions[player]
	local data = self.services.DataService:Get(player)
	if not session or not data then
		return
	end
	local ok, why = Closet.buy(data, id)
	if not ok then
		local say = {
			marks = "Not enough Marks for that yet: runs pay them, or the till sells them.",
			owned = "That's already yours.",
			free = "That one's everyone's: no need to buy it.",
		}
		tell(player, say[why] or "That isn't for sale.")
		self:_send(player)
		return
	end
	session.outfit = Closet.try(session.outfit, id)
	self.services.OutfitService:SetTrying(player, session.outfit)
	tell(player, string.format("%s: it's yours.", Wardrobe.Garments[id].name))
	self.services.DataService:Send(player)
	task.spawn(self.services.DataService.SaveNow, self.services.DataService, player)
	if self.services.Telemetry then
		self.services.Telemetry:Log("ShopBuy", { garment = id, marks = Closet.price(id) }, player)
	end
	self:_send(player)
end

-- Out of the fitting room: what's yours of what you have on is what you
-- wear now (in the slots you changed); the rest goes back on the rack.
function ShopService:Done(player: Player, save: boolean?)
	local session = self.sessions[player]
	if not session then
		return
	end
	self.sessions[player] = nil
	if self.booth == player then
		self.booth = nil
	end
	local data = self.services.DataService:Get(player)
	local changed = false
	if data then
		for _, slot in Wardrobe.Slots do
			local id = session.outfit[slot]
			if id and id ~= session.before[slot] and Closet.owns(data, id) then
				Closet.wear(data, id)
				changed = true
			end
		end
	end
	if session.root and session.root.Parent then
		session.root.Anchored = false
	end
	player:SetAttribute(PA.Trying, nil)
	if player.Parent then
		self.services.OutfitService:SetTrying(player, nil)
		Net.get("ShopState"):FireClient(player, nil)
	end
	if changed and save ~= false then
		task.spawn(self.services.DataService.SaveNow, self.services.DataService, player)
	end
end

-- The counter and the pegboard (LB4) ------------------------------------------------

-- Opens (or refreshes) the counter's or the pegboard's card: what's yours of
-- each kind, the torch you carry, your car, your Marks.
function ShopService:Wares(player: Player, which: string)
	local data = self.services.DataService:Get(player)
	if not data then
		return
	end
	local owned = {}
	for kind, k in Catalog.Kinds do
		owned[kind] = {}
		for _, id in k.order do
			if Catalog.owns(data, kind, id) then
				table.insert(owned[kind], id)
			end
		end
	end
	Net.get("WareState"):FireClient(player, {
		which = which,
		marks = data.Marks,
		owned = owned,
		torch = Catalog.torchOf(data),
		car = Catalog.carOf(data),
	})
end

-- What you carry and drive, everywhere it shows.
function ShopService:_show(player: Player)
	local data = self.services.DataService:Get(player)
	if data then
		player:SetAttribute(PA.TorchLook, Catalog.torchOf(data))
	end
	local cars = self.services.CarService
	if cars then
		cars:Redress()
	end
end

-- Buys a ware for Marks, then uses it (carries the torch, paints the car,
-- fits the bit, tunes the radio).
function ShopService:WareBuy(player: Player, kind: string, id: string, which: string)
	local data = self.services.DataService:Get(player)
	if not data then
		return
	end
	local ok, why = Catalog.buy(data, kind, id)
	if not ok then
		local say = {
			marks = "Not enough Marks for that yet: runs pay them, or the boutique's till sells them.",
			owned = "That's already yours.",
			free = "That one's everyone's: no need to buy it.",
		}
		tell(player, say[why] or "That isn't for sale.")
	else
		self:WareUse(player, kind, id, true, which, true)
		tell(player, string.format("%s: it's yours.", Catalog.item(kind, id).name))
		self.services.DataService:Send(player)
		if self.services.Telemetry then
			self.services.Telemetry:Log("WareBuy", { kind = kind, id = id, marks = Catalog.price(kind, id) }, player)
		end
	end
	self:Wares(player, which)
end

-- Uses a ware you own: carry a torch, paint the car, fit (`on`) or take off
-- a bit, tune the radio.
function ShopService:WareUse(player: Player, kind: string, id: string, on: boolean, which: string, quiet: boolean?)
	local data = self.services.DataService:Get(player)
	if not data then
		return
	end
	local ok
	if kind == "torch" then
		ok = Catalog.carry(data, id)
	elseif kind == "paint" then
		ok = Catalog.paint(data, id)
	elseif kind == "carbit" then
		ok = Catalog.fit(data, id, on)
	elseif kind == "radio" then
		ok = Catalog.tune(data, id)
	end
	if ok then
		self:_show(player)
		task.spawn(self.services.DataService.SaveNow, self.services.DataService, player)
	end
	if not quiet then
		self:Wares(player, which)
	end
end

-- The till ---------------------------------------------------------------------------

-- Opens the till's card: the products on it (one without an id yet can't be
-- bought), and who's here to buy for.
function ShopService:Till(player: Player)
	local data = self.services.DataService:Get(player)
	if not data then
		return
	end
	local list = {}
	for name, product in Products.Products do
		if product.till then
			table.insert(list, {
				name = name,
				label = product.label or name,
				robux = product.robux,
				open = type(product.id) == "number",
				order = product.till,
			})
		end
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	local friends = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(friends, { userId = other.UserId, name = other.DisplayName })
		end
	end
	Net.get("ShopTill"):FireClient(player, { products = list, friends = friends, marks = data.Marks })
end

-- A product bought at the till, for you (`forUserId` 0) or a friend here.
function ShopService:TillBuy(player: Player, name: string, forUserId: number)
	local product = Products.Products[name]
	if not product or not product.till then
		return
	end
	local money_ = self.services.MonetizationService
	local ok, why
	if forUserId ~= 0 then
		local friend = Players:GetPlayerByUserId(forUserId)
		if friend then
			ok, why = money_:PromptGift(player, name, friend)
		end
	else
		ok = money_:Prompt(player, name)
	end
	if not ok then
		local say = {
			region = "Roblox prices change by country, so a gift can only go to someone whose prices are the same as yours or lower.",
			unknown = "The till can't check that gift just now: try again in a moment.",
		}
		tell(player, say[why] or "The till can't take that yet.")
	end
end

-- The starter pack, offered once (the plan: "shown once, after your first
-- run"): when you're back in the hub with a run behind you.
function ShopService:CheckOffer(player: Player)
	local data = self.services.DataService:Get(player)
	local product = Products.Passes.StarterPack
	if not data or data.StarterPack or data.StarterOffered or data.RunsPlayed < 1 then
		return
	end
	if not product or type(product.id) ~= "number" then
		return -- (not on sale yet: offered once it is)
	end
	data.StarterOffered = true
	Net.get("StarterOffer"):FireClient(player, {
		robux = product.robux,
		label = product.label,
		garment = product.grant.garment and Wardrobe.Garments[product.grant.garment].name,
		marks = product.grant.marks,
	})
end

-- A pass's grant given (Services/MonetizationService): said.
function ShopService:PassGranted(player: Player, name: string)
	local pass = Products.Passes[name]
	local garment = pass and pass.grant and pass.grant.garment
	tell(
		player,
		string.format("Thank you! %s.%s", labelOf(name), garment and " Try the jacket on at the boutique." or "")
	)
end

-- Gifts -------------------------------------------------------------------------------

-- A gift just granted to `player` (MonetizationService): tell them, and put
-- its box at their feet.
function ShopService:GiftDelivered(player: Player, from: Player, productName: string)
	Net.get("GiftArrived"):FireClient(player, { from = from.DisplayName, what = labelOf(productName) })
	tell(from, string.format("Your gift is waiting for %s, wrapped.", player.DisplayName))
	self:ShowGifts(player)
end

-- The giver's name for a box's tag.
local function giverName(userId: number): string
	local here = Players:GetPlayerByUserId(userId)
	if here then
		return here.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	return ok and name or "a friend"
end

-- The oldest unopened gift as a wrapped box in front of `player`, in the
-- hub; opening it (only they can) tells them what it was.
function ShopService:ShowGifts(player: Player)
	local data = self.services.DataService:Get(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or #data.Gifts == 0 or self.boxes[player] or not root or not self.origin then
		return
	end
	local gift = data.Gifts[1]
	local name = giverName(gift.from)
	-- On the floor a few studs in front of them.
	local ahead = (root.CFrame * CFrame.new(0, 0, -3.2)).Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model }
	local hit = workspace:Raycast(ahead, Vector3.new(0, -12, 0), params)
	local ground = hit and hit.Position or (ahead - Vector3.new(0, 3, 0))
	local floor = CFrame.new(ground) * CFrame.Angles(0, math.rad(20), 0)
	local box = Instance.new("Model")
	box.Name = "Gift"
	local paper = PropFactory.part(
		box,
		"Paper",
		Vector3.new(1.4, 1.1, 1.4),
		floor * CFrame.new(0, 0.55, 0),
		Color3.fromRGB(176, 34, 40),
		Enum.Material.SmoothPlastic,
		{ collide = false }
	)
	for _, size in { Vector3.new(1.44, 1.14, 0.22), Vector3.new(0.22, 1.14, 1.44) } do
		PropFactory.part(
			box,
			"Ribbon",
			size,
			floor * CFrame.new(0, 0.55, 0),
			Color3.fromRGB(226, 186, 72),
			Enum.Material.SmoothPlastic,
			{ collide = false }
		)
	end
	PropFactory.part(
		box,
		"Bow",
		Vector3.new(0.5, 0.26, 0.5),
		floor * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color3.fromRGB(226, 186, 72),
		Enum.Material.SmoothPlastic,
		{ collide = false }
	)
	box.PrimaryPart = paper
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "A gift from " .. name
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = paper
	box.Parent = self.services.LobbyService.folder or workspace
	self.boxes[player] = box
	prompt.Triggered:Connect(function(who)
		if who ~= player then
			tell(who, "That's " .. player.DisplayName .. "'s gift.")
			return
		end
		self:_open(player)
	end)
end

function ShopService:_open(player: Player)
	local data = self.services.DataService:Get(player)
	local box = self.boxes[player]
	self.boxes[player] = nil
	if box then
		box:Destroy()
	end
	local gift = data and Profile.openGift(data)
	if not gift then
		return
	end
	-- (Its grant was given when it was bought: opening it shows what it was.)
	Net.get("GiftArrived")
		:FireClient(player, { from = giverName(gift.from), what = labelOf(gift.product), opened = true })
	self.services.DataService:Send(player)
	task.spawn(self.services.DataService.SaveNow, self.services.DataService, player)
	task.delay(1.5, function()
		if player.Parent then
			self:ShowGifts(player)
		end
	end)
end

-- F2 `gift [product]`: a gift from yourself, as if a friend had bought it
-- (granted, saved, its box out). Returns what happened.
function ShopService:DebugGift(player: Player, name: string): string
	local product = Products.Products[name]
	local data = self.services.DataService:Get(player)
	if not product or not data then
		return "gift <" .. table.concat({ "MarksSmall", "MarksMedium", "MarksLarge", "ArcadePlay" }, "|") .. ">"
	end
	local id = "debug-gift-" .. tostring(os.clock())
	Profile.applyPurchase(data, id, product.grant or {}, { product = name, from = player.UserId })
	self:GiftDelivered(player, player, name)
	self.services.DataService:Send(player)
	return "gift: " .. labelOf(name)
end

function ShopService:Start()
	Net.onServer("ShopTry", { interval = 0.08, types = { "string" } }, function(player, id)
		self:Try(player, id)
	end)
	Net.onServer("ShopBuy", { interval = 0.5, types = { "string" } }, function(player, id)
		self:Buy(player, id)
	end)
	Net.onServer("ShopDone", { interval = 0.3 }, function(player)
		self:Done(player)
	end)
	Net.onServer("TillBuy", { interval = 1, types = { "string", "number" } }, function(player, name, forUserId)
		self:TillBuy(player, name, math.floor(forUserId))
	end)
	Net.onServer(
		"WareBuy",
		{ interval = 0.5, types = { "string", "string", "string" } },
		function(player, kind, id, which)
			self:WareBuy(player, kind, id, which)
		end
	)
	Net.onServer(
		"WareUse",
		{ interval = 0.15, types = { "string", "string", "boolean", "string" } },
		function(player, kind, id, on, which)
			self:WareUse(player, kind, id, on, which)
		end
	)
	Net.onServer("StarterAnswer", { interval = 1, types = { "boolean" } }, function(player, yes)
		if yes then
			self.services.MonetizationService:Prompt(player, "StarterPack")
		end
		task.spawn(self.services.DataService.SaveNow, self.services.DataService, player)
	end)
	local function onPlayer(player: Player)
		player.CharacterRemoving:Connect(function()
			self:Done(player, true)
			local box = self.boxes[player]
			self.boxes[player] = nil
			if box then
				box:Destroy()
			end
		end)
		-- Back in a lobby with a run behind you (live: from your run server),
		-- and your gifts waiting.
		task.spawn(function()
			local data = self.services.DataService:WaitForProfile(player, 15)
			if not data then
				return
			end
			-- The torch look you carry, into the run with you (any server).
			player:SetAttribute(PA.TorchLook, Catalog.torchOf(data))
			task.wait(6)
			if player.Parent then
				self:CheckOffer(player)
				self:ShowGifts(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self:Done(player, true)
		local box = self.boxes[player]
		self.boxes[player] = nil
		if box then
			box:Destroy()
		end
	end)
end

return ShopService
