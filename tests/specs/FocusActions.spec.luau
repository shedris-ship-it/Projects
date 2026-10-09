-- What tap E and hold E do to the thing you look at (Logic/FocusActions; the
-- owner's solo playtest, 2026-10-08).
return function(test, check, Shared, require)
	local FocusActions = require(Shared.Logic.FocusActions)

	local function kinds(target)
		local tap, hold = FocusActions.choose(target)
		return tap and tap.kind or "-", hold and hold.kind or "-", tap, hold
	end

	test("a door: tap opens or shuts it, hold drags it", function()
		local tap, hold, t = kinds({ kind = "piece", pieceAction = "Close" })
		check.equal(tap, "tap")
		check.equal(hold, "drag")
		check.equal(t.text, "Close")
	end)

	test("a door with a lock to pick: holding picks it, the mouse still drags", function()
		local tap, hold, _, h = kinds({ kind = "piece", prompts = { { id = 1, action = "Pick the lock", hold = 8 } } })
		check.equal(tap, "tap")
		check.equal(hold, "holdPrompt")
		check.equal(h.id, 1)
	end)

	test("the piano: tap plays it, hold pushes it", function()
		local tap, hold, t = kinds({
			kind = "pushable",
			canPush = true,
			prompts = { { id = "play", action = "Play", hold = 0 } },
		})
		check.equal(tap, "prompt")
		check.equal(t.id, "play")
		check.equal(hold, "push")
	end)

	test("the piano out of pushing reach still plays", function()
		local tap, hold =
			kinds({ kind = "pushable", canPush = false, prompts = { { id = 1, action = "Play", hold = 0 } } })
		check.equal(tap, "prompt")
		check.equal(hold, "-")
	end)

	test("plain furniture: holding pushes, a tap does nothing", function()
		local tap, hold = kinds({ kind = "pushable", canPush = true })
		check.equal(tap, "-")
		check.equal(hold, "push")
	end)

	test("the dining table: holding sets a place, the mouse pushes", function()
		local tap, hold = kinds({
			kind = "pushable",
			canPush = true,
			prompts = { { id = 1, action = "Set the table", hold = 1 } },
		})
		check.equal(tap, "-")
		check.equal(hold, "holdPrompt")
	end)

	test("a hiding place E hides you in: tap hides you, hold pushes it (a door of its own is the mouse's)", function()
		local tap, hold, t = kinds({
			kind = "pushable",
			hideSpot = true,
			canPush = true,
			prompts = {
				{ id = "door", action = "Open", hold = 0 },
				{ id = "hide", action = "Hide", hold = 0.25, hide = true },
			},
		})
		check.equal(tap, "prompt")
		check.equal(t.id, "hide")
		check.equal(hold, "push")
	end)

	test("a walk-in wardrobe, locker or closet (no hiding prompt): its door's prompt, holding pushes", function()
		local tap, hold, t = kinds({
			kind = "pushable",
			hideSpot = true,
			canPush = true,
			prompts = { { id = "door", action = "Open", hold = 0 } },
		})
		check.equal(tap, "prompt")
		check.equal(t.id, "door")
		check.equal(hold, "push")
	end)

	test("a mug: tap picks it up", function()
		local tap, hold = kinds({ kind = "thing" })
		check.equal(tap, "pick")
		check.equal(hold, "-")
	end)

	test("the music box: tap picks it up, holding winds it", function()
		local tap, hold = kinds({ kind = "thing", prompts = { { id = 1, action = "Wind it up", hold = 0.8 } } })
		check.equal(tap, "pick")
		check.equal(hold, "holdPrompt")
	end)

	test("a thing with a quick prompt: the tap is the prompt (the mouse picks it up)", function()
		local tap, hold = kinds({ kind = "thing", prompts = { { id = 1, action = "Take the receiver", hold = 0 } } })
		check.equal(tap, "prompt")
		check.equal(hold, "-")
	end)

	test("a light switch: a tap", function()
		local tap, hold =
			kinds({ kind = "prompt", prompts = { { id = 1, action = "Switch the light off", hold = 0 } } })
		check.equal(tap, "prompt")
		check.equal(hold, "-")
	end)

	test("the lantern shrine: a hold", function()
		local tap, hold = kinds({ kind = "prompt", prompts = { { id = 1, action = "Light the lantern", hold = 5 } } })
		check.equal(tap, "-")
		check.equal(hold, "holdPrompt")
	end)

	test("nothing to do: nothing", function()
		local tap, hold = kinds({ kind = "prompt", prompts = {} })
		check.equal(tap, "-")
		check.equal(hold, "-")
	end)
end
