-- His keys (Logic/GuestKeys): which locks they open, when he may pass, the
-- tell before the door opens, and when he's through.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local GuestKeys = require(Shared.Logic.GuestKeys)
	local ToolLocks = require(Shared.Logic.ToolLocks)
	local G = Config.Guest

	test("his keys open keys, codes and hidden latches; never boards, chains, cranks, power or a seal", function()
		for _, kind in { "key", "pocket", "double", "padlock", "hidden" } do
			check.truthy(GuestKeys.opens({ kind = kind }, G), kind .. " opens")
		end
		for _, kind in { "boards", "chain", "crank", "power", "seal", "bolt" } do
			check.equal(GuestKeys.opens({ kind = kind }, G), false, kind .. " never")
		end
		for kind in ToolLocks.Kinds do
			check.equal(GuestKeys.opens({ kind = kind }, G), false, "tool lock " .. kind)
		end
		check.equal(GuestKeys.opens({ kind = "key", vault = true }, G), false, "not the safe room's steel")
		local off = table.clone(G)
		off.Keys = false
		check.equal(GuestKeys.opens({ kind = "key" }, off), false, "switched off: no keys")
	end)

	test("he only passes with nobody near and nobody watching the door", function()
		check.truthy(GuestKeys.mayPass({ nearest = G.KeyPassClear + 5, seen = false }, G), "alone")
		local ok, why = GuestKeys.mayPass({ nearest = G.KeyPassClear - 1, seen = false }, G)
		check.equal(ok, false, "someone near")
		check.equal(why, "someone near", "says why")
		check.equal(GuestKeys.mayPass({ nearest = math.huge, seen = true }, G), false, "watched")
	end)

	test("the keys are heard first: at least a second and a half, shorter in a hunt", function()
		check.atLeast(GuestKeys.tellSeconds(false, G), 1.5, "between hunts")
		check.atLeast(GuestKeys.tellSeconds(true, G), 1.5, "in a hunt")
		check.truthy(GuestKeys.tellSeconds(true, G) <= GuestKeys.tellSeconds(false, G), "a hunt is quicker")
		local tiny = table.clone(G)
		tiny.KeyPassSecondsHunt = 0.2
		check.equal(GuestKeys.tellSeconds(true, tiny), 1.5, "never under 1.5 s")
	end)

	test("through: on the other side, clear of the doorway", function()
		check.truthy(GuestKeys.through(-2, 3), "crossed")
		check.equal(GuestKeys.through(-2, 1), false, "in the doorway")
		check.equal(GuestKeys.through(-2, -4), false, "went back")
		check.truthy(GuestKeys.through(0, 3), "from the line itself")
	end)
end
