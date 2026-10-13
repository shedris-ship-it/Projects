-- The kit (Data/Kit, World/Kit): every entry dresses a real kind, and each
-- mesh was modelled at the size of the thing it dresses, so fitting it
-- never stretches it out of shape.
return function(test, check, Shared, require)
	local Kit = require(Shared.Data.Kit)
	local Props = require(Shared.Data.Props)
	local Config = require(Shared.Config)
	local Valuables = require(Shared.Data.Valuables)
	local Landmarks = require(Shared.Data.Landmarks)

	-- How far a modelled piece may differ from the grey-box it dresses, as a
	-- share of each side (a raised panel or a cushion's curve stands proud).
	local TOLERANCE = 0.08

	test("every prop entry names a real kind and fits its size", function()
		for kind, entry in Kit.Props do
			local prop = Props.Kinds[kind]
			check.truthy(prop, kind .. " is a prop kind")
			if entry.each then
				-- (One mesh on each of its parts, fitted to that part.)
				check.equal(type(entry.each.mesh), "string", kind .. " names the mesh on each part")
				check.equal(type(entry.each.match), "string", kind .. " says which parts")
				continue
			end
			-- (Its `others` are the same kind's other things: each fits too.)
			for _, one in { entry, table.unpack(entry.others or {}) } do
				local name = kind .. ":" .. tostring(one.mesh)
				check.equal(type(one.mesh), "string", name .. " names its mesh")
				check.equal(#one.size, 3, name .. " gives its modelled size")
				if one ~= entry then
					check.truthy(one.names and #one.names > 0, name .. " says which items wear it")
				end
				-- Never bigger than the grey-box (it would poke through walls and
				-- other things); smaller is fine (a coat rack is narrower than its
				-- footprint), but not so small that the grey-box's body shows round
				-- it. (A piece that `rises` is held to the footprint only.)
				for axis = 1, 3 do
					local want = prop.size[axis]
					local got = one.size[axis]
					if not (one.rises and axis == 2) then
						check.atMost(
							(got - want) / want,
							TOLERANCE,
							string.format("%s axis %d: modelled %.2f, prop %.2f", name, axis, got, want)
						)
					end
					check.atLeast(
						got / want,
						0.5,
						string.format("%s axis %d: modelled %.2f of %.2f", name, axis, got, want)
					)
				end
			end
		end
	end)

	test("an imported piece gives its mesh's asset id", function()
		local function idOf(name, entry)
			if entry.id ~= nil then
				check.equal(type(entry.id), "number", name .. "'s id is a number")
				check.truthy(entry.id > 0 and entry.id == math.floor(entry.id), name .. "'s id is an asset id")
			end
		end
		for _, group in { Kit.Props, Kit.Slabs, Kit.Parts, Kit.Fixtures, Kit.Decor, Kit.Things, Kit.Landmarks } do
			for name, entry in group do
				idOf(name, entry)
				for _, piece in entry.pieces or {} do
					idOf(piece.mesh, piece)
				end
				if entry.each then
					idOf(entry.each.mesh, entry.each)
				end
				for _, variant in entry.variants or {} do
					idOf(variant.mesh, variant)
				end
				for _, other in entry.others or {} do
					idOf(other.mesh, other)
				end
			end
		end
		check.truthy(Kit.Props.Chair.id, "the spike's chair is imported")
	end)

	test("a prop's moving pieces say where they hang and what they stand for", function()
		for kind, entry in Kit.Props do
			for _, piece in entry.pieces or {} do
				check.equal(type(piece.match), "string", kind .. "'s piece names its model")
				check.equal(type(piece.mesh), "string", kind .. "'s piece names its mesh")
				check.equal(#piece.size, 3, piece.mesh .. " gives its modelled size")
				check.equal(#(piece.at or { 0, 0, 0 }), 3, piece.mesh .. "'s at is { x, y, z }")
				check.truthy(piece.hide and #piece.hide > 0, piece.mesh .. " hides the grey-box it stands for")
				-- Within the prop (a drawer's front no wider than the dresser).
				local prop = Props.Kinds[kind]
				check.atMost(piece.size[1], prop.size[1] * (1 + TOLERANCE), piece.mesh .. " fits across its prop")
			end
		end
	end)

	test("the trim's mouldings are modelled at the game's sections", function()
		local T = Config.Trim
		local want = {
			Baseboard = { T.BaseboardHeight, T.BaseboardDepth },
			Crown = { T.CrownHeight, T.CrownDepth },
			Casing = { T.CasingWidth, T.CasingDepth },
			DadoRail = { T.DadoHeight, T.DadoDepth },
		}
		for name, section in want do
			local entry = Kit.Parts[name]
			check.truthy(entry, name .. " has a moulding")
			-- (Stretched to each run's length; its section must already fit,
			-- or the stretch would squash it out of shape.)
			check.equal(entry.fit, true, name .. " fits its run")
			check.atMost(math.abs(entry.size[2] - section[1]), 0.005, name .. "'s height")
			check.atMost(math.abs(entry.size[3] - section[2]), 0.005, name .. "'s depth")
			check.equal(entry.turn, 180, name .. " faces the room (its part's -Z)")
		end
	end)

	test("wall decor entries dress real decor and fit it", function()
		for kind, entry in Kit.Decor do
			local decor = Props.WallDecor[kind]
			check.truthy(decor, kind .. " is a wall decor kind")
			check.truthy(entry.mesh or (entry.variants and #entry.variants > 0), kind .. " names a mesh")
			for _, variant in entry.variants or {} do
				check.equal(type(variant.mesh), "string", kind .. "'s variant names its mesh")
			end
			for axis = 1, 2 do
				local got, want = entry.size[axis], decor.size[axis]
				check.atMost(
					math.abs(got - want) / want,
					TOLERANCE,
					string.format("%s axis %d: modelled %.2f, decor %.2f", kind, axis, got, want)
				)
			end
			check.equal(#entry.at, 3, kind .. "'s at is { x, y, out }")
			check.truthy(entry.hide and #entry.hide > 0, kind .. " hides the grey-box it stands for")
		end
	end)

	test("a piece's centre is a small nudge within its prop", function()
		for name, entry in Kit.Props do
			if entry.centre then
				check.equal(#entry.centre, 2, name .. "'s centre is { x, z }")
				check.atMost(math.abs(entry.centre[1]), 0.5, name .. "'s centre x")
				check.atMost(math.abs(entry.centre[2]), 0.5, name .. "'s centre z")
			end
		end
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

	test("the things and stations name their meshes, and their pieces hide the game's", function()
		for name, entry in Kit.Things do
			check.equal(type(entry.mesh), "string", name .. " names its mesh")
			check.equal(#entry.size, 3, name .. " gives its modelled size")
			-- (Things and stations, never furniture: the radio on its table is
			-- the biggest.)
			for axis = 1, 3 do
				check.atMost(entry.size[axis], 5.5, string.format("%s axis %d: a thing, not furniture", name, axis))
			end
			for _, piece in entry.pieces or {} do
				check.equal(type(piece.match), "string", name .. "'s piece names its model")
				check.equal(#(piece.at or { 0, 0, 0 }), 3, piece.mesh .. "'s at is { x, y, z }")
				check.truthy(piece.hide and #piece.hide > 0, piece.mesh .. " hides the grey-box it stands for")
			end
			-- (The rest are small: 2.5 studs at most every way.)
			if name ~= "HomeComputer" and name ~= "FuseBox" and name ~= "Radio" and name ~= "BellBoard" then
				for axis = 1, 3 do
					check.atMost(entry.size[axis], 2.5, string.format("%s axis %d: small", name, axis))
				end
			end
		end
	end)

	test("every valuable has its look, within the room it takes on a top", function()
		for _, valuable in Valuables do
			local entry = Kit.Things[valuable.id]
			check.truthy(entry, valuable.id .. " has a kit entry")
			-- (Data/Valuables' size is its footprint, { x, z }: what it claims
			-- on a surface, World/Dressing.)
			check.atMost(entry.size[1], valuable.size[1] * (1 + TOLERANCE), valuable.id .. " fits its footprint across")
			check.atMost(entry.size[3], valuable.size[2] * (1 + TOLERANCE), valuable.id .. " fits its footprint deep")
		end
	end)

	test("a placed piece's offset and scaled fit are well formed", function()
		for name, entry in Kit.Parts do
			if entry.at then
				check.equal(#entry.at, 3, name .. "'s at is { x, y, z }")
			end
			if entry.fit ~= nil then
				check.truthy(entry.fit == true or entry.fit == "y" or entry.fit == "scale", name .. "'s fit is known")
			end
		end
	end)

	test("every corridor landmark has its look, hung from the wall", function()
		local ids = {}
		for _, landmark in Landmarks do
			ids[landmark.id] = true
			check.truthy(Kit.Landmarks[landmark.id], landmark.id .. " has a kit entry")
		end
		for id, entry in Kit.Landmarks do
			check.truthy(ids[id], id .. " is a landmark (Data/Landmarks)")
			check.equal(type(entry.mesh), "string", id .. " names its mesh")
			check.equal(#entry.size, 3, id .. " gives its modelled size")
			check.equal(#entry.centre, 2, id .. "'s centre is { x, out }")
			check.equal(type(entry.floor), "number", id .. " says where its box starts")
			-- (Out from the wall: its box's middle is in front of it.)
			check.truthy(entry.centre[2] > 0, id .. " stands out from the wall")
			check.atMost(entry.centre[2] - entry.size[3] / 2, 0.02, id .. "'s back is on the wall")
		end
		-- The founder's name is the game's, on its plate.
		check.truthy(table.find(Kit.Landmarks.portrait.keep or {}, "Plate"), "the portrait keeps its name plate")
	end)

	test("the moving fittings are modelled at the game's sizes", function()
		local function near(got, want, what)
			check.atMost(
				math.abs(got - want) / want,
				TOLERANCE,
				string.format("%s: modelled %.2f, the game's %.2f", what, got, want)
			)
		end
		local level = Config.Level
		-- A slat spans the shutter (the doorway and 0.6), the casing a storey.
		near(Kit.Parts.ShutterSlat.size[1], level.DoorWidth + 0.6, "a shutter slat's width")
		near(Kit.Parts.DumbwaiterCasing.size[2], level.WallHeight, "the dumbwaiter casing's height")
		near(Kit.Parts.DumbwaiterHatch.size[1], Config.Dumbwaiter.Width - 0.3, "the dumbwaiter hatch's width")
		near(Kit.Parts.ChuteHatch.size[1], Config.Mansion.Chute.Width + 0.3, "the chute hatch's width")
		-- (The hand wheel is scaled to each crank's wheel: Data/Kit `fit`.)
		check.equal(Kit.Parts.HandWheel.fit, "scale", "the hand wheel fits each crank")
	end)
end
