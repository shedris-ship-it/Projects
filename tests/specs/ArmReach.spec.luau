-- Your arm reaching what you hold (Logic/ArmReach): both bones keep their
-- length, the hand always gets there, and the elbow bends the way you asked.
return function(test, check, Shared, require)
	local ArmReach = require(Shared.Logic.ArmReach)

	local function distance(p, q)
		return ArmReach.length({ p[1] - q[1], p[2] - q[2], p[3] - q[3] })
	end

	local cases = {
		{ shoulder = { -0.6, -0.8, 0.05 }, wrist = { -0.53, -0.55, -1.0 } }, -- the torch
		{ shoulder = { 0.6, -0.8, 0.05 }, wrist = { 0.51, -0.5, -1.0 } }, -- a tool
		{ shoulder = { -0.6, -0.8, 0.05 }, wrist = { -0.4, -1.9, -0.6 } }, -- lowered away
		{ shoulder = { 0.6, -0.8, 0.05 }, wrist = { 0.6, -0.8, -3 } }, -- out of reach
		{ shoulder = { 0.6, -0.8, 0.05 }, wrist = { 0.62, -0.78, 0.0 } }, -- far too close
	}

	test("the bones keep their length and the hand reaches its wrist", function()
		local a, b = 0.6, 0.62
		for i, case in cases do
			local elbow, shoulder = ArmReach.solve(case.shoulder, case.wrist, a, b, { 1, -1, 0 })
			check.near(distance(shoulder, elbow), a, 1e-3, "upper arm, case " .. i)
			check.near(distance(elbow, case.wrist), b, 1e-3, "forearm, case " .. i)
		end
	end)

	test("in reach, the shoulder stays where it was", function()
		local elbow, shoulder = ArmReach.solve(cases[1].shoulder, cases[1].wrist, 0.6, 0.62, { -1, -1, 0 })
		check.near(distance(shoulder, cases[1].shoulder), 0, 1e-9, "unmoved")
		check.truthy(elbow ~= nil, "an elbow")
	end)

	test("the elbow bends towards the pole: out and down", function()
		local s, w = cases[1].shoulder, cases[1].wrist
		local elbow = ArmReach.solve(s, w, 0.6, 0.62, { -1, -1, 0 })
		local middle = { (s[1] + w[1]) / 2, (s[2] + w[2]) / 2, (s[3] + w[3]) / 2 }
		check.truthy(elbow[1] < middle[1], "out to the left for the left arm")
		check.truthy(elbow[2] < middle[2], "and down")
	end)

	test("a pole along the arm still gives an elbow", function()
		local s, w = { 0, 0, 0 }, { 0, 0, -1 }
		local elbow = ArmReach.solve(s, w, 0.6, 0.6, { 0, 0, -1 })
		check.near(distance(s, elbow), 0.6, 1e-3, "upper arm")
		check.near(distance(elbow, w), 0.6, 1e-3, "forearm")
	end)
end
