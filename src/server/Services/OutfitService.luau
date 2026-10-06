-- Everyone in the house wears period clothes (owner, 2026-10-03): faded
-- shirts and jeans instead of modern avatars, so the squad looks like one
-- group of investigators in 1988. LoadCharacterAppearance is off, so
-- characters spawn as the plain R15 body and this paints it (Logic/Outfit).
-- Flat colours for now; textured shirts can come later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Outfit = require(Shared.Logic.Outfit)

local OutfitService = {}

local SHIRT = { "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" }
local PANTS = { "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg" }
local SKIN = { "Head", "LeftHand", "RightHand" }
local SHOES = { "LeftFoot", "RightFoot" }
local STRAY = { "Accessory", "Shirt", "Pants", "ShirtGraphic", "BodyColors", "CharacterMesh" }

local joined = {} -- player -> squad slot, in the order they arrived

local function colour(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- Paints a character in slot `index`.
function OutfitService:Apply(character: Model, index: number)
	for _, child in character:GetChildren() do
		for _, class in STRAY do
			if child:IsA(class) then
				child:Destroy()
				break
			end
		end
	end
	local palette = Outfit.palette(index)
	local function paint(names: { string }, rgb: { number })
		for _, name in names do
			local part = character:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				part.Color = colour(rgb)
			end
		end
	end
	paint(SKIN, palette.skin)
	paint(SHIRT, palette.shirt)
	paint(PANTS, palette.pants)
	paint(SHOES, palette.shoes)
end

function OutfitService:Start()
	local function track(player: Player)
		if not joined[player] then
			local slot = 0
			for _, other in joined do
				slot = math.max(slot, other)
			end
			joined[player] = slot + 1
		end
		player.CharacterAdded:Connect(function(character)
			if character:WaitForChild("UpperTorso", 10) then
				self:Apply(character, joined[player])
			end
		end)
		if player.Character then
			self:Apply(player.Character, joined[player])
		end
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		joined[player] = nil
	end)
end

return OutfitService
