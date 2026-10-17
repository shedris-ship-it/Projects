-- What a player owns and wears, and buying clothes for Marks (LB3; docs/
-- plans/lobby-rework.md, "Boutique"). Pure: Services/ShopService spends and
-- saves, Services/OutfitService dresses.
--
-- The free starter set (Data/Wardrobe `free`) is everyone's; the rest is
-- bought once and kept (a profile's `Owned.garment`). What you choose to wear
-- (`Wearing[slot]`) goes into the run with you, in first person and to your
-- squad. A slot you haven't chosen is your squad slot's (Logic/Outfit.wear,
-- and for the hair, its colour and the face Logic/Outfit.look, by body), so
-- a new squad still reads as different people at a glance.

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

-- What a player wears: { Top, Bottom, Shoes, Hair, Colour, Face } garment
-- ids, each slot their choice while it's still theirs, else their squad
-- slot's (`index`; the hair and face by `body`, else the one they chose).
function Closet.outfit(data, index: number, body: string?)
	local settings = type(data) == "table" and type(data.Settings) == "table" and data.Settings or {}
	local default = table.clone(Outfit.wear(index))
	for slot, id in Outfit.look(index, body or settings.body) do
		default[slot] = id
	end
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

-- The tint that makes a hair piece's grey map look `colour` (both sRGB 0 to
-- 255; `mean`, how light the map reads, 0 to 1: Data/KitHair): the colour
-- over the map, a channel at a time, no brighter than white (a
-- SurfaceAppearance's Color multiplies its map, World/Kit.tint).
function Closet.hairTint(colour: { number }, mean: number): { number }
	local out = {}
	for i = 1, 3 do
		local c = math.clamp(colour[i] or 0, 0, 255)
		out[i] = math.floor(math.min(255, c / math.max(mean, 0.05)) + 0.5)
	end
	return out
end

-- Which way to face in the fitting room (Config.Fitting): the first of
-- `turns` whose line to the mirror's camera runs clear for `need` studs, or
-- else the one that runs clear furthest. `clear[i]` is how far turn i's
-- line gets before it meets something.
function Closet.mirrorTurn(turns: { number }, clear: { number }, need: number): number
	local best, far = turns[1], -math.huge
	for i, turn in turns do
		local reach = clear[i] or 0
		if reach >= need then
			return turn
		end
		if reach > far then
			best, far = turn, reach
		end
	end
	return best
end

return Closet
