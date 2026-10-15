-- The map and the journal (Tab; docs/plans/gameplay-rework.md, R2c "the map
-- and the journal"). The map draws the house as the squad knows it, from
-- the server's MapState (Services/MapService): rooms someone has been in,
-- doorways seen and their locks, where notes were read, keys and heirlooms
-- seen lying about, the puzzles and cases found, the table, and a friend
-- who's down. You are drawn; your living friends aren't (you can talk).
-- The journal lists the notes you've read (UI/Reader) and your key ring,
-- with a button to leave each key at your feet for someone else.
--
-- The map that saves time (docs/plans/level-design.md section 11, L3.5): a
-- pencil tick on a room with nothing the run needs left in it, a ring round
-- what's been seen and not yet done, the rooms of a floor whose house plans
-- someone has read (outlined, named), and who carries what.
--
-- The 1988 interface (V7): the map is a plan pencilled on graph paper (rooms
-- outlined in graphite and named by hand, locks and marks in coloured
-- pencil, where you stand in red, the room you're in highlighted), the
-- journal a page of a ring-bound notebook in ballpoint. The objective's slip
-- is taped to the header.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Assets = require(Shared.Assets)
local GuestMood = require(Shared.Logic.GuestMood)
local Net = require(Shared.Net)
local Ui = require(script.Parent.Parent.Lib.Ui)

local player = Players.LocalPlayer
local PA = Constants.PlayerAttributes

local Map = {}
Map.__index = Map

-- How each kind of doorway looks: colour, and its short tag.
-- What each storey is called (Logic/FloorPlan's names).
local MIN_ROOM_PIXELS = 56 -- the smallest room on the map, across its shorter side

local STOREY_NAMES = { [-1] = "Cellar", [0] = "Ground floor", [1] = "Upper floor", [2] = "Attic" }

-- Coloured pencils on graph paper (V7): dark enough to read on it.
local PENCIL = Ui.Theme.pencil
local RED = Ui.Theme.red
local DOORS = {
	door = { color = PENCIL },
	unknown = { color = PENCIL },
	key = { color = RED, tag = "KEY" },
	double = { color = RED, tag = "2 KEYS" },
	padlock = { color = Color3.fromRGB(180, 92, 18), tag = "CODE" },
	bolt = { color = Ui.Theme.pen, tag = "BOLT" },
	power = { color = Color3.fromRGB(150, 116, 0), tag = "POWER" },
	crank = { color = Color3.fromRGB(110, 78, 46), tag = "CRANK" },
	levers = { color = Color3.fromRGB(150, 104, 24), tag = "2 LEVERS" },
	-- Tool locks (docs/plans/level-design.md section 11, L3.3).
	boards = { color = Color3.fromRGB(116, 70, 36), tag = "BOARDS" },
	chain = { color = Color3.fromRGB(80, 84, 96), tag = "CHAIN" },
}
local MARKS = {
	terminal = { text = "PC", color = Color3.fromRGB(30, 110, 70) },
	display = { text = "CASE", color = Color3.fromRGB(40, 88, 130) },
	breaker = { text = "FUSES", color = Color3.fromRGB(150, 116, 0) },
	safe = { text = "SAFE", color = Color3.fromRGB(70, 72, 84) },
	musicbox = { text = "PIANO", color = Color3.fromRGB(112, 58, 130) },
	tunebox = { text = "MUSIC BOX", color = Color3.fromRGB(112, 58, 130) },
	crank = { text = "CRANK", color = Color3.fromRGB(110, 78, 46) },
	levers = { text = "LEVER", color = Color3.fromRGB(150, 104, 24) },
	dumbwaiter = { text = "LIFT", color = Color3.fromRGB(110, 88, 58) },
	-- A step's chest or fridge, chained or nailed shut (its label says which).
	piece = { text = "SHUT", color = Color3.fromRGB(96, 88, 80) },
	-- A corridor's landmark (its label is its name: "Stag's head").
	landmark = { text = "LANDMARK", color = Color3.fromRGB(96, 86, 66) },
}
local TICK = Ui.Theme.goodInk
local GOLD = Color3.fromRGB(160, 112, 14) -- the table, the heirlooms
local HIGHLIGHT = Color3.fromRGB(250, 236, 92) -- a highlighter on the room you're in

function Map.new(ctx)
	-- `floor`: the storey on show (the squad playtest, 2026-10-10: one floor
	-- at a time, flipped, opening on the one you stand on).
	local self = setmetatable({ ctx = ctx, tab = "Map", open = false, state = nil, floor = nil }, Map)
	local gui = Ui.screen("ConsensusMap", 40, ctx.playerGui)
	gui.Enabled = false
	self.gui = gui
	Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Parent = gui,
	})
	-- The paper: graph paper for the map, a notebook page for the journal
	-- (Map:Render swaps it).
	local holder, sheet = Ui.paper("Graph", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.86, 0, 0.82, 0),
		-- (Square: a turned frame stops clipping its scrolling body.)
		Parent = gui,
	})
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(1100, 720), Parent = holder })
	self.sheet = sheet
	Ui.modal(holder)
	local panel = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = sheet,
	})
	self.title = Ui.title("Map", {
		Position = UDim2.fromOffset(24, 8),
		Size = UDim2.fromOffset(300, 36),
		TextSize = 32,
		Parent = panel,
	})
	self.summary = Ui.typed("", {
		Position = UDim2.new(0, 24, 0, 46),
		Size = UDim2.new(0.5, -40, 0, 18),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextSize = 13,
		TextColor3 = Ui.Theme.typeDim,
		Parent = panel,
	})
	-- The objective's slip, taped to the header.
	local slipHolder, slip = Ui.paper("Slip", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -236, 0, 8),
		Size = UDim2.fromOffset(330, 62),
		Rotation = 1.2,
		Parent = panel,
	}, false)
	self.objective = Ui.hand("", {
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.new(1, -28, 1, -12),
		TextScaled = true,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 3,
		Parent = slip,
	})
	Ui.new("UITextSizeConstraint", { MaxTextSize = 23, MinTextSize = 13, Parent = self.objective })
	Ui.tape(slipHolder, UDim2.new(0, 10, 0, 6), -30, 56)
	self.objectiveSlip = slipHolder
	local tabs = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 10),
		Size = UDim2.fromOffset(200, 30),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Ui.list(6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right) })
	self.tabButtons = {}
	for _, name in { "Map", "Journal" } do
		self.tabButtons[name] = Ui.paperButton(
			name,
			{ Size = UDim2.fromOffset(94, 30), TextSize = 19, Parent = tabs },
			function()
				self.tab = name
				self:Render()
			end
		)
	end
	-- Up and down a floor (also the arrow keys, or the shoulder buttons).
	self.floorBar = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 44),
		Size = UDim2.fromOffset(220, 24),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = panel,
	}, { Ui.list(4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right) })
	self.floorDown = Ui.paperButton(
		"< down",
		{ Size = UDim2.fromOffset(60, 24), TextSize = 14, LayoutOrder = 1, Parent = self.floorBar },
		function()
			self:Flip(-1)
		end
	)
	self.floorName = Ui.hand("", {
		Size = UDim2.fromOffset(110, 24),
		TextSize = 23,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Parent = self.floorBar,
	})
	self.floorUp = Ui.paperButton(
		"up >",
		{ Size = UDim2.fromOffset(50, 24), TextSize = 14, LayoutOrder = 3, Parent = self.floorBar },
		function()
			self:Flip(1)
		end
	)
	UserInputService.InputBegan:Connect(function(input)
		if not self.open or self.tab ~= "Map" then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.Up or key == Enum.KeyCode.PageUp or key == Enum.KeyCode.ButtonR1 then
			self:Flip(1)
		elseif key == Enum.KeyCode.Down or key == Enum.KeyCode.PageDown or key == Enum.KeyCode.ButtonL1 then
			self:Flip(-1)
		end
	end)
	self.body = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(24, 78),
		Size = UDim2.new(1, -48, 1, -98),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Ui.Theme.type,
		ScrollBarImageTransparency = 0.5,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.XY,
		Parent = panel,
	})
	ctx.state.LayoutChanged:Connect(function()
		if self.open then
			self:Render()
		end
	end)
	Net.get("MapState").OnClientEvent:Connect(function(state)
		self.state = state
		if self.open then
			self:Render()
		end
	end)
	player:GetAttributeChangedSignal(PA.KeyRing):Connect(function()
		if self.open and self.tab == "Journal" then
			self:Render()
		end
	end)
	return self
