-- Loads Roblox-style ModuleScripts from disk under Lune.
--
-- Shared logic modules use `require(script.Parent.X)` exactly as they do in
-- Roblox. This harness gives each module a fake `script` whose Parent and
-- children map onto the folder layout Rojo produces, so the same files run
-- unchanged in Studio and in `lune run tests/run`.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local Harness = {}

local cache: { [string]: any } = {}
local Node = {}

-- Lune's filesystem calls yield, and metamethods can't yield, so the whole
-- folder tree (and every source file) is read up front.
local function scan(path: string, name: string, parent: any?)
	local node = setmetatable({}, Node)
	rawset(node, "__path", path)
	rawset(node, "__name", name)
	rawset(node, "__parent", parent)
	rawset(node, "__children", {})
	if fs.isFile(path) then
		rawset(node, "__isModule", true)
		rawset(node, "__source", fs.readFile(path))
		-- A module's children live in a sibling folder of the same name.
		local folder = string.gsub(path, "%.luau?$", "")
		if fs.isDir(folder) then
			for _, entry in fs.readDir(folder) do
				local childName = string.gsub(entry, "%.luau?$", "")
				node.__children[childName] = scan(folder .. "/" .. entry, childName, node)
			end
		end
	else
		rawset(node, "__isModule", false)
		for _, entry in fs.readDir(path) do
			local full = path .. "/" .. entry
			if fs.isDir(full) or string.match(entry, "%.luau?$") then
				local childName = string.gsub(entry, "%.luau?$", "")
				if not node.__children[childName] then
					node.__children[childName] = scan(full, childName, node)
				end
			end
		end
	end
	return node
end

function Node.__index(self, key)
	if key == "Name" then
		return rawget(self, "__name")
	elseif key == "Parent" then
		return rawget(self, "__parent")
	elseif key == "WaitForChild" or key == "FindFirstChild" then
		return function(node, name)
			return rawget(node, "__children")[name]
		end
	end
	return rawget(self, "__children")[key]
end

Node.__tostring = function(self)
	return "Node(" .. rawget(self, "__path") .. ")"
end

local requireModule

local function makeEnv(scriptNode)
	return {
		script = scriptNode,
		require = requireModule,
		task = task,
	}
end

requireModule = function(target)
	if type(target) == "string" then
		return require(target)
	end
	assert(getmetatable(target) == Node, "require expects a module node")
	local path = rawget(target, "__path")
	if cache[path] ~= nil then
		return cache[path]
	end
	assert(rawget(target, "__isModule"), "not a module: " .. path)
	local chunk = luau.load(rawget(target, "__source"), {
		debugName = path,
		environment = makeEnv(target),
		injectGlobals = true,
	})
	local result = chunk()
	cache[path] = result
	return result
end

-- Root node for a folder on disk, named like the Rojo instance it becomes.
function Harness.root(path: string, name: string)
	return scan(path, name, nil)
end

Harness.require = requireModule

return Harness
