-- The build id is what tells the owner which code Studio is running.
return function(test, check, Shared, require)
	local Build = require(Shared.Build)

	test("the build id is a date and a counter", function()
		check.truthy(type(Build.id) == "string", "id is text")
		check.truthy(
			string.match(Build.id, "^%d%d%d%d%-%d%d%-%d%d%.%d+$") ~= nil,
			"id looks like 2026-10-04.2: " .. tostring(Build.id)
		)
	end)

	test("the build says what is new", function()
		check.truthy(type(Build.note) == "string" and #Build.note > 8, "note is a few words")
	end)
end
