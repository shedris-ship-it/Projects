-- The kit (Data/Kit, World/Kit): every entry dresses a real kind, and each
-- mesh was modelled at the size of the thing it dresses, so fitting it
-- never stretches it out of shape.
return function(test, check, Shared, require)
	local Kit = require(Shared.Data.Kit)
	local Props = require(Shared.Data.Props)
	local Config = require(Shared.Config)

	-- How far a modelled piece may differ from the grey-box it dresses, as a
	-- share of each side (a raised panel or a cushion's curve stands proud).
	local TOLERANCE = 0.08

	test("every prop entry names a real kind and fits its size", function()
		for kind, entry in Kit.Props do
			local prop = Props.Kinds[kind]
			check.truthy(prop, kind .. " is a prop kind")
			check.equal(type(entry.mesh), "string", kind .. " names its mesh")
			check.equal(#entry.size, 3, kind .. " gives its modelled size")
			-- Never bigger than the grey-box (it would poke through walls and
			-- other things); smaller is fine (a coat rack is narrower than its
			-- footprint), but not so small that the grey-box's body shows round it.
			for axis = 1, 3 do
				local want = prop.size[axis]
				local got = entry.size[axis]
				check.atMost(
					(got - want) / want,
					TOLERANCE,
					string.format("%s axis %d: modelled %.2f, prop %.2f", kind, axis, got, want)
				)
				check.atLeast(
					got / want,
					0.5,
					string.format("%s axis %d: modelled %.2f of %.2f", kind, axis, got, want)
				)
			end
		end
	end)

	test("an imported piece gives its mesh's asset id", function()
		for _, group in { Kit.Props, Kit.Slabs } do
			for name, entry in group do
				if entry.id ~= nil then
					check.equal(type(entry.id), "number", name .. "'s id is a number")
					check.truthy(entry.id > 0 and entry.id == math.floor(entry.id), name .. "'s id is an asset id")
				end
			end
		end
		check.truthy(Kit.Props.Chair.id, "the spike's chair is imported")
	end)

	test("the door slab's mesh fits the slab", function()
		local door = Kit.Slabs.Door
		check.truthy(door, "a door entry")
		local width = Config.Level.DoorWidth - 0.2 -- World/LevelBuilder's slab
		local height = Config.Level.DoorHeight - 0.2
		check.atMost(math.abs(door.size[1] - width) / width, TOLERANCE, "slab width")
		check.atMost(math.abs(door.size[2] - height) / height, TOLERANCE, "slab height")
		check.atMost(door.size[3], 0.6, "no thicker than a door")
	end)
end
