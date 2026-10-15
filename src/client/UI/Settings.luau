-- First-launch screen and settings (doc section 8, "UI and accessibility"):
-- graphics presets, film grain, reduce flicker, lens flares, subtitles,
-- colour-blind-safe pings, the meters, FOV and volume. Also explains how to
-- play. In the 1988 interface (V7): two typed sheets, the how-to and a form
-- you tick.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent.Parent.Lib.Ui)
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local GraphicsPreset = require(ReplicatedStorage:WaitForChild("Shared").Logic.GraphicsPreset)
local Wardrobe = require(ReplicatedStorage:WaitForChild("Shared").Data.Wardrobe)

-- The next body in the wardrobe's order (V6: Boy, Girl).
local function nextBody(current: string?): string
	local order = Wardrobe.BodyOrder
	local at = table.find(order, current or Wardrobe.DefaultBody) or 0
	return order[at % #order + 1]
end

-- The real keys, as Controllers/ActionController binds them (WP9: the
-- outside playtest found the bolt on the torch's key and no list anywhere).
local CONTROLS = table.concat({
	"E  open, pick up, use  ·  hold E  drag a door or drawer, push furniture  ·  carrying: click throws, E puts down",
	"hold click  drag or carry too  ·  right click  throw  ·  F  torch up or away  ·  R  use the tool in hand  ·  X  put down",
	"1 2  a tool in your hand (again: away)  ·  wheel  next  ·  Ctrl  crouch  ·  Shift  run  ·  Space  jump (hidden: hold your breath)  ·  V  bolt  ·  Q  squeeze past",
	"Tab  map and journal  ·  G  ping  ·  C  callouts  ·  Enter  say a line  ·  E  leave a puzzle or a note  ·  F1  settings  ·  F2  debug",
}, "\n")

local Settings = {}
Settings.__index = Settings

-- Three bullets (the audit of 2026-10-06: the eight-bullet wall taught
-- nothing). The house teaches the rest as it comes up (UI/Tips). The third
-- is his three rules ("a Guest you can read", 2026-10-11), word for word as
-- the tips say them.
local HOW_TO = table.concat({
	"The front door has locked behind you. The dining table is laid for a guest, with empty places.",
	"",
	"• Find the family's heirlooms and set each at its place at the table. Then get out by the front door.",
	"• The house is locked wing by wing. Keys and doors share a mark; notes and puzzles point the way. E opens and picks up; hold E (or the mouse) on anything to drag, pull or carry it.",
	"• Something lives here, and it keeps three rules:",
	"   1. Watch him. He only creeps closer while nobody's looking; two of you watching him in the light stop him (alone, your beam), until he's after someone.",
	"   2. Don't pester him. In his face or on his heels, his head turns: back off. Keep on and he warns you once, then comes for you with his hands out.",
	"   3. When he hunts: break his sight (shut a door, throw something), hide (a wardrobe, under a bed), or get to a lit lantern.",
	"   Caught, you're down: a friend has 30 seconds to hold E on you. Talk: Tab is the map, G pings.",
}, "\n")

-- Laid out at this size; Ui.fit shrinks it on a small screen.
local WIDTH, HEIGHT = 980, 690
local ROW = 25
local INSET = 34 -- the paper's worn edge

function Settings.new(ctx)
	local self = setmetatable({ ctx = ctx }, Settings)
	local gui = Ui.screen("ConsensusSettings", 70, ctx.playerGui)
	gui.Enabled = false
	self.gui = gui
	Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Parent = gui,
	})
	local root = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Ui.fit(root, WIDTH, HEIGHT)
	Ui.modal(root)

	-- The left sheet: how to play and the keys, typed.
	local _, how = Ui.paper("Sheet", {
		Size = UDim2.fromOffset(540, HEIGHT),
		Rotation = -0.8,
		Parent = root,
	})
	local page = Ui.new("Frame", {
		Position = UDim2.fromOffset(INSET, INSET - 6),
		Size = UDim2.new(1, -INSET * 2, 1, -INSET * 2 + 6),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = how,
	})
	Ui.title("Before you go in", { Size = UDim2.new(1, 0, 0, 40), TextSize = 34, ZIndex = 3, Parent = page })
	Ui.rule(page, 42, Ui.Theme.type, 0.6).ZIndex = 3
	self.howTo = Ui.typed(HOW_TO, {
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 372),
		TextSize = 15,
		LineHeight = 1.05,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
		Parent = page,
	})
	Ui.typed("THE KEYS", {
		Position = UDim2.fromOffset(0, 432),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
		ZIndex = 3,
		Parent = page,
	})
	self.controls = Ui.typed(CONTROLS, {
		Position = UDim2.fromOffset(0, 456),
		Size = UDim2.new(1, 0, 0, 132),
		TextSize = 12,
		TextColor3 = Ui.Theme.typeDim,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
		Parent = page,
	})
	-- (A note in red pencil in the margin.)
	Ui.hand('Photosensitivity: this game uses flickering lights. Turn on "Reduce flicker" if you need to.', {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 21,
		LineHeight = 0.9,
		TextColor3 = Ui.Theme.red,
		ZIndex = 3,
		Parent = page,
	})

	-- The right sheet: a typed form, ticked.
	local _, form = Ui.paper("Sheet", {
		Position = UDim2.fromOffset(556, 4),
		Size = UDim2.fromOffset(WIDTH - 556, HEIGHT - 8),
		Rotation = 0.9,
		Parent = root,
	})
	local sheet = Ui.new("Frame", {
		Position = UDim2.fromOffset(INSET - 4, INSET - 8),
		Size = UDim2.new(1, -INSET * 2 + 8, 1, -INSET * 2 + 8),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = form,
	})
	Ui.title("Settings", { Size = UDim2.new(1, 0, 0, 40), TextSize = 34, ZIndex = 3, Parent = sheet })
	Ui.typed("FORM 88-2  ·  tick what you need", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 16),
		Size = UDim2.fromOffset(220, 16),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Ui.Theme.typeDim,
		ZIndex = 3,
		Parent = sheet,
	})
	Ui.rule(sheet, 42, Ui.Theme.type, 0.6).ZIndex = 3
	local column = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = sheet,
	}, { Ui.list(3) })
	local function line(text: string, order: number, onClick)
		return Ui.paperButton(text, {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, ROW),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
			Parent = column,
		}, onClick)
	end
	-- Choices cycle on a click (the visual rework: Logic/GraphicsPreset).
	self.choices = {}
	for i, option in
		{
			-- Your body, asked on the first launch too (V6).
			{ key = "body", label = "Body", next = nextBody },
			{ key = "graphics", label = "Graphics", next = GraphicsPreset.nextSetting },
			{ key = "grain", label = "Film grain", next = GraphicsPreset.nextGrain },
		}
	do
		local button = line("", -10 + i, function()
			ctx.state:SetSetting(option.key, option.next(ctx.state.settings[option.key]))
			self:Render()
		end)
		self.choices[option.key] = { button = button, label = option.label }
	end
	self.toggles = {}
	for i, option in
		{
			{ key = "reduceFlicker", label = "Reduce flicker" },
			{ key = "lensFlares", label = "Lens flares and glare" },
			{ key = "subtitles", label = "Subtitles for sound cues" },
			{ key = "colorblind", label = "Colour-blind-safe pings" },
			{ key = "centerDot", label = "Centre dot (aiming aid)" },
			{ key = "showMeters", label = "Show meters (stamina, torch, tools)" },
			{ key = "tips", label = "Show tips in the house" },
			{ key = "crouchToggle", label = "Ctrl toggles crouch (off: hold)" },
			{ key = "hideBody", label = "Hide your own body (first person)" },
			{ key = "skipCutscenes", label = "Skip cutscenes" },
		}
	do
		local button = line(option.label, i, function()
			ctx.state:SetSetting(option.key, not ctx.state.settings[option.key])
			self:Render()
		end)
		-- A box typed on the form, an X typed in it (its own column, so the
		-- words line up ticked or not).
		Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 36), Parent = button })
		local box = Ui.typed("", {
			Position = UDim2.fromOffset(-36, 0),
			Size = UDim2.fromOffset(30, ROW),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 3,
			Parent = button,
		})
		self.toggles[option.key] = { button = button, box = box }
	end
	self.sliders = {}
	for i, option in
		{
			{ key = "fov", label = "Field of view", min = 60, max = 90, step = 5 },
			{ key = "cameraMotion", label = "Camera motion (head bob)", min = 0, max = 1, step = 0.1 },
			{ key = "masterVolume", label = "Volume", min = 0, max = 1, step = 0.1 },
			{ key = "sfxVolume", label = "Effects volume", min = 0, max = 1, step = 0.1 },
			{ key = "ambientVolume", label = "Ambience volume", min = 0, max = 1, step = 0.1 },
			{ key = "musicVolume", label = "Music volume", min = 0, max = 1, step = 0.1 },
		}
	do
		local row = Ui.new("Frame", {
			LayoutOrder = 10 + i,
			Size = UDim2.new(1, 0, 0, ROW),
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = column,
		})
		local label = Ui.typed("", {
			Size = UDim2.new(1, -76, 1, 0),
			TextSize = 15,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 3,
			Parent = row,
		})
		local function nudge(direction)
			local value = ctx.state.settings[option.key] or option.min
			value = math.clamp(
				math.floor((value + direction * option.step) / option.step + 0.5) * option.step,
				option.min,
				option.max
			)
			ctx.state:SetSetting(option.key, value)
			self:Render()
		end
		Ui.paperButton("[-]", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -38, 0, 0),
			Size = UDim2.fromOffset(36, ROW),
			TextSize = 15,
			ZIndex = 3,
			Parent = row,
		}, function()
			nudge(-1)
		end)
		Ui.paperButton("[+]", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(36, ROW),
			TextSize = 15,
			ZIndex = 3,
			Parent = row,
		}, function()
			nudge(1)
		end)
		self.sliders[option.key] = { label = label, text = option.label }
	end
	Ui.paperButton("Done", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 2),
		Size = UDim2.fromOffset(110, 34),
		TextSize = 22,
		ZIndex = 3,
		Parent = sheet,
	}, function()
		self:Close()
	end)

	ctx.state.ProfileChanged:Connect(function()
		-- (Config.Debug.SkipIntroInStudio: a Studio test never waits on the dialog.)
		local skip = RunService:IsStudio() and Config.Debug.SkipIntroInStudio
		if not skip and not ctx.state.settings.seenIntro and not self.shownIntro then
			self.shownIntro = true
			self:Open()
		end
	end)
	return self
