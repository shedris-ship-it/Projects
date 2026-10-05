-- Gate A for the mansion builder (docs/plans/mansion-generation.md, M2): proof
-- that the old house is built part for part the same after the builder is
-- rewritten. Not a Lune script: run it in Studio through the MCP
-- `execute_luau` tool on the **Server** datamodel, during a run started with
-- the F2 console (`seed 1800820264`, wait for its toast, then `start`).
--
-- It hashes every part under Workspace.ConsensusLevel (size, position,
-- rotation, collision, material), leaving out characters (the Companion
-- walks, so its limbs move). Baseline on build 2026-10-04.3, the same on two
-- fresh runs: parts 2151, hash 1550694282. Re-baselined with the owner's OK
-- when furniture gained drawers and doors (gameplay rework R1a.5, build
-- 2026-10-05.1, two fresh runs with `layout cells`): parts 2272, hash
-- 1308511249. Run it before opening anything: an opened drawer moves parts.

local level = workspace:FindFirstChild("ConsensusLevel")
if not level then
	return "no level yet"
end
local function r(v)
	return string.format("%.2f", math.floor(v * 100 + 0.5) / 100)
end
local function angle(a)
	return string.format("%.2f", (math.floor(a * 100 + 0.5) / 100) % 360)
end
local function inCharacter(d)
	local m = d:FindFirstAncestorOfClass("Model")
	while m do
		if m:FindFirstChildOfClass("Humanoid") then
			return true
		end
		m = m:FindFirstAncestorOfClass("Model")
	end
	return false
end
local lines = {}
for _, d in level:GetDescendants() do
	if d:IsA("BasePart") and not inCharacter(d) then
		local p, o, s = d.Position, d.Orientation, d.Size
		table.insert(
			lines,
			table.concat({
				d.ClassName,
				d.Name,
				r(s.X),
				r(s.Y),
				r(s.Z),
				r(p.X),
				r(p.Y),
				r(p.Z),
				angle(o.X),
				angle(o.Y),
				angle(o.Z),
				tostring(d.CanCollide),
				d.Material.Name,
			}, "|")
		)
	end
end
table.sort(lines)
local h = 5381
local M = 2147483647
for _, line in lines do
	for i = 1, #line do
		h = (h * 33 + string.byte(line, i)) % M
	end
	h = (h * 33 + 10) % M
end
return ("parts %d, hash %d"):format(#lines, h)
