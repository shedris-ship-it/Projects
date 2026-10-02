-- Ping wheel (hold G, aim with the mouse, release) and structured callouts
-- (C): non-voice parity for everything players would otherwise say out loud.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pings = require(Shared.Data.Pings)

local Ui = require(script.Parent.Parent.Lib.Ui)

local PingWheel = {}
PingWheel.__index = PingWheel

local RADIUS = 110

function PingWheel.new(ctx)
	local self = setmetatable({ ctx = ctx, selected = nil, open = false }, PingWheel)
	local gui = Ui.screen("ConsensusPingWheel", 30, ctx.playerGui)
	self.wheel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(RADIUS * 2 + 120, RADIUS * 2 + 120),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	Ui.modal(self.wheel)
	self.options = {}
	for i, ping in Pings.Types do
		local angle = (i - 1) / #Pings.Types * math.pi * 2 - math.pi / 2
		local button = Ui.button(ping.shape .. "  " .. ping.label, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(angle) * RADIUS, 0.5, math.sin(angle) * RADIUS),
			Size = UDim2.fromOffset(130, 36),
			TextColor3 = Ui.color(ping.color),
			Parent = self.wheel,
		}, function()
			self.selected = ping.id
			self:Close(true)
		end)
		table.insert(self.options, { id = ping.id, angle = angle, button = button })
	end

	self.callouts = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.fromOffset(560, 44),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, { Ui.list(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center) })
	Ui.modal(self.callouts)
	Ui.label("Call out what you're looking at:", {
		Size = UDim2.fromOffset(200, 36),
		TextSize = 13,
		TextColor3 = Ui.Theme.textDim,
		Parent = self.callouts,
	})
	for _, callout in Pings.Callouts do
		Ui.button(callout.label, { Size = UDim2.fromOffset(52, 36), TextSize = 13, Parent = self.callouts }, function()
			ctx.controllers.WitnessController:SendCallout(callout.id)
			self.callouts.Visible = false
		end)
	end
	return self
end

function PingWheel:Open()
	if not self.ctx.state:InRun() then
		return
	end
	self.open = true
	self.selected = nil
	self.wheel.Visible = true
	self.callouts.Visible = false
end

function PingWheel:Close(send: boolean)
	if not self.open then
		return
	end
	self.open = false
	self.wheel.Visible = false
	if send and self.selected then
		self.ctx.controllers.WitnessController:SendPing(self.selected)
	end
	self.selected = nil
end

function PingWheel:ToggleCallouts()
	if not self.ctx.state:InRun() then
		return
	end
	self.callouts.Visible = not self.callouts.Visible
end

function PingWheel:Update()
	if not self.open then
		return
	end
	-- Pick the option in the direction of the mouse from screen centre.
	local mouse = UserInputService:GetMouseLocation()
	local camera = workspace.CurrentCamera
	local center = camera.ViewportSize / 2
	local offset = mouse - center
	if offset.Magnitude > 30 then
		local angle = math.atan2(offset.Y, offset.X)
		local best, bestDelta = nil, math.huge
		for _, option in self.options do
			local delta = math.abs((angle - option.angle + math.pi) % (2 * math.pi) - math.pi)
			if delta < bestDelta then
				best, bestDelta = option, delta
			end
		end
		self.selected = best and best.id
	end
	for _, option in self.options do
		option.button.BackgroundColor3 = option.id == self.selected and Ui.Theme.accent or Ui.Theme.panelLight
	end
end

return PingWheel
