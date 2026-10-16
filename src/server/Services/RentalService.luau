-- The video store's tapes (docs/plans/lobby-rework.md, "Video rental:
-- picking a case"; LB2). A rental box for each location on the NEW RELEASES
-- island (Data/Mall Tapes): take The Halfway House and carry it to a car,
-- where it goes in the deck (Services/CarService) and becomes the car's
-- case; St. Odile Ward stands there marked COMING SOON. The tape is the only
-- way to pick a case. Take it again to put it back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Locations = require(Shared.Data.Locations)
local Mall = require(Shared.Data.Mall)
local Net = require(Shared.Net)
local PropFactory = require(Shared.World.PropFactory)

local PA = Constants.PlayerAttributes

local RentalService = {}

-- A rental box's look: its colour and the cover's two lines.
local COVERS = {
	HalfwayHouse = { box = { 30, 26, 34 }, ink = { 236, 226, 196 }, accent = { 200, 40, 34 } },
	StOdileWard = { box = { 210, 214, 216 }, ink = { 40, 46, 52 }, accent = { 60, 110, 150 } },
}

function RentalService:Init(services)
	self.services = services
end

-- A rental box: a part with its cover drawn on its front (`face`) and, when
-- it's not out yet, a COMING SOON sticker.
local function box(parent: Instance, name: string, size: Vector3, cf: CFrame, location, face: Enum.NormalId)
	local look = COVERS[location.id] or COVERS.HalfwayHouse
	local c = function(t)
		return Color3.fromRGB(t[1], t[2], t[3])
	end
	local part = PropFactory.part(parent, name, size, cf, c(look.box), Enum.Material.SmoothPlastic, {
		collide = false,
		castShadow = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 120
	gui.LightInfluence = 0.6
	gui.Parent = part
	local band = Instance.new("Frame")
	band.Size = UDim2.new(1, 0, 0.12, 0)
	band.Position = UDim2.fromScale(0, 0.06)
	band.BackgroundColor3 = c(look.accent)
	band.BorderSizePixel = 0
	band.Parent = gui
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.9, 0, 0.45, 0)
	title.Position = UDim2.fromScale(0.05, 0.28)
	title.BackgroundTransparency = 1
	title.Text = string.upper(location.name)
	title.TextScaled = true
	title.TextWrapped = true
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = c(look.ink)
	title.Parent = gui
	local foot = Instance.new("TextLabel")
	foot.Size = UDim2.new(0.9, 0, 0.12, 0)
	foot.Position = UDim2.fromScale(0.05, 0.8)
	foot.BackgroundTransparency = 1
	foot.Text = location.available and "VHS · RENT ME" or "COMING SOON"
	foot.TextScaled = true
	foot.Font = Enum.Font.SourceSansBold
	foot.TextColor3 = location.available and c(look.ink) or Color3.fromRGB(200, 40, 34)
	foot.Parent = gui
	return part
end

-- The boxes on the island, in the mall MallBuilder made.
function RentalService:Build(parent: Instance, origin: Vector3)
	-- (A run server builds only the garage: no video store, no shelf.)
	local places = self.services.PlaceService
	if places and places:IsRun() then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Tapes"
	folder.Parent = parent
	for _, spot in Mall.Tapes or {} do
		local location = Locations.ById[spot.location]
		if location then
			-- Its front faces +x, the way through the store; stood on the shelf
			-- and leaning back on the tapes behind it.
			local size = Vector3.new(0.72, 1.12, 0.18)
			local cf = CFrame.new(origin + Vector3.new(spot.x, spot.y, spot.z))
				* CFrame.Angles(0, math.rad(-90), 0)
				* CFrame.Angles(math.rad(8), 0, 0)
				* CFrame.new(0, size.Y / 2, 0)
			local part = box(folder, "Tape_" .. location.id, size, cf, location, Enum.NormalId.Front)
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = location.available and "Rent" or "Look"
			prompt.ObjectText = location.name
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt.Parent = part
			prompt.Triggered:Connect(function(player)
				self:_shelf(player, location)
			end)
		end
	end
end

function RentalService:_shelf(player: Player, location)
	if not location.available then
		Net.get("Notify"):FireClient(player, location.name .. " isn't out on video yet. Coming soon.", "info")
		return
	end
	if player:GetAttribute(PA.Tape) == location.id then
		self:Take(player) -- put back
		Net.get("Notify"):FireClient(player, "You put the tape back.", "info")
		return
	end
	self:Give(player, location.id)
	Net.get("Notify"):FireClient(player, "You've got " .. location.name .. ". Take it to a car in the garage.", "info")
end

-- The tape in your right hand.
local function hold(player: Player, locationId: string)
	local character = player.Character
	local hand = character and character:FindFirstChild("RightHand") :: BasePart?
	if not hand then
		return
	end
	local old = character:FindFirstChild("RentalTape")
	if old then
		old:Destroy()
	end
	local location = Locations.ById[locationId]
	local part = box(
		character,
		"RentalTape",
		Vector3.new(0.6, 0.95, 0.16),
		hand.CFrame * CFrame.new(0, -0.45, -0.2),
		location,
		Enum.NormalId.Front
	)
	part.Anchored = false
	part.Massless = true
	part.CanQuery = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = part
	weld.Parent = part
end

function RentalService:Give(player: Player, locationId: string)
	player:SetAttribute(PA.Tape, locationId)
	hold(player, locationId)
end

-- Takes the tape out of your hand (into a car's deck, or back on the shelf).
function RentalService:Take(player: Player)
	player:SetAttribute(PA.Tape, nil)
	local tape = player.Character and player.Character:FindFirstChild("RentalTape")
	if tape then
		tape:Destroy()
	end
end

function RentalService:Start()
	local function onPlayer(player: Player)
		-- (A new body keeps the tape in its hand.)
		player.CharacterAdded:Connect(function(character)
			local tape = player:GetAttribute(PA.Tape)
			if tape then
				character:WaitForChild("RightHand", 10)
				hold(player, tape)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return RentalService
