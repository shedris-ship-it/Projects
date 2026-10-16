-- Owning and choosing the lobby's other wares (LB4; docs/plans/lobby-rework.md,
-- "Electronics", "The garage"): the torch's looks and the cars' bits. Pure:
-- Services/ShopService spends and saves; the torch you carry goes into the
-- run with you (PA.TorchLook), and your car's setup shows on any car you
-- drive (Services/CarService). The clothes are Logic/Closet's.
--
-- A profile keeps each kind it owns in `Owned[kind]` (the free ones are
-- everyone's), the torch you carry in `Wearing.torch`, and your car in `Car`
-- ({ paint, bits = { [id] = true }, radio }).

local CarBits = require(script.Parent.Parent.Data.CarBits)
local TorchLooks = require(script.Parent.Parent.Data.TorchLooks)

local Catalog = {}

Catalog.Kinds = {
	torch = { items = TorchLooks.Looks, order = TorchLooks.Order, default = TorchLooks.Default },
	paint = { items = CarBits.Paints, order = CarBits.PaintOrder, default = "Maroon" },
	carbit = { items = CarBits.Bits, order = CarBits.BitOrder },
	radio = { items = CarBits.Radio, order = CarBits.RadioOrder, default = "Off" },
}

function Catalog.item(kind: string, id: string)
	local k = Catalog.Kinds[kind]
	return k and type(id) == "string" and k.items[id] or nil
end

function Catalog.owns(data, kind: string, id: string): boolean
	local item = Catalog.item(kind, id)
	if not item then
		return false
	end
	if item.free then
		return true
	end
	local owned = type(data) == "table" and type(data.Owned) == "table" and data.Owned[kind]
	return type(owned) == "table" and owned[id] == true
end

-- Its price in Marks, or nil (free, or not sold).
function Catalog.price(kind: string, id: string): number?
	local item = Catalog.item(kind, id)
	if not item or item.free or type(item.price) ~= "number" then
		return nil
	end
	return item.price
end

-- Buys one with Marks. Returns ok and, when not, why: "unknown", "free",
-- "owned", "marks".
function Catalog.buy(data, kind: string, id: string): (boolean, string?)
	local item = Catalog.item(kind, id)
	if not item then
		return false, "unknown"
	end
	if item.free then
		return false, "free"
	end
	local price = Catalog.price(kind, id)
	if not price then
		return false, "unknown"
	end
	if Catalog.owns(data, kind, id) then
		return false, "owned"
	end
	if (tonumber(data.Marks) or 0) < price then
		return false, "marks"
	end
	data.Marks -= price
	data.Owned[kind] = type(data.Owned[kind]) == "table" and data.Owned[kind] or {}
	data.Owned[kind][id] = true
	return true, nil
end

-- The torch ---------------------------------------------------------------------

-- Carries a torch look you own (into the next run and the hub's hand).
function Catalog.carry(data, id: string): (boolean, string?)
	if not Catalog.item("torch", id) then
		return false, "unknown"
	end
	if not Catalog.owns(data, "torch", id) then
		return false, "notOwned"
	end
	data.Wearing.torch = id
	return true, nil
end

-- The torch look a player carries: theirs while it's still theirs.
function Catalog.torchOf(data): string
	local wearing = type(data) == "table" and type(data.Wearing) == "table" and data.Wearing.torch
	if type(wearing) == "string" and Catalog.owns(data, "torch", wearing) then
		return wearing
	end
	return TorchLooks.Default
end

-- The car ------------------------------------------------------------------------

local function car(data)
	if type(data.Car) ~= "table" then
		data.Car = {}
	end
	if type(data.Car.bits) ~= "table" then
		data.Car.bits = {}
	end
	return data.Car
end

-- Paints your car with a paint you own.
function Catalog.paint(data, id: string): (boolean, string?)
	if not Catalog.item("paint", id) then
		return false, "unknown"
	end
	if not Catalog.owns(data, "paint", id) then
		return false, "notOwned"
	end
	car(data).paint = id
	return true, nil
end

-- Fits (or takes off) a bit you own.
function Catalog.fit(data, id: string, on: boolean): (boolean, string?)
	if not Catalog.item("carbit", id) then
		return false, "unknown"
	end
	if on and not Catalog.owns(data, "carbit", id) then
		return false, "notOwned"
	end
	car(data).bits[id] = on or nil
	return true, nil
end

-- Tunes your car's radio to a station you own.
function Catalog.tune(data, id: string): (boolean, string?)
	if not Catalog.item("radio", id) then
		return false, "unknown"
	end
	if not Catalog.owns(data, "radio", id) then
		return false, "notOwned"
	end
	car(data).radio = id
	return true, nil
end

-- Your car as the lobby sees it when you drive: { paint, bits = { [id] =
-- true }, radio }, only what's still yours (the rest as a plain car).
function Catalog.carOf(data)
	local setup = type(data) == "table" and type(data.Car) == "table" and data.Car or {}
	local paint = setup.paint
	if type(paint) ~= "string" or not Catalog.owns(data, "paint", paint) then
		paint = Catalog.Kinds.paint.default
	end
	local radio = setup.radio
	if type(radio) ~= "string" or not Catalog.owns(data, "radio", radio) then
		radio = Catalog.Kinds.radio.default
	end
	local bits = {}
	if type(setup.bits) == "table" then
		for id, on in setup.bits do
			if on == true and Catalog.owns(data, "carbit", id) then
				bits[id] = true
			end
		end
	end
	return { paint = paint, bits = bits, radio = radio }
end

-- The plain car (nobody's bits): an empty car, or one with no driver.
function Catalog.plainCar()
	return { paint = Catalog.Kinds.paint.default, bits = {}, radio = Catalog.Kinds.radio.default }
end

return Catalog
