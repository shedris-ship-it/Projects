-- The only way to type to your squad. Roblox's own chat is switched off, so
-- every line is spoken aloud and the stalker can hear it (Services/ChatService).

local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Ui = require(script.Parent.Parent.Lib.Ui)

local SpeakBox = {}
SpeakBox.__index = SpeakBox

function SpeakBox.new(ctx)
	local self = setmetatable({ ctx = ctx }, SpeakBox)
	local gui = Ui.screen("ConsensusSpeak", 40, ctx.playerGui)
	self.panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.new(0, 460, 0, 64),
		BackgroundColor3 = Ui.Theme.ink,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(8), Ui.stroke(Ui.Theme.accent, 1, 0.5), Ui.padding(8) })
	Ui.modal(self.panel)
	Ui.label("Everything you say can be heard. /w to whisper. Enter to send.", {
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 12,
		TextColor3 = Ui.Theme.textDim,
		Parent = self.panel,
	})
	self.box = Ui.new("TextBox", {
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = Ui.Theme.panelLight,
		TextColor3 = Ui.Theme.text,
		PlaceholderText = "say something...",
		PlaceholderColor3 = Ui.Theme.textDim,
		Font = Ui.Theme.font,
		TextSize = 16,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = self.panel,
	}, { Ui.corner(6), Ui.padding(4) })
	self.box:GetPropertyChangedSignal("Text"):Connect(function()
		if #self.box.Text > Config.Voice.MaxChars + 3 then
			self.box.Text = string.sub(self.box.Text, 1, Config.Voice.MaxChars + 3)
		end
	end)
	self.box.FocusLost:Connect(function(enterPressed)
		local text = self.box.Text
		self:Close()
		if enterPressed and string.match(text, "%S") then
			ctx.controllers.SpeechController:Say(text)
		end
	end)
	return self
end

function SpeakBox:Open()
	if self.panel.Visible then
		return
	end
	self.panel.Visible = true
	self.box.Text = ""
	self.box:CaptureFocus()
end

function SpeakBox:Close()
	self.panel.Visible = false
	self.box.Text = ""
	if UserInputService:GetFocusedTextBox() == self.box then
		self.box:ReleaseFocus()
	end
end

return SpeakBox
