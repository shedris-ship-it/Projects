-- Owns every screen. Components live in client/UI and get a shared context.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UIFolder = script.Parent.Parent:WaitForChild("UI")
local Ui = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Ui"))

local player = Players.LocalPlayer

local UIController = {}

function UIController:Init(controllers)
	self.controllers = controllers
	self.state = controllers.StateController
	self.components = {}
	self.pendingToasts = {}
end

function UIController:Start()
	local playerGui = player:WaitForChild("PlayerGui")
	-- Soft key presses for buttons.
	local audio = self.controllers.AudioController
	Ui.Sounds.hover = function()
		audio:PlayUi("UIHover", 0.1, 1.15)
	end
	Ui.Sounds.click = function()
		audio:PlayUi("UIClick", 0.3, 0.9)
	end
	local ctx = {
		controllers = self.controllers,
		state = self.state,
		ui = self,
		playerGui = playerGui,
	}
	for _, name in
		{
			"HideView",
			"Hud",
			"Hotbar",
			"FocusMarkers",
			"Toasts",
			"PingWheel",
			"SpeakBox",
			"Map",
			"Puzzle",
			"TuneStrip",
			"Reader",
			"Lobby",
			"Dossier",
			"Settings",
			"Overlays",
			"DownedMarkers",
			"Tips",
			"DebugOverlay",
		}
	do
		local module = UIFolder:FindFirstChild(name)
		if module then
			local ok, component = pcall(function()
				return require(module).new(ctx)
			end)
			if ok then
				self.components[name] = component
			else
				warn("[Consensus] UI " .. name .. " failed: " .. tostring(component))
			end
		end
	end
	for _, toast in self.pendingToasts do
		self:Toast(toast[1], toast[2])
	end
	self.pendingToasts = {}
	RunService.RenderStepped:Connect(function(dt)
		for name, component in self.components do
			if component.Update then
				local ok, err = pcall(component.Update, component, dt)
				if not ok then
					warn("[Consensus] UI " .. name .. " update failed: " .. tostring(err))
					component.Update = nil
				end
			end
		end
	end)
	local net = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Net)
	net.get("Notify").OnClientEvent:Connect(function(text, kind)
		self:Toast(text, kind)
	end)
	-- F2 `ui map|journal` (Services/DebugService): open a screen as if its
	-- key were pressed (for tests that can't press Tab).
	player:GetAttributeChangedSignal("DebugUi"):Connect(function()
		local what = string.match(tostring(player:GetAttribute("DebugUi")), "^(%a+)")
		local map = self.components.Map
		if map and (what == "map" or what == "journal") then
			map.tab = what == "journal" and "Journal" or "Map"
			if not map.open then
				map:Toggle()
			else
				map:Render()
			end
		elseif map and what == "close" and map.open then
			map:Toggle()
		end
	end)
end

function UIController:Toast(text: string, kind: string?)
	local toasts = self.components.Toasts
	if toasts then
		toasts:Push(text, kind or "info")
	else
		table.insert(self.pendingToasts, { text, kind })
	end
end

function UIController:Caption(text: string)
	local toasts = self.components.Toasts
	if toasts then
		toasts:Caption(text)
	end
end

function UIController:OpenPingWheel()
	local wheel = self.components.PingWheel
	if wheel then
		wheel:Open()
	end
end

function UIController:ClosePingWheel(send: boolean)
	local wheel = self.components.PingWheel
	if wheel then
		wheel:Close(send)
	end
end

function UIController:ToggleCallouts()
	local wheel = self.components.PingWheel
	if wheel then
		wheel:ToggleCallouts()
	end
end

function UIController:OpenSpeak()
	local box = self.components.SpeakBox
	if box then
		box:Open()
	end
end

function UIController:ToggleMap()
	local map = self.components.Map
	if map then
		map:Toggle()
	end
end

function UIController:ToggleSettings()
	local settings = self.components.Settings
	if settings then
		settings:Toggle()
	end
end

function UIController:ToggleDebug()
	local debugOverlay = self.components.DebugOverlay
	if debugOverlay then
		debugOverlay:Toggle()
	end
end

return UIController
