-- The family's valuables ("reasons to play again", the owner's choice of
-- 2026-10-11: push your luck). Optional: worth Config.Valuables.Marks for
-- everyone in the squad, each, but only once carried out of the front door.
-- Carried in your hands like an heirloom, so he knows your room while you
-- hold one (Logic/Scent) and puts back one left lying. Nothing here looks
-- like an heirloom (World/Items: candlestick, watch, locket, doll, cup).
--
--   id     the builder in World/Items (Items.valuable)
--   label  what it's called on its prompt, in tips and the Dossier
--   size   its footprint on a top, { across, deep } (ItemService:TopSpot)

return {
	{ id = "CarriageClock", label = "carriage clock", size = { 1.2, 0.9 } },
	{ id = "JewelleryBox", label = "jewellery box", size = { 1.4, 1 } },
	{ id = "SilverTeapot", label = "silver teapot", size = { 1.3, 1 } },
	{ id = "CashBox", label = "cash box", size = { 1.4, 1 } },
}
