-- The Guest's takedown (Logic/Takedown; the visual rework V8, the owner's
-- picks of 2026-10-15): the taste on a down, the taking when you're Lost,
-- each from three openings. Both bodies are posed from one timeline on every
-- client, so it has to hold together at every moment.
return function(test, check, Shared, require)
	local Takedown = require(Shared.Logic.Takedown)
	local GuestPose = require(Shared.Logic.GuestPose)
	local Kinematics = require(Shared.Logic.Kinematics)

	local K = Kinematics

	local function specs()
		local list = {}
		for _, kind in { "taste", "taking" } do
			for _, opening in { "front", "behind", "hiding" } do
				table.insert(
					list,
					Takedown.fill({
						kind = kind,
						opening = opening,
						guest = { 0.4, -2.9 },
						from = opening == "hiding" and { 0, 1.8 } or nil,
						yaw = opening == "behind" and math.pi or 0.3,
						slam = kind == "taking" and { 0.5, 1 } or nil,
						way = kind == "taking" and { -0.3, -1 } or nil,
					})
				)
			end
		end
		return list
	end

	local function finite(value, path: string)
		if type(value) == "number" then
			check.truthy(value == value and value ~= math.huge and value ~= -math.huge, path .. " is finite")
		elseif type(value) == "table" then
			for k, v in value do
				finite(v, path .. "." .. tostring(k))
			end
		end
	end

	local function dist(a, b): number
		return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
	end

	local function guestWrist(sample, side: string)
		local g = sample.guest
		local rf = { r = K.rot(0, g.root.yaw, 0), p = { g.root.x, g.root.y, g.root.z } }
		return K.point(rf, GuestPose.wrist(g.joints, side))
	end

	test("every takedown holds together from start to finish: finite, on or above the floor", function()
		for _, spec in specs() do
			local length = Takedown.length(spec)
			check.truthy(length > 3 and length < 12, spec.kind .. "/" .. spec.opening .. " length " .. length)
			local t = 0
			while t <= length + 0.3 do
				local s = Takedown.sample(spec, t)
				finite(s, spec.kind .. "/" .. spec.opening .. "@" .. string.format("%.2f", t))
				check.atLeast(s.victim.pelvis.p[2], 0.3, "the body stays above the floor")
				check.atLeast(s.points.head[2], 0.2, "the head too")
				-- (Hung up by the ankle in the taking, never into a 10-stud ceiling.)
				check.atMost(s.points.head[2], spec.kind == "taking" and 8.8 or 6.5, "and isn't thrown to the ceiling")
				-- A rotation stays a rotation (the blends never fold it flat).
				local r = s.victim.pelvis.r
				local det = r[1][1] * (r[2][2] * r[3][3] - r[2][3] * r[3][2])
					- r[1][2] * (r[2][1] * r[3][3] - r[2][3] * r[3][1])
					+ r[1][3] * (r[2][1] * r[3][2] - r[2][2] * r[3][1])
				check.near(det, 1, 0.02, "the pelvis turns, never squashes")
				t += 0.05
			end
		end
	end)

	test("the taste: you're held off your feet with his hand over your face", function()
		for _, spec in specs() do
			if spec.kind == "taste" then
				local t = Takedown.openingLength(spec) + 1.0
				local s = Takedown.sample(spec, t)
				check.atLeast(s.points.ankle[2], 0.45, spec.opening .. ": your feet are off the floor")
				check.atMost(
					dist(guestWrist(s, "Right"), s.points.face),
					1.0,
					spec.opening .. ": his hand is at your face"
				)
				check.atMost(
					dist(guestWrist(s, "Left"), s.points.collar),
					1.0,
					spec.opening .. ": his other hand has your collar"
				)
				-- Never inside him: his root keeps its distance from your body.
				local flat =
					math.sqrt((s.guest.root.x - s.victim.pelvis.p[1]) ^ 2 + (s.guest.root.z - s.victim.pelvis.p[3]) ^ 2)
				check.atLeast(flat, 1.4, spec.opening .. ": you're held in front of him, not inside him")
			end
		end
	end)

	test("the taste ends with you face down where you'll lie downed", function()
		for _, spec in specs() do
			if spec.kind == "taste" then
				local m = Takedown.marks(spec)
				local s = Takedown.sample(spec, m.finish)
				check.atMost(dist(s.victim.pelvis.p, spec.rest.p), 1e-4, "the body is at rest")
				for i = 1, 3 do
					for j = 1, 3 do
						check.near(s.victim.pelvis.r[i][j], spec.rest.r[i][j], 1e-3, "and lies as the downed pose does")
					end
				end
			end
		end
	end)

	test("the taste's camera: the two of you, his face, black on the bite, then the floor", function()
		local spec = Takedown.fill({ kind = "taste", opening = "front" })
		local m = Takedown.marks(spec)
		check.truthy(m.close < m.tear and m.tear < m.black and m.black < m.wake and m.wake < m.finish, "beats in order")
		check.equal((Takedown.shot(spec, 0.1)), "pair", "first the pair")
		check.equal((Takedown.shot(spec, m.close + 0.05)), "face", "close on his face as he looks you over")
		check.equal((Takedown.shot(spec, m.tear + 0.05)), "face", "his face as it tears")
		local shot, black = Takedown.shot(spec, m.black + 0.05)
		check.equal(shot, "black", "black on the bite")
		check.equal(black, 1, "all black")
		check.equal((Takedown.shot(spec, m.wake + 0.5)), "floor", "then up from the floor")
	end)

	test("the taking: hung up by the ankle, then slammed flat on your back", function()
		local T = Takedown.Beats.taking
		for _, spec in specs() do
			if spec.kind == "taking" then
				local open = Takedown.openingLength(spec)
				local hung = Takedown.sample(spec, open + T.wrench[2] + 0.2)
				check.atLeast(hung.points.ankle[2], 7.5, spec.opening .. ": held up high by the ankle")
				check.atMost(hung.points.head[2], hung.victim.pelvis.p[2] - 1, spec.opening .. ": head down")
				check.atMost(dist(guestWrist(hung, "Right"), hung.points.ankle), 0.8, spec.opening .. ": in his hand")
				local down = Takedown.sample(spec, open + T.hit + 0.01)
				check.near(down.victim.pelvis.p[2], 0.55, 0.05, spec.opening .. ": flat on the floor")
				check.atMost(down.points.head[2], 1.0, spec.opening .. ": the head on the boards")
				check.atMost(
					dist(guestWrist(down, "Right"), down.points.ankle),
					0.8,
					spec.opening .. ": still holding on"
				)
				-- Landed where the layout says, and the server checks that floor.
				local layout = Takedown.layout(spec)
				check.atMost(
					math.sqrt((down.victim.pelvis.p[1] - layout.L[1]) ^ 2 + (down.victim.pelvis.p[3] - layout.L[2]) ^ 2),
					1e-3,
					spec.opening .. ": where it was laid out"
				)
				local first = Takedown.shot(spec, open + 0.5)
				check.truthy(first == "slam" or first == "grab", "the low side shot")
				check.equal((Takedown.shot(spec, open + T.slam[1])), "slam", "side on to the slam as he slams")
			end
		end
	end)

	test("the taking: dragged off by the ankle, him ahead, your hips hauled up", function()
		for _, spec in specs() do
			if spec.kind == "taking" then
				local m = Takedown.marks(spec)
				local endS = Takedown.sample(spec, m.finish)
				local last = spec.path[#spec.path]
				check.atMost(
					math.sqrt((endS.guest.root.x - last[1]) ^ 2 + (endS.guest.root.z - last[2]) ^ 2),
					0.05,
					spec.opening .. ": he ends at the way out"
				)
				local mid = Takedown.sample(spec, m.drag + 1)
				check.atMost(mid.victim.pelvis.p[2], 1.8, "your hips off the floor")
				check.atMost(mid.points.head[2], 0.9, "your head dragging")
				check.atMost(dist(guestWrist(mid, "Right"), mid.points.ankle), 0.7, "with your ankle in his hand")
				check.near(endS.victim.fade, 1, 1e-6, "gone into the dark at the end")
				check.equal((Takedown.shot(spec, m.drag + 0.05)), "drag", "the low shot as you go")
				-- The live drag picks up exactly where the timeline leaves it.
				local live = table.clone(spec)
				live.live = true
				live._geo = nil
				local hand = Takedown.sample(live, Takedown.length(live))
				local g = hand.guest.root
				local hold = Takedown.Drag.hold
				local fx, fz = -math.sin(g.yaw), -math.cos(g.yaw)
				local at = { g.x - fx * hold[1] - fz * hold[2], hold[3], g.z - fz * hold[1] + fx * hold[2] }
				check.atMost(dist(hand.points.ankle, at), 1e-3, "the ankle where the live drag holds it")
			end
		end
	end)

	test("cues come in order, within the takedown, the scream picked by the body", function()
		for _, spec in specs() do
			local cues = Takedown.cues(spec, "Female")
			local length = Takedown.length(spec)
			local last = -1
			local screamed = false
			for _, cue in cues do
				check.atLeast(cue[1], last, "in order")
				check.atMost(cue[1], length, "within it")
				last = cue[1]
				if cue[2] == "TakedownScreamFemale" then
					screamed = true
				end
			end
			check.truthy(screamed, spec.kind .. ": the scream")
		end
	end)

	test("half a turn blends through upright frames", function()
		local a = { r = K.rot(0, 0, 0), p = { 0, 0, 0 } }
		local b = { r = K.rot(0, math.pi, 0), p = { 0, 0, 0 } }
		for k = 0, 1, 0.1 do
			local f = Takedown.slerpFrame(a, b, k)
			local up = K.apply(f.r, { 0, 1, 0 })
			check.near(K.length(up), 1, 1e-6, "unit")
		end
	end)
end
