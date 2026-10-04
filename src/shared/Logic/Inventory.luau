-- A player's three hands-and-pockets slots (owner, 2026-10-04): slot 1 is the
-- flashlight, always, and slots 2 and 3 hold tools found around the house.
-- Only one slot is in your hands at a time. Pure, so the rules are tests
-- (tests/specs/Inventory.spec.luau). An item is { id = "Camera", uid = "tool:3",
-- film = 6 }: `uid` names the one object in the world, `film` rides with a Camera.
--
-- Empty slots are `false` (a Luau array can't hold nil).

local Inventory = {}

Inventory.SLOTS = 3
Inventory.TORCH_SLOT = 1
Inventory.TORCH = "Flashlight"

function Inventory.new()
	return { slots = { { id = Inventory.TORCH }, false, false }, active = 1 }
end

function Inventory.held(inv)
	return inv.slots[inv.active] or nil
end

-- The id in your hands, or nil for empty hands.
function Inventory.heldId(inv): string?
	local item = inv.slots[inv.active]
	return item and item.id or nil
end

-- Is the torch the thing in your hands (and so allowed to be lit)?
function Inventory.torchHeld(inv): boolean
	return inv.active == Inventory.TORCH_SLOT
end

-- Put `slot` in your hands. Empty slots can be chosen too (empty hands), but
-- only 1 to 3 are valid. Returns whether anything changed.
function Inventory.select(inv, slot: number): boolean
	if slot ~= math.floor(slot) or slot < 1 or slot > Inventory.SLOTS or slot == inv.active then
		return false
	end
	inv.active = slot
	return true
end

-- The next slot with something in it, `direction` +1 or -1, wrapping. Empty
-- slots are skipped so the wheel never lands on nothing; the torch always
-- counts, so there is always somewhere to go.
function Inventory.cycle(inv, direction: number): boolean
	for step = 1, Inventory.SLOTS - 1 do
		local slot = (inv.active - 1 + direction * step) % Inventory.SLOTS + 1
		if inv.slots[slot] then
			inv.active = slot
			return true
		end
	end
	return false
end

-- Take `item` into the first empty tool slot. With both full, it swaps with the
-- tool in your hands (which is returned so the caller can drop it); with the
-- torch in your hands and both full, it is refused. Returns ok, the slot it
-- went to, and the item that was swapped out.
function Inventory.pickup(inv, item)
	for slot = 2, Inventory.SLOTS do
		if not inv.slots[slot] then
			inv.slots[slot] = item
			return true, slot, nil
		end
	end
	if inv.active > Inventory.TORCH_SLOT and inv.slots[inv.active] then
		local old = inv.slots[inv.active]
		inv.slots[inv.active] = item
		return true, inv.active, old
	end
	return false, nil, nil
end

-- Empty a tool slot and return what was in it. The torch can't be dropped. If
-- it was in your hands, you go back to the torch.
function Inventory.drop(inv, slot: number)
	if slot <= Inventory.TORCH_SLOT or slot > Inventory.SLOTS then
		return nil
	end
	local item = inv.slots[slot]
	if not item then
		return nil
	end
	inv.slots[slot] = false
	if inv.active == slot then
		inv.active = Inventory.TORCH_SLOT
	end
	return item
end

-- Everything but the torch, for a player who goes down. Back to the torch.
function Inventory.dropAll(inv)
	local items = {}
	for slot = 2, Inventory.SLOTS do
		local item = Inventory.drop(inv, slot)
		if item then
			table.insert(items, item)
		end
	end
	inv.active = Inventory.TORCH_SLOT
	return items
end

function Inventory.has(inv, id: string): boolean
	for _, item in inv.slots do
		if item and item.id == id then
			return true
		end
	end
	return false
end

-- The three slot ids for display, "" for empty.
function Inventory.ids(inv): { string }
	local out = {}
	for slot = 1, Inventory.SLOTS do
		out[slot] = inv.slots[slot] and inv.slots[slot].id or ""
	end
	return out
end

return Inventory
