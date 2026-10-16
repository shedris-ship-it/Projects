-- The torch's looks (LB4; docs/plans/lobby-rework.md, "Electronics"): sold for
-- Marks at the electronics shop's counter (Services/ShopService), carried
-- into the run (Logic/Catalog). Looks only: every one keeps the beam, its
-- brightness and range, the switch's glow and the hand's grip exactly as
-- they are (World/ToolModel builds each round the same lens and switch);
-- nothing on one glows. The squad sees yours in your hand
-- (Controllers/HeldTorchController).
--
-- `mesh`: its kit model (Data/Kit Tools; tools/blender/kitlib/toolkit.py);
-- `paint`: the grey box's colours while that isn't in yet. Prices: the
-- owner's picks of 2026-10-16 ("I'll go with your suggestions for now").

return {
	Default = "Metal",
	Looks = {
		Metal = { name = "Metal torch", mesh = "ToolTorch", free = true },
		Rubber = {
			name = "Yellow rubber work torch",
			mesh = "ToolTorchRubber",
			price = 1000,
			paint = { body = { 248, 196, 26 }, head = { 30, 30, 32 } },
		},
		Brass = {
			name = "Brass torch",
			mesh = "ToolTorchBrass",
			price = 1500,
			paint = { body = { 196, 160, 84 }, head = { 196, 160, 84 } },
		},
		Chrome = {
			name = "Long chrome torch",
			mesh = "ToolTorchChrome",
			price = 2000,
			paint = { body = { 216, 216, 222 }, head = { 216, 216, 222 } },
		},
	},
	-- The counter's order: the free one, then cheapest first.
	Order = { "Metal", "Rubber", "Brass", "Chrome" },
}
