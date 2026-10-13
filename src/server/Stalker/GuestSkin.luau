-- Dresses The Guest's rig in his Blender model (V5, the Guest remodelled;
-- tools/blender/guest.py, docs/ART.md "The Guest"). The rig is
-- Stalker/StalkerModel's, unchanged: the same invisible joint parts and
-- Motor6Ds every client animates. Over it go his skinned meshes, each welded
-- to the part it rides on, bending with Bones this makes from Data/GuestRig
-- (a Bone of each mesh bone's name, where it rested in Blender): one at each
-- joint part, four down each finger, and the face's under the mask.
--
-- The mask (GuestMask) hangs on the head by a weld of its own (MaskWeld),
-- which each client turns and slips (Lib/GuestMask); the face's bones, its
-- shards, its two shells and the dark behind its holes ride on it.
--
-- All or nothing: if any piece's mesh isn't loaded (not imported yet, or
-- it failed), he's built from primitives as before (StalkerModel).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GuestRig = require(Shared.Data.GuestRig)
local Kit = require(Shared.World.Kit)

local GuestSkin = {}

local function v(t)
	return Vector3.new(t[1], t[2], t[3])
end

-- Is every piece's mesh in (Kit.preload)?
function GuestSkin.ready(): boolean
	for name in GuestRig.Pieces do
		if not Kit.template(name) then
			return false
		end
	end
	return true
end

-- Dresses the rig. parts: the rig's parts by name, built at rest (standing
-- on y = 0 at the origin facing -Z, as GuestRig's places are). Returns the
-- mask, or nil if it couldn't (the rig is left as it was).
function GuestSkin.dress(model: Model, parts: { [string]: BasePart }): MeshPart?
	if not GuestSkin.ready() then
		return nil
	end
	local looks = Kit.folder()
	local head = parts.Head
	local made: { [string]: MeshPart } = {}
	for name, piece in GuestRig.Pieces do
		local mesh = (Kit.template(name) :: MeshPart):Clone()
		for _, child in mesh:GetChildren() do
			child:Destroy()
		end
		mesh.Name = name
		mesh.Anchored = false
		mesh.CanCollide = false
		mesh.CanTouch = false
		mesh.CanQuery = false
		mesh.Massless = true
		mesh.CFrame = CFrame.new(v(piece.centre))
		local overlay = piece.overlay ~= nil
		mesh.CastShadow = not overlay and piece.look ~= "Void"
		if piece.look == "Void" then
			-- The dark behind the eye holes and the grin: black Neon gives
			-- back no light at all, even in your torch (as the old face's
			-- holes did).
			mesh.Material = Enum.Material.Neon
			mesh.Color = Color3.new(0, 0, 0)
		else
			local look = looks and looks:FindFirstChild(piece.look)
			if look and look:IsA("SurfaceAppearance") then
				look:Clone().Parent = mesh
			end
		end
		if overlay then
			mesh.Transparency = 1 -- (each client fades it in with his form)
		end
		made[name] = mesh
	end
	-- The mask on the head, by a weld each client can turn.
	local mask = made.GuestMask
	local maskWeld = Instance.new("Weld")
	maskWeld.Name = "MaskWeld"
	maskWeld.Part0 = head
	maskWeld.Part1 = mask
	maskWeld.C0 = head.CFrame:ToObjectSpace(mask.CFrame)
	maskWeld.Parent = mask
	mask.Parent = head
	-- Everything else welded to its part (the mask's pieces to the mask).
	for name, piece in GuestRig.Pieces do
		if name ~= "GuestMask" then
			local mesh = made[name]
			local onto = piece.part == "Mask" and mask or parts[piece.part]
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = onto
			weld.Part1 = mesh
			weld.Parent = mesh
			mesh.Parent = onto
		end
	end
	-- The bones, each where it rested in Blender (none turned).
	local bones: { [string]: Bone } = {}
	local rest: { [string]: Vector3 } = {}
	for _, spec in GuestRig.Bones do
		local at = v(spec.at)
		local bone = Instance.new("Bone")
		bone.Name = spec.name
		if spec.part then
			local holder = spec.part == "Mask" and mask or parts[spec.part]
			bone.CFrame = holder.CFrame:ToObjectSpace(CFrame.new(at))
			bone.Parent = holder
		else
			bone.CFrame = CFrame.new(at - rest[spec.bone])
			bone.Parent = bones[spec.bone]
		end
		bones[spec.name] = bone
		rest[spec.name] = at
	end
	model:SetAttribute("GuestKit", true)
	return mask
end

return GuestSkin
