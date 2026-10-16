-- Everyone in the house wears period clothes (owner, 2026-10-03): faded
-- shirts and jeans instead of modern avatars, so the squad looks like one
-- group of investigators in 1988. LoadCharacterAppearance is off, so
-- characters spawn in the body this gives them and this dresses them.
--
-- The body (V6, the owner's pick, 2026-10-14): ROBLOX Boy or Girl, chosen at
-- first play and in Settings (`body`, Data/Wardrobe), spawned with
-- LoadCharacterWithHumanoidDescription and changed in place when you pick
-- the other.
--
-- The clothes (V6): each squad member's outfit (a top, trousers and shoes
-- from Data/Wardrobe), its modelled pieces welded on the body's parts
-- (World/Kit.wear), over skin. Until a garment's meshes are in (Data/Kit
-- Wear) the body is painted in its colours instead (its `paint`, or
-- Logic/Outfit.palette's), as before.
--
-- Since LB3 (the boutique) the outfit is the player's own: what they own
-- and chose to wear (Logic/Closet.outfit), their squad slot's in any slot
-- they haven't chosen; in the changing booth, what they're trying on
-- (Services/ShopService, SetTrying).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Closet = require(Shared.Logic.Closet)
local Kit = require(Shared.World.Kit)
local Outfit = require(Shared.Logic.Outfit)
local Wardrobe = require(Shared.Data.Wardrobe)

local OutfitService = {}

local SHIRT = { "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" }
local PANTS = { "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg" }
local SKIN = { "Head", "LeftHand", "RightHand" }
local SHOES = { "LeftFoot", "RightFoot" }
local STRAY = { "Accessory", "Shirt", "Pants", "ShirtGraphic", "BodyColors", "CharacterMesh" }

local joined = {} -- player -> squad slot, in the order they arrived
local bodyOf = {} -- player -> the body their character was dressed in
local trying = {} -- player -> the outfit they're trying on in the changing booth
local watched = setmetatable({}, { __mode = "k" }) -- character -> its look, once its new parts are dressed as they come

local function colour(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

function OutfitService:Init(services)
	self.Data = services.DataService
end

-- The body a player chose (or the default).
function OutfitService:BodyOf(player: Player): string
	local data = self.Data and self.Data:Get(player)
	local body = data and data.Settings and data.Settings.body
	return Wardrobe.Bodies[body] and body or Wardrobe.DefaultBody
end

-- A description of the player's body, in their skin tone.
function OutfitService:Description(player: Player): HumanoidDescription
	local body = Wardrobe.Bodies[self:BodyOf(player)]
	local desc = Instance.new("HumanoidDescription")
	for key, id in body.parts do
		(desc :: any)[key] = id
	end
	local skin = colour(Outfit.palette(joined[player] or 1).skin)
	for _, key in { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" } do
		(desc :: any)[key] = skin
	end
	return desc
end

-- Spawn a player in their body (LobbyService, in place of LoadCharacter).
function OutfitService:LoadCharacter(player: Player)
	bodyOf[player] = self:BodyOf(player)
	local ok, err = pcall(function()
		player:LoadCharacterWithHumanoidDescription(self:Description(player))
	end)
	if not ok then
		-- (The body's parts couldn't load: the plain body, still dressed.)
		warn("[Consensus] body for " .. player.Name .. " failed: " .. tostring(err))
		player:LoadCharacter()
	end
end

-- What a player wears now: what they're trying on in the booth, else
-- their own (Logic/Closet.outfit).
function OutfitService:OutfitOf(player: Player)
	if trying[player] then
		return trying[player]
	end
	return Closet.outfit(self.Data and self.Data:Get(player), joined[player] or 1)
end

-- What a character wears (`outfit`, { Top, Bottom, Shoes }; squad slot
-- `index` for its skin and the painted colours): for each body part, its
-- colour and the wardrobe pieces on it (those whose garment is wholly in).
function OutfitService:Look(outfit, index: number)
	local palette = Outfit.palette(index)
	local look = { colours = {}, pieces = {} }
	local dressed = {}
	local shoes = Wardrobe.Garments[outfit.Shoes]
	-- (High-tops are worn in place of the trousers' shins, once they're in.)
	local shinless = shoes ~= nil and shoes.over == true and Kit.hasWear(shoes.pieces)
	for _, slot in Wardrobe.Slots do
		local garment = Wardrobe.Garments[outfit[slot]]
		if garment and Kit.hasWear(garment.pieces) then
			for part, mesh in garment.pieces do
				local shin = part == "LeftLowerLeg" or part == "RightLowerLeg"
				if not (slot == "Bottom" and shin and shinless) then
					look.pieces[part] = look.pieces[part] or {}
					table.insert(look.pieces[part], mesh)
				end
			end
			dressed[slot] = true
		end
	end
	-- Under clothes, skin (a gap at a wrist shows a wrist); where a garment
	-- isn't in yet, its colour painted on as before.
	local skin = palette.skin
	local function paint(names, rgb)
		for _, name in names do
			look.colours[name] = colour(rgb)
		end
	end
	local function shade(slot, fallback)
		local garment = Wardrobe.Garments[outfit[slot]]
		return garment and garment.paint or fallback
	end
	paint(SKIN, skin)
	paint(SHIRT, dressed.Top and skin or shade("Top", palette.shirt))
	paint(PANTS, dressed.Bottom and skin or shade("Bottom", palette.pants))
	paint(SHOES, dressed.Shoes and skin or shade("Shoes", palette.shoes))
	local top = Wardrobe.Garments[outfit.Top]
	if top and top.short then
		paint({ "LeftLowerArm", "RightLowerArm" }, skin)
	end
	if dressed.Bottom then
		look.colours.LowerTorso = colour(skin)
	end
	return look
end

-- Dresses one body part: its colour, and its pieces (any it wore before go).
local function dressPart(part: BasePart, look)
	local c = look.colours[part.Name]
	if c then
		part.Color = c
	end
	for _, child in part:GetChildren() do
		if child:GetAttribute("Wear") then
			child:Destroy()
		end
	end
	for _, mesh in look.pieces[part.Name] or {} do
		Kit.wear(part, mesh)
	end
end

-- Dresses a character in slot `index`, in `outfit` (a player's own:
-- OutfitOf; the squad slot's when not given, for stand-ins).
function OutfitService:Apply(character: Model, index: number, outfit)
	for _, child in character:GetChildren() do
		for _, class in STRAY do
			if child:IsA(class) then
				child:Destroy()
				break
			end
		end
	end
	local look = self:Look(outfit or Outfit.wear(index), index)
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and (look.colours[child.Name] or look.pieces[child.Name]) then
			dressPart(child, look)
		end
	end
	-- A body's parts arrive after the character does (a description's
	-- meshes swap in, and again when you change body): dress each as it
	-- comes. (Seen in Studio, 2026-10-14: painted at spawn, every part was
	-- then replaced, grey.)
	local first = watched[character] == nil
	watched[character] = look
	if first then
		character.ChildAdded:Connect(function(child)
			local current = watched[character]
			if current and child:IsA("BasePart") and (current.colours[child.Name] or current.pieces[child.Name]) then
				task.defer(function()
					if child.Parent == character then
						dressPart(child, current)
					end
				end)
			end
		end)
	end
end

-- They picked the other body: change it on the character they have.
function OutfitService:_redress(player: Player)
	local body = self:BodyOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if body == bodyOf[player] or not humanoid then
		return
	end
	bodyOf[player] = body
	local ok, err = pcall(function()
		humanoid:ApplyDescription(self:Description(player))
	end)
	if not ok then
		warn("[Consensus] new body for " .. player.Name .. " failed: " .. tostring(err))
	end
	if character.Parent then
		self:Apply(character, joined[player], self:OutfitOf(player))
	end
end

-- Dresses a player again in what they wear now (bought, chosen, tried on).
function OutfitService:Redress(player: Player)
	local character = player.Character
	if character and character.Parent then
		self:Apply(character, joined[player] or 1, self:OutfitOf(player))
	end
end

-- The changing booth (Services/ShopService): `outfit` tried on, or nil to
-- go back to their own.
function OutfitService:SetTrying(player: Player, outfit)
	trying[player] = outfit
	self:Redress(player)
end

-- F2 `outfit <n>`: dress yourself as squad member n (DebugService; your
-- own choices still win in the slots you've chosen).
function OutfitService:DebugWear(player: Player, index: number): string
	joined[player] = math.max(1, math.floor(index))
	self:Redress(player)
	local outfit = self:OutfitOf(player)
	return table.concat({ outfit.Top, outfit.Bottom, outfit.Shoes }, ", ")
end

-- F2 `outfit lineup`: both bodies in every outfit, standing in one row in
-- front of `at` (facing it), to judge the clothes from the front;
-- `outfit clear` takes them away.
function OutfitService:DebugLineup(at: CFrame?): number
	local old = workspace:FindFirstChild("DebugLineup")
	if old then
		old:Destroy()
	end
	if not at then
		return 0
	end
	local folder = Instance.new("Folder")
	folder.Name = "DebugLineup"
	folder.Parent = workspace
	local count = 0
	for row, bodyName in Wardrobe.BodyOrder do
		for index = 1, #Wardrobe.Outfits do
			local desc = Instance.new("HumanoidDescription")
			for key, id in Wardrobe.Bodies[bodyName].parts do
				(desc :: any)[key] = id
			end
			local ok, model = pcall(function()
				return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
			end)
			if ok and model then
				model.Name = bodyName .. index
				local across = (row - 1) * #Wardrobe.Outfits + index
				local total = #Wardrobe.BodyOrder * #Wardrobe.Outfits
				local spot = at * CFrame.new((across - (total + 1) / 2) * 3.2, 0, -8) * CFrame.Angles(0, math.pi, 0)
				model:PivotTo(spot)
				local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					root.Anchored = true
				end
				model.Parent = folder
				self:Apply(model, index)
				count += 1
			end
		end
	end
	return count
end

-- F2 `crowd <n>`: n stand-ins for a full lobby (LB1b's 50-player
-- measurement), each a real body in a real outfit, both bodies and every
-- outfit in turn, standing at `spots` (CFrames on the floor) with Roblox's
-- idle playing, as other players' characters would be drawn. `crowd clear`
-- (no spots) takes them away. Returns how many stand.
function OutfitService:DebugCrowd(spots: { CFrame }?): number
	local old = workspace:FindFirstChild("DebugCrowd")
	if old then
		old:Destroy()
	end
	if not spots or #spots == 0 then
		return 0
	end
	local folder = Instance.new("Folder")
	folder.Name = "DebugCrowd"
	folder.Parent = workspace
	local idle = Instance.new("Animation")
	idle.AnimationId = "rbxassetid://507766666" -- (Roblox's R15 idle)
	local count = 0
	for i, spot in spots do
		local bodyName = Wardrobe.BodyOrder[(i - 1) % #Wardrobe.BodyOrder + 1]
		local desc = Instance.new("HumanoidDescription")
		for key, id in Wardrobe.Bodies[bodyName].parts do
			(desc :: any)[key] = id
		end
		local ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
		if ok and model then
			model.Name = "Stand-in" .. i
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local hip = humanoid and humanoid.HipHeight or 2
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			model:PivotTo(spot * CFrame.new(0, hip + (root and root.Size.Y / 2 or 1), 0))
			if root then
				root.Anchored = true
			end
			model.Parent = folder
			self:Apply(model, (i - 1) % #Wardrobe.Outfits + 1)
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if animator then
				pcall(function()
					local track = animator:LoadAnimation(idle)
					track.Looped = true
					track:Play()
				end)
			end
			count += 1
			if i % 10 == 0 then
				task.wait() -- (a lobby's worth at once would stall the server a moment)
			end
		end
	end
	return count
end

function OutfitService:Start()
	-- (The clothes are kit meshes: the server builds them once from their ids.
	-- Until they're in, characters are painted; then everyone is dressed.)
	task.spawn(function()
		Kit.preload()
		Kit.share(Kit.toolNames())
		for player in joined do
			self:Redress(player)
		end
	end)
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
				self:Apply(character, joined[player], self:OutfitOf(player))
			end
		end)
		-- (The body's own colours land after CharacterAdded: dress again once
		-- its appearance has loaded.)
		player.CharacterAppearanceLoaded:Connect(function(character)
			if character.Parent then
				self:Apply(character, joined[player], self:OutfitOf(player))
			end
		end)
		if player.Character then
			self:Redress(player)
		end
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		joined[player] = nil
		bodyOf[player] = nil
		trying[player] = nil
	end)
	if self.Data then
		self.Data.SettingsSaved:Connect(function(player)
			task.spawn(self._redress, self, player)
		end)
	end
end

return OutfitService
