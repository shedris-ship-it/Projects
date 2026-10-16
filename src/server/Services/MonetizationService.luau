-- Robux purchases (design doc section 7's MonetizationService; section 9 on
-- what is and isn't sold; docs/plans/lobby-rework.md, "Purchases").
--
-- ProcessReceipt grants each purchase once. The grant and its receipt are
-- applied together (Logic/Profile.applyPurchase) and saved before Roblox is
-- told the purchase is granted; if the save fails both are taken back and
-- Roblox asks again later, so nothing is granted twice or lost. Products
-- and passes come from Data/Products; one without an id can't be bought.
--
-- Gifts (LB3, the boutique's till): a product bought for a friend in the
-- same lobby is granted to them and saved with its receipt before Roblox is
-- told, a wrapped box waiting for them to open (Services/ShopService). If
-- they've left by then, the buyer has it instead, so nothing paid for is
-- lost.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared.Data.Products)
local Profile = require(Shared.Logic.Profile)

local MonetizationService = {}

function MonetizationService:Init(services)
	self.services = services
	self.Data = services.DataService
	self.Telemetry = services.Telemetry
	self.byId = {} -- developer product id -> { name, product }
	self.passIds = {} -- pass name -> id
	self.owned = {} -- player -> { [pass name] = true }, once seen owned
	self.gifting = {} -- buyer -> { product, to (userId), at }: the gift being bought
end

function MonetizationService:Start()
	for name, product in Products.Products do
		if type(product.id) == "number" then
			self.byId[product.id] = { name = name, product = product }
		end
	end
	for name, pass in Products.Passes do
		if type(pass.id) == "number" then
			self.passIds[name] = pass.id
		end
	end
	MarketplaceService.ProcessReceipt = function(receipt)
		local ok, decision = pcall(self._process, self, receipt)
		if not ok then
			warn("[Consensus] a purchase couldn't be processed: " .. tostring(decision))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return decision
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		if bought then
			for name, id in self.passIds do
				if id == passId then
					self.owned[player] = self.owned[player] or {}
					self.owned[player][name] = true
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.owned[player] = nil
		self.gifting[player] = nil
	end)
end

-- Who a purchase of `name` by `buyer` goes to now: a friend they're buying
-- it for (still here, profile loaded), else themselves.
function MonetizationService:_recipient(buyer: Player, name: string): (Player, boolean)
	local gift = self.gifting[buyer]
	if gift and gift.product == name and os.clock() - gift.at < 600 then
		local friend = Players:GetPlayerByUserId(gift.to)
		if friend and friend ~= buyer and self.Data:Get(friend) then
			return friend, true
		end
	end
	return buyer, false
end

function MonetizationService:_process(receipt)
	local entry = self.byId[receipt.ProductId]
	if not entry then
		-- A product this build doesn't know (an id not in Data/Products yet):
		-- leave it for a server that does.
		warn("[Consensus] a purchase of an unknown product: " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local buyer = Players:GetPlayerByUserId(receipt.PlayerId)
	if not buyer then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- granted when they're next in a server
	end
	local buyerData = self.Data:WaitForProfile(buyer, 10)
	if not buyerData then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if Profile.hasReceipt(buyerData, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- a gift already given: Roblox asking again
	end
	local player, isGift = self:_recipient(buyer, entry.name)
	local data = self.Data:Get(player)
	local gift = isGift and { product = entry.name, from = buyer.UserId } or nil
	local applied, undo = Profile.applyPurchase(data, receipt.PurchaseId, entry.product.grant or {}, gift)
	if not applied then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted: Roblox asking again
	end
	if not self.Data:SaveNow(player) then
		undo()
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	self.Data:Send(player)
	if isGift then
		-- (The buyer keeps the receipt too, so a later ask never grants it to
		-- them as well; it's given either way.)
		self.gifting[buyer] = nil
		table.insert(buyerData.Receipts, receipt.PurchaseId)
		while #buyerData.Receipts > Profile.MaxReceipts do
			table.remove(buyerData.Receipts, 1)
		end
		task.spawn(self.Data.SaveNow, self.Data, buyer)
		local shop = self.services and self.services.ShopService
		if shop then
			shop:GiftDelivered(player, buyer, entry.name)
		end
	end
	if self.Telemetry then
		self.Telemetry:Log("Purchase", { product = entry.name, robux = receipt.CurrencySpent, gift = isGift }, buyer)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Opens Roblox's purchase prompt for a product, for a friend in this lobby
-- (a gift). False when it can't be: no id yet, the friend isn't here, or a
-- once-only product they already have.
function MonetizationService:PromptGift(buyer: Player, name: string, friend: Player): boolean
	local product = Products.Products[name]
	if not product or type(product.id) ~= "number" or friend == buyer or friend.Parent ~= Players then
		return false
	end
	local data = self.Data:Get(friend)
	if not data or (product.once and name == "StarterPack" and data.StarterPack) then
		return false
	end
	self.gifting[buyer] = { product = name, to = friend.UserId, at = os.clock() }
	MarketplaceService:PromptProductPurchase(buyer, product.id)
	return true
end

-- Whether a player owns a game pass (by its name in Data/Products). Asks
-- Roblox the first time and remembers a yes.
function MonetizationService:OwnsPass(player: Player, name: string): boolean
	local owned = self.owned[player]
	if owned and owned[name] then
		return true
	end
	local id = self.passIds[name]
	if not id then
		return false
	end
	local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
	if ok and result then
		self.owned[player] = owned or {}
		self.owned[player][name] = true
		return true
	end
	return false
end

-- Opens Roblox's purchase prompt for a product or pass by name; false when
-- it can't be bought yet (no id), or a once-only product already was.
function MonetizationService:Prompt(player: Player, name: string): boolean
	local product = Products.Products[name]
	if product and type(product.id) == "number" then
		local data = self.Data:Get(player)
		if product.once and name == "StarterPack" and data and data.StarterPack then
			return false
		end
		self.gifting[player] = nil
		MarketplaceService:PromptProductPurchase(player, product.id)
		return true
	end
	local pass = self.passIds[name]
	if pass then
		MarketplaceService:PromptGamePassPurchase(player, pass)
		return true
	end
	return false
end

return MonetizationService
