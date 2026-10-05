-- The home computer's password hack and the padlock its code opens
-- (Logic/Puzzles/Terminal, Logic/Puzzles/Padlock; docs/plans/gameplay-rework.md
-- section 7).
return function(test, check, Shared, require)
	local Rng = require(Shared.Lib.Rng)
	local Words = require(Shared.Data.Words)
	local Terminal = require(Shared.Logic.Puzzles.Terminal)
	local Padlock = require(Shared.Logic.Puzzles.Padlock)

	test("the word lists: right lengths, capitals only, no repeats, plenty of each", function()
		for length, list in Words do
			check.truthy(#list >= 30, "at least 30 words of " .. length)
			local seen = {}
			for _, word in list do
				check.equal(#word, length, word .. " is " .. length .. " letters")
				check.truthy(string.match(word, "^%u+$") ~= nil, word .. " is capitals")
				check.truthy(not seen[word], word .. " only once")
				seen[word] = true
			end
		end
	end)

	test("likeness counts letters in the same places", function()
		check.equal(Terminal.likeness("HOUSE", "HORSE"), 4, "one letter off")
		check.equal(Terminal.likeness("TABLE", "CHAIR"), 0, "nothing shared")
		check.equal(Terminal.likeness("DINNER", "DINNER"), 6, "the same word")
	end)

	test("every screen can be cracked within four tries by a careful player", function()
		for seed = 1, 300 do
			local spec = Terminal.generate(Rng.new(seed), {})
			check.truthy(table.find(spec.words, spec.answer) ~= nil, "the password is on the screen")
			check.truthy(#spec.words >= 8, "seed " .. seed .. ": enough words (" .. #spec.words .. ")")
			check.truthy(Terminal.solvableWithin(spec.words, spec.words, Terminal.Tries), "seed " .. seed)
		end
	end)

	test("the screen shows every word where its span says, and the view hides the password", function()
		local spec = Terminal.generate(Rng.new(11), {})
		local words = 0
		for _, span in spec.spans do
			local text = spec.lines[span.row].text
			if span.kind == "word" then
				words += 1
				check.equal(string.sub(text, span.col, span.col + span.length - 1), span.word, "the word is there")
			else
				local opening = string.sub(text, span.col, span.col)
				check.truthy(string.find("([{<", opening, 1, true) ~= nil, "a bracket opens the span")
				local inside = string.sub(text, span.col + 1, span.col + span.length - 2)
				check.truthy(string.match(inside, "%a") == nil, "nothing but junk inside a bracket pair")
			end
		end
		check.equal(words, #spec.words, "one span a word")
		local view = Terminal.view(spec)
		check.equal(view.answer, nil, "no answer in the view")
		check.equal(view.words, nil, "nor the list it's picked from")
	end)

	test("a wrong word costs a try and says its likeness; four wrong lock it out", function()
		local spec = Terminal.generate(Rng.new(5), {})
		local state = Terminal.start(spec)
		local wrong = {}
		for _, word in spec.words do
			if word ~= spec.answer then
				table.insert(wrong, word)
			end
		end
		local _, events = Terminal.step(spec, state, { kind = "word", word = wrong[1], now = 0 })
		check.equal(events[1].kind, "likeness", "told how close")
		check.equal(events[1].likeness, Terminal.likeness(wrong[1], spec.answer), "the right number")
		check.equal(state.tries, Terminal.Tries - 1, "a try gone")
		for i = 2, Terminal.Tries do
			_, events = Terminal.step(spec, state, { kind = "word", word = wrong[i], now = 1 })
		end
		check.equal(events[#events].kind, "lockout", "locked out")
		_, events = Terminal.step(spec, state, { kind = "word", word = spec.answer, now = 2 })
		check.equal(events[1].kind, "refused", "nothing while locked out")
		_, events = Terminal.step(spec, state, { kind = "word", word = spec.answer, now = 2 + Terminal.LockoutSeconds })
		check.equal(events[1].kind, "solved", "the same password afterwards")
		check.truthy(Terminal.solved(state), "solved")
	end)

	test("brackets remove a wrong word (never the password) or give tries back, once each", function()
		for seed = 1, 40 do
			local spec = Terminal.generate(Rng.new(seed), {})
			local state = Terminal.start(spec)
			Terminal.step(spec, state, { kind = "word", word = spec.duds[#spec.duds], now = 0 })
			for index, effect in spec.brackets do
				local _, events = Terminal.step(spec, state, { kind = "bracket", index = index, now = 1 })
				if effect == "reset" then
					check.equal(state.tries, Terminal.Tries, "tries back")
				else
					check.truthy(events[1].word ~= spec.answer, "never the password")
				end
				local _, again = Terminal.step(spec, state, { kind = "bracket", index = index, now = 1 })
				check.equal(again[1].kind, "refused", "each pair works once")
			end
			check.truthy(not state.removed[spec.answer], "the password stays")
		end
	end)

	test("the same seed makes the same screen", function()
		local a = Terminal.generate(Rng.new(99), {})
		local b = Terminal.generate(Rng.new(99), {})
		check.equal(a.answer, b.answer, "same password")
		check.equal(a.lines[3].text, b.lines[3].text, "same dump")
	end)

	test("the padlock opens to its code and rattles otherwise", function()
		local spec = Padlock.generate(Rng.new(3), {})
		check.truthy(spec.wheels == 3 or spec.wheels == 4, "three or four wheels")
		local state = Padlock.start(spec)
		local _, events = Padlock.step(spec, state, { kind = "pull" })
		local zero = true
		for _, digit in spec.answer do
			zero = zero and digit == 0
		end
		if not zero then
			check.equal(events[1].kind, "rattle", "wrong: it rattles")
		end
		for wheel, digit in spec.answer do
			for _ = 1, digit do
				Padlock.step(spec, state, { kind = "turn", wheel = wheel, delta = 1 })
			end
		end
		_, events = Padlock.step(spec, state, { kind = "pull" })
		check.equal(events[1].kind, "solved", "the code opens it")
		check.equal(#string.split(Padlock.code(spec), " "), spec.wheels, "printed digit by digit")
		local other = Padlock.start(spec)
		Padlock.step(spec, other, { kind = "turn", wheel = 1, delta = -1 })
		check.equal(other.digits[1], 9, "the wheel turns round past 0")
		local _, refused = Padlock.step(spec, other, { kind = "turn", wheel = 9, delta = 1 })
		check.equal(refused[1].kind, "refused", "no such wheel")
	end)
end
