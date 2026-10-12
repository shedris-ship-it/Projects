-- The storm that builds (Logic/Storm): its stage follows Dread and never
-- goes back while Dread holds; strikes are near or far, with thunder after.
return function(test, check, Shared, require)
	local Storm = require(Shared.Logic.Storm)
	local Rng = require(Shared.Lib.Rng)
	local Config = require(Shared.Config)
	local cfg = Config.Storm

	test("still, then rain, then the storm as Dread rises", function()
		check.equal(Storm.stage(0, false, cfg), Storm.Still, "a calm house")
		check.equal(Storm.stage(cfg.RainAt, false, cfg), Storm.Rain, "rain at RainAt")
		check.equal(Storm.stage(cfg.ThunderAt, false, cfg), Storm.Thunder, "thunder at ThunderAt")
		check.equal(Storm.stage(0, true, cfg), Storm.Thunder, "the run out is always the storm")
		local last = Storm.Still
		for dread = 0, 100 do
			local stage = Storm.stage(dread, false, cfg)
			check.truthy(stage >= last, "never back down as Dread rises")
			last = stage
		end
	end)

	test("no strikes when it's still; far ones in the rain; both in the storm", function()
		local rng = Rng.new(7)
		check.equal(Storm.nextIn(rng, Storm.Still, cfg), nil, "no lightning on a still night")
		local gap = Storm.nextIn(rng, Storm.Thunder, cfg)
		check.truthy(gap >= cfg.Every[1] and gap <= cfg.Every[2], "storm gap in range")
		local nears, fars = 0, 0
		for _ = 1, 400 do
			local s = Storm.strike(rng, Storm.Rain, cfg)
			check.atMost(s.near, cfg.RainNear, "rain strikes stay far")
			check.equal(s.sound, "far", "a far rumble in the rain")
		end
		for _ = 1, 400 do
			local s = Storm.strike(rng, Storm.Thunder, cfg)
			if s.sound == "near" then
				nears += 1
			else
				fars += 1
			end
		end
		check.truthy(nears > 0 and fars > nears, "near cracks happen, far rumbles more often")
	end)

	test("each strike's flashes and thunder are in bounds", function()
		local rng = Rng.new(11)
		for _ = 1, 500 do
			local s = Storm.strike(rng, Storm.Thunder, cfg)
			check.truthy(#s.flashes >= 1 and #s.flashes <= 3, "one to three flashes")
			check.equal(s.flashes[1].at, 0, "the first at once")
			for i, f in s.flashes do
				check.truthy(f.strength > 0 and f.strength <= 1, "strength 0-1")
				check.truthy(f.seconds > 0 and f.seconds < 0.2, "a flash is brief")
				if i > 1 then
					check.truthy(f.at > s.flashes[i - 1].at, "flashes in order")
				end
			end
			check.truthy(
				s.thunder >= cfg.ThunderDelay[1] and s.thunder <= cfg.ThunderDelay[2],
				"thunder delay in range"
			)
			check.truthy(s.variant >= 1 and s.variant <= 3, "one of three sounds")
		end
		-- Nearer is louder and sooner.
		local a = Storm.strike(Rng.new(1), Storm.Thunder, cfg)
		local b = Storm.strike(Rng.new(2), Storm.Thunder, cfg)
		local near, far = a.near > b.near and a or b, a.near > b.near and b or a
		check.truthy(near.thunder <= far.thunder, "nearer thunder comes sooner")
		check.truthy(near.volume >= far.volume, "and louder")
	end)
end
