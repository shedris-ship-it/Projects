-- Debug overlay (F2): seed, phase, Drift and its sources, the stalker's tier,
-- target, tactic and memory, squad-profile signals, performance numbers, and
-- a console for debug commands (type "help"). Commands only work in Studio or
-- for allow-listed user ids; the server checks.

local Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Build)
local Net = require(Shared.Net)

local Ui = require(script.Parent.Parent.Lib.Ui)

local DebugOverlay = {}
DebugOverlay.__index = DebugOverlay

function DebugOverlay.new(ctx)
	local self = setmetatable({ ctx = ctx, open = false, data = nil, frames = 0, fpsClock = 0, fps = 0 }, DebugOverlay)
	local gui = Ui.screen("ConsensusDebug", 90, ctx.playerGui)
	gui.Enabled = false
	self.gui = gui
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 60),
		Size = UDim2.fromOffset(600, 640),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Parent = gui,
	}, { Ui.corner(6), Ui.padding(10) })
	Ui.modal(panel)
	self.text = Ui.label("", {
		Size = UDim2.new(1, 0, 1, -40),
		Font = Enum.Font.Code,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(170, 255, 190),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	})
	self.input = Ui.new("TextBox", {
		Position = UDim2.new(0, 0, 1, -32),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Color3.fromRGB(20, 30, 22),
		TextColor3 = Color3.fromRGB(200, 255, 210),
		PlaceholderText = "command (help)",
		Font = Enum.Font.Code,
		TextSize = 14,
		ClearTextOnFocus = true,
		Text = "",
		Parent = panel,
	}, { Ui.corner(4) })
	self.input.FocusLost:Connect(function(enter)
		if enter and self.input.Text ~= "" then
			-- "steps" is answered here: it tests this client's audio, not the server.
			local footsteps = ctx.controllers.FootstepController
			-- "drag <right> <away>" moves your hand on the door you're looking at
			-- (Controllers/HandsController), here on this client.
			local words = string.split(string.lower(self.input.Text), " ")
			local hands = ctx.controllers.HandsController
			if words[1] == "drag" and hands then
				ctx.ui:Toast(hands:DebugDrag(tonumber(words[2]) or 0, tonumber(words[3]) or 0), "debug")
				return
			end
			if string.lower(self.input.Text) == "steps" and footsteps then
				footsteps:Diagnose(function(summary)
					ctx.ui:Toast(summary, "debug")
				end)
				return
			end
			Net.get("DebugCommand"):FireServer(self.input.Text)
		end
	end)
	Net.get("DebugState").OnClientEvent:Connect(function(data)
		self.data = data
	end)
	return self
end

function DebugOverlay:Toggle()
	self.open = not self.open
	self.gui.Enabled = self.open
	Net.get("DebugCommand"):FireServer(self.open and "overlay on" or "overlay off")
end

function DebugOverlay:Update(dt: number)
	if not self.open then
		return
	end
	self.frames += 1
	self.fpsClock += dt
	if self.fpsClock >= 0.5 then
		self.fps = self.frames / self.fpsClock
		self.frames = 0
		self.fpsClock = 0
	end
	local lines = {
		-- Both sides' build ids: if they differ, the place is half-synced.
		string.format(
			"build   client %s · server %s%s",
			Build.id,
			tostring(self.data and self.data.version or "?"),
			(self.data and self.data.version and self.data.version ~= Build.id) and "  <-- MISMATCH" or ""
		),
		string.format(
			"client  %3.0f fps · %.0f MB · %d instances",
			self.fps,
			Stats:GetTotalMemoryUsageMb(),
			Stats.InstanceCount
		),
	}
	local d = self.data
	if d then
		table.insert(
			lines,
			string.format("server  heartbeat %.1f ms · %d instances", d.serverHeartbeatMs or 0, d.instances or 0)
		)
		table.insert(
			lines,
			string.format(
				"phase %s · seed %s · build %.2fs",
				tostring(d.phase),
				tostring(d.seed),
				d.buildSeconds or 0
			)
		)
		table.insert(lines, string.format("drift %.1f", d.drift or 0))
		table.insert(lines, "drift sources: " .. table.concat(d.driftSources or {}, ", "))
		local s = d.stalker
		if s then
			table.insert(lines, "")
			table.insert(
				lines,
				string.format(
					"stalker %s · tier %d%s · watchers %d · costare %.1f",
					s.mode,
					s.tier,
					s.final and " · FINAL" or "",
					s.watchers,
					s.coStare
				)
			)
			table.insert(lines, "director: " .. tostring(s.director))
			if s.nav then
				table.insert(lines, "walk: " .. s.nav)
			end
			table.insert(lines, "target: " .. tostring(s.target) .. " · tactic: " .. tostring(s.tactic))
			table.insert(lines, "top: " .. table.concat(s.top or {}, " | "))
			table.insert(lines, "memory: " .. table.concat(s.memories or {}, ", "))
		end
		if d.stats and #d.stats > 0 then
			-- The run in numbers (Logic/RunStats).
			table.insert(lines, "")
			for _, line in d.stats do
				table.insert(lines, line)
			end
		end
		table.insert(lines, "")
		table.insert(lines, "profile:")
		for _, signal in d.signals or {} do
			table.insert(lines, "  " .. signal)
		end
	else
		table.insert(lines, "(waiting for server: debug needs Studio or an allow-listed user id)")
	end
	self.text.Text = table.concat(lines, "\n")
end

return DebugOverlay
