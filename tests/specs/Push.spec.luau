-- Pushing furniture (Logic/Push): how fast a piece moves for how many push
-- it, by weight (docs/plans/gameplay-rework.md section 4.6).
return function(test, check, Shared, require)
	local Push = require(Shared.Logic.Push)
	local Physical = require(Shared.Data.Physical)
	local Config = require(Shared.Config)
	local cfg = Config.Push

	local function weight(kind: string): number
		return Physical.Furniture[kind].weight
	end

	test("one player creeps a bed; two move it at full speed", function()
		local alone, creeping = Push.speed(1, weight("Bed"), cfg)
		check.equal(alone, cfg.CreepSpeed, "one: a creep")
		check.truthy(creeping, "and it scrapes")
		local two, strained = Push.speed(2, weight("Bed"), cfg)
		check.near(two, cfg.MaxSpeed, 1e-9, "two: full speed")
		check.truthy(not strained, "moving properly")
	end)

	test("a dresser moves for one, slowly", function()
		local speed, creeping = Push.speed(1, weight("Dresser"), cfg)
		check.truthy(not creeping, "it moves")
		check.truthy(speed > cfg.CreepSpeed * 2 and speed < cfg.MaxSpeed * 0.7, "but slowly: " .. speed)
	end)

	test("the piano wants three", function()
		local _, two = Push.speed(2, weight("Piano"), cfg)
		check.truthy(two, "two only creep it")
		local _, three = Push.speed(3, weight("Piano"), cfg)
		check.truthy(not three, "three move it")
	end)

	test("speed rises with strength and never passes the cap", function()
		local last = 0
		for strength = 1, 6 do
			local speed = Push.speed(strength, weight("Wardrobe"), cfg)
			check.truthy(speed >= last, "never slower with more help")
			check.truthy(speed <= cfg.MaxSpeed + 1e-9, "never over the cap")
			last = speed
		end
		check.equal(Push.speed(0, 1, cfg), 0, "nobody pushing")
	end)

	test("every piece of furniture is carried, pushed, or left fixed on purpose", function()
		local Props = require(Shared.Data.Props)
		local fixed = {
			Counter = true,
			Sink = true,
			Toilet = true,
			Bathtub = true,
			Stove = true,
			WaterHeater = true,
			Car = true,
			Curtain = true,
			Rug = true,
			Shrine = true,
		}
		for kind in Props.Kinds do
			local info = Physical.Furniture[kind]
			if fixed[kind] then
				check.equal(info, nil, kind .. " is fixed")
			else
				check.truthy(info ~= nil, kind .. " has a weight or a class")
				check.truthy(
					(info.class ~= nil and Physical.Classes[info.class] ~= nil) or (info.weight or 0) > 0,
					kind .. " is carried or pushed"
				)
			end
		end
	end)

	test("pushes together add up; pushes against each other cancel", function()
		local d = Push.direction({ { x = 1, z = 0 }, { x = 1, z = 0.2 } })
		check.truthy(d ~= nil and d.x > 0.98, "two the same way")
		check.equal(Push.direction({ { x = 1, z = 0 }, { x = -1, z = 0 } }), nil, "head to head")
		check.equal(Push.direction({}), nil, "nobody")
		local one = Push.direction({ { x = 0, z = -3 } })
		check.near(one.z, -1, 1e-9, "one push, made unit")
	end)

	test("heavier pieces scrape louder, and straining is loudest", function()
		check.truthy(Push.noise(2, false, 7) > Push.noise(1, false, 7), "heavier")
		check.truthy(Push.noise(2, true, 7) > Push.noise(2, false, 7), "creeping")
	end)
end
