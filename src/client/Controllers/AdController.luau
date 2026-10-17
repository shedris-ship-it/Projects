-- The lobby mall's ad frames, for your own eyes (LB6; docs/plans/lobby-
-- rework.md, "Immersive ads"; Logic/Ads). Where a frame's AdGui is up and
-- Roblox may not show you ads (PolicyService's AreAdsAllowed), the AdGui
-- comes off your copy of the face and our own 1988 poster goes on in its
-- place (World/AdPoster), so the mall looks the same to everyone. Where the
-- policy can't be read the AdGui stays: Roblox shows its fallback, our
-- poster, to anyone it can't serve. In Studio, F2 `ads deny` (the player
-- attribute DebugAdsAllowed) tries the other answer. Looks only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdPoster = require(Shared.World.AdPoster)
local Ads = require(Shared.Logic.Ads)
local Constants = require(Shared.Constants)
local Mall = require(Shared.Data.Mall)

local AdController = {}

local OURS = "AdPosterLocal" -- the attribute on a poster this client put up

function AdController:Init(_controllers) end

local slots = {} -- slot name -> its Data/Mall `Ads` entry
for _, slot in Mall.Ads do
	slots[slot.slot] = slot
end

function AdController:Start()
	local player = Players.LocalPlayer
	local allowed: boolean? = nil
	local ready = false
	local faces = {} -- the faces seen, to look at again when the answer changes

	-- What this player may be shown: the debug answer, or Roblox's.
	local function policy(): boolean?
		local forced = player:GetAttribute("DebugAdsAllowed")
		if type(forced) == "boolean" then
			return forced
		end
		return allowed
	end

	-- The poster this client put up on a face, if any (the server's may be
	-- there too for a moment, with the same name).
	local function ourPoster(face: Instance): Instance?
		for _, child in face:GetChildren() do
			if child.Name == AdPoster.Name and child:GetAttribute(OURS) == true then
				return child
			end
		end
		return nil
	end

	local function look(face: Instance)
		if not ready or not face:IsA("BasePart") or not face.Parent then
			return
		end
		local slot = slots[face:GetAttribute("AdSlot")]
		if not slot then
			return
		end
		local mine = ourPoster(face)
		if face:GetAttribute("AdUp") == true and Ads.show(true, policy()) == "poster" then
			-- Ours instead, on your copy only.
			local gui = face:FindFirstChildOfClass("AdGui")
			if gui then
				gui:Destroy()
			end
			if not mine then
				AdPoster.build(face, slot):SetAttribute(OURS, true)
			end
		elseif mine and face:GetAttribute("AdUp") ~= true then
			-- The server's poster is back (F2 `ads poster`): it shows the same.
			mine:Destroy()
		end
	end

	local function add(face: Instance)
		if faces[face] then
			look(face)
			return
		end
		faces[face] = true
		face.ChildAdded:Connect(function()
			task.defer(look, face)
		end)
		face:GetAttributeChangedSignal("AdUp"):Connect(function()
			task.defer(look, face)
		end)
		face.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				faces[face] = nil
			end
		end)
		look(face)
	end

	local function again()
		for face in faces do
			if face:FindFirstChildOfClass("AdGui") == nil and face:GetAttribute("AdUp") == true then
				-- Taken off for you before: the server's comes back only with a
				-- new one, so a changed answer waits for that (F2 `ads ad`).
				continue
			end
			look(face)
		end
	end
	player:GetAttributeChangedSignal("DebugAdsAllowed"):Connect(again)

	task.spawn(function()
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(info) == "table" and type(info.AreAdsAllowed) == "boolean" then
			allowed = info.AreAdsAllowed
		end
		ready = true
		for _, face in CollectionService:GetTagged(Constants.Tags.AdFace) do
			add(face)
		end
	end)
	CollectionService:GetInstanceAddedSignal(Constants.Tags.AdFace):Connect(function(face)
		task.defer(add, face)
	end)
end

return AdController
