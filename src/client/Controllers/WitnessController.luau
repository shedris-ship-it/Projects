-- Your eyes, client side (doc section 6): aiming (the centre of the view;
-- there is no crosshair, UI/FocusMarkers shows the target), camera view
-- reports for the observation rule (two of you watching him freeze him),
-- pings, structured callouts, and the world markers that show them. The
-- hold-to-Witness gesture retired with the clue loop (R2c).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Pings = require(Shared.Data.Pings)
local Util = require(Shared.Lib.Util)

local Ui = require(script.Parent.Parent.Lib.Ui)

local player = Players.LocalPlayer

local WitnessController = {
	aim = nil, -- what the view points at this frame, during a run (UI/FocusMarkers)
}

function WitnessController:Init(controllers)
	self.controllers = controllers
	self.state = controllers.StateController
end

-- What the centre of the screen points at.
function WitnessController:Aim()
	local camera = Workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	-- You can't aim at a Guest you can't see.
	local guest = self.controllers.GuestController
	local model = guest and guest:Model()
	if model and not guest:IsVisibleLocally() then
		table.insert(exclude, model)
	end
	params.FilterDescendantsInstances = exclude
	local result = Workspace:Raycast(ray.Origin, ray.Direction * (Config.Witness.MaxRange + 15), params)
	if not result then
		return { position = ray.Origin + ray.Direction * 30, distance = math.huge }
	end
	local id, label = self.controllers.PerceptionController:LabelFor(result.Instance)
	return {
		position = result.Position,
		instance = result.Instance,
		targetId = id,
		label = label,
		distance = (result.Position - ray.Origin).Magnitude,
	}
end

function WitnessController:SendPing(pingType: string)
	local aim = self:Aim()
	Net.get("Ping"):FireServer(pingType, aim.position)
end

function WitnessController:SendCallout(calloutType: string)
	local aim = self:Aim()
	Net.get("Callout"):FireServer(calloutType, aim.position)
end

-- Markers ---------------------------------------------------------------------------

function WitnessController:_marker(
	position: Vector3,
	text: string,
	color: Color3,
	shape: string,
	lifetime: number,
	alwaysOnTop: boolean
)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = Workspace.Terrain
	local gui = Ui.new("BillboardGui", {
		Size = UDim2.fromOffset(180, 64),
		AlwaysOnTop = alwaysOnTop,
		LightInfluence = 0,
		MaxDistance = 300,
		Adornee = attachment,
		Parent = attachment,
	}, {
		Ui.label(shape, {
			Size = UDim2.new(1, 0, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = color,
			Font = Ui.Theme.fontBold,
			TextSize = 28,
			TextStrokeTransparency = 0.4,
		}),
		Ui.label(text, {
			Name = "Caption",
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.new(1, 0, 0, 34),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Ui.Theme.text,
			TextSize = 14,
			TextStrokeTransparency = 0.5,
		}),
	})
	task.delay(lifetime, function()
		if attachment.Parent then
			Ui.tween(gui.Caption, 0.4, { TextTransparency = 1 })
			task.wait(0.4)
			attachment:Destroy()
		end
	end)
	return attachment, gui
end

function WitnessController:Start()
	local ui = self.controllers.UIController
	Net.get("Pinged").OnClientEvent:Connect(function(ping)
		local info = Pings.TypeById[ping.type]
		if not info then
			return
		end
		local colorblind = self.state.settings.colorblind
		local color = colorblind and Ui.Theme.text or Ui.color(info.color)
		local name = ping.echo and (ping.name .. "'s Echo") or ping.name
		self:_marker(
			ping.position,
			string.format("%s · %s", name, info.label),
			color,
			info.shape,
			Config.Social.PingLifetime,
			true
		)
		if ping.from ~= player.UserId then
			ui:Toast(string.format("%s pinged: %s", name, info.label), "ping")
		end
	end)
	Net.get("CalloutHeard").OnClientEvent:Connect(function(callout)
		local info = Pings.CalloutById[callout.type]
		local camera = Workspace.CurrentCamera
		local offset = callout.position - camera.CFrame.Position
		local look = camera.CFrame.LookVector
		local hour = Util.clockDirection(look.X, look.Z, offset.X, offset.Z)
		local who = callout.from == player.UserId and "You say" or (callout.name .. " says")
		-- A claim, not a marker: the listener may not perceive it at all.
		ui:Toast(
			string.format(
				"%s: %s at %d o'clock, %s",
				who,
				info and info.label or "something",
				hour,
				Util.distanceBand(offset.Magnitude)
			),
			"callout"
		)
	end)
	local reportClock = 0
	RunService.RenderStepped:Connect(function(dt)
		-- What the view points at, for the focus markers.
		self.aim = self.state:InRun() and self:Aim() or nil
		-- View reports drive the observation rule on the server.
		reportClock += dt
		if reportClock >= 1 / 12 and self.state:InRun() then
			reportClock = 0
			Net.get("ReportView"):FireServer(Workspace.CurrentCamera.CFrame)
		end
	end)
end

return WitnessController