end

function Settings:Render()
	local settings = self.ctx.state.settings
	local preset = self.ctx.state:Graphics()
	for key, choice in self.choices do
		local value
		if key == "graphics" then
			local chosen = GraphicsPreset.Order[settings.graphics or 0]
			value = chosen or ("Auto (" .. preset .. ")")
		elseif key == "body" then
			local body = Wardrobe.Bodies[settings.body or Wardrobe.DefaultBody]
			value = body and body.name or Wardrobe.DefaultBody
		else
			value = GraphicsPreset.GrainNames[settings.grain or 2] or "Film"
		end
		choice.button.Text = choice.label .. ":  " .. value .. "  >"
	end
	for key, toggle in self.toggles do
		toggle.box.Text = settings[key] and "[X]" or "[  ]"
	end
	for key, slider in self.sliders do
		local value = settings[key]
		slider.label.Text = string.format(
			"%s:  %s",
			slider.text,
			key == "fov" and tostring(value) or (math.floor((value or 0) * 100 + 0.5) .. "%")
		)
	end
end

function Settings:Open()
	self:Render()
	self.gui.Enabled = true
end

function Settings:Close()
	self.gui.Enabled = false
	if not self.ctx.state.settings.seenIntro then
		self.ctx.state:SetSetting("seenIntro", true)
	end
end

function Settings:Toggle()
	if self.gui.Enabled then
		self:Close()
	else
		self:Open()
	end
end

return Settings
