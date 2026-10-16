-- Things to read in the lobby (the story's foundation; Data/Lore, docs/plans/
-- lobby-story.md): each on a piece already in the mall, E reads it on a sheet
-- (UI/Reader, the NoteText remote, as a note in the house; kept out of the
-- run's journal). Drafts, until the owner settles the story, show only in
-- Studio. A run server builds none: it's only the squad's waiting room.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Lore = require(Shared.Data.Lore)
local Mall = require(Shared.Data.Mall)
local Net = require(Shared.Net)
local PropFactory = require(Shared.World.PropFactory)

local LoreService = {}

function LoreService:Init(services)
	self.services = services
end

-- The nth Data/Mall block of a room and name.
function LoreService.block(on)
	local n = 0
	for _, b in Mall.Blocks do
		if b.room == on.room and b.name == on.name then
			n += 1
			if n == (on.n or 1) then
				return b
			end
		end
	end
	return nil
end

function LoreService:Build(parent: Instance, origin: Vector3)
	local places = self.services.PlaceService
	if places and places:IsRun() then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Lore"
	folder.Parent = parent
	for _, entry in Lore do
		if entry.draft and not RunService:IsStudio() then
			continue
		end
		local b = LoreService.block(entry.on)
		if not b then
			warn("[Consensus] lore " .. entry.id .. ": no block " .. entry.on.name .. " in the " .. entry.on.room)
			continue
		end
		local rot = b.rot or { 0, 0, 0 }
		local offset = entry.offset or { 0, 0, 0 }
		local frame = CFrame.new(origin + Vector3.new(b.x, b.y, b.z))
			* CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
			* CFrame.new(offset[1], offset[2], offset[3])
		local size = entry.size or { 1.6, 1.6, 1.6 }
		local part = PropFactory.part(
			folder,
			"Lore" .. entry.id,
			Vector3.new(size[1], size[2], size[3]),
			frame,
			Color3.new(0, 0, 0),
			Enum.Material.SmoothPlastic,
			{ collide = false, transparency = 1, castShadow = false }
		)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = entry.action or "Read"
		prompt.ObjectText = entry.object or ""
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
		prompt.Triggered:Connect(function(player)
			self:Read(player, entry)
		end)
	end
end

function LoreService:Read(player: Player, entry)
	Net.get("NoteText"):FireClient(player, {
		id = "lore:" .. entry.id,
		text = entry.text,
		style = entry.style,
		-- (Not the run's: it stays out of the journal.)
		keep = false,
	})
end

return LoreService
