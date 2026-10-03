return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local VoiceNoise = require(Shared.Logic.VoiceNoise)
	local V = Config.Voice

	test("mic level maps to silent, talking and loud", function()
		check.equal(VoiceNoise.bucket(0, 0, V), 0)
		check.equal(VoiceNoise.bucket(V.TalkLevel + 0.001, 0, V), 1)
		check.equal(VoiceNoise.bucket(V.LoudLevel + 0.001, 0, V), 2)
	end)

	test("hysteresis stops a flickering mic toggling buckets", function()
		local justBelow = V.LoudLevel * 0.9
		check.equal(VoiceNoise.bucket(justBelow, 0, V), 1, "not loud from cold")
		check.equal(VoiceNoise.bucket(justBelow, 2, V), 2, "stays loud")
		check.equal(VoiceNoise.bucket(V.TalkLevel * 0.9, 1, V), 1, "stays talking")
		check.equal(VoiceNoise.bucket(V.TalkLevel * 0.5, 1, V), 0, "quiet again")
	end)

	test("radius grows with the bucket and silence makes none", function()
		check.equal(VoiceNoise.radius(0, V), 0)
		check.truthy(VoiceNoise.radius(2, V) > VoiceNoise.radius(1, V), "loud carries further")
	end)

	test("typing is never silent, and longer lines carry further", function()
		local _, short = VoiceNoise.fromText("hi", V)
		local _, long = VoiceNoise.fromText("the key is in the kitchen drawer", V)
		check.truthy(short >= V.TextBaseRadius, "short line still audible")
		check.truthy(long > short, "longer carries further")
	end)

	test("shouting and exclaiming are louder, whispering is quieter", function()
		local _, calm = VoiceNoise.fromText("it is behind you", V)
		local _, shout = VoiceNoise.fromText("IT IS BEHIND YOU", V)
		local _, bang = VoiceNoise.fromText("it is behind you!!!", V)
		local text, whisper, flag = VoiceNoise.fromText("/w it is behind you", V)
		check.truthy(shout > calm, "caps")
		check.truthy(bang > calm, "exclamation marks")
		check.truthy(whisper < calm, "whisper")
		check.equal(flag, true, "flagged as whisper")
		check.equal(text, "it is behind you", "prefix stripped")
	end)

	test("text radius is capped and long lines are cut", function()
		local text, radius = VoiceNoise.fromText(string.rep("A", 500) .. "!!!!!", V)
		check.equal(#(text :: string), V.MaxChars)
		check.atMost(radius, V.TextMaxRadius * V.ShoutScale * (1 + 3 * V.ExclaimScale) + 1e-6, "capped")
	end)

	test("empty or whitespace-only lines make no noise", function()
		check.equal((VoiceNoise.fromText("   ", V)), nil)
		check.equal((VoiceNoise.fromText("/w   ", V)), nil)
	end)
end
