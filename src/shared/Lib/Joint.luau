-- Where something that swings or slides is, from the attributes on its main
-- part (docs/plans/gameplay-rework.md section 4.5). Doors (Services/
-- DoorService) and furniture pieces (World/PropFactory, Services/
-- FurnitureService) carry the same attributes, so the server and the client
-- that drags one (Controllers/HandsController) pose it the same way:
--   Joint  "hinge" or "slide"
--   Hinge  a point on the hinge's axis (hinges)
--   Axis   the hinge's axis, or the way a drawer pulls out (default up)
--   Sign   1, or -1 for a hinge that opens by turning the other way
--   Shut   the main part's CFrame when shut
--   Max    how far it opens (degrees, or studs for a slide)
--   Rate   how fast it moves (per second)
--   Latch  within this of shut it snaps shut
--   Value  where it is now (written by the server when it stops)
-- The rules for how it moves are Logic/Articulation.

local Joint = {}

export type Joint = {
	kind: string,
	hinge: Vector3,
	axis: Vector3,
	sign: number,
	shut: CFrame,
	max: number,
	rate: number,
	latch: number,
}

function Joint.read(primary: BasePart): Joint?
	local kind = primary:GetAttribute("Joint")
	local shut = primary:GetAttribute("Shut")
	if typeof(kind) ~= "string" or typeof(shut) ~= "CFrame" then
		return nil
	end
	local axis = primary:GetAttribute("Axis")
	local hinge = primary:GetAttribute("Hinge")
	return {
		kind = kind,
		hinge = typeof(hinge) == "Vector3" and hinge or shut.Position,
		axis = typeof(axis) == "Vector3" and axis.Unit or Vector3.yAxis,
		sign = primary:GetAttribute("Sign") or 1,
		shut = shut,
		max = primary:GetAttribute("Max") or 90,
		rate = primary:GetAttribute("Rate") or 240,
		latch = primary:GetAttribute("Latch") or 0,
	}
end

-- Write a joint onto its main part (the builders call this once).
function Joint.write(primary: BasePart, joint)
	primary:SetAttribute("Joint", joint.kind)
	primary:SetAttribute("Hinge", joint.hinge)
	primary:SetAttribute("Axis", joint.axis)
	primary:SetAttribute("Sign", joint.sign)
	primary:SetAttribute("Shut", joint.shut or primary.CFrame)
	primary:SetAttribute("Max", joint.max)
	primary:SetAttribute("Rate", joint.rate)
	primary:SetAttribute("Latch", joint.latch)
end

-- A hinge that turns about an upright axis (a door, a cupboard door), as
-- opposed to a lid.
function Joint.upright(joint: Joint): boolean
	return joint.kind == "hinge" and math.abs(joint.axis.Y) > 0.99
end

-- The main part's CFrame when it's `value` open.
function Joint.pose(joint: Joint, value: number): CFrame
	if joint.kind == "slide" then
		return joint.shut + joint.axis * value
	end
	local hinge = joint.hinge
	return CFrame.new(hinge)
		* CFrame.fromAxisAngle(joint.axis, math.rad(joint.sign * value))
		* CFrame.new(-hinge)
		* joint.shut
end

-- How far open a main part at `cframe` is (the inverse of `pose`).
function Joint.valueOf(joint: Joint, cframe: CFrame): number
	if joint.kind == "slide" then
		return (cframe.Position - joint.shut.Position):Dot(joint.axis)
	end
	local axis, angle = (cframe * joint.shut:Inverse()):ToAxisAngle()
	local turn = math.deg(angle) * (axis:Dot(joint.axis) >= 0 and 1 or -1)
	return turn * joint.sign
end

return Joint
