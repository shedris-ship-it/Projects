-- What a player owns and wears, and buying clothes for Marks (LB3; docs/
-- plans/lobby-rework.md, "Boutique"). Pure: Services/ShopService spends and
-- saves, Services/OutfitService dresses.
--
-- The free starter set (Data/Wardrobe `free`) is everyone's; the rest is
-- bought once and kept (a profile's `Owned.garment`). What you choose to wear
-- (`Wearing[slot]`) goes into the run with you, in first person and to your
-- squad. A slot you haven't chosen is your squad slot's (Logic/Outfit.wear),
-- so a new squad still reads as different people at a glance.

local Wardrobe = require(script.Parent.Parent.Data.Wardrobe)
local Outfit = require(script.Parent.Outfit)

local Closet = {}

-- The garments' key in a profile's `Owned` (Logic/Profile).
Closet.Kind = "garment"

local function ownedSet(data)
	local owned = type(data) == "table" and type(data.Owned) == "table" and data.Owned[Closet.Kind]
	return type(owned) == "table" and owned or nil
end

function Closet.owns(data, id: string): boolean
	local garment = Wardrobe.Garments[id]
	if not garment then
		return false
	end
	if garment.free then
		return true
	end
	local owned = ownedSet(data)
	return owned ~= nil and owned[id] == true
end

-- A garment's price in Marks, or nil (free, or not sold).
function Closet.price(id: string): number?
	local garment = Wardrobe.Garments[id]
	if not garment or garment.free or type(garment.price) ~= "number" then
		return nil
	end
	return garment.price
end

-- Puts a garment in a profile's wardrobe (bought, or a purchase's grant).
function Closet.give(data, id: string): boolean
	if not Wardrobe.Garments[id] or type(data.Owned) ~= "table" then
		return false
	end
	data.Owned[Closet.Kind] = ownedSet(data) or {}
	data.Owned[Closet.Kind][id] = true
	return true
end

-- Buys a garment with Marks. Returns ok and, when not, why: "unknown",
-- "free" (everyone has it), "owned", "marks" (not enough).
function Closet.buy(data, id: string): (boolean, string?)
	local garment = Wardrobe.Garments[id]
	if not garment then
		return false, "unknown"
	end
	if garment.free then
		return false, "free"
	end
	local price = Closet.price(id)
	if not price then
		return false, "unknown"
	end
	if Closet.owns(data, id) then
		return false, "owned"
	end
	if (tonumber(data.Marks) or 0) < price then
		return false, "marks"
	end
	data.Marks -= price
	Closet.give(data, id)
	return true, nil
end

-- Chooses to wear a garment you own, in its slot. Returns ok and, when not,
-- why: "unknown", "notOwned".
function Closet.wear(data, id: string): (boolean, string?)
	local garment = Wardrobe.Garments[id]
	if not garment then
		return false, "unknown"
	end
	if not Closet.owns(data, id) then
		return false, "notOwned"
	end
	if type(data.Wearing) ~= "table" then
		data.Wearing = {}
	end
	data.Wearing[garment.slot] = id
	return true, nil
end

-- What a player wears: { Top, Bottom, Shoes } garment ids, each slot their
-- choice while it's still theirs, else their squad slot's (`index`).
function Closet.outfit(data, index: number)
	local default = Outfit.wear(index)
	local wearing = type(data) == "table" and type(data.Wearing) == "table" and data.Wearing or {}
	local out = {}
	for _, slot in Wardrobe.Slots do
		local chosen = wearing[slot]
		local garment = type(chosen) == "string" and Wardrobe.Garments[chosen]
		if garment and garment.slot == slot and Closet.owns(data, chosen) then
			out[slot] = chosen
		else
			out[slot] = default[slot]
		end
	end
	return out
end

-- An outfit with `id` tried on in its slot (the changing booth: anything
-- on the racks, owned or not).
function Closet.try(outfit, id: string)
	local out = table.clone(outfit)
	local garment = Wardrobe.Garments[id]
	if garment then
		out[garment.slot] = id
	end
	return out
end

-- Whether everything in an outfit is yours (nothing you haven't bought
-- leaves the shop on you).
function Closet.ownsAll(data, outfit): boolean
	for _, slot in Wardrobe.Slots do
		if outfit[slot] and not Closet.owns(data, outfit[slot]) then
			return false
		end
	end
	return true
end

-- A slot's garments, in the booth's order (Data/Wardrobe.Order).
function Closet.slotList(slot: string): { string }
	local out = {}
	for _, id in Wardrobe.Order do
		local garment = Wardrobe.Garments[id]
		if garment and garment.slot == slot then
			table.insert(out, id)
		end
	end
	return out
end

-- The garment `step` along from `id` in its slot's list, round and round.
function Closet.step(slot: string, id: string?, step: number): string?
	local list = Closet.slotList(slot)
	if #list == 0 then
		return nil
	end
	local at = id and table.find(list, id) or 1
	return list[(at - 1 + step) % #list + 1]
end

return Closet
