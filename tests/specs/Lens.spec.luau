-- The lens's rules (Logic/Lens): grain on film's clock, rack focus that never
-- hides the Guest, eye adaptation that keeps the dark dark, glare by distance.
return function(test, check, Shared, require)
	local Lens = require(Shared.Logic.Lens)
	local Config = require(Shared.Config)
	local cfg = Config.Lens

	test("the grain changes 24 times a second whatever the frame rate", function()
		for _, fps in { 30, 60, 144, 240 } do
			local changes, last = 0, Lens.grainTick(0, cfg.GrainFps)
			for frame = 1, fps * 10 do
				local tick = Lens.grainTick(frame / fps, cfg.GrainFps)
				if tick ~= last then
					changes += 1
					last = tick
				end
			end
			check.equal(changes, cfg.GrainFps * 10, "ten seconds at " .. fps .. " fps")
		end
	end)

	test("each grain tick picks a frame and an offset in range, and repeats itself", function()
		local frames, size = 8, 512
		local used, same = {}, 0
		local lastFrame = nil
		for tick = 1, 2000 do
			local frame, x, y = Lens.grainPick(tick, frames, size)
			check.truthy(frame >= 1 and frame <= frames, "frame in range")
			check.truthy(x >= 0 and x < size and y >= 0 and y < size, "offset in range")
			used[frame] = true
			if frame == lastFrame then
				same += 1
			end
			lastFrame = frame
			local again = { Lens.grainPick(tick, frames, size) }
			check.equal(again[1], frame, "the same tick, the same frame")
			check.equal(again[2], x, "and the same offset")
		end
		for frame = 1, frames do
			check.truthy(used[frame], "frame " .. frame .. " is used")
		end
		check.atMost(same, 2000 / frames * 1.5, "a frame doesn't stick")
	end)

	test("the grain's strength follows the setting, Dread and the dark", function()
		check.equal(Lens.grainOpacity(0, 100, 1, true, cfg), 0, "off is off")
		local fine = Lens.grainOpacity(1, 0, 0, true, cfg)
		local film = Lens.grainOpacity(2, 0, 0, true, cfg)
		check.truthy(film > fine and fine > 0, "Film is stronger than Fine")
		check.truthy(Lens.grainOpacity(2, 100, 0, true, cfg) > film, "Dread thickens it")
		check.truthy(Lens.grainOpacity(2, 0, 1, true, cfg) > film, "the dark thickens it")
		check.truthy(Lens.grainOpacity(2, 0, 0, false, cfg) < film, "the hub is lighter")
		check.atMost(Lens.grainOpacity(2, 100, 1, true, cfg), 0.5, "never a snowstorm")
		-- The light specks: dim over a dark view (no TV snow on black).
		local dark, lit = Lens.grainLight(1, cfg), Lens.grainLight(0, cfg)
		check.truthy(dark < lit, "light specks brighter in the light")
		check.atMost(dark, 0.2, "and nearly gone in the dark")
		check.atMost(lit, 1, "never past white")
	end)

	test("rack focus follows the view and never leaves the Guest soft", function()
		local f = cfg.Focus
		local d, r, far = Lens.focus(3, nil, cfg)
		check.near(d, 3, 1e-9, "a note held up")
		check.truthy(far > f.FarBlur, "the room behind goes softer")
		d, r = Lens.focus(nil, nil, cfg)
		check.equal(d, f.Far, "nothing hit: far focus")
		d = Lens.focus(0.5, nil, cfg)
		check.equal(d, f.Near, "never nearer than Near")
		-- Reading something close with him 30 studs off: he stays sharp.
		for _, guest in { 10, 20, 30, 40 } do
			d, r = Lens.focus(3, guest, cfg)
			check.truthy(guest <= d + r, "the Guest at " .. guest .. " inside the sharp zone")
		end
		d, r = Lens.focus(3, 55, cfg)
		check.truthy(55 > d + r, "beyond GuestReadable he may go soft")
	end)

	test("eyes adapt a little and darkness stays dark", function()
		local e = cfg.Exposure
		local lit = Lens.exposure(2 ^ e.Key - e.Floor, cfg)
		check.near(lit, 0, 1e-6, "a lamp-lit room needs no change")
		check.equal(Lens.exposure(0, cfg), e.Max, "pitch black opens up only to Max")
		check.atMost(e.Max, 0.5, "Max is a small lift")
		check.equal(Lens.exposure(100, cfg), e.Min, "a blaze closes down to Min")
		check.truthy(Lens.exposure(0.05, cfg) > Lens.exposure(1, cfg), "darker opens more")
		check.truthy(Lens.exposureRate(0, 0.3, cfg) < Lens.exposureRate(0.3, 0, cfg), "slower into the dark")
		check.equal(Lens.lightAt(2, 40, 40), 0, "nothing at the range")
		check.near(Lens.lightAt(2, 40, 0), 2, 1e-9, "full at the light")
		check.equal(Lens.darkness(0, cfg), 1, "no light is dark")
		check.equal(Lens.darkness(e.Lit * 2, cfg), 0, "plenty of light isn't")
	end)

	test("glare shrinks with distance, fades out by MaxDistance and follows the light", function()
		local g = cfg.Glare
		local near = Lens.glare(5, 1, 1, 1000, cfg)
		local far = Lens.glare(25, 1, 1, 1000, cfg)
		check.truthy(near > far, "nearer is bigger")
		local _, opacity = Lens.glare(g.MaxDistance, 1, 1, 1000, cfg)
		check.equal(opacity, 0, "gone at MaxDistance")
		local _, out = Lens.glare(10, 0, 1, 1000, cfg)
		check.equal(out, 0, "a dead light has no glare")
		local _, edge = Lens.glare(10, 1, 0, 1000, cfg)
		local _, ahead = Lens.glare(10, 1, 1, 1000, cfg)
		check.truthy(ahead > edge and edge > 0, "strongest looked at, still there at the edge")
		local size = Lens.glare(0.2, 1, 1, 1000, cfg)
		check.atMost(size, g.MaxPixels, "never bigger than MaxPixels")
		check.equal(Lens.dirt(0, 1, cfg), 0, "no dirt off-centre")
		check.truthy(Lens.dirt(1, 1, cfg) > Lens.dirt(0.8, 1, cfg), "more dirt dead centre")
	end)
end
