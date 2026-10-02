-- Test runner: `lune run tests/run` from the repository root.
-- Runs every tests/specs/*.spec.luau file. A spec returns a function that
-- receives (test, assert, Shared), where Shared is the src/shared folder as
-- the ReplicatedStorage.Shared instance tree would see it.

local fs = require("@lune/fs")
local process = require("@lune/process")
local luau = require("@lune/luau")

local Harness = require("./harness")

local Shared = Harness.root("src/shared", "Shared")

local check = {}

function check.truthy(value, message)
	if not value then
		error(message or "expected a truthy value", 2)
	end
end

function check.equal(actual, expected, message)
	if actual ~= expected then
		error(
			string.format("%s: expected %s, got %s", message or "values differ", tostring(expected), tostring(actual)),
			2
		)
	end
end

function check.near(actual, expected, tolerance, message)
	if math.abs(actual - expected) > tolerance then
		error(
			string.format(
				"%s: expected %s ± %s, got %s",
				message or "not near",
				tostring(expected),
				tostring(tolerance),
				tostring(actual)
			),
			2
		)
	end
end

function check.atMost(actual, limit, message)
	if actual > limit then
		error(string.format("%s: expected <= %s, got %s", message or "too large", tostring(limit), tostring(actual)), 2)
	end
end

function check.atLeast(actual, limit, message)
	if actual < limit then
		error(string.format("%s: expected >= %s, got %s", message or "too small", tostring(limit), tostring(actual)), 2)
	end
end

local filter = process.args[1]
local passed, failed = 0, 0
local failures = {}

local specFiles = {}
for _, name in fs.readDir("tests/specs") do
	if string.match(name, "%.spec%.luau$") and (filter == nil or string.find(name, filter, 1, true)) then
		table.insert(specFiles, name)
	end
end
table.sort(specFiles)

for _, name in specFiles do
	local path = "tests/specs/" .. name
	local chunk = luau.load(fs.readFile(path), { debugName = path, injectGlobals = true })
	local spec = chunk()
	print("● " .. name)
	local function test(description, fn)
		local ok, err = pcall(fn)
		if ok then
			passed += 1
			print("    ✓ " .. description)
		else
			failed += 1
			print("    ✗ " .. description)
			table.insert(failures, string.format("%s › %s\n      %s", name, description, tostring(err)))
		end
	end
	local ok, err = pcall(spec, test, check, Shared, Harness.require)
	if not ok then
		failed += 1
		table.insert(failures, string.format("%s failed to load\n      %s", name, tostring(err)))
	end
end

print(string.format("\n%d passed, %d failed", passed, failed))
for _, failure in failures do
	print("\n✗ " .. failure)
end
if failed > 0 then
	process.exit(1)
end
