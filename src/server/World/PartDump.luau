-- Gate A (docs/plans/mansion-generation.md, M2): a hash of every part the
-- house builder made, so a change that should leave the old house alone can
-- prove it did. F2 `gatea` runs it; tools/studio/partdump.luau is the same
-- for Studio's command bar. Characters (the Companion walks) and run content
-- (WorldService's RunContent folder, and anything marked RunContent, like
-- lock plates riding on doors) are left out.

local PartDump = {}

local function r(v: number): string
	return string.format("%.2f", math.floor(v * 100 + 0.5) / 100)
end

local function angle(a: number): string
	return string.format("%.2f", (math.floor(a * 100 + 0.5) / 100) % 360)
end

local function inCharacter(d: Instance): boolean
	local m = d:FindFirstAncestorOfClass("Model")
	while m do
		if m:FindFirstChildOfClass("Humanoid") then
			return true
		end
		m = m:FindFirstAncestorOfClass("Model")
	end
	return false
end

local function runContent(level: Instance, d: Instance): boolean
	local node = d.Parent
	while node and node ~= level do
		if node.Name == "RunContent" or node:GetAttribute("RunContent") then
			return true
		end
		node = node.Parent
	end
	return false
end

-- Returns the part count and the hash of the level folder's builder parts.
function PartDump.hash(level: Instance): (number, number)
	local lines = {}
	for _, d in level:GetDescendants() do
		if d:IsA("BasePart") and not inCharacter(d) and not runContent(level, d) then
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
	return #lines, h
end

return PartDump
