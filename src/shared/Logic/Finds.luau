-- Which find a drawer or cupboard holds (Data/Finds): a weighted pick among
-- those the run hasn't had its fill of yet. Pure (tests/specs/Finds.spec).

local Finds = {}

-- `counts`: name -> how many the run has had; `squad`: 1 to 4. Returns the
-- entry, or nil when every kind is used up.
function Finds.pick(list, rng, counts, squad: number)
	local open, total = {}, 0
	for _, entry in list do
		local max = entry.max and entry.max[math.clamp(squad, 1, #entry.max)]
		if not max or (counts[entry.name] or 0) < max then
			table.insert(open, entry)
			total += entry.weight
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for _, entry in open do
		roll -= entry.weight
		if roll < 0 then
			return entry
		end
	end
	return open[#open]
end

-- The entry for a model name, or nil.
function Finds.byName(list, name: string)
	for _, entry in list do
		if entry.name == name then
			return entry
		end
	end
	return nil
end

return Finds
