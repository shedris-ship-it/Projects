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
