-- The maths behind how movement feels (owner, 2026-10-03): how fast you move
-- in each situation, stride length, head bob, landing dip, sprint FOV kick and
-- the footstep sample bag. Pure, so the numbers are tests (tests/specs/Feel.spec.luau).
-- Camera motion (bob, roll, kick, dip) all scale with the "Camera motion"
-- setting, 0 to 1; 0 is off. Only position and roll are ever bobbed: pitch and
-- yaw would change what the server thinks you're looking at.

local Feel = {}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- 0 at walking pace up to 1 at a full sprint (and below 0 never).
local function sprintShare(speed: number, P): number
	return math.clamp((speed - P.WalkSpeed) / (P.SprintSpeed - P.WalkSpeed), 0, 1)
end

-- How fast the character is allowed to move right now (studs/s). Sprint and
-- the downed crawl are unchanged by the slow walk; the hub stays brisk; out of
-- stamina you stagger at WindedSpeed instead of dropping to a walk.
-- ctx: downed, hidden, hub, sprinting, exhausted
function Feel.targetSpeed(ctx, P, crawlSpeed: number): number
	if ctx.downed then
		return crawlSpeed
	elseif ctx.hidden then
		return 0
	elseif ctx.sprinting and not ctx.exhausted then
		return P.SprintSpeed
	elseif ctx.hub then
		return P.LobbyWalkSpeed
	elseif ctx.exhausted then
		return P.WindedSpeed
	end
	return P.WalkSpeed
end

-- Studs per step: longer strides when you run.
function Feel.stride(speed: number, P, F): number
	return lerp(F.StrideWalk, F.StrideSprint, sprintShare(speed, P))
end

function Feel.stepsPerSecond(speed: number, P, F): number
	return speed / Feel.stride(speed, P, F)
end

-- Steps are heard only above a creep, and louder the faster you go.
function Feel.stepVolume(speed: number, P, F): number
	if speed < F.FootstepMinSpeed then
		return 0
	end
	return lerp(F.FootstepVolumeWalk, F.FootstepVolumeSprint, sprintShare(speed, P))
end

-- Peak bob in studs (vertical, sideways) and degrees of roll for a speed.
-- Zero in the air, at a standstill and with the setting at 0; light at a
-- walk, intense at a sprint.
function Feel.bobAmplitude(speed: number, grounded: boolean, intensity: number, P, F): (number, number, number)
	if not grounded or speed < 0.5 or intensity <= 0 then
		return 0, 0, 0
	end
	local t = sprintShare(speed, P)
	local ease = math.clamp(speed / P.WalkSpeed, 0, 1) -- slower than a walk bobs less
	local k = math.clamp(intensity, 0, 1) * ease
	return lerp(F.BobWalk[1], F.BobSprint[1], t) * k,
		lerp(F.BobWalk[2], F.BobSprint[2], t) * k,
		lerp(F.BobWalk[3], F.BobSprint[3], t) * k
end

-- The bob at a phase measured in steps: one bounce a step, one sway per two.
function Feel.bobAt(phase: number, vertical: number, lateral: number, roll: number): (number, number, number)
	return vertical * math.sin(phase * 2 * math.pi),
		lateral * math.sin(phase * math.pi),
		roll * math.sin(phase * math.pi + math.pi / 2)
end

-- How far the camera dips (studs) when you land at a fall speed.
function Feel.landingDip(fallSpeed: number, intensity: number, F): number
	local t = math.clamp((fallSpeed - F.LandMinSpeed) / (F.LandMaxSpeed - F.LandMinSpeed), 0, 1)
	return t * F.LandDip * math.clamp(intensity, 0, 1)
end

-- Extra field of view (degrees) while you run.
function Feel.fovKick(speed: number, intensity: number, P, F): number
	local t = math.clamp((speed - P.WalkSpeed * 1.25) / (P.SprintSpeed - P.WalkSpeed * 1.25), 0, 1)
	return F.FovKick * t * math.clamp(intensity, 0, 1)
end

-- Roll (degrees) leaning into a turn, from the yaw rate in degrees/second.
function Feel.turnLean(yawRate: number, intensity: number, F): number
	return math.clamp(-yawRate * F.TurnLean, -F.TurnLeanMax, F.TurnLeanMax) * math.clamp(intensity, 0, 1)
end

-- Footstep samples: a shuffled bag, so every sample plays once before any
-- repeats, and never the same one twice in a row.
function Feel.newBag(count: number)
	return { count = count, queue = {}, last = nil }
end

function Feel.draw(bag, rng): number
	if bag.count <= 1 then
		return 1
	end
	if #bag.queue == 0 then
		local order = {}
		for i = 1, bag.count do
			order[i] = i
		end
		-- Fisher-Yates.
		for i = bag.count, 2, -1 do
			local j = rng:NextInteger(1, i)
			order[i], order[j] = order[j], order[i]
		end
		-- The first of a new round must differ from the last played.
		if order[1] == bag.last then
			order[1], order[bag.count] = order[bag.count], order[1]
		end
		bag.queue = order
	end
	local pick = table.remove(bag.queue, 1)
	bag.last = pick
	return pick
end

-- A multiplier near 1: 1 +- spread.
function Feel.jitter(rng, spread: number): number
	return 1 + (rng:NextNumber() * 2 - 1) * spread
end

return Feel
