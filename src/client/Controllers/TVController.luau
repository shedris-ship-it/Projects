-- A television's static (the owner, 2026-10-13: "when you turn it on it has
-- white noise + the static ... the white noise should obviously have a
-- lighting effect"). While a TV's Television fixture runs (Services/
-- InteractService: anyone turning up its static, or him doing it to lure
-- you), each client draws snow on its screen and lets the static's cold,
-- flickering light out into the room. The hiss is the fixture's own loop
-- (Controllers/AudioController). Decoration only: what counts as lit is
-- still WorldService's light rule. A TV far from you sleeps. "Reduce
-- flicker" slows the snow and holds the light steady.
--
-- The snow is one noise sheet drawn once into an EditableImage, shown a
-- window at a time at a new place every flip (no upload); where Roblox
-- won't make one, the lens's film grain frames stand in (Assets.Lens).

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)

local T = Config.TV

local TVController = {}

function TVController:Init(controllers)
	self.state = controllers.StateController
end

local SHEET = Vector2.new(128, 512) -- the noise sheet, in pixels
local WINDOW = Vector2.new(128, 92) -- what a screen shows of it at once

local tvs = {} -- screen -> its static
local sheet: any = nil -- the EditableImage's content, once made (false: it couldn't be)

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- The noise: mostly dim grey specks with bright ones among them, a faint
-- blue cast, and now and then a brighter streak along a row (a CRT's snow).
local function makeSheet()
	if sheet ~= nil then
		return sheet
	end
	local ok, image = pcall(function()
		return AssetService:CreateEditableImage({ Size = SHEET })
	end)
	if not ok or not image then
		sheet = false
		return sheet
	end
	local rng = Random.new(1988)
	local data = buffer.create(SHEET.X * SHEET.Y * 4)
	for y = 0, SHEET.Y - 1 do
		local streak = rng:NextNumber() < 0.04 and rng:NextNumber(0.15, 0.35) or 0
		for x = 0, SHEET.X - 1 do
			local v = math.clamp(rng:NextNumber() ^ 1.6 + streak, 0, 1) * 255
			local i = (y * SHEET.X + x) * 4
			buffer.writeu8(data, i, v * 0.94)
			buffer.writeu8(data, i + 1, v * 0.97)
			buffer.writeu8(data, i + 2, math.min(255, v * 1.04))
			buffer.writeu8(data, i + 3, 255)
		end
	end
	local wrote = pcall(function()
		image:WritePixelsBuffer(Vector2.zero, SHEET, data)
	end)
	sheet = wrote and Content.fromObject(image) or false
	return sheet
end

local function build(screen: BasePart)
	-- The prop's front (+Z, toward the room) is the screen's Back face.
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Static"
	gui.Face = Enum.NormalId.Back
	gui.LightInfluence = 0
	gui.Brightness = T.Glow
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = WINDOW * 2
	gui.ClipsDescendants = true
	gui.Enabled = false
	local snow = Instance.new("ImageLabel")
	snow.Name = "Snow"
	snow.Size = UDim2.fromScale(1, 1)
	snow.BackgroundColor3 = Color3.fromRGB(70, 72, 78)
	snow.BorderSizePixel = 0
	snow.ResampleMode = Enum.ResamplerMode.Pixelated
	local content = makeSheet()
	local grain = false
	if content then
		snow.ImageContent = content
		snow.ImageRectSize = WINDOW
	else
		-- (No EditableImage here: the film grain's frames, coarse and bright.)
		grain = true
		snow.Image = Assets.Lens.Grain[1]
		snow.ImageRectSize = WINDOW
		snow.ImageColor3 = Color3.new(1, 1, 1)
	end
	snow.Parent = gui
	local layers = { snow }
	if grain then
		-- (A second frame over it, so the specks are as thick as snow.)
		local over = snow:Clone()
		over.Name = "Snow2"
		over.BackgroundTransparency = 1
		over.ZIndex = 2
		over.Image = Assets.Lens.Grain[2]
		over.Parent = gui
		table.insert(layers, over)
	end
	-- A darker band rolling slowly down, as a badly tuned set's does.
	local roll = Instance.new("Frame")
	roll.Name = "Roll"
	roll.Size = UDim2.fromScale(1, 0.22)
	roll.BackgroundColor3 = Color3.new(0, 0, 0)
	roll.BackgroundTransparency = 0.55
	roll.BorderSizePixel = 0
	roll.ZIndex = 3
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = roll
	roll.Parent = gui
	gui.Parent = screen
	-- The static's light: a point just out from the glass, so it spreads
	-- over the floor, the walls round the set and the ceiling as a screen's
	-- glow does (a SurfaceLight's cone missed everything near the set, seen
	-- 2026-10-13); the set's own cabinet shades the wall behind it.
	local at = Instance.new("Attachment")
	at.Name = "StaticLightAt"
	at.Position = Vector3.new(0, 0, T.Out) -- (+Z: the screen's face toward the room)
	at.Parent = screen
	local light = Instance.new("PointLight")
	light.Name = "StaticLight"
	light.Color = rgb(T.Colour)
	light.Range = T.Range
	light.Brightness = 0
	light.Shadows = true
	light.Enabled = false
	light.Parent = at
	return {
		screen = screen,
		model = screen.Parent,
		gui = gui,
		layers = layers,
		roll = roll,
		grain = grain,
		light = light,
		on = false,
		nextFlip = 0,
		level = 0.5,
		rolled = 0,
	}
end

local function add(screen: Instance)
	if not screen:IsA("BasePart") or tvs[screen] then
		return
	end
	tvs[screen] = build(screen)
	screen.Destroying:Connect(function()
		tvs[screen] = nil
	end)
end

local function switch(tv, on: boolean, preset)
	if tv.on == on then
		return
	end
	tv.on = on
	tv.gui.Enabled = on
	tv.light.Enabled = on
	if on then
		tv.light.Shadows = preset.lightShadows ~= false
	end
end

function TVController:Start()
	for _, screen in CollectionService:GetTagged(Constants.Tags.TV) do
		add(screen)
	end
	CollectionService:GetInstanceAddedSignal(Constants.Tags.TV):Connect(add)

	RunService.RenderStepped:Connect(function(dt)
		if next(tvs) == nil then
			return
		end
		local camera = Workspace.CurrentCamera
		local from = camera and camera.CFrame.Position or Vector3.zero
		local _, preset = self.state:Graphics()
		local steady = self.state.settings and self.state.settings.reduceFlicker == true
		local now = os.clock()
		for screen, tv in tvs do
			local running = tv.model ~= nil and tv.model:GetAttribute("Running") == true
			local near = screen.Parent ~= nil and (screen.Position - from).Magnitude < T.Near
			switch(tv, running and near, preset)
			if not tv.on then
				continue
			end
			-- New snow every flip (fewer with Reduce flicker), the light
			-- jumping with it.
			if now >= tv.nextFlip then
				tv.nextFlip = now + 1 / (steady and T.Steady or T.Flips)
				local span = (tv.grain and Vector2.new(512, 512) or SHEET) - WINDOW
				for _, layer in tv.layers do
					-- (cosmetic: client timing only)
					layer.ImageRectOffset =
						Vector2.new(math.random(0, math.floor(span.X)), math.random(0, math.floor(span.Y)))
					if tv.grain then
						layer.Image = Assets.Lens.Grain[math.random(1, #Assets.Lens.Grain)]
					end
				end
				tv.level = steady and 0.5 or math.random()
			end
			local b = T.Brightness
			tv.light.Brightness = b[1] + (b[2] - b[1]) * tv.level
			tv.rolled = (tv.rolled + dt * T.Roll) % 1.22
			tv.roll.Position = UDim2.fromScale(0, tv.rolled - 0.22)
		end
	end)
end

return TVController
