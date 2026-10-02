-- Syntax check: compiles every .luau file under src/ with the Luau compiler.
-- Usage: lune run tests/compile

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local failures = 0
local count = 0

local function walk(path: string)
	for _, entry in fs.readDir(path) do
		local full = path .. "/" .. entry
		if fs.isDir(full) then
			walk(full)
		elseif string.match(entry, "%.luau$") then
			count += 1
			local ok, err = pcall(luau.compile, fs.readFile(full))
			if not ok then
				failures += 1
				print("✗ " .. full .. "\n    " .. tostring(err))
			end
		end
	end
end

walk("src")
print(string.format("%d files compiled, %d failed", count, failures))
if failures > 0 then
	process.exit(1)
end
