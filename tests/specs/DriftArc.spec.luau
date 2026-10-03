return function(test, check, Shared, require)
	local Config = require(Shared.Config)

	local function startOf(name)
		for _, state in Config.Drift.States do
			if state.name == name then
				return state.min
			end
		end
		error("no Drift state " .. name)
	end

	test("the Drift arc follows the doc: fluorescents at Fraying, everything at Breaking, sag at Collapsing", function()
		local arc = Config.DriftArc
		check.equal(arc.UtilityFlickerAt, startOf("Fraying"), "utility lights flicker first")
		check.equal(arc.AllFlickerAt, startOf("Breaking"), "then everything")
		check.equal(arc.LampDimAt, startOf("Collapsing"), "lamps sag at Collapsing")
		check.equal(arc.MonochromeAt, startOf("Collapsing"), "the colour drains at Collapsing")
		check.truthy(arc.LampDimTo > 0 and arc.LampDimTo < 1, "lamps sag but don't go out")
		check.truthy(arc.CollapseSaturation <= -0.8, "nearly monochrome")
	end)

	test("blood appears only from Breaking onward", function()
		local G = Config.Grime
		check.truthy(G.BloodAt[1] >= startOf("Breaking"), "never before Breaking")
		check.truthy(G.BloodAt[2] <= 100 and G.BloodAt[2] >= G.BloodAt[1], "a sane range")
		check.truthy(G.BloodFade > 0 and G.BloodFade < 1, "a stain, not an opaque patch")
		check.truthy(G.BloodChance > 0 and G.BloodChance <= 1, "chance per room")
	end)

	test("shadow range has hysteresis so lights don't flicker at its edge", function()
		check.truthy(Config.ShadowRadius.off > Config.ShadowRadius.on, "off range is wider than on range")
	end)
end
