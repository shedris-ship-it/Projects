-- The exit door's house side: the EXIT sign must stay clear of the panels, knob
-- plate and kick plate (owner, 2026-10-04: the letters were drawn across the
-- knob). All numbers are Config.Exit fractions of the slab, as the door looks
-- from inside the house, y counted down from the top.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)

	local E = Config.Exit
	local W, H = Config.Level.DoorWidth, Config.Level.DoorHeight

	-- A rectangle as { left, top, right, bottom } in slab fractions, from a centre
	-- offset (a fraction from the slab's middle, y negative is down) and a size in
	-- slab fractions.
	local function rect(offsetX: number, offsetY: number, sizeX: number, sizeY: number)
		local cx, cy = 0.5 + offsetX, 0.5 - offsetY
		return { cx - sizeX / 2, cy - sizeY / 2, cx + sizeX / 2, cy + sizeY / 2 }
	end

	local sign = { E.Sign.x, E.Sign.y, E.Sign.x + E.Sign.w, E.Sign.y + E.Sign.h }

	local function overlapsInY(a, b)
		return a[2] < b[4] and b[2] < a[4]
	end

	test("the sign sits inside the door, in the top band", function()
		check.truthy(sign[1] >= 0 and sign[3] <= 1, "inside the door's width")
		check.truthy(sign[2] >= 0 and sign[4] <= 0.35, "in the top third")
		check.truthy(E.Sign.h * H >= 1.2, "tall enough to read from across a room")
	end)

	test("the sign clears both lower panels", function()
		for _, side in { -1, 1 } do
			local panel = rect(side * E.PanelOffset[1], E.PanelOffset[2], E.PanelSize[1], E.PanelSize[2])
			check.truthy(not overlapsInY(sign, panel), "the sign runs into a panel")
		end
	end)

	test("the sign clears the knob plate, with room to spare", function()
		-- The knob plate is in studs; convert to slab fractions.
		local knob = rect(E.KnobOffset[1], E.KnobOffset[2], E.KnobPlate[1] / W, E.KnobPlate[2] / H)
		check.truthy(not overlapsInY(sign, knob), "the sign runs into the knob")
		check.truthy(knob[2] - sign[4] >= 0.1, "less than a tenth of the door between sign and knob")
	end)

	test("the sign clears the kick plate", function()
		local kickTop = 1 - (0.6 + E.KickPlateHeight) / H
		check.truthy(sign[4] < kickTop, "the sign runs into the kick plate")
	end)

	test("the panels and knob stay on the door", function()
		for _, side in { -1, 1 } do
			local panel = rect(side * E.PanelOffset[1], E.PanelOffset[2], E.PanelSize[1], E.PanelSize[2])
			check.truthy(panel[1] >= 0 and panel[3] <= 1 and panel[2] >= 0 and panel[4] <= 1, "a panel leaves the door")
		end
		local knob = rect(E.KnobOffset[1], E.KnobOffset[2], E.KnobPlate[1] / W, E.KnobPlate[2] / H)
		check.truthy(knob[1] >= 0 and knob[3] <= 1, "the knob plate is on the door")
	end)
end
