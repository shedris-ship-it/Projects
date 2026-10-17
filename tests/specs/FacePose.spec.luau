-- Faces that react (Logic/FacePose; hair and faces, 2026-10-17): which pose
-- a face makes, eased in and out, and what it sets on the head.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local FacePose = require(Shared.Logic.FacePose)

	test("downed outranks holding your breath, which outranks being scared", function()
		check.equal(FacePose.target({}), nil, "at rest")
		check.equal(FacePose.target({ scared = true }), "scared", "a hunt")
		check.equal(FacePose.target({ scared = true, holding = true }), "hold", "holding it in a hunt")
		check.equal(FacePose.target({ scared = true, holding = true, downed = true }), "wince", "downed")
	end)

	test("a pose eases in and back out, and is let go at rest", function()
		local w = FacePose.step({}, "scared", 0.05, Config.Face.Ease)
		check.truthy(w.scared > 0 and w.scared < 1, "on its way in")
		for _ = 1, 60 do
			w = FacePose.step(w, "scared", 0.05, Config.Face.Ease)
		end
		check.equal(w.scared, 1, "all the way")
		w = FacePose.step(w, "wince", 0.05, Config.Face.Ease)
		check.truthy(w.scared < 1 and w.wince > 0, "one fades as the next comes")
		for _ = 1, 60 do
			w = FacePose.step(w, nil, 0.05, Config.Face.Ease)
		end
		check.equal(next(w), nil, "at rest, nothing held")
	end)

	test("values: each property the larger pose's share, never past 1", function()
		local poses = { a = { JawDrop = 1, LipsTogether = 0.5 }, b = { JawDrop = 0.4 } }
		local v = FacePose.values({ a = 0.5, b = 1 }, poses)
		check.equal(v.JawDrop, 0.5, "a's half beats b's 0.4")
		check.equal(v.LipsTogether, 0.25, "a's half of 0.5")
		check.equal(next(FacePose.values({}, poses)), nil, "no poses, nothing set")
	end)

	test("the configured poses are FaceControls values between 0 and 1", function()
		local props = FacePose.props(Config.Face.Poses)
		check.truthy(#props > 0, "they set something")
		for name, pose in Config.Face.Poses do
			check.truthy(
				FacePose.target({ downed = name == "wince", holding = name == "hold", scared = name == "scared" })
					== name,
				name .. " is reachable"
			)
			for prop, v in pose do
				check.truthy(type(prop) == "string" and v >= 0 and v <= 1, name .. "." .. prop)
			end
		end
	end)
end
