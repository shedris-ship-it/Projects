-- Graphics presets (Logic/GraphicsPreset): Auto picks by Roblox's quality or
-- the device; a chosen preset always wins; old settings carry over once.
return function(test, check, Shared, require)
	local GraphicsPreset = require(Shared.Logic.GraphicsPreset)
	local Config = require(Shared.Config)
	local cfg = Config.Graphics

	test("a chosen preset wins over the device", function()
		check.equal(GraphicsPreset.resolve(1, { touchOnly = true }, cfg), "Cinematic", "Cinematic on a phone")
		check.equal(GraphicsPreset.resolve(2, {}, cfg), "Balanced", "Balanced")
		check.equal(GraphicsPreset.resolve(3, { quality = 10 }, cfg), "Performance", "Performance on a fast PC")
	end)

	test("Auto follows Roblox's quality, else the device", function()
		check.equal(GraphicsPreset.resolve(0, { quality = 10 }, cfg), "Cinematic", "quality 10")
		check.equal(GraphicsPreset.resolve(0, { quality = cfg.AutoCinematicAt }, cfg), "Cinematic", "at the line")
		check.equal(GraphicsPreset.resolve(0, { quality = cfg.AutoBalancedAt }, cfg), "Balanced", "middling")
		check.equal(GraphicsPreset.resolve(0, { quality = 1 }, cfg), "Performance", "quality 1")
		check.equal(GraphicsPreset.resolve(0, { touchOnly = true }, cfg), "Performance", "a phone on Automatic")
		check.equal(GraphicsPreset.resolve(0, { console = true }, cfg), "Balanced", "a console on Automatic")
		check.equal(GraphicsPreset.resolve(nil, {}, cfg), "Cinematic", "a PC on Automatic")
	end)

	test("every preset names the same switches", function()
		local keys = {}
		for key in cfg.Presets.Cinematic do
			keys[key] = true
		end
		for _, name in GraphicsPreset.Order do
			local preset = cfg.Presets[name]
			check.truthy(preset, name .. " exists")
			for key in keys do
				check.equal(type(preset[key]), "boolean", name .. "." .. key)
			end
			for key in preset do
				check.truthy(keys[key], name .. " has no stray " .. key)
			end
		end
	end)

	test("the buttons cycle through every choice", function()
		local seen, setting = {}, 0
		for _ = 1, 4 do
			setting = GraphicsPreset.nextSetting(setting)
			seen[setting] = true
		end
		check.equal(setting, 0, "back to Auto after four presses")
		check.truthy(seen[1] and seen[2] and seen[3], "every preset on the way")
		check.equal(GraphicsPreset.nextGrain(2), 0, "Film, then off")
		check.equal(GraphicsPreset.nextGrain(0), 1, "off, then Fine")
		check.equal(GraphicsPreset.nextGrain(1), 2, "Fine, then Film")
	end)

	test("the old toggles carry over once", function()
		local changes = GraphicsPreset.migrate({ lowEnd = true, reduceGrain = true })
		check.equal(changes.graphics, 3, "low-end becomes Performance")
		check.equal(changes.grain, 0, "reduce grain becomes no grain")
		changes = GraphicsPreset.migrate({ lowEnd = true, graphics = 1, reduceGrain = true, grain = 2 })
		check.equal(changes.graphics, nil, "a chosen preset is kept")
		check.equal(changes.grain, nil, "a chosen grain is kept")
		changes = GraphicsPreset.migrate({ lowEnd = false })
		check.equal(next(changes), nil, "nothing to carry")
	end)
end