end

function Map:Toggle()
	if not self.ctx.state:InRun() and not self.open then
		return
	end
	self.open = not self.open
	self.gui.Enabled = self.open
	if self.open then
		-- Open on the floor you stand on.
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		self.floor = root and self.ctx.state:StoreyAt(root.Position.Y) or self.floor
		self:Render()
	end
end

-- Show the next floor up (1) or down (-1) that someone has seen.
function Map:Flip(step: number)
	local floors = self.floors or {}
	local at = table.find(floors, self.floor) or 1
	local nextFloor = floors[math.clamp(at + step, 1, math.max(1, #floors))]
	if nextFloor ~= nil and nextFloor ~= self.floor then
		self.floor = nextFloor
		self:Render()
	end
end

function Map:_clear()
	for _, child in self.body:GetChildren() do
		child:Destroy()
	end
end

function Map:Render()
	self:_clear()
	self.title.Text = self.tab
	self.floorBar.Visible = false
	-- The paper for the tab, and the tab you're on underlined in red.
	local journal = self.tab == "Journal"
	local paper = Assets.Paper[journal and "Notebook" or "Graph"]
	self.sheet.Image = paper.image
	self.sheet.ScaleType = journal and Enum.ScaleType.Stretch or Enum.ScaleType.Tile
	if not journal then
		self.sheet.TileSize = UDim2.fromOffset(paper.tile, paper.tile)
	end
	for name, button in self.tabButtons do
		button.TextColor3 = name == self.tab and Ui.Theme.red or Ui.Theme.type
	end
	-- (On the notebook the writing starts right of its red margin, drawn at
	-- 110 of its 768 pixels.)
	local left = journal and UDim.new(110 / 768, 16) or UDim.new(0, 24)
	self.title.Position = UDim2.new(left, UDim.new(0, 8))
	self.summary.Position = UDim2.new(left, UDim.new(0, 46))
	self.summary.Size = UDim2.new(UDim.new(0.5 - left.Scale, -left.Offset - 34), UDim.new(0, 18))
	self.body.Position = UDim2.new(left, UDim.new(0, 78))
	self.body.Size = UDim2.new(UDim.new(1 - left.Scale, -left.Offset - 24), UDim.new(1, -98))
	local objective = self.ctx.state:Run(Constants.RunState.Objective) or ""
	self.objective.Text = objective
	self.objectiveSlip.Visible = objective ~= ""
	if self.tab == "Journal" then
		self:_renderJournal()
	else
		self:_renderMap()
	end
end

-- The map ---------------------------------------------------------------------------

function Map:_summary(state)
	local parts = {}
	if state and state.table then
		table.insert(parts, string.format("Places set: %d of %d", state.table.set, state.table.places))
	end
	local locked = 0
	for _, door in state and state.doors or {} do
		if DOORS[door.kind] and DOORS[door.kind].tag then
			locked += 1
		end
	end
	if locked > 0 then
		table.insert(parts, locked .. (locked == 1 and " lock" or " locks") .. " found")
	end
	table.insert(parts, "Only what someone has seen.")
	return table.concat(parts, "  ·  ")
end

function Map:_renderMap()
	local layout = self.ctx.state.layout
	local state = self.state
	self.summary.Text = self:_summary(state)
	if not layout or not state then
		Ui.hand("No map yet.", { Size = UDim2.fromOffset(300, 24), Parent = self.body })
		return
	end
	local ox, oz = layout.origin[1], layout.origin[3]
	local byId = {}
	for _, room in layout.rooms do
		byId[room.id] = room
	end
	-- Rooms someone has been in, and the far side of a doorway seen (an
	-- outline: a room is there, nobody knows what).
	local entered, glimpsed = {}, {}
	for _, id in state.rooms do
		entered[id] = true
	end
	for _, door in state.doors do
		for _, id in { door.a, door.b } do
			if not entered[id] then
				glimpsed[id] = true
			end
		end
	end
	-- Nothing left in it the run needs (a tick).
	local done = {}
	for _, id in state.done or {} do
		done[id] = true
	end
	-- The rooms of a floor whose house plans someone has read (never a
	-- servants' passage: Logic/HousePlans).
	local planned = {}
	for _, storey in state.plans or {} do
		for _, room in layout.rooms do
			local bottom = room.floor or 0
			local roof = room.tall and (room.top or bottom + 1) or bottom
			if storey >= bottom and storey <= roof and not room.passage and room.kind ~= "passage" then
				if not entered[room.id] and not glimpsed[room.id] then
					planned[room.id] = true
				end
			end
		end
	end
	local shown = {}
	for id in entered do
		table.insert(shown, byId[id])
	end
	for id in glimpsed do
		table.insert(shown, byId[id])
	end
	for id in planned do
		table.insert(shown, byId[id])
	end
	if #shown == 0 then
		Ui.hand("Nowhere yet.", { Size = UDim2.fromOffset(300, 24), Parent = self.body })
		return
	end
	-- The rooms on the map set the scale (the outside playtest's map clipped
	-- when the whole house did), never smaller than a readable room
	-- (MIN_ROOM_PIXELS); the body scrolls when it outgrows the panel. The
	-- mansion's storeys side by side, two to a row when the house has a cellar
	-- or an attic as well (docs/plans/level-design.md section 10.1), and only
	-- the storeys somebody has seen a room on.
	-- One storey at a time (the squad playtest, 2026-10-10), of those somebody
	-- has seen a room on; the others a flip away. The frame is the whole of
	-- what's been seen, so a floor keeps its place when you flip.
	local storeyShown = {}
	for _, room in shown do
		local bottom = room.floor or 0
		local roof = room.tall and (room.top or bottom + 1) or bottom
		for f = bottom, roof do
			storeyShown[f] = true
		end
	end
	local floors = {}
	for f in storeyShown do
		table.insert(floors, f)
	end
	table.sort(floors)
	self.floors = floors
	if self.floor == nil or not storeyShown[self.floor] then
		-- The nearest seen floor to the one asked for (or the ground floor).
		local want, best = self.floor or 0, nil
		for _, f in floors do
			if best == nil or math.abs(f - want) < math.abs(best - want) then
				best = f
			end
		end
		self.floor = best or 0
	end
	local view = self.floor
	local low, high = view, view
	local count = #floors
	self.floorBar.Visible = count > 1
	self.floorName.Text = STOREY_NAMES[view] or ("Floor " .. view)
	local at = table.find(floors, view) or 1
	self.floorDown.Visible = at > 1
	self.floorUp.Visible = at < count
	local cols, rows = 1, 1
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	local smallest = math.huge
	for _, room in shown do
		minX, maxX = math.min(minX, room.x), math.max(maxX, room.x + room.w)
		minZ, maxZ = math.min(minZ, room.z), math.max(maxZ, room.z + room.d)
		smallest = math.min(smallest, room.w, room.d)
	end
	local gap = 30
	local label = 24 -- pixels under each storey for its name
	local width = (maxX - minX) * cols + gap * (cols - 1)
	local height = maxZ - minZ
	-- As big as the panel allows, under the floors' names and the key (the
	-- panel's size from the screen's: it isn't measured yet the moment the
	-- map opens).
	local viewport = workspace.CurrentCamera.ViewportSize
	local areaX = math.min(viewport.X * 0.86, 1100) - 56
	local areaY = math.min(viewport.Y * 0.82, 720) - 92 - 46 - label * rows
	local scale = math.min(math.max(150, areaY) / (height * rows), math.max(300, areaX) / width)
	if smallest < math.huge then
		scale = math.max(scale, MIN_ROOM_PIXELS / smallest)
	end
	local rowPixels = height * scale + label
	local canvas = Ui.new("Frame", {
		Size = UDim2.fromOffset(width * scale, rowPixels * rows + 40),
		BackgroundTransparency = 1,
		Parent = self.body,
	})
	-- Where a storey's plan starts on the canvas, in pixels.
	local function corner(floor: number): (number, number)
		local i = math.clamp(floor, low, high) - low
		return (i % cols) * (maxX - minX + gap) * scale, (i // cols) * rowPixels
	end
	-- Where a point on the floor on show goes; nil on another floor.
	local function toMap(x: number, z: number, floor: number?): (number?, number?)
		if (floor or 0) ~= view then
			return nil, nil
		end
		local left, top = corner(view)
		return left + ((x - ox) - minX) * scale, top + ((z - oz) - minZ) * scale
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local here = root and self.ctx.state:RoomAt(root.Position)
	for floor = low, high do
		local left, top = corner(floor)
		local lanterns = {}
		for _, entry in state.lanterns or {} do
			lanterns[entry.room] = entry.lit
		end
		for _, room in shown do
			local bottom = room.floor or 0
			local roof = room.tall and (room.top or bottom + 1) or bottom
			if floor >= bottom and floor <= roof then
				self:_room(canvas, room, floor, entered[room.id] == true, here, scale, minX, minZ, left, top, {
					done = done[room.id] == true,
					planned = planned[room.id] == true,
					hint = state.hint == room.id,
					lantern = lanterns[room.id],
				})
			end
		end
	end
	-- The table.
	local tableX, tableY = nil, nil
	if state.table then
		tableX, tableY = toMap(state.table.x, state.table.z, state.table.floor)
	end
	if tableX and tableY then
		local x, y = tableX, tableY
		self:_dot(canvas, x, y, 14, GOLD, string.format("table %d/%d", state.table.set, state.table.places))
	end
	for _, door in state.doors do
		local look = DOORS[door.kind] or DOORS.door
		local x, y = toMap(door.x, door.z, door.floor)
		if not x or not y then
			continue
		end
		local size = look.tag and 9 or 6
		if look.tag then
			-- A lock seen and not yet open: something to do here.
			self:_ring(canvas, x, y, 19, look.color)
		end
		Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = look.color,
			Rotation = 45,
			Parent = canvas,
		})
		if look.tag then
			Ui.hand(look.tag .. (door.label and (" " .. door.label) or ""), {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(x, y + 6),
				Size = UDim2.fromOffset(150, 19),
				FontFace = Ui.Fonts.handBold,
				TextSize = 17,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = look.color,
				ZIndex = 4,
				Parent = canvas,
			})
		end
	end
	for _, note in state.notes do
		local x, y = toMap(note.x, note.z, note.floor)
		if not x or not y then
			continue
		end
		self:_dot(canvas, x, y, 8, Ui.Theme.pen, "note")
	end
	for _, item in state.items do
		local x, y = toMap(item.x, item.z, item.floor)
		if not x or not y then
			continue
		end
		local color = item.kind == "heirloom" and GOLD
			or item.kind == "valuable" and Color3.fromRGB(70, 84, 110)
			or Color3.fromRGB(136, 96, 16)
		self:_dot(canvas, x, y, 8, color, item.label)
	end
	for _, mark in state.marks do
		local look = MARKS[mark.kind] or { text = mark.label or mark.kind, color = Ui.Theme.text }
		local text = (mark.kind == "piece" or mark.kind == "landmark") and mark.label or look.text
		local x, y = toMap(mark.x, mark.z, mark.floor)
		if not x or not y then
			continue
		end
		local color = mark.done and Ui.Theme.typeDim or look.color
		if not mark.done and mark.kind ~= "landmark" then
			self:_ring(canvas, x, y, 18, color)
		end
		self:_dot(canvas, x, y, 8, color, text .. (mark.done and " (done)" or ""))
	end
	local elsewhere = {}
	for _, down in state.downed do
		local x, y = toMap(down.x, down.z, down.floor)
		if x and y then
			self:_dot(canvas, x, y, 12, RED, down.name .. " is down")
		else
			local where = STOREY_NAMES[down.floor or 0] or "another floor"
			table.insert(elsewhere, down.name .. " is down (" .. string.lower(where) .. ")")
		end
	end
	if #elsewhere > 0 then
		self.summary.Text ..= "  ·  " .. table.concat(elsewhere, ", ")
	end
	-- You: a dot, and a stroke the way you face.
	local youX, youY = nil, nil
	if root then
		youX, youY = toMap(root.Position.X, root.Position.Z, self.ctx.state:StoreyAt(root.Position.Y))
	end
	if root and youX and youY then
		local x, y = youX, youY
		local look = root.CFrame.LookVector
		local facing = Vector2.new(look.X, look.Z)
		if facing.Magnitude > 1e-3 then
			facing = facing.Unit
			-- Map x is the world's X and map y its Z, so a bar turned by this
			-- angle points the way you face.
			Ui.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(x + facing.X * 7, y + facing.Y * 7),
				Size = UDim2.fromOffset(13, 3),
				BackgroundColor3 = RED,
				BorderSizePixel = 0,
				Rotation = math.deg(math.atan2(facing.Y, facing.X)),
				ZIndex = 4,
				Parent = canvas,
			})
		end
		self:_dot(canvas, x, y, 11, RED, "you")
	end
	Ui.typed(
		"Diamonds: doorways; a ring: seen, not done yet.  A tick: nothing left there.  note: read here.  At the table: places set.",
		{
			Position = UDim2.fromOffset(0, rowPixels * rows + 4),
			-- (A small floor, the attic's, is narrower than the line: it wraps.)
			Size = UDim2.fromOffset(math.max(width * scale, 360), 18),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = 12,
			TextColor3 = Ui.Theme.typeDim,
			Parent = canvas,
		}
	)
end

function Map:_room(canvas, room, floor: number, entered: boolean, here, scale, minX, minZ, left, top, o)
	local x0, z0 = left + (room.x - minX) * scale, top + (room.z - minZ) * scale
	local isHere = here and here.id == room.id
	-- Pencilled on the graph paper: an outline in graphite, the room you're in
	-- gone over with a highlighter, a lantern's room shaded, a done room's
	-- outline lighter.
	local fill = isHere and HIGHLIGHT or PENCIL
	local fillAlpha = isHere and 0.78 or (room.lantern and 0.84 or 0.94)
	if not entered then
		-- Glimpsed through a doorway: there's a room, nobody knows what. From
		-- the house plans: its outline in blue pencil and its name, faint.
		Ui.new("TextLabel", {
			Position = UDim2.fromOffset(x0 + 2, z0 + 2),
			Size = UDim2.fromOffset(room.w * scale - 4, room.d * scale - 4),
			BackgroundTransparency = 1,
			Text = o.planned and room.name or "",
			TextWrapped = true,
			TextScaled = room.w * scale < 70,
			TextSize = 17,
			TextYAlignment = Enum.TextYAlignment.Top,
			FontFace = Ui.Fonts.hand,
			TextColor3 = o.planned and Ui.Theme.pen or PENCIL,
			TextTransparency = 0.3,
			Parent = canvas,
		}, {
			Ui.corner(2),
			Ui.stroke(o.planned and Ui.Theme.pen or PENCIL, 1, o.planned and 0.45 or 0.65),
			Ui.new("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 10 }),
			Ui.padding(3),
		})
		return
	end
	if room.tall and room.role == "start" and floor == 1 then
		-- Upstairs the hall is only its gallery, round three walls over the
		-- open hall (Logic/TallRooms).
		local g = 8 * scale
		for _, strip in
			{
				{ 0, 0, room.w * scale, g },
				{ 0, g, g, room.d * scale - g },
				{ room.w * scale - g, g, g, room.d * scale - g },
			}
		do
			Ui.new("Frame", {
				Position = UDim2.fromOffset(x0 + strip[1] + 2, z0 + strip[2] + 2),
				Size = UDim2.fromOffset(math.max(1, strip[3] - 4), math.max(1, strip[4] - 4)),
				BackgroundColor3 = fill,
				BackgroundTransparency = fillAlpha,
				Parent = canvas,
			}, { Ui.stroke(PENCIL, 1.5, 0.2) })
		end
		return
	end
	local tag = room.role == "start" and " (Hall)"
		or room.role == "deliberation" and " (Table)"
		or room.kind == "stair" and " (Stairs)"
		or ""
	if room.lantern then
		-- Seen lit, seen unlit, or not seen yet (WP3: the map says which).
		tag ..= o.lantern == true and " (Lantern, lit)" or o.lantern == false and " (unlit lantern)" or " (Lantern)"
	end
	Ui.new("TextLabel", {
		Position = UDim2.fromOffset(x0 + 2, z0 + 2),
		Size = UDim2.fromOffset(room.w * scale - 4, room.d * scale - 4),
		BackgroundColor3 = fill,
		BackgroundTransparency = fillAlpha,
		Text = room.name .. tag,
		TextWrapped = true,
		TextSize = 20,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextYAlignment = Enum.TextYAlignment.Top,
		FontFace = Ui.Fonts.hand,
		LineHeight = 0.9,
		TextColor3 = PENCIL,
		TextTransparency = (o.done and not isHere) and 0.35 or 0,
		Parent = canvas,
	}, {
		Ui.stroke(PENCIL, 1.5, (o.done and not isHere) and 0.55 or 0.15),
		Ui.new("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 11 }),
		Ui.padding(4),
	})
	if o.done then
		-- Bottom right, clear of the name.
		self:_tick(canvas, x0 + room.w * scale - 16, z0 + room.d * scale - 10)
	end
	if o.hint then
		-- Stuck-assist: the room the objective line points at.
		self:_ring(canvas, x0 + room.w * scale / 2, z0 + room.d * scale / 2, 30, RED)
	end
end

-- A pencil tick: a short stroke down and a long one up, from (x, y).
function Map:_tick(canvas, x: number, y: number)
	for _, stroke in { { x + 1.5, y + 1.5, 5, 45 }, { x + 6, y - 0.5, 10, -50 } } do
		Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(stroke[1], stroke[2]),
			Size = UDim2.fromOffset(stroke[3], 2),
			BackgroundColor3 = TICK,
			BorderSizePixel = 0,
			Rotation = stroke[4],
			ZIndex = 4,
			Parent = canvas,
		})
	end
end

-- A ring round something seen and not yet done.
function Map:_ring(canvas, x: number, y: number, size: number, color: Color3)
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = canvas,
	}, { Ui.corner(size), Ui.stroke(color, 1.5, 0.15) })
