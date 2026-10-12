-- Where a mansion room's windows go (Logic/Windows): only on outer walls,
-- clear of doorways, other wall items and furniture against the wall; a
-- template's window on an inner wall moves out; long outer walls get more.
return function(test, check, Shared, require)
	local Windows = require(Shared.Logic.Windows)
	local RoomFit = require(Shared.Logic.RoomFit)
	local Props = require(Shared.Data.Props)
	local Config = require(Shared.Config)
	local cfg = Config.Window.Openings
	local half = Props.WallDecor.Window.size[1] / 2

	-- A 30 x 20 room (inner half extents 14.5 x 9.5): the south and east walls
	-- face outside, north and west face other rooms.
	local inner = { x = 14.5, z = 9.5 }
	local function outerSE(side)
		return side == "S" or side == "E"
	end

	local function windowsOf(decor)
		local list = {}
		for _, item in decor do
			if item.kind == "Window" then
				table.insert(list, item)
			end
		end
		return list
	end

	local function checkClear(placed, doors, fit, outer)
		for i, w in placed do
			check.truthy(outer(w.side, w.along, half), w.id .. " is on an outer wall")
			for _, door in doors do
				if door.side == w.side then
					check.atLeast(
						math.abs(door.along - w.along),
						RoomFit.WallItemClear,
						w.id .. " clear of the doorway"
					)
				end
			end
			for j, other in placed do
				if j ~= i and other.side == w.side then
					check.atLeast(math.abs(other.along - w.along), 2 * half + RoomFit.WallItemGap, "windows apart")
				end
			end
			for _, slot in fit.wallSlots or {} do
				if slot.side == w.side then
					check.atLeast(math.abs(slot.along - w.along), half + RoomFit.SlotHalf, w.id .. " off the wall slot")
				end
			end
		end
	end

	test("a window on an inner wall moves to an outer one", function()
		local fit = {
			props = {},
			decor = { { id = "window", kind = "Window", side = "N", along = 4, y = 6 } },
			wallSlots = {},
		}
		local doors = { { side = "N", along = 0 } }
		local decor, placed = Windows.arrange(fit, inner, doors, outerSE, cfg, false)
		check.equal(#placed, 1, "the window is kept")
		check.truthy(placed[1].side == "S" or placed[1].side == "E", "on an outer wall")
		check.equal(#windowsOf(decor), 1, "and in the decor")
		check.equal(placed[1].id, "window", "keeping its id")
		checkClear(placed, doors, fit, outerSE)
	end)

	test("a window already on an outer wall stays put", function()
		local fit =
			{ props = {}, decor = { { id = "w", kind = "Window", side = "S", along = -6, y = 6 } }, wallSlots = {} }
		local _, placed = Windows.arrange(fit, inner, {}, outerSE, cfg, false)
		check.equal(placed[1].side, "S", "same wall")
		check.near(placed[1].along, -6, 1e-9, "same place")
	end)

	test("long outer walls get more, spaced, within the room's limit", function()
		local fit = { props = {}, decor = {}, wallSlots = { { id = "slot", side = "S", along = 5 } } }
		local doors = { { side = "E", along = 2 } }
		local _, placed = Windows.arrange(fit, inner, doors, outerSE, cfg, true)
		check.truthy(#placed >= 2, "a 30-stud outer wall gets windows")
		check.atMost(#placed, cfg.Max, "never more than Max")
		for i, a in placed do
			for j, b in placed do
				if i ~= j and a.side == b.side then
					check.atLeast(math.abs(a.along - b.along), cfg.Spacing, "spaced")
				end
			end
		end
		checkClear(placed, doors, fit, outerSE)
	end)

	test("no outer wall, no window; furniture against the wall keeps the glass clear", function()
		local fit = { props = {}, decor = { { id = "w", kind = "Window", side = "N", along = 0 } }, wallSlots = {} }
		local _, placed = Windows.arrange(fit, inner, {}, function()
			return false
		end, cfg, true)
		check.equal(#placed, 0, "an inner room has none")
		-- A wardrobe against the whole south wall: no window behind it.
		local ex = RoomFit.footprint("Wardrobe", 0)
		local props = {}
		for x = -inner.x + ex, inner.x - ex, 2 * ex do
			table.insert(props, { kind = "Wardrobe", x = x, z = inner.z - 1.5, ry = 0 })
		end
		local _, south = Windows.arrange({ props = props, decor = {}, wallSlots = {} }, inner, {}, function(side)
			return side == "S"
		end, cfg, true)
		check.equal(#south, 0, "nothing behind the wardrobes")
	end)
end
