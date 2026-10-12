-- A player's two slots for found tools and bulky things (owner, 2026-10-04;
-- docs/plans/gameplay-rework.md section 4.1, reworked in section 20). The
-- torch is not in them: since 2026-10-12 it has its own hand and its own key
-- (the owner, after playing IT WANTS IN: "you press F and you flip it up, press
-- F again and its gone, and the inventory was separate from the flashlight").
-- F raises it into your left hand and puts it away (Services/PlayerStateService);
-- the slots fill your right hand.
--
-- `active` is the slot in your right hand, or 0 for a free hand. Pressing a
-- slot's key again puts its tool away. There was a fourth slot, your bare
-- hands, that went with the squad playtest (2026-10-08): your hands work with
-- or without a tool out (Controllers/HandsController).
--
-- Pure, so the rules are tests (tests/specs/Inventory.spec.luau). An item is
-- { id = "Radio", uid = "tool:3" }: `uid` names the one object in the world.
-- The thing you're carrying in your hands is the hands' own business
-- (HandsService), not an item here.
--
-- Empty slots are `false` (a Luau array can't hold nil).

local Inventory = {}

Inventory.SLOTS = 2
Inventory.TOOL_SLOTS = { 1, 2 }
Inventory.FREE = 0 -- `active` with nothing in your right hand
-- The torch's id for the models that draw it (Lib/ViewModel, UI/Hotbar's
-- torch panel). It is never in a slot.
Inventory.TORCH = "Flashlight"

local function isToolSlot(slot: number): boolean
	return table.find(Inventory.TOOL_SLOTS, slot) ~= nil
end
Inventory.isToolSlot = isToolSlot

function Inventory.new()
	return { slots = { false, false }, active = Inventory.FREE }
end

function Inventory.held(inv)
	return inv.slots[inv.active] or nil
end

-- The id in your right hand, or nil for a free hand.
function Inventory.heldId(inv): string?
	local item = inv.slots[inv.active]
	return item and item.id or nil
end

-- The tool in your hands (the same as heldId: the slots hold only tools).
Inventory.toolId = Inventory.heldId

-- Put `slot` in your hand, or 0 to put away what's there. Its own key again
-- puts it away, unless `exact` (the wheel says where it wants to be, not what
-- was pressed); an empty slot leaves the hand free. Returns whether anything
-- changed.
function Inventory.select(inv, slot: number, exact: boolean?): boolean
	if slot ~= math.floor(slot) or slot < 0 or slot > Inventory.SLOTS then
		return false
	end
	local wanted = slot
	if (slot == inv.active and not exact) or (slot ~= Inventory.FREE and not inv.slots[slot]) then
		wanted = Inventory.FREE
	end
	if wanted == inv.active then
		return false
	end
	inv.active = wanted
	return true
end

-- The next thing for your hand, `direction` +1 or -1, wrapping through a free
-- hand and every slot with something in it (an empty slot has nothing to hold).
function Inventory.cycle(inv, direction: number): boolean
	local order = { Inventory.FREE }
	for _, slot in Inventory.TOOL_SLOTS do
		if inv.slots[slot] then
			table.insert(order, slot)
		end
	end
	if #order == 1 then
		return Inventory.select(inv, Inventory.FREE)
	end
	local at = table.find(order, inv.active) or 1
	inv.active = order[(at - 1 + direction) % #order + 1]
	return true
end

-- Take `item` into the first empty slot. With both full, it swaps with the tool
-- in your hand (which is returned so the caller can drop it); with a free hand
-- and both full, it is refused. Returns ok, the slot it went to, and the item
-- that was swapped out.
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

-- Empty a slot and return what was in it. If it was in your hand, the hand is
-- free.
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
		inv.active = Inventory.FREE
	end
	return item
end

-- Every tool, for a player who goes down. A free hand.
function Inventory.dropAll(inv)
	local items = {}
	for _, slot in Inventory.TOOL_SLOTS do
		local item = Inventory.drop(inv, slot)
		if item then
			table.insert(items, item)
		end
	end
	inv.active = Inventory.FREE
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
