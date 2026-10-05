-- A player's four slots (owner, 2026-10-04; docs/plans/gameplay-rework.md
-- section 4.1): slot 1 is the flashlight, always; slots 2 and 3 hold tools and
-- bulky things found around the house; slot 4 is your bare hands, for grabbing,
-- dragging, carrying and throwing. Only one slot is in your hands at a time.
-- Anything but the torch clips it to your shirt (a weak light where your body
-- faces), so the light can stay on whatever you hold. Pure, so the rules are
-- tests (tests/specs/Inventory.spec.luau). An item is { id = "Radio", uid =
-- "tool:3" }: `uid` names the one object in the world. The thing you're
-- carrying in your hands is the hands' own business (HandsService), not an
-- item here.
--
-- Empty slots are `false` (a Luau array can't hold nil).

local Inventory = {}

Inventory.SLOTS = 4
Inventory.TORCH_SLOT = 1
Inventory.HANDS_SLOT = 4
Inventory.TOOL_SLOTS = { 2, 3 }
Inventory.TORCH = "Flashlight"
Inventory.HANDS = "Hands"

local function isToolSlot(slot: number): boolean
	return table.find(Inventory.TOOL_SLOTS, slot) ~= nil
end
Inventory.isToolSlot = isToolSlot

function Inventory.new()
	return { slots = { { id = Inventory.TORCH }, false, false, { id = Inventory.HANDS } }, active = 1 }
end

function Inventory.held(inv)
	return inv.slots[inv.active] or nil
end

-- The id in your hands: the torch, a tool, "Hands", or nil for an empty slot.
function Inventory.heldId(inv): string?
	local item = inv.slots[inv.active]
	return item and item.id or nil
end

-- The tool in your hands, or nil with the torch, bare hands or an empty slot.
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

-- Bare hands: free to grab, drag and push.
function Inventory.handsFree(inv): boolean
	return inv.active == Inventory.HANDS_SLOT
end

-- Put `slot` in your hands. Empty tool slots can be chosen too (nothing in
-- that hand), but only 1 to 4 are valid. Returns whether anything changed.
function Inventory.select(inv, slot: number): boolean
	if slot ~= math.floor(slot) or slot < 1 or slot > Inventory.SLOTS or slot == inv.active then
		return false
	end
	inv.active = slot
	return true
end

-- The next slot with something in it, `direction` +1 or -1, wrapping. Empty
-- slots are skipped so the wheel never lands on nothing; the torch and your
-- hands always count, so there is always somewhere to go.
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
-- torch or bare hands in your hands and both full, it is refused. Returns ok,
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

-- Empty a tool slot and return what was in it. The torch and your hands can't
-- be dropped. If it was in your hands, you go back to the torch.
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

-- The four slot ids for display, "" for empty.
function Inventory.ids(inv): { string }
	local out = {}
	for slot = 1, Inventory.SLOTS do
		out[slot] = inv.slots[slot] and inv.slots[slot].id or ""
	end
	return out
end

return Inventory
