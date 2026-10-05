-- The marks on keys and locks (docs/plans/level-design.md section 11, L3.0):
-- every door that takes something found (a key, a code, power) carries one
-- mark on its plate, on both faces, and whatever opens it carries the same
-- mark: "the phone key" fits the door with a phone. A key is never named
-- after the room behind its door (nobody has seen that room yet), and
-- describing a mark is a reason to talk ("mine has scissors on it").
--
-- Things a 1988 family house is full of, easy to say aloud and to tell
-- apart by torchlight. Each glyph is a plain text symbol that Roblox draws
-- in one colour (checked in Studio, 2026-10-05: the moon, the chess pieces
-- and the anchor came out as empty boxes or coloured emoji). L3.1 gives them
-- owners (the family's charms).

local Marks = {
	{ id = "star", name = "star", glyph = "★" },
	{ id = "sun", name = "sun", glyph = "☀" },
	{ id = "flower", name = "flower", glyph = "✿" },
	{ id = "note", name = "note", glyph = "♪" },
	{ id = "umbrella", name = "umbrella", glyph = "☂", article = "an" },
	{ id = "phone", name = "phone", glyph = "☎" },
	{ id = "scissors", name = "scissors", glyph = "✂", article = "" },
	{ id = "heart", name = "heart", glyph = "♥" },
	{ id = "cloud", name = "cloud", glyph = "☁" },
}

local byId = {}
local ids = {}
for _, mark in Marks do
	byId[mark.id] = mark
	table.insert(ids, mark.id)
end

-- The mark's glyph ("★"), or "" for no mark.
local function glyph(id: string?): string
	local mark = id and byId[id]
	return mark and mark.glyph or ""
end

-- A mark said in a sentence: "a star", "an umbrella", "scissors".
local function said(name: string): string
	for _, mark in Marks do
		if mark.name == name then
			local article = mark.article or "a"
			return article == "" and name or (article .. " " .. name)
		end
	end
	return "a " .. name
end

return {
	List = Marks,
	ById = byId,
	Ids = ids,
	glyph = glyph,
	said = said,
}
