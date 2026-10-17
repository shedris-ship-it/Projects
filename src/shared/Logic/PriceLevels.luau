-- Regional pricing and gifts (2026-10-16; Roblox's Creator Docs, "Regional
-- pricing"). Roblox can sell a product for less where prices run lower: each
-- player has a price level, 1 to 1000, 1000 being the full price. A gift
-- bought cheaply in one country and given in another would undersell the
-- game there, so a gift goes only from a player whose level is at least the
-- friend's (Roblox's own rule; Services/MonetizationService asks at join, as
-- the docs advise, and before each gift).

local PriceLevels = {}

PriceLevels.Full = 1000

-- Whether `sender` may buy a gift for `recipient` (their levels), and why not.
function PriceLevels.canGift(sender: number?, recipient: number?): (boolean, string?)
	if type(sender) ~= "number" or type(recipient) ~= "number" then
		return false, "unknown"
	elseif sender < recipient then
		return false, "region"
	end
	return true, nil
end

-- The price a player is shown (client Lib/Prices): what Roblox's prompt will
-- charge them. GetProductInfoAsync answers a client with its own player's
-- price in PriceInRobux (regional, and after any discount of theirs: Roblox
-- Plus takes 10% off, the owner's account, 2026-10-16); nil when it gives none.
function PriceLevels.shown(info): number?
	local price = type(info) == "table" and info.PriceInRobux
	if type(price) ~= "number" or not (price >= 1 and price < 1e9) then
		return nil
	end
	return math.floor(price)
end

-- Everything on sale in Data/Products (an id filed), to ask Roblox the price
-- of: { name, id, pass }, by name.
function PriceLevels.onSale(products)
	local out = {}
	for _, kind in { "Products", "Passes" } do
		for name, entry in products[kind] or {} do
			if type(entry.id) == "number" then
				table.insert(out, { name = name, id = entry.id, pass = kind == "Passes" })
			end
		end
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

-- Data/Products' own figure for a product or pass, by name: shown until
-- Roblox answers, or if it can't.
function PriceLevels.listed(products, name: string): number?
	local entry = (products.Products or {})[name] or (products.Passes or {})[name]
	return entry and entry.robux
end

-- MarketplaceService:GetUsersPriceLevelsAsync's answer ({ { UserId,
-- PriceLevel } }) as { [userId] = level }, anything malformed left out.
function PriceLevels.read(infos)
	local out = {}
	if type(infos) ~= "table" then
		return out
	end
	for _, info in infos do
		if type(info) == "table" and type(info.UserId) == "number" and type(info.PriceLevel) == "number" then
			out[info.UserId] = math.clamp(info.PriceLevel, 1, PriceLevels.Full)
		end
	end
	return out
end

return PriceLevels
