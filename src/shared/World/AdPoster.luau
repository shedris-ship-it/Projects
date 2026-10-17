-- Our own poster on an ad frame's face (LB6; Logic/Ads, Data/Posters): its
-- uploaded image, or until then the frame's lit blank (an empty lightbox's
-- THIS SPACE AVAILABLE, the video store's, a screen's colour bars). The
-- server puts it on a frame whose AdGui isn't up (World/MallBuilder); a
-- client puts it on for its own player when they can't be shown ads
-- (Controllers/AdController), so the mall looks the same to everyone. Unlit
-- and a little bright, as a backlit face is; on the generator, so it browns
-- out with the mall (Controllers/MallController).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ads = require(Shared.Logic.Ads)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Posters = require(Shared.Data.Posters)

local AdPoster = {}

AdPoster.Name = "Poster" -- the SurfaceGui's

local INK = Color3.fromRGB(74, 58, 42)

-- An empty frame in a dead mall: the diffuser yellowed with age, brightest
-- where its tubes are.
local function blankPanel(parent: Instance, blank)
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	panel.BorderSizePixel = 0
	panel.Parent = parent
	local tubes = Instance.new("UIGradient")
	tubes.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(196, 182, 150)),
		ColorSequenceKeypoint.new(0.3, Color3.fromRGB(236, 226, 200)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(236, 226, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 182, 150)),
	})
	tubes.Parent = panel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.84, 0.44)
	label.Position = UDim2.fromScale(0.08, 0.12)
	label.BackgroundTransparency = 1
	label.Text = blank.big
	label.TextScaled = true
	label.TextColor3 = INK
	label.Font = Enum.Font.Bodoni
	label.Parent = panel
	local rule = Instance.new("Frame")
	rule.Size = UDim2.new(0.36, 0, 0, 3)
	rule.Position = UDim2.fromScale(0.32, 0.64)
	rule.BackgroundColor3 = INK
	rule.BorderSizePixel = 0
	rule.Parent = panel
	local small = Instance.new("TextLabel")
	small.Size = UDim2.fromScale(0.8, 0.1)
	small.Position = UDim2.fromScale(0.1, 0.72)
	small.BackgroundTransparency = 1
	small.Text = blank.small
	small.TextScaled = true
	small.TextColor3 = INK
	small.Font = Enum.Font.SourceSansSemibold
	small.Parent = panel
end

-- A TV off the air: colour bars, and the card over them.
local BARS = {
	{ 192, 192, 192 },
	{ 192, 192, 0 },
	{ 0, 192, 192 },
	{ 0, 192, 0 },
	{ 192, 0, 192 },
	{ 192, 0, 0 },
	{ 0, 0, 192 },
}
local STRIP = {
	{ 0, 0, 192 },
	{ 16, 16, 16 },
	{ 192, 0, 192 },
	{ 16, 16, 16 },
	{ 0, 192, 192 },
	{ 16, 16, 16 },
	{ 192, 192, 192 },
}
local FOOT = { { 0, 33, 76 }, { 235, 235, 235 }, { 50, 0, 106 }, { 16, 16, 16 }, { 16, 16, 16 } }

local function row(parent: Instance, colours, top: number, height: number)
	for i, c in colours do
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(1 / #colours, height)
		bar.Position = UDim2.fromScale((i - 1) / #colours, top)
		bar.BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3])
		bar.BorderSizePixel = 0
		bar.Parent = parent
	end
end

local function barsPanel(parent: Instance, blank)
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
	panel.BorderSizePixel = 0
	panel.Parent = parent
	row(panel, BARS, 0, 0.67)
	row(panel, STRIP, 0.67, 0.08)
	row(panel, FOOT, 0.75, 0.25)
	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(0.62, 0.2)
	card.Position = UDim2.fromScale(0.19, 0.24)
	card.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
	card.BorderSizePixel = 0
	card.Parent = panel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.7)
	label.Position = UDim2.fromScale(0.05, 0.15)
	label.BackgroundTransparency = 1
	label.Text = blank.big
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(236, 236, 236)
	label.Font = Enum.Font.SourceSansBold
	label.Parent = card
end

-- Puts our poster on `face` (its Front), for the frame `slot` (Data/Mall
-- `Ads`), in place of any there. Returns the SurfaceGui.
function AdPoster.build(face: BasePart, slot): SurfaceGui
	AdPoster.clear(face)
	local gui = Instance.new("SurfaceGui")
	gui.Name = AdPoster.Name
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = Config.Ads.Face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = Config.Ads.PixelsPerStud
	local image = Ads.image(slot, Posters)
	if image then
		local picture = Instance.new("ImageLabel")
		picture.Name = "Picture"
		picture.Size = UDim2.fromScale(1, 1)
		picture.BackgroundColor3 = Color3.fromRGB(20, 18, 16)
		picture.BorderSizePixel = 0
		picture.Image = image
		picture.ScaleType = Enum.ScaleType.Stretch
		picture.Parent = gui
	else
		local blank = Posters.Blank[Ads.kind(slot)] or Posters.Blank.lightbox
		if blank.bars then
			barsPanel(gui, blank)
		else
			blankPanel(gui, blank)
		end
	end
	gui.Parent = face
	CollectionService:AddTag(gui, Constants.Tags.MallPower)
	return gui
end

-- Takes our poster off `face`.
function AdPoster.clear(face: BasePart)
	local old = face:FindFirstChild(AdPoster.Name)
	if old then
		old:Destroy()
	end
end

return AdPoster
