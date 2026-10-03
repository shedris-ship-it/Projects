-- What The Guest learns about each Witness's eyes (owner, 2026-10-03: "feel
-- like he's adapting to you"; doc section 5 "Adaptation"). Fed by the camera
-- direction every client already reports (ReportView, ~12 Hz):
--
--   * how often you look behind you (a "rear check")
--   * which shoulder you look over
--   * whether you stare at him or run when you see him
--
-- He uses it to move just after you've checked, to come at you on the side
-- you check least, and to pick whoever looks back least. Every habit has a
-- counter: look back often, at uneven times, over both shoulders.
--
-- Yaws are radians (Roblox: 0 = facing -Z, + turns left). Plain numbers.

local GazeHabits = {}

local REAR = 115 -- degrees from "forward" that counts as looking behind
local RESET = 70 -- must come back under this before another check counts
local DEFAULT_INTERVAL = 25

local function delta(a: number, b: number): number
	local d = math.deg(a - b) % 360
	if d > 180 then
		d -= 360
	end
	return d
end

function GazeHabits.new()
	return {
		forward = nil, -- the yaw that counts as "ahead"
		lookingBack = false,
		lastCheck = nil,
		interval = DEFAULT_INTERVAL, -- moving average of seconds between checks
		checks = 0,
		left = 0,
		right = 0,
		stares = 0,
		flees = 0,
	}
end

-- One sample. lookYaw: where the camera faces. moveYaw: the direction of
-- travel, or nil when standing still (then "ahead" drifts slowly towards
-- wherever you settle your gaze).
function GazeHabits.sample(h, t: number, lookYaw: number, moveYaw: number?, dt: number)
	if moveYaw then
		h.forward = moveYaw
	elseif h.forward == nil then
		h.forward = lookYaw
	elseif not h.lookingBack then
		-- Standing still: "ahead" follows your gaze, slowly.
		local d = delta(lookYaw, h.forward)
		h.forward += math.rad(d) * math.min(1, dt * 0.35)
	end
	local off = delta(lookYaw, h.forward)
	if not h.lookingBack and math.abs(off) >= REAR then
		h.lookingBack = true
		if h.lastCheck then
			local gap = t - h.lastCheck
			h.interval += (gap - h.interval) * 0.35
		end
		h.lastCheck = t
		h.checks += 1
		if off > 0 then
			h.left += 1
		else
			h.right += 1
		end
	elseif h.lookingBack and math.abs(off) <= RESET then
		h.lookingBack = false
	end
end

-- Seconds since you last looked behind you (a long time if never).
function GazeHabits.sinceCheck(h, t: number): number
	return h.lastCheck and (t - h.lastCheck) or math.huge
end

-- How likely you are to keep facing ahead for a while: 1 just after a rear
-- check, falling to 0 as your usual next check comes due.
function GazeHabits.creepWindow(h, t: number): number
	if not h.lastCheck then
		return 0.5
	end
	return math.clamp(1 - (t - h.lastCheck) / math.max(h.interval, 1), 0, 1)
end

-- Which side you look over: +1 always the left shoulder, -1 always the
-- right, 0 even. He comes at you from the other side.
function GazeHabits.sideBias(h): number
	return (h.left - h.right) / (h.left + h.right + 2)
end

-- 0..1: how blind your back is (rarely checks behind -> 1).
function GazeHabits.blindBack(h): number
	if h.checks == 0 then
		return 0.6
	end
	return math.clamp((h.interval - 8) / 30, 0, 1)
end

-- When you see him: did you hold his gaze or run?
function GazeHabits.recordSighting(h, stared: boolean)
	if stared then
		h.stares += 1
	else
		h.flees += 1
	end
end

-- 0..1: how much you stare him down rather than run.
function GazeHabits.stareHabit(h): number
	-- Neutral (0.5) until he has seen how you react.
	return (h.stares + 0.5) / (h.stares + h.flees + 1)
end

return GazeHabits
