-- A player's three slots (owner, 2026-10-04; docs/plans/gameplay-rework.md
-- section 4.1): slot 1 is the flashlight, always; slots 2 and 3 hold tools and
-- bulky things found around the house. Only one slot is in your hands at a
-- time. Anything but the torch clips it to your shirt (a weak light where your
-- body faces), so the light can stay on whatever you hold; an empty slot is a
-- free hand.
--
-- There was a fourth slot, your bare hands, that grabbing anything switched
-- to: the squad playtest (2026-10-08) found that losing the torch's beam to
-- open a door "doesn't feel good". Your hands now work from any slot
-- (Controllers/HandsController), and the torch stays where it is.
--
-- Pure, so the rules are tests (tests/specs/Inventory.spec.luau). An item is
-- { id = "Radio", uid = "tool:3" }: `uid` names the one object in the world.
-- The thing you're carrying in your hands is the hands' own business
-- (HandsService), not an item here.
--
-- Empty slots are `false` (a Luau array can't hold nil).

local Inventory = {}

Inventory.SLOTS = 3
Inventory.TORCH_SLOT = 1
Inventory.TOOL_SLOTS = { 2, 3 }
Inventory.TORCH = "Flashlight"

local function isToolSlot(slot: number): boolean
	return table.find(Inventory.TOOL_SLOTS, slot) ~= nil
end
Inventory.isToolSlot = isToolSlot

function Inventory.new()
	return { slots = { { id = Inventory.TORCH }, false, false }, active = 1 }
end

function Inventory.held(inv)
	return inv.slots[inv.active] or nil
end

-- The id in your hands: the torch, a tool, or nil for an empty slot (a free hand).
function Inventory.heldId(inv): string?
	local item = inv.slots[inv.active]
	return item and item.id or nil
end

-- The tool in your hands, or nil with the torch or an empty slot.
function Inventory.toolId(inv): string?
	return isToolSlot(inv.active) and Inventory.heldId(inv) or nil
end

-- Is the torch the thing in your hands (its full beam)?
function Inventory.torchHeld(inv): boolean
	return inv.active == Inventory.TORCH_SLOT
end

-- Anything else in your hands clips the torch to your shirt.
function Inventory.torchClipped(inv): boolean
	return inv.active ~= Inventory.TORCH_SLOT
end

-- Put `slot` in your hands. Empty tool slots can be chosen too (nothing in
-- that hand), but only 1 to 3 are valid. Returns whether anything changed.
function Inventory.select(inv, slot: number): boolean
	if slot ~= math.floor(slot) or slot < 1 or slot > Inventory.SLOTS or slot == inv.active then
		return false
	end
	inv.active = slot
	return true
end

-- The next slot, `direction` +1 or -1, wrapping. A tool slot counts whether
-- it holds something or not: an empty one is a free hand (the torch on your
-- shirt), as the old fourth slot was, so the wheel always has somewhere to go.
function Inventory.cycle(inv, direction: number): boolean
	inv.active = (inv.active - 1 + direction) % Inventory.SLOTS + 1
	return true
end

-- Take `item` into the first empty tool slot. With both full, it swaps with the
-- tool in your hands (which is returned so the caller can drop it); with the
-- torch in your hands and both full, it is refused. Returns ok,
-- the slot it went to, and the item that was swapped out.
function Inventory.pickup(inv, item)
	for _, slot in Inventory.TOOL_SLOTS do
		if not inv.slots[slot] then
			inv.slots[slot] = item
			return true, slot, nil
		end
	end
	if isToolSlot(inv.active) and inv.slots[inv.active] then
		local old = inv.slots[inv.active]
		inv.slots[inv.active] = item
		return true, inv.active, old
	end
	return false, nil, nil
end

-- Empty a tool slot and return what was in it. The torch can't be dropped. If
-- it was in your hands, you go back to the torch.
function Inventory.drop(inv, slot: number)
	if not isToolSlot(slot) then
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

-- Every tool, for a player who goes down. Back to the torch.
function Inventory.dropAll(inv)
	local items = {}
	for _, slot in Inventory.TOOL_SLOTS do
		local item = Inventory.drop(inv, slot)
		if item then
			table.insert(items, item)
		end
	end
	inv.active = Inventory.TORCH_SLOT
	return items
end

-- The slot ids for display, "" for empty.
function Inventory.ids(inv): { string }
	local out = {}
	for slot = 1, Inventory.SLOTS do
		out[slot] = inv.slots[slot] and inv.slots[slot].id or ""
	end
	return out
end

return Inventory
