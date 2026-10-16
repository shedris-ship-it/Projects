-- The lobby's things to read (Data/Lore, Services/LoreService): each on a
-- piece that's there, short enough for its sheet, about a map that exists.
return function(test, check, Shared, require)
	local Lore = require(Shared.Data.Lore)
	local Mall = require(Shared.Data.Mall)
	local Locations = require(Shared.Data.Locations)

	local function block(on)
		local n = 0
		for _, b in Mall.Blocks do
			if b.room == on.room and b.name == on.name then
				n += 1
				if n == (on.n or 1) then
					return b
				end
			end
		end
		return nil
	end

	-- Where an entry's prompt is (its block's middle and its offset, turned
	-- about Y as the block is; the mall's blocks only turn about Y).
	local function at(entry)
		local b = block(entry.on)
		local o = entry.offset or { 0, 0, 0 }
		local a = math.rad((b.rot or { 0, 0, 0 })[2])
		local x = o[1] * math.cos(a) + o[3] * math.sin(a)
		local z = -o[1] * math.sin(a) + o[3] * math.cos(a)
		return { b.x + x, b.y + o[2], b.z + z }
	end

	test("each sits on a piece in the mall, about a map that exists", function()
		local seen = {}
		for _, entry in Lore do
			check.truthy(type(entry.id) == "string" and not seen[entry.id], tostring(entry.id) .. " is a new id")
			seen[entry.id] = true
			check.truthy(block(entry.on) ~= nil, entry.id .. " is on a block that's there")
			check.truthy(entry.style == "hand" or entry.style == "typed", entry.id .. " is handwritten or typed")
			check.truthy(entry.location == nil or Locations.ById[entry.location] ~= nil, entry.id .. "'s map exists")
			check.truthy(type(entry.text) == "string" and #entry.text > 0, entry.id .. " has something to read")
		end
	end)

	test("each fits its sheet", function()
		for _, entry in Lore do
			if entry.style == "hand" then
				check.atMost(#entry.text, 320, entry.id .. ": a handwritten note is short")
			else
				check.atMost(#entry.text, 1000, entry.id .. ": a typed page")
			end
		end
	end)

	test("no two prompts on top of each other", function()
		for i, a in Lore do
			for j = i + 1, #Lore do
				local b = Lore[j]
				local pa, pb = at(a), at(b)
				local d = math.sqrt((pa[1] - pb[1]) ^ 2 + (pa[2] - pb[2]) ^ 2 + (pa[3] - pb[3]) ^ 2)
				check.atLeast(d, 1.5, a.id .. " and " .. b.id .. " apart")
			end
		end
	end)
end
