-- Small engine-agnostic helpers shared by server, client and tests.

local Util = {}

function Util.clamp(value: number, min: number, max: number): number
	if value < min then
		return min
	elseif value > max then
		return max
	end
	return value
end

function Util.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Util.round(value: number, step: number?): number
	local s = step or 1
	return math.floor(value / s + 0.5) * s
end

function Util.count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

function Util.keys(t: { [any]: any }): { any }
	local result = {}
	for key in t do
		table.insert(result, key)
	end
	table.sort(result, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return result
end

function Util.map(list: { any }, fn: (any, number) -> any): { any }
	local result = table.create(#list)
	for i, v in list do
		result[i] = fn(v, i)
	end
	return result
end

function Util.filter(list: { any }, fn: (any) -> boolean): { any }
	local result = {}
	for _, v in list do
		if fn(v) then
			table.insert(result, v)
		end
	end
	return result
end

function Util.toSet(list: { any }): { [any]: boolean }
	local set = {}
	for _, v in list do
		set[v] = true
	end
	return set
end

function Util.contains(list: { any }, value: any): boolean
	return table.find(list, value) ~= nil
end

function Util.deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for k, v in value do
		result[k] = Util.deepCopy(v)
	end
	return result
end

-- Clock direction (1-12) of a target relative to a facing direction, on the
-- XZ plane. 12 is straight ahead, 3 is to the right.
function Util.clockDirection(forwardX: number, forwardZ: number, toX: number, toZ: number): number
	local forwardAngle = math.atan2(forwardX, -forwardZ)
	local targetAngle = math.atan2(toX, -toZ)
	local delta = (targetAngle - forwardAngle) % (2 * math.pi)
	local hour = math.floor(delta / (2 * math.pi) * 12 + 0.5) % 12
	if hour == 0 then
		hour = 12
	end
	return hour
end

function Util.formatClock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- Distance band wording used by structured callouts, so text-only players
-- get a sense of range without an exact marker.
function Util.distanceBand(distance: number): string
	if distance < 12 then
		return "close"
	elseif distance < 30 then
		return "nearby"
	elseif distance < 60 then
		return "a room or two away"
	end
	return "far off"
end

return Util
