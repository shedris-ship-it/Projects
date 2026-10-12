-- The end-of-run Dossier (doc section 2): what happened, what the house was,
-- and what the stalker learned about you.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GuestMood = require(Shared.Logic.GuestMood)
local Net = require(Shared.Net)

local Ui = require(script.Parent.Parent.Lib.Ui)

local Dossier = {}
Dossier.__index = Dossier

local REASONS = {
	Extracted = "You got out.",
	Collapse = "Drift reached 100. The house had enough of you, and hunted you down.",
	AllLost = "Nobody got out.",
	Abandoned = "The squad left.",
	Debug = "Ended from the debug console.",
}

function Dossier.new(ctx)
	local self = setmetatable({ ctx = ctx }, Dossier)
	local gui = Ui.screen("ConsensusDossier", 60, ctx.playerGui)
	gui.Enabled = false
	self.gui = gui
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(760, 560),
		BackgroundColor3 = Ui.Theme.paper,
		Parent = gui,
	}, { Ui.corner(6), Ui.padding(22) })
	Ui.modal(panel)
	self.title = Ui.label("", {
		Size = UDim2.new(1, 0, 0, 36),
		Font = Ui.Theme.fontType,
		TextSize = 32,
		TextColor3 = Ui.Theme.ink,
		Parent = panel,
	})
	self.subtitle = Ui.label("", {
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 14,
		TextColor3 = Color3.fromRGB(90, 70, 50),
		Parent = panel,
	})
	local scroll = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 1, -140),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	})
	self.body = Ui.label("", {
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Ui.Theme.fontType,
		TextSize = 16,
		TextColor3 = Ui.Theme.ink,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = scroll,
	})
	Ui.button("Close", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.fromOffset(140, 40),
		Parent = panel,
	}, function()
		gui.Enabled = false
	end)
	Net.get("Dossier").OnClientEvent:Connect(function(data)
		self:Show(data)
	end)
	return self
end

function Dossier:Show(data)
	local s = data.summary
	local d = data.dossier
	self.title.Text = s.won and "YOU GOT OUT" or "THE HOUSE KEPT YOU"
	self.subtitle.Text = string.format(
		"%s  ·  %s  ·  %dm %02ds  ·  final Drift %d  ·  seed %s (%s)",
		REASONS[s.reason] or s.reason,
		s.resolved and "The dinner was served" or "The table was never set",
		s.minutes,
		s.seconds,
		s.drift,
		tostring(s.seed),
		s.difficulty or "Normal"
	)
	local lines = {}
	table.insert(lines, string.format("+%d Marks%s", data.marks or 0, data.extracted and " (got out)" or ""))
	local escape = s.escape
	if escape then
		table.insert(lines, "")
		table.insert(lines, "THE HOUSE")
		table.insert(lines, string.format("  Places set at the table: %d of %d", escape.placesSet, escape.places))
		table.insert(lines, string.format("  Locked doors opened: %d of %d", escape.locksOpened, escape.locks))
		if escape.puzzles > 0 then
			table.insert(lines, string.format("  Puzzles solved: %d of %d", escape.puzzlesSolved, escape.puzzles))
		end
		for _, line in escape.lines or {} do
			table.insert(lines, "  " .. line)
		end
	end
	-- The family's valuables (push your luck): what got out, and what didn't.
	local haul = s.haul
	if haul and (#haul.carried > 0 or haul.left > 0) then
		table.insert(lines, "")
		table.insert(lines, "THE FAMILY'S VALUABLES")
		for _, v in haul.carried do
			table.insert(lines, string.format("  The %s: carried out by %s (+%d Marks each)", v.label, v.by, haul.each))
		end
		if haul.left > 0 then
			table.insert(
				lines,
				string.format(
					"  %d left in the house%s.",
					haul.left,
					#haul.carried == 0 and ", where he keeps them" or ""
				)
			)
		end
	end
	if s.stats and #s.stats > 0 then
		table.insert(lines, "")
		table.insert(lines, "THE NIGHT IN NUMBERS")
		for _, line in s.stats do
			table.insert(lines, "  " .. line)
		end
	end
	table.insert(lines, "")
	table.insert(lines, "WHAT IT LEARNED ABOUT YOU")
	for _, habit in d.habits do
		table.insert(lines, "  " .. habit)
	end
	if d.favouriteSpot then
		table.insert(lines, "  It knows your favourite hiding place: " .. d.favouriteSpot .. ".")
	end
	if #d.closeCalls > 0 then
		table.insert(lines, "")
		table.insert(lines, "CLOSEST CALLS")
		for _, call in d.closeCalls do
			table.insert(lines, string.format("  %s: %.1f studs", call.name, call.distance))
		end
	end
	if #d.catches > 0 then
		table.insert(lines, "")
		table.insert(lines, "CAUGHT")
		for _, c in d.catches do
			table.insert(lines, string.format("  %s × %d", c.name, c.count))
		end
	end
	if #d.tactics > 0 then
		table.insert(lines, "")
		table.insert(lines, "HOW IT STALKED YOU")
		for i, t in d.tactics do
			if i > 5 then
				break
			end
			table.insert(lines, string.format("  %s (×%d)", t.description, t.count))
		end
	end
	-- His moods tonight, each with what to do about it next time
	-- (Logic/GuestMood; "a Guest you can read", 2026-10-11).
	local moods = {}
	for _, entry in s.moods or {} do
		local mood = GuestMood.Moods[entry.id]
		if mood then
			local name = string.upper(string.sub(mood.name, 1, 1)) .. string.sub(mood.name, 2)
			table.insert(moods, string.format("  %s (×%d). %s %s", name, entry.count, mood.tell, mood.counter))
		end
	end
	if #moods > 0 then
		table.insert(lines, "")
		table.insert(lines, "HIS MOODS TONIGHT")
		for _, line in moods do
			table.insert(lines, line)
		end
	end
	table.insert(lines, "")
	table.insert(lines, string.format("Hides %d  ·  Pings %d", d.totals.hides, d.totals.pings))
	self.body.Text = table.concat(lines, "\n")
	self.gui.Enabled = true
	task.defer(function()
		self:_fit()
	end)
end

-- As tall as its text. AutomaticSize didn't grow it when the text was set
-- with the screen off: the debrief stopped after about 23 lines, with nothing
-- to scroll to (the audit of 2026-10-11).
function Dossier:_fit()
	local body = self.body
	local width = body.AbsoluteSize.X
	if width <= 0 then
		return
	end
	local bounds = TextService:GetTextSize(body.Text, body.TextSize, body.Font, Vector2.new(width, math.huge))
	body.AutomaticSize = Enum.AutomaticSize.None
	body.Size = UDim2.new(1, -10, 0, bounds.Y + 8)
end

return Dossier
