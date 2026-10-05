-- Every kind of puzzle keeps the registry's contract (Logic/PuzzleKinds):
-- the same seed makes the same puzzle, its screen never carries the answer,
-- a click that isn't one is refused, and doing it right solves it.
return function(test, check, Shared, require)
	local Rng = require(Shared.Lib.Rng)
	local Kinds = require(Shared.Logic.PuzzleKinds)

	local FUNCTIONS = { "generate", "view", "start", "step", "solved", "public", "parse", "solve" }

	-- A plain-text picture of a table, keys sorted, for comparing two specs.
	local function dump(value, depth: number?): string
		depth = depth or 0
		if type(value) ~= "table" or depth > 6 then
			return tostring(value)
		end
		local keys = {}
		for key in value do
			table.insert(keys, key)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		local parts = {}
		for _, key in keys do
			table.insert(parts, tostring(key) .. "=" .. dump(value[key], depth + 1))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end

	test("every kind has the whole contract", function()
		for kind, module in Kinds do
			for _, name in FUNCTIONS do
				check.truthy(type(module[name]) == "function", kind .. "." .. name)
			end
		end
	end)

	test("the same seed makes the same puzzle", function()
		for kind, module in Kinds do
			for seed = 1, 10 do
				local a = module.generate(Rng.new(seed), {})
				local b = module.generate(Rng.new(seed), {})
				check.equal(dump(a), dump(b), kind .. " seed " .. seed)
			end
		end
	end)

	test("what the screen gets never holds the answer", function()
		for kind, module in Kinds do
			for seed = 1, 10 do
				local spec = module.generate(Rng.new(seed), {})
				local state = module.start(spec)
				check.equal(module.view(spec).answer, nil, kind .. ": the view")
				check.equal(module.public(state, 0).answer, nil, kind .. ": the state")
				check.truthy(not module.solved(state), kind .. " starts unsolved")
			end
		end
	end)

	test("a click that isn't one is refused; doing it right solves it", function()
		for kind, module in Kinds do
			for seed = 1, 10 do
				local spec = module.generate(Rng.new(seed), {})
				local state = module.start(spec)
				check.equal(module.parse("nonsense", nil, nil, nil, 0), nil, kind .. ": junk")
				module.solve(spec, state, 0)
				check.truthy(module.solved(state), kind .. " seed " .. seed .. " solves")
			end
		end
	end)
end
