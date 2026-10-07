-- His keys (the Guest rework, 2026-10-07; the owner's choice: "keys and
-- secret ways"). He's the host: a door still locked with a key, a code or a
-- passage's hidden latch is his to open, so no locked wing is a safe wall at
-- your back. Never boards, a chain, a crank, the power or the dinner's seal:
-- those are nailed, chained, wound or wired, not locked.
--
-- The tell comes first: his key ring and the lock turning, heard on both
-- sides (Config.Guest.KeyPassSeconds, never under 1.5 s). He only passes when
-- nobody is near the door on either side and nobody sees it, the doorway
-- stays barred to players while it's open (Services/DoorService), and he
-- locks it again behind him. He never relocks a door the squad opened. A
-- hidden door he comes out of stays found: he showed you the passage. Pure.

local GuestKeys = {}

-- Can his keys open a lock of this kind? `lock` is a LockPlanner lock (or
-- LockService's hidden-door lock).
function GuestKeys.opens(lock, cfg): boolean
	if not cfg.Keys or not lock then
		return false
	end
	if lock.vault then
		return false -- the safe room's steel door is powered, not locked
	end
	return cfg.KeyKinds[lock.kind] == true
end

-- May he pass now? ctx: nearest (walking studs from the door to the nearest
-- active player, either side), seen (anyone sees the door), refused (seconds
-- since he last had to turn back from it).
function GuestKeys.mayPass(ctx, cfg): (boolean, string?)
	if ctx.nearest < cfg.KeyPassClear then
		return false, "someone near"
	elseif ctx.seen then
		return false, "watched"
	end
	return true, nil
end

-- How long the tell lasts before the door opens: shorter in a hunt, never
-- under 1.5 s (doc section 5's fairness: a sound before anything happens).
function GuestKeys.tellSeconds(hunting: boolean, cfg): number
	local seconds = hunting and cfg.KeyPassSecondsHunt or cfg.KeyPassSeconds
	return math.max(1.5, seconds)
end

-- Is he through? `start` and `now` are his signed distances along the
-- door's normal (from the door's centre) when it opened and now.
function GuestKeys.through(start: number, now: number): boolean
	if start == 0 then
		return math.abs(now) > 2.5
	end
	return math.sign(now) ~= math.sign(start) and math.abs(now) > 2.5
end

return GuestKeys
