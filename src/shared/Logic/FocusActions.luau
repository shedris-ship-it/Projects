-- What E does to the one thing you're looking at, on a keyboard (the owner's
-- solo playtest, 2026-10-08: a light switch beside a door took the door's E,
-- the piano offered only a push, "maybe we could streamline the UI a little
-- bit or make a better focus system"). Controllers/HandsController finds the
-- thing (your eye ray first, else the nearest to the middle of your view);
-- this says what a tap of E does and what holding it does, and so what its
-- one marker says (UI/FocusMarkers). Pure (tests/specs/FocusActions.spec).
--
-- `target`:
--   kind       "piece" (a door, a drawer, a lid your hands take), "thing" (a
--              small thing you carry), "pushable" (furniture) or "prompt"
--              (anything else with a prompt: a switch, a note, a key)
--   hideSpot   furniture you hide in (E hides you, or you walk in and shut
--              its doors: a closet, a wardrobe, a locker)
--   prompts    its E prompts, the one you look at most first:
--              { { id, action, hold (seconds), hide (a hiding place's) } }
--   pieceAction  what the door's or drawer's own prompt says ("Open", "Try")
--   canPush    close enough to push (furniture)
--
-- An action: { kind, id?, text }, where kind is "tap" (open or shut a door
-- or drawer, HandsService:Tap), "pick" (pick it up), "prompt" (fire that
-- prompt), "drag" (take hold of it), "push" or "holdPrompt" (hold that
-- prompt for its time).

local FocusActions = {}

-- A prompt held this long or longer is a hold of its own (setting the table,
-- the lantern shrine, picking a lock), so holding E is that, not a push.
FocusActions.LongHold = 0.5

local function long(prompt): boolean
	return prompt.hold >= FocusActions.LongHold
end

local function promptAction(prompt)
	return { kind = long(prompt) and "holdPrompt" or "prompt", id = prompt.id, text = prompt.action }
end

-- The hiding prompt among them, or nil.
local function hideOf(prompts)
	for _, prompt in prompts do
		if prompt.hide then
			return prompt
		end
	end
	return nil
end

-- The first prompt of the kind wanted (short or long), or nil.
local function first(prompts, wantLong: boolean)
	for _, prompt in prompts do
		if long(prompt) == wantLong then
			return prompt
		end
	end
	return nil
end

-- What a tap of E does and what holding E does: `tap`, `hold` (either may be nil).
function FocusActions.choose(target)
	local prompts = target.prompts or {}
	local push = target.canPush and { kind = "push", text = "Push" } or nil
	if target.hideSpot then
		-- E hides you; holding it pushes the furniture (its doors and drawers
		-- take the mouse). A walk-in place (a closet, a wardrobe, a locker)
		-- has no hiding prompt: you hide by shutting yourself in, so it's
		-- furniture with doors like any other.
		local hide = hideOf(prompts)
		if hide then
			return { kind = "prompt", id = hide.id, text = hide.action }, push
		end
	end
	if target.kind == "thing" then
		-- A small thing: tap to carry it. One with a prompt of its own (a music
		-- box's "Wind it up", a wind-up toy): a long one is held, a short one
		-- is the tap (pick it up with the mouse then).
		local own = prompts[1]
		if own and not long(own) then
			return promptAction(own), nil
		end
		return { kind = "pick", text = "Pick up" }, own and promptAction(own) or nil
	elseif target.kind == "piece" then
		-- A door or a drawer: tap to open or shut it (its own prompt's job),
		-- hold to take hold of it. A long prompt on it (picking a lock, a
		-- crank) is the hold instead; the mouse still drags.
		local held = first(prompts, true)
		return { kind = "tap", text = target.pieceAction or "Open" },
			held and promptAction(held) or { kind = "drag", text = "Drag" }
	elseif target.kind == "pushable" or target.hideSpot then
		-- Furniture: its own short prompt is the tap (the piano's Play, the
		-- washing machine), holding pushes. A long prompt of its own (setting
		-- the table) is the hold, and the mouse pushes.
		local held = first(prompts, true)
		local short = first(prompts, false)
		if held then
			return short and promptAction(short) or nil, promptAction(held)
		end
		return short and promptAction(short) or nil, push
	end
	-- A switch, a note, a key on a hook: its prompt, tapped or held.
	local own = prompts[1]
	if not own then
		return nil, nil
	end
	if long(own) then
		return nil, promptAction(own)
	end
	return promptAction(own), nil
end

return FocusActions
