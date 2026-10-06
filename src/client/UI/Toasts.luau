-- Notifications feed and audio captions.

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
	tip = Color3.fromRGB(222, 206, 160), -- teaching (UI/Tips)
	debug = Color3.fromRGB(150, 255, 170),
}

function Toasts.new(ctx)
	local self = setmetatable({}, Toasts)
	local gui = Ui.screen("ConsensusToasts", 20, ctx.playerGui)
	self.feed = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -170),
		Size = UDim2.new(0, 460, 0, 300),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self.caption = Ui.label("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -120),
		Size = UDim2.new(0, 600, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Ui.Theme.fontType,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(230, 230, 230),
		TextStrokeTransparency = 0.3,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
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
		BackgroundColor3 = Ui.Theme.ink,
		BackgroundTransparency = 0.25,
		LayoutOrder = self.order,
		Parent = self.feed,
	}, {
		Ui.corner(6),
		Ui.padding(8),
		Ui.new("Frame", {
			Size = UDim2.new(0, 3, 1, 0),
			Position = UDim2.new(0, -8, 0, 0),
			BackgroundColor3 = color,
		}),
		Ui.label(text, {
			Name = "Text",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextColor3 = color,
			TextSize = 15,
		}),
	})
	table.insert(self.entries, entry)
	while #self.entries > 6 do
		table.remove(self.entries, 1):Destroy()
	end
	local lifetime = (kind == "danger" or kind == "ritual" or kind == "debug") and 9 or 6
	task.delay(lifetime, function()
		if entry.Parent then
			Ui.tween(entry, 0.5, { BackgroundTransparency = 1 })
			Ui.tween(entry.Text, 0.5, { TextTransparency = 1 })
			task.wait(0.5)
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
	self.caption.TextStrokeTransparency = 0.3
	self.captionToken = (self.captionToken or 0) + 1
	local token = self.captionToken
	task.delay(3, function()
		if self.captionToken == token then
			Ui.tween(self.caption, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

return Toasts
