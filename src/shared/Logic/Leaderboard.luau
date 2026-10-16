-- A short board kept whole in one saved value (LB5; docs/plans/lobby-rework.md,
-- "The diner" and "Arcade"): the diner's run records and the arcade's high
-- scores (Services/BoardService). Only the top few ever show, so a board is
-- one list, sorted best first, and each list is written with UpdateAsync
-- only when an entry would make it.
--
-- An entry: { value = number, key = string?, ... } (anything else is the
-- caller's: names, a squad's size). `low`: lower values are better (the
-- fastest runs); otherwise higher (the longest, a score). Ties keep the
-- older entry first. With `unique`, a board holds one entry per key (a
-- player's best score), and a worse one never replaces it.

local Leaderboard = {}

local function better(a: number, b: number, low: boolean?): boolean
	if low then
		return a < b
	end
	return a > b
end

-- Whether `value` would make a board of `size` holding `list`.
function Leaderboard.makes(list, value: number, size: number, low: boolean?): boolean
	if #list < size then
		return true
	end
	return better(value, list[#list].value, low)
end

-- A saved board as it should be: entries with a number value, best first,
-- `size` of them at most (a bad write, or a size that shrank).
function Leaderboard.clean(list, size: number, low: boolean?)
	local out = {}
	if type(list) ~= "table" then
		return out
	end
	for _, entry in list do
		if type(entry) == "table" and type(entry.value) == "number" and entry.value == entry.value then
			table.insert(out, entry)
		end
	end
	-- (A stable sort: insertion, so ties keep their order.)
	for i = 2, #out do
		local entry = out[i]
		local j = i - 1
		while j >= 1 and better(entry.value, out[j].value, low) do
			out[j + 1] = out[j]
			j -= 1
		end
		out[j + 1] = entry
	end
	while #out > size do
		table.remove(out)
	end
	return out
end

-- The board with `entry` on it, and its place (1 is the top), or the board
-- unchanged and nil when it doesn't make it. Never changes `list`.
function Leaderboard.insert(list, entry, size: number, low: boolean?, unique: boolean?)
	local out = Leaderboard.clean(list, size, low)
	if unique and entry.key ~= nil then
		for i, old in out do
			if old.key == entry.key then
				if not better(entry.value, old.value, low) then
					return out, nil
				end
				table.remove(out, i)
				break
			end
		end
	end
	local at = #out + 1
	for i, old in out do
		if better(entry.value, old.value, low) then
			at = i
			break
		end
	end
	if at > size then
		return out, nil
	end
	table.insert(out, at, entry)
	while #out > size do
		table.remove(out)
	end
	return out, at
end

-- The week a moment falls in, counted from Monday 5 January 1970 (UTC):
-- weekly boards start again each Monday at midnight UTC.
function Leaderboard.week(seconds: number): number
	return math.floor((seconds - 4 * 86400) / (7 * 86400))
end

return Leaderboard