end

-- A small round mark with a word under it.
function Map:_dot(canvas, x: number, y: number, size: number, color: Color3, text: string?)
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		ZIndex = 4,
		Parent = canvas,
	}, { Ui.corner(size) })
	if text then
		-- On a scrap of the paper's own colour, above the room it stands in, so
		-- it reads over the pencil lines.
		Ui.hand(text, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(x, y + size / 2),
			Size = UDim2.fromOffset(16 + 8 * #text, 19),
			BackgroundColor3 = Color3.fromRGB(238, 236, 224),
			BackgroundTransparency = 0.1,
			FontFace = Ui.Fonts.handBold,
			TextSize = 17,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = color,
			ZIndex = 5,
			Parent = canvas,
		})
	end
end

-- The journal -----------------------------------------------------------------------

function Map:_renderJournal()
	self.summary.Text = "Your keys, who carries what, his moods, notes read."
	local list = Ui.new("Frame", {
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self.body,
	}, { Ui.list(6) })
	-- Written in ballpoint: headings gone over twice and underlined.
	local function heading(text: string, order: number)
		local label = Ui.hand(text, {
			Size = UDim2.new(1, 0, 0, 36),
			FontFace = Ui.Fonts.handBold,
			TextSize = 29,
			TextColor3 = Ui.Theme.pen,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			LayoutOrder = order,
			Parent = list,
		})
		local underline = Ui.new("Frame", {
			Position = UDim2.new(0, 0, 1, -2),
			Size = UDim2.fromOffset(0, 2),
			BackgroundColor3 = Ui.Theme.pen,
			BackgroundTransparency = 0.25,
			Rotation = -0.6,
			Parent = label,
		})
		-- (As long as the words, once they're drawn.)
		task.defer(function()
			underline.Size = UDim2.fromOffset(label.TextBounds.X + 8, 2)
		end)
	end
	local function line(text: string, order: number, dim: boolean?)
		return Ui.hand(text, {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = 24,
			LineHeight = 0.9,
			TextColor3 = dim and Ui.Theme.pencil or Ui.Theme.pen,
			TextTransparency = dim and 0.15 or 0,
			LayoutOrder = order,
			Parent = list,
		})
	end
	heading("Your keys", 1)
	local ring = player:GetAttribute(PA.KeyRing)
	local order = 2
	if typeof(ring) ~= "string" or ring == "" then
		line("None. A key you find goes on your ring; a locked door takes it.", order, true)
		order += 1
	else
		for entry in string.gmatch(ring, "[^\n]+") do
			-- token=label=where its door is (empty until someone has seen it).
			local token, label, place = string.match(entry, "^([^=]+)=([^=]*)=?(.*)$")
			if token then
				local row = Ui.new("Frame", {
					Size = UDim2.new(1, 0, 0, 44),
					BackgroundTransparency = 1,
					LayoutOrder = order,
					Parent = list,
				})
				order += 1
				Ui.hand(label, {
					Size = UDim2.new(1, -170, 0, 26),
					TextSize = 25,
					TextColor3 = Ui.Theme.pen,
					Parent = row,
				})
				Ui.hand((place and place ~= "") and ("its door: in " .. place) or "its door: not found yet", {
					Position = UDim2.fromOffset(14, 24),
					Size = UDim2.new(1, -184, 0, 20),
					TextSize = 21,
					TextColor3 = Ui.Theme.pencil,
					Parent = row,
				})
				Ui.paperButton("Leave it here", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 2),
					Size = UDim2.fromOffset(160, 28),
					TextSize = 15,
					Parent = row,
				}, function()
					Net.get("DropKey"):FireServer(token)
				end)
			end
		end
	end
	-- Who carries which key and which tool (everyone sees everyone's).
	heading("Who carries what", 60)
	local carried = self.state and self.state.carried or {}
	if #carried == 0 then
		line("Nobody carries a key or a tool for a lock yet.", 61, true)
	end
	for i, entry in carried do
		line(entry.name .. ": " .. table.concat(entry.what, ", "), 61 + i)
	end
	-- His moods you've seen ("a Guest you can read", 2026-10-11): a field
	-- guide, each with its tell and what to do (Logic/GuestMood.lesson).
	heading("His moods you've seen", 80)
	local guest = self.ctx.controllers.GuestController
	local moods = guest and guest:MoodsSeen() or {}
	if #moods == 0 then
		line("None yet. Watch him a moment when he stands still: how he holds himself says what he's about.", 81, true)
	end
	for i, id in moods do
		line(GuestMood.lesson(id) or id, 81 + i)
	end
	heading("Notes you've read", 100)
	local reader = self.ctx.ui.components.Reader
	local notes = reader and reader:Read() or {}
	if #notes == 0 then
		line("None yet.", 101, true)
	end
	for i, note in notes do
		-- The note itself, taped into the notebook.
		local pasted = Ui.new("Frame", {
			Size = UDim2.new(1, -40, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 101 + i,
			Parent = list,
		}, { Ui.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4) }) })
		local paper = Ui.new("ImageLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Image = Assets.Paper.Sheet.image,
			ScaleType = Enum.ScaleType.Stretch,
			Parent = pasted,
		}, {
			Ui.new("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
			}),
		})
		Ui.hand(note.text, {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = 24,
			LineHeight = 0.9,
			TextColor3 = Ui.Theme.pen,
			Parent = paper,
		})
		Ui.tape(pasted, UDim2.new(0, 24, 0, 8), -20, 64)
	end
end

return Map
