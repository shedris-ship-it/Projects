-- Period clothes for the squad (owner, 2026-10-03): everyone in a faded 1980s
-- shirt and jeans, no hats, no modern avatars. Each squad member gets a
-- different shirt so they read as one group but stay tellable apart.
-- Pure; Services/OutfitService paints it.

local Outfit = {}

local SHIRTS = {
	{ 196, 160, 84 }, -- mustard
	{ 70, 110, 112 }, -- teal
	{ 150, 70, 60 }, -- brick
	{ 110, 118, 72 }, -- olive
	{ 88, 110, 150 }, -- dusty blue
	{ 214, 200, 168 }, -- cream
	{ 110, 70, 96 }, -- plum
	{ 170, 120, 60 }, -- rust
}
local PANTS = {
	{ 62, 76, 104 }, -- denim
	{ 44, 52, 72 }, -- dark denim
	{ 150, 136, 104 }, -- khaki
	{ 100, 76, 56 }, -- corduroy
	{ 84, 84, 92 }, -- charcoal
}
local SKINS = {
	{ 234, 196, 160 },
	{ 214, 170, 130 },
	{ 176, 128, 92 },
	{ 138, 96, 66 },
	{ 104, 70, 50 },
	{ 244, 214, 184 },
}
local SHOES = { 38, 34, 32 }

Outfit.ShirtCount = #SHIRTS

-- index is 1 for the first player, 2 for the next.
-- Colours are { r, g, b } in 0..255.
function Outfit.palette(index: number)
	local i = math.max(math.floor(index), 1) - 1
	return {
		shirt = SHIRTS[i % #SHIRTS + 1],
		pants = PANTS[(i * 3) % #PANTS + 1],
		skin = SKINS[(i * 5) % #SKINS + 1],
		shoes = SHOES,
	}
end

return Outfit
