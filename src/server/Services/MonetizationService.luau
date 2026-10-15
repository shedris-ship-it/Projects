-- Robux purchases (design doc section 7's MonetizationService; section 9 on
-- what is and isn't sold; docs/plans/lobby-rework.md, "Purchases").
--
-- ProcessReceipt grants each purchase once. The grant and its receipt are
-- applied together (Logic/Profile.applyPurchase) and saved before Roblox is
-- told the purchase is granted; if the save fails both are taken back and
-- Roblox asks again later, so nothing is granted twice or lost. Products
-- and passes come from Data/Products; one without an id can't be bought.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared.Data.Products)
local Profile = require(Shared.Logic.Profile)

local MonetizationService = {}

function MonetizationService:Init(services)
	self.Data = services.DataService
	self.Telemetry = services.Telemetry
	self.byId = {} -- developer product id -> { name, product }
	self.passIds = {} -- pass name -> id
	self.owned = {} -- player -> { [pass name] = true }, once seen owned
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
	end)
end

function MonetizationService:_process(receipt)
	local entry = self.byId[receipt.ProductId]
	if not entry then
		-- A product this build doesn't know (an id not in Data/Products yet):
		-- leave it for a server that does.
		warn("[Consensus] a purchase of an unknown product: " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- granted when they're next in a server
	end
	local data = self.Data:WaitForProfile(player, 10)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local applied, undo = Profile.applyPurchase(data, receipt.PurchaseId, entry.product.grant or {})
	if not applied then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted: Roblox asking again
	end
	if not self.Data:SaveNow(player) then
		undo()
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	self.Data:Send(player)
	if self.Telemetry then
		self.Telemetry:Log("Purchase", { product = entry.name, robux = receipt.CurrencySpent }, player)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
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
