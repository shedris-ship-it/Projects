-- Faces that react (hair and faces, 2026-10-17; docs/progress/
-- 2026-10-17-hair-faces/). Everyone's face is one of Roblox's dynamic heads
-- (Data/Wardrobe Face): it blinks and moves with voice chat by itself. In a
-- run it also shows what's happening to you, from what every client already
-- knows: downed, a wince; holding your breath, eyes screwed shut and cheeks
-- full; a hunt, or The Guest near, scared. Each is a pose of the head's
-- FaceControls (Config.Face.Poses), eased in and out. Pure: Controllers/
-- FaceController reads the state and writes the heads.

local FacePose = {}

-- The one pose a face should be making now, or nil: being downed outranks
-- holding your breath, which outranks being scared.
function FacePose.target(state: { downed: boolean?, holding: boolean?, scared: boolean? }): string?
	if state.downed then
		return "wince"
	elseif state.holding then
		return "hold"
	elseif state.scared then
		return "scared"
	end
	return nil
end

-- Each pose's weight eased toward 1 (the target) or 0 (the rest), at `ease`
-- a second. Returns a new table; poses at rest are left out.
function FacePose.step(weights: { [string]: number }, target: string?, dt: number, ease: number): { [string]: number }
	local out = {}
	local k = math.clamp(dt * ease, 0, 1)
	if target and weights[target] == nil then
		weights = table.clone(weights)
		weights[target] = 0
	end
	for name, w in weights do
		local goal = name == target and 1 or 0
		local nw = w + (goal - w) * k
		if math.abs(goal - nw) < 0.005 then
			nw = goal
		end
		if nw > 0 then
			out[name] = nw
		end
	end
	return out
end

-- The FaceControls values for weighted poses: each property the larger of
-- the poses' (weight times value), 0 to 1.
function FacePose.values(weights: { [string]: number }, poses): { [string]: number }
	local out = {}
	for name, w in weights do
		for prop, v in poses[name] or {} do
			out[prop] = math.clamp(math.max(out[prop] or 0, w * v), 0, 1)
		end
	end
	return out
end

-- Every property any pose touches (so a face let go is set back to rest).
function FacePose.props(poses): { string }
	local seen, out = {}, {}
	for _, pose in poses do
		for prop in pose do
			if not seen[prop] then
				seen[prop] = true
				table.insert(out, prop)
			end
		end
	end
	table.sort(out)
	return out
end

return FacePose
