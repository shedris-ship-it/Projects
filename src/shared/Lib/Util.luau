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

-- How far a model reaches up and down in the world: the lowest and highest
-- points of its parts' own boxes, turned however each part is turned.
-- (Model:GetBoundingBox turns its box with the model's pivot, so a model
-- whose pivot lies on its side, like a lamp built round a turned cylinder,
-- measures wrongly.)
function Util.verticalSpan(model: Instance): (number, number)
	local low, high = math.huge, -math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local cf, size = d.CFrame, d.Size
			local half = (
				math.abs(cf.RightVector.Y) * size.X
				+ math.abs(cf.UpVector.Y) * size.Y
				+ math.abs(cf.LookVector.Y) * size.Z
			) / 2
			low = math.min(low, cf.Position.Y - half)
			high = math.max(high, cf.Position.Y + half)
		end
	end
	return low, high
end

return Util
