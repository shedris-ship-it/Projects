-- Notifications and audio captions. In the 1988 interface (V7) no boxes:
-- notices are pale typed lines over the world, a short stroke of their
-- colour before each; captions are a film's subtitles.

local Ui = require(script.Parent.Parent.Lib.Ui)

local Toasts = {}
Toasts.__index = Toasts

local KIND_COLORS = {
	info = Ui.Theme.text,
	good = Ui.Theme.good,
	warning = Ui.Theme.warn,
	danger = Ui.Theme.danger,
	ritual = Ui.Theme.ritual,
	verdict = Ui.Theme.accent,
	phase = Ui.Theme.accent,
	ping = Ui.Theme.textDim,
	callout = Color3.fromRGB(200, 220, 255),
	witness = Ui.Theme.accent,
	tip = Color3.fromRGB(226, 210, 166), -- teaching (UI/Tips)
	debug = Color3.fromRGB(150, 255, 170),
}

function Toasts.new(ctx)
	local self = setmetatable({}, Toasts)
	-- Above the map (40), the reader (45) and a puzzle (46), under the overlays
	-- (50): a line said while the map is open is still read.
	local gui = Ui.screen("ConsensusToasts", 48, ctx.playerGui)
	self.feed = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 28, 1, -150),
		Size = UDim2.new(0, 480, 0, 300),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.new("UIListLayout", {
			Padding = UDim.new(0, 5),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	-- (Above the hotbar and the hiding hints.)
	self.caption = Ui.subtitle("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -128),
		Size = UDim2.new(0, 760, 0, 30),
		TextSize = 22,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = gui,
	})
	self.order = 0
	self.entries = {}
	return self
end

function Toasts:Push(text: string, kind: string)
	self.order += 1
	local color = KIND_COLORS[kind] or Ui.Theme.text
	local entry = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self.order,
		Parent = self.feed,
	})
	local dash = Ui.new("Frame", {
		Name = "Dash",
		Position = UDim2.fromOffset(0, 7),
		Size = UDim2.fromOffset(10, 2),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.15,
		Parent = entry,
	})
	local label = Ui.label(text, {
		Name = "Text",
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -18, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextColor3 = color:Lerp(Ui.Theme.text, 0.35),
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.55,
		TextSize = 16,
		Parent = entry,
	})
	table.insert(self.entries, entry)
	while #self.entries > 6 do
		table.remove(self.entries, 1):Destroy()
	end
	local lifetime = (kind == "danger" or kind == "ritual" or kind == "debug") and 9 or 6
	task.delay(lifetime, function()
		if entry.Parent then
			Ui.tween(dash, 0.6, { BackgroundTransparency = 1 })
			Ui.tween(label, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 })
			task.wait(0.6)
			local index = table.find(self.entries, entry)
			if index then
				table.remove(self.entries, index)
			end
			entry:Destroy()
		end
	end)
end

function Toasts:Caption(text: string)
	self.caption.Text = text
	self.caption.TextTransparency = 0
	self.caption.TextStrokeTransparency = 0.55
	self.captionToken = (self.captionToken or 0) + 1
	local token = self.captionToken
	task.delay(3, function()
		if self.captionToken == token then
			Ui.tween(self.caption, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

return Toasts
