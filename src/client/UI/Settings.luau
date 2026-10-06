-- First-launch screen and settings (doc section 8, "UI and accessibility"):
-- reduce flicker, reduce grain, subtitles, colour-blind-safe pings, a
-- low-end graphics mode, FOV and volume. Also explains how to play.

local Ui = require(script.Parent.Parent.Lib.Ui)

local Settings = {}
Settings.__index = Settings

-- Three bullets (the audit of 2026-10-06: the eight-bullet wall taught
-- nothing). The house teaches the rest as it comes up (UI/Tips).
local HOW_TO = table.concat({
	"The front door has locked behind you. The dining table is laid for a guest, with empty places.",
	"",
	"• Find the family's heirlooms and set each at its place at the table. Then get out by the front door.",
	"• The house is locked wing by wing. Keys and doors share a mark; notes and puzzles point the way. Hold the mouse on anything to drag, pull or carry it.",
	"• Something lives here. Two of you watching it in the light stops it; alone, your beam does, while the battery lasts. Hide (E), hold your breath (Space), and talk: Tab is the map, G pings.",
}, "\n")

function Settings.new(ctx)
	local self = setmetatable({ ctx = ctx }, Settings)
	local gui = Ui.screen("ConsensusSettings", 70, ctx.playerGui)
	gui.Enabled = false
	self.gui = gui
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(860, 560),
		BackgroundColor3 = Ui.Theme.panel,
		Parent = gui,
	}, { Ui.corner(10), Ui.stroke(Ui.Theme.accent, 1, 0.4), Ui.padding(20) })
	Ui.modal(panel)
	Ui.label("BEFORE YOU GO IN", {
		Size = UDim2.new(1, 0, 0, 32),
		Font = Ui.Theme.fontType,
		TextSize = 28,
		TextColor3 = Ui.Theme.accent,
		Parent = panel,
	})
	Ui.label(HOW_TO, {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(0.55, -10, 1, -90),
		TextSize = 14,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	})
	Ui.label('Photosensitivity: this game uses flickering lights. Turn on "Reduce flicker" if you need to.', {
		Position = UDim2.new(0, 0, 1, -44),
		Size = UDim2.new(0.55, -10, 0, 40),
		TextSize = 12,
		TextColor3 = Ui.Theme.warn,
		Parent = panel,
	})
	local column = Ui.new("Frame", {
		Position = UDim2.new(0.55, 10, 0, 40),
		Size = UDim2.new(0.45, -10, 1, -40),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Ui.list(8) })
	self.toggles = {}
	for i, option in
		{
			{ key = "reduceFlicker", label = "Reduce flicker" },
			{ key = "reduceGrain", label = "Reduce grain" },
			{ key = "subtitles", label = "Subtitles for sound cues" },
			{ key = "colorblind", label = "Colour-blind-safe pings" },
			{ key = "lowEnd", label = "Low-end graphics (phones)" },
			{ key = "centerDot", label = "Centre dot (aiming aid)" },
		}
	do
		local button = Ui.button(
			"",
			{ LayoutOrder = i, Size = UDim2.new(1, 0, 0, 34), TextSize = 14, Parent = column },
			function()
				ctx.state:SetSetting(option.key, not ctx.state.settings[option.key])
				self:Render()
			end
		)
		self.toggles[option.key] = { button = button, label = option.label }
	end
	self.sliders = {}
	for i, option in
		{
			{ key = "fov", label = "Field of view", min = 60, max = 90, step = 5 },
			{ key = "cameraMotion", label = "Camera motion (head bob)", min = 0, max = 1, step = 0.1 },
			{ key = "masterVolume", label = "Volume", min = 0, max = 1, step = 0.1 },
			{ key = "sfxVolume", label = "Effects volume", min = 0, max = 1, step = 0.1 },
			{ key = "ambientVolume", label = "Ambience volume", min = 0, max = 1, step = 0.1 },
		}
	do
		local row = Ui.new(
			"Frame",
			{ LayoutOrder = 10 + i, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = column }
		)
		local label = Ui.label("", { Size = UDim2.new(1, -90, 1, 0), TextSize = 14, Parent = row })
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
		Ui.button("−", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -46, 0, 0),
			Size = UDim2.fromOffset(40, 34),
			Parent = row,
		}, function()
			nudge(-1)
		end)
		Ui.button("+", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(40, 34),
			Parent = row,
		}, function()
			nudge(1)
		end)
		self.sliders[option.key] = { label = label, text = option.label }
	end
	Ui.button("Done", {
		LayoutOrder = 99,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Color3.fromRGB(70, 56, 36),
		Parent = column,
	}, function()
		self:Close()
	end)

	ctx.state.ProfileChanged:Connect(function()
		if not ctx.state.settings.seenIntro and not self.shownIntro then
			self.shownIntro = true
			self:Open()
		end
	end)
	return self
end

function Settings:Render()
	local settings = self.ctx.state.settings
	for key, toggle in self.toggles do
		toggle.button.Text = toggle.label .. ":  " .. (settings[key] and "ON" or "off")
		toggle.button.BackgroundColor3 = settings[key] and Color3.fromRGB(70, 90, 70) or Ui.Theme.panelLight
	end
	for key, slider in self.sliders do
		local value = settings[key]
		slider.label.Text = string.format(
			"%s: %s",
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
