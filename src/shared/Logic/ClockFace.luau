-- Clock hands from a time string (docs/ART.md, Hero props). Wall clocks, the
-- grandfather clock and the "Clocks disagree" tell all show their time with
-- hands, so a clue clock looks exactly like any other clock in the house.

local ClockFace = {}

-- "3:15" -> hours, minutes; nil for anything that isn't a time.
function ClockFace.parse(text: string?): (number?, number?)
	if type(text) ~= "string" then
		return nil, nil
	end
	local h, m = string.match(text, "^%s*(%d%d?):(%d%d)%s*$")
	local hours, minutes = tonumber(h), tonumber(m)
	if not hours or not minutes or hours > 23 or minutes > 59 then
		return nil, nil
	end
	return hours, minutes
end

-- Hand angles in degrees, clockwise from twelve. The hour hand creeps
-- between hours as a real clock's does. Returns 0, 0 for an unreadable time.
function ClockFace.angles(text: string?): (number, number)
	local hours, minutes = ClockFace.parse(text)
	if not hours then
		return 0, 0
	end
	local minuteAngle = (minutes :: number) * 6
	local hourAngle = ((hours :: number) % 12) * 30 + (minutes :: number) * 0.5
	return hourAngle, minuteAngle
end

return ClockFace
