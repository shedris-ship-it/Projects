-- Bleeding-out teammates (owner, 2026-10-03: downs are short and the squad
-- has to drop everything). A pulsing marker over each downed Witness with the
-- seconds they have left and how far away they are; off-screen or behind you,
-- it sticks to the screen edge with an arrow. Driven only by the replicated
-- State and DownedUntil player attributes, so no remote is needed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)

local Ui = require(script.Parent.Parent.Lib.Ui)

local PS = Constants.PlayerStates
local PA = Constants.PlayerAttributes

local player = Players.LocalPlayer

local EDGE_MARGIN = 70

local DownedMarkers = {}
DownedMarkers.__index = DownedMarkers

function DownedMarkers.new(ctx)
	local self = setmetatable({ ctx = ctx, markers = {} }, DownedMarkers)
	self.gui = Ui.screen("ConsensusDownedMarkers", 40, ctx.playerGui)
	return self
end

function DownedMarkers:_build(other: Player)
	local frame = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(200, 64),
		BackgroundTransparency = 1,
		Parent = self.gui,
	})
	local diamond = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromOffset(14, 14),
		Rotation = 45,
		BackgroundColor3 = Ui.Theme.danger,
		Parent = frame,
	}, { Ui.stroke(Color3.new(0, 0, 0), 1, 0.3) })
	local arrow = Ui.label("▲", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromOffset(30, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 26,
		TextColor3 = Ui.Theme.danger,
		TextStrokeTransparency = 0.4,
		Visible = false,
		Parent = frame,
	})
	local label = Ui.label("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(1, 0, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Ui.Theme.fontBold,
		TextSize = 14,
		TextColor3 = Ui.Theme.text,
		TextStrokeTransparency = 0.3,
		Parent = frame,
	})
	local marker = { frame = frame, diamond = diamond, arrow = arrow, label = label }
	self.markers[other] = marker
	return marker
end

function DownedMarkers:Update()
	local seen = {}
	local camera = Workspace.CurrentCamera
	if self.ctx.state:InRun() and camera then
		local viewport = camera.ViewportSize
		local now = Workspace:GetServerTimeNow()
		for _, other in Players:GetPlayers() do
			local head = other ~= player
				and other:GetAttribute(PA.State) == PS.Downed
				and other.Character
				and other.Character:FindFirstChild("Head")
			local downedUntil = other:GetAttribute(PA.DownedUntil)
			if head and head:IsA("BasePart") and downedUntil then
				seen[other] = true
				local marker = self.markers[other] or self:_build(other)
				local left = math.max(0, downedUntil - now)
				local position = head.Position + Vector3.new(0, 1.5, 0)
				local screen, onScreen = camera:WorldToViewportPoint(position)
				local x, y = screen.X, screen.Y
				local clamped = not onScreen
					or x < EDGE_MARGIN
					or x > viewport.X - EDGE_MARGIN
					or y < EDGE_MARGIN
					or y > viewport.Y - EDGE_MARGIN
				if clamped then
					-- Point from the screen centre towards them, behind you included.
					local relative = camera.CFrame:PointToObjectSpace(position)
					local direction = Vector2.new(relative.X, -relative.Y)
					if direction.Magnitude < 1e-3 then
						direction = Vector2.new(0, 1)
					end
					direction = direction.Unit
					local cx, cy = viewport.X / 2, viewport.Y / 2
					local reach = math.min(
						(cx - EDGE_MARGIN) / math.max(math.abs(direction.X), 1e-3),
						(cy - EDGE_MARGIN) / math.max(math.abs(direction.Y), 1e-3)
					)
					x, y = cx + direction.X * reach, cy + direction.Y * reach
					marker.arrow.Rotation = math.deg(math.atan2(direction.Y, direction.X)) + 90
				end
				marker.frame.Position = UDim2.fromOffset(x, y)
				marker.arrow.Visible = clamped
				marker.diamond.Visible = not clamped
				local distance = (position - camera.CFrame.Position).Magnitude
				marker.label.Text = string.format(
					"%s\n%d s · %d studs",
					other.DisplayName,
					math.ceil(left),
					math.floor(distance + 0.5)
				)
				local urgent = left <= Config.Run.BleedWarnSeconds
				local pulse = 0.5 + 0.5 * math.sin(os.clock() * (urgent and 12 or 5))
				marker.diamond.BackgroundTransparency = 0.1 + 0.5 * pulse
				marker.arrow.TextTransparency = 0.5 * pulse
				marker.label.TextColor3 = urgent and Ui.Theme.danger or Ui.Theme.text
			end
		end
	end
	for other, marker in self.markers do
		if not seen[other] then
			marker.frame:Destroy()
			self.markers[other] = nil
		end
	end
end

return DownedMarkers
