-- The diner's run records (LB5; docs/plans/lobby-rework.md, "The diner"; the
-- rules in Logic/Records). A finished run posts its time, from its arrival
-- to the last of the squad out of the front door, to its fastest and its
-- longest list (Services/BoardService keeps them); a lobby writes the two
-- boards over the diner's back bar in white letters on their felt, the menu
-- board Normal and the specials board Hard, four lists of five each, and
-- reads them again now and then. The time is the server's own, so the
-- boards need no other check; only real runs count (Records.counts).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mall = require(Shared.Data.Mall)
local Net = require(Shared.Net)
local Records = require(Shared.Logic.Records)

local RecordsService = {}

-- The letters (white plastic on black felt) and the board's grid.
local INK = Color3.fromRGB(236, 232, 218)
local DIM = Color3.fromRGB(170, 164, 150)
local PPS = 60 -- pixels a stud: 13 x 4 studs is 780 x 240
local FONT = Enum.Font.Oswald

local BOARDS = { MenuBoard = "Normal", SpecialsBoard = "Hard" }
local SOLO_SHARE = 0.4 -- of the board's width, for the two solo lists

function RecordsService:Init(services)
	self.services = services
	self.boards = {} -- difficulty -> { [list id] = { labels } }
end

local function label(
	parent: Instance,
	text: string,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	size: number
)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(w, h)
	l.Font = FONT
	l.Text = text
	l.TextColor3 = color
	l.TextSize = size
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

-- The two boards' faces: a sheet of letters over each board's felt (the
-- block's own face, just in front of the felt: kitlib/mall2 menu_board).
function RecordsService:Build(parent: Instance, origin: Vector3)
	local places = self.services.PlaceService
	if places and places:IsRun() then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Records"
	folder.Parent = parent
	for _, b in Mall.Blocks do
		local difficulty = b.room == "diner" and BOARDS[b.name]
		if not difficulty then
			continue
		end
		local rot = b.rot or { 0, 0, 0 }
		local face = Instance.new("Part")
		face.Name = difficulty .. "Records"
		face.Anchored = true
		face.CanCollide = false
		face.CanQuery = false
		face.CanTouch = false
		face.Transparency = 1
		face.Size = Vector3.new(b.size[1], b.size[2], b.size[3])
		face.CFrame = CFrame.new(origin + Vector3.new(b.x, b.y, b.z))
			* CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		face.Parent = folder
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back -- (the block's +Z, its front)
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = PPS
		gui.LightInfluence = 0.5
		gui.Brightness = 1.2
		gui.MaxDistance = 90
		gui.Parent = face
		local w, h = b.size[1] * PPS, b.size[2] * PPS
		local top = label(gui, "THE SHORT NIGHT · OUT OF THE FRONT DOOR", 0, 4, w, 22, DIM, 18)
		top.TextXAlignment = Enum.TextXAlignment.Center
		local columns = {}
		-- (A squad's line holds its names: its columns get more of the board.)
		local solo = w * SOLO_SHARE / 2
		local squad = (w - 2 * solo) / 2
		local x = 0
		for i, list in Records.Lists do
			local cw = list.solo and solo or squad
			label(gui, list.title, x + 12, 30, cw - 18, 30, INK, 26)
			local rows = {}
			for r = 1, Records.Size do
				local row = label(gui, "", x + 12, 62 + (r - 1) * ((h - 70) / Records.Size), cw - 18, 32, INK, 24)
				-- (Long lines shrink a little before they're cut short.)
				row.TextScaled = true
				local limit = Instance.new("UITextSizeConstraint")
				limit.MaxTextSize = 24
				limit.MinTextSize = 15
				limit.Parent = row
				rows[r] = row
			end
			columns[list.id] = rows
			if i > 1 then
				local rule = Instance.new("Frame")
				rule.BackgroundColor3 = DIM
				rule.BackgroundTransparency = 0.6
				rule.BorderSizePixel = 0
				rule.Position = UDim2.fromOffset(x, 34)
				rule.Size = UDim2.fromOffset(2, h - 44)
				rule.Parent = gui
			end
			x += cw
		end
		self.boards[difficulty] = columns
	end
	self.services.BoardService.Changed:Connect(function()
		self:_render()
	end)
	self:_render()
	task.spawn(function()
		for _, difficulty in Records.Difficulties do
			for _, list in Records.Lists do
				self.services.BoardService:Watch(Records.board(difficulty, list.id), Records.Size, list.low)
			end
		end
	end)
end

function RecordsService:_render()
	for difficulty, columns in self.boards do
		for _, list in Records.Lists do
			local entries = self.services.BoardService:Get(Records.board(difficulty, list.id))
			for r, row in columns[list.id] do
				row.Text = string.format("%d  %s", r, Records.line(entries[r], list.solo))
				row.TextColor3 = entries[r] and INK or DIM
			end
		end
	end
end

-- A finished run (Services/RunOrchestrator): { won, extracted, studio,
-- debugged, night, difficulty, seconds, size, names, at, players }. Posts it
-- if it counts, and tells the squad where it landed.
function RecordsService:Post(run)
	local counts, why = Records.counts(run)
	if not counts and self.forceNext and (why == "studio" or why == "debug") then
		-- (F2 `record count`: the next run counts in Studio, for a test.)
		local test = table.clone(run)
		test.studio, test.debugged = false, false
		counts, why = Records.counts(test)
	end
	self.forceNext = nil
	if not counts then
		print("[Consensus] the diner's records: this run doesn't count (" .. tostring(why) .. ")")
		return
	end
	task.spawn(function()
		local entry = Records.entry(run)
		for _, list in Records.lists(run) do
			local rank = self.services.BoardService:Post(list.board, entry, Records.Size, list.low)
			if rank then
				local text = string.format(
					"On the diner's board: the %s%s %s, %s, on %s.",
					({ "", "2nd ", "3rd ", "4th ", "5th " })[rank] or "",
					list.low and "fastest" or "longest",
					(run.size or 1) <= 1 and "solo run" or "squad",
					Records.clock(entry.value),
					run.difficulty == "Hard" and "the specials board" or "the menu board"
				)
				for _, player in run.players or {} do
					if player.Parent then
						Net.get("Notify"):FireClient(player, text, "info")
					end
				end
			end
		end
	end)
end

return RecordsService
