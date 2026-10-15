-- The end-of-run Dossier (doc section 2): what happened, what the house was,
-- and what the stalker learned about you. In the 1988 interface (V7): a
-- police case file, the report typed on a sheet laid in a manila folder, a
-- rubber stamp across it, the night in numbers pencilled on a slip.

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

-- Laid out at this size (Ui.fit shrinks it on a small screen).
local WIDTH, HEIGHT = 940, 650

function Dossier.new(ctx)
	local self = setmetatable({ ctx = ctx }, Dossier)
	local gui = Ui.screen("ConsensusDossier", 60, ctx.playerGui)
	gui.Enabled = false
	self.gui = gui
	Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Parent = gui,
	})
	local root = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Ui.fit(root, WIDTH, HEIGHT)
	Ui.modal(root)
	-- The folder, open.
	Ui.paper("Folder", {
		Size = UDim2.fromScale(1, 1),
		Rotation = -0.6,
		ZIndex = 1,
		Parent = root,
	})
	-- The report, typed on a sheet laid in it.
	local _, sheet = Ui.paper("Sheet", {
		Position = UDim2.fromOffset(34, 18),
		Size = UDim2.fromOffset(560, HEIGHT - 36),
		-- (Square: a turned frame stops clipping its scrolling body.)
		ZIndex = 2,
		Parent = root,
	})
	local panel = Ui.new("Frame", {
		Position = UDim2.fromOffset(36, 30),
		Size = UDim2.new(1, -66, 1, -62),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = sheet,
	})
	Ui.typed("INCIDENT REPORT  ·  CASE 88-0412", {
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 12,
		TextColor3 = Ui.Theme.typeDim,
		ZIndex = 3,
		Parent = panel,
	})
	self.title = Ui.typed("", {
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 30,
		ZIndex = 3,
		Parent = panel,
	})
	self.subtitle = Ui.typed("", {
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 13,
		TextColor3 = Ui.Theme.typeDim,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
		Parent = panel,
	})
	Ui.rule(panel, 94, Ui.Theme.type, 0.55).ZIndex = 3
	local scroll = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 102),
		Size = UDim2.new(1, 0, 1, -102),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Ui.Theme.type,
		ScrollBarImageTransparency = 0.5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 3,
		Parent = panel,
	})
	self.body = Ui.typed("", {
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 15,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
		Parent = scroll,
	})
	-- The night in numbers, pencilled on a slip clipped to the folder.
	local slipHolder, slip = Ui.paper("Slip", {
		Position = UDim2.fromOffset(618, 150),
		Size = UDim2.fromOffset(290, 150),
		Rotation = -2.2,
		ZIndex = 2,
		Parent = root,
	})
	self.notes = Ui.hand("", {
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -36, 1, -24),
		TextSize = 25,
		LineHeight = 0.95,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
		Parent = slip,
	})
	Ui.tape(slipHolder, UDim2.new(0.5, 0, 0, 0), 4, 90)
	-- The stamp, across the top of the folder.
	self.stamp = Ui.stamp("", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(764, 80),
		Rotation = -8,
		TextSize = 34,
		Parent = root,
	})
	Ui.paperButton("Close the file", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -34, 1, -28),
		Size = UDim2.fromOffset(200, 36),
		TextSize = 20,
		ZIndex = 3,
		Parent = root,
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
	self.stamp.Text = s.won and "CLOSED: GOT OUT" or "MISSING"
	self.subtitle.Text = string.format(
		"%s  ·  %s",
		REASONS[s.reason] or s.reason,
		s.resolved and "The dinner was served." or "The table was never set."
	)
	-- (Pencilled on the slip.)
	self.notes.Text = string.format(
		"+%d Marks%s\n%dm %02ds in the house\nfinal Drift %d\nseed %s, %s",
		data.marks or 0,
		data.extracted and ", got out" or "",
		s.minutes,
		s.seconds,
		s.drift,
		tostring(s.seed),
		s.difficulty or "Normal"
	)
	local lines = {}
	local escape = s.escape
	if escape then
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
	local bounds =
		TextService:GetTextSize(body.Text, body.TextSize, Enum.Font.SpecialElite, Vector2.new(width, math.huge))
	body.AutomaticSize = Enum.AutomaticSize.None
	body.Size = UDim2.new(1, -10, 0, bounds.Y + 8)
end

return Dossier
