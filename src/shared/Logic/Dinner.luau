-- How the dinner table is laid (Services/FinaleService): the empty places
-- down both long sides, and the head of the table where he sits (or waits,
-- R2c). Pure (tests/specs/Dinner.spec), so the fairness promise is a test:
-- someone setting a place, even standing back from it, is never within his
-- close-contact reach (Config.Guest.ContactRadius) of the head.
--
-- Along the table's length, 0 is its middle; across, places sit `side` studs
-- either side of the middle line. Returns { places = { { along, side } },
-- head = along } where head is past the end of the table (negative).

local Dinner = {}

-- A player setting a place stands this far beyond its plate, out from the
-- table's side (the prompt reaches 8, so they could stand further).
Dinner.STAND_OUT = 1.5

function Dinner.layout(count: number, length: number, across: number, contactRadius: number, margin: number)
	local places = {}
	local side = across / 2 - 1
	for i = 1, count do
		local along = -length / 2 + length * i / (count + 1)
		table.insert(places, { along = along, side = (i % 2 == 1) and side or -side })
	end
	-- The head: past the end of the table, and far enough out that the
	-- nearest place (and whoever stands at it) is out of his reach.
	local reach = contactRadius + margin
	local head = -length / 2 - 1.6
	for _, place in places do
		local out = math.abs(place.side) + Dinner.STAND_OUT
		local need = place.along - math.sqrt(math.max(0, reach * reach - out * out))
		head = math.min(head, need)
	end
	return { places = places, head = head }
end

-- The nearest any place (with someone standing at it) gets to the head.
function Dinner.closest(layout): number
	local best = math.huge
	for _, place in layout.places do
		local out = math.abs(place.side) + Dinner.STAND_OUT
		local d = math.sqrt((place.along - layout.head) ^ 2 + out * out)
		best = math.min(best, d)
	end
	return best
end

return Dinner
