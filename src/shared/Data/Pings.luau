-- Ping wheel and structured callouts (doc section 6: voice / non-voice parity).
-- Each ping has a colour AND a shape, so the colour-blind-safe setting can
-- lean on shapes alone.

local Pings = {
	Types = {
		{ id = "Look", label = "Look here", color = { 240, 240, 240 }, shape = "◎" },
		{ id = "Anchor", label = "Anchor this", color = { 120, 200, 255 }, shape = "◆" },
		{ id = "Danger", label = "Danger", color = { 255, 90, 80 }, shape = "▲" },
		{ id = "Wrong", label = "Wrong", color = { 255, 200, 60 }, shape = "✕" },
		{ id = "Clear", label = "Clear", color = { 120, 230, 140 }, shape = "●" },
		{ id = "Follow", label = "Follow me", color = { 200, 150, 255 }, shape = "➤" },
	},
	Callouts = {
		{ id = "Door", label = "door" },
		{ id = "Figure", label = "figure" },
		{ id = "Item", label = "item" },
		{ id = "Sound", label = "sound" },
		{ id = "Wall", label = "wall" },
		{ id = "Light", label = "light" },
	},
}

local typeById = {}
for _, ping in Pings.Types do
	typeById[ping.id] = ping
end
local calloutById = {}
for _, callout in Pings.Callouts do
	calloutById[callout.id] = callout
end
Pings.TypeById = typeById
Pings.CalloutById = calloutById

return Pings
