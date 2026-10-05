-- The map and the journal (Tab; docs/plans/gameplay-rework.md, R2c "the map
-- and the journal"). The map draws the house as the squad knows it, from
-- the server's MapState (Services/MapService): rooms someone has been in,
-- doorways seen and their locks, where notes were read, keys and heirlooms
-- seen lying about, the puzzles and cases found, the table, and a friend
-- who's down. You are drawn; your living friends aren't (you can talk).
-- The journal lists the notes you've read (UI/Reader) and your key ring,
-- with a button to leave each key at your feet for someone else.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Ui = require(script.Parent.Parent.Lib.Ui)

local player = Players.LocalPlayer
local PA = Constants.PlayerAttributes

local Map = {}
Map.__index = Map

-- How each kind of doorway looks: colour, and its short tag.
-- What each storey is called (Logic/FloorPlan's names).
local STOREY_NAMES = { [-1] = "Cellar", [0] = "Ground floor", [1] = "Upper floor", [2] = "Attic" }

local DOORS = {
	door = { color = Color3.fromRGB(150, 140, 120) },
	unknown = { color = Color3.fromRGB(150, 140, 120) },
	key = { color = Color3.fromRGB(196, 74, 60), tag = "KEY" },
	double = { color = Color3.fromRGB(196, 74, 60), tag = "2 KEYS" },
	padlock = { color = Color3.fromRGB(214, 150, 60), tag = "CODE" },
	bolt = { color = Color3.fromRGB(120, 140, 190), tag = "BOLT" },
	power = { color = Color3.fromRGB(230, 200, 70), tag = "POWER" },
	crank = { color = Color3.fromRGB(180, 150, 120), tag = "CRANK" },
}
local MARKS = {
	terminal = { text = "PC", color = Color3.fromRGB(120, 200, 150) },
	display = { text = "CASE", color = Color3.fromRGB(170, 200, 220) },
	breaker = { text = "FUSES", color = Color3.fromRGB(230, 200, 70) },
	safe = { text = "SAFE", color = Color3.fromRGB(200, 200, 210) },
	musicbox = { text = "PIANO", color = Color3.fromRGB(220, 190, 230) },
	crank = { text = "CRANK", color = Color3.fromRGB(180, 150, 120) },
	dumbwaiter = { text = "LIFT", color = Color3.fromRGB(190, 170, 140) },
}

function Map.new(ctx)
	local self = setmetatable({ ctx = ctx, tab = "Map", open = false, state = nil }, Map)
	local gui = Ui.screen("ConsensusMap", 40, ctx.playerGui)
	gui.Enabled = false
	self.gui = gui
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.86, 0, 0.82, 0),
		BackgroundColor3 = Ui.Theme.panel,
		BackgroundTransparency = 0.05,
		Parent = gui,
	}, {
		Ui.corner(10),
		Ui.stroke(Ui.Theme.accent, 1, 0.5),
		Ui.new("UISizeConstraint", { MaxSize = Vector2.new(1100, 720) }),
	})
	Ui.modal(panel)
	self.title = Ui.label("MAP", {
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.fromOffset(300, 28),
		Font = Ui.Theme.fontType,
		TextSize = 26,
		TextColor3 = Ui.Theme.accent,
		Parent = panel,
	})
	self.summary = Ui.label("", {
		Position = UDim2.new(0, 20, 0, 42),
		Size = UDim2.new(1, -40, 0, 20),
		TextSize = 14,
		TextColor3 = Ui.Theme.textDim,
		Parent = panel,
	})
	local tabs = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 14),
		Size = UDim2.fromOffset(360, 32),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Ui.list(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right) })
	for _, name in { "Map", "Journal" } do
		Ui.button(name, { Size = UDim2.fromOffset(100, 30), TextSize = 14, Parent = tabs }, function()
			self.tab = name
			self:Render()
		end)
	end
	self.body = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 72),
		Size = UDim2.new(1, -40, 1, -92),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
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
	self.title.Text = string.upper(self.tab)
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
		Ui.label("No map yet.", { Size = UDim2.fromOffset(300, 20), Parent = self.body })
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
	local shown = {}
	for id in entered do
		table.insert(shown, byId[id])
	end
	for id in glimpsed do
		table.insert(shown, byId[id])
	end
	if #shown == 0 then
		Ui.label("Nowhere yet.", { Size = UDim2.fromOffset(300, 20), Parent = self.body })
		return
	end
	-- The whole house's extent sets the scale (so the map doesn't jump as it
	-- grows). The mansion's storeys side by side, two to a row when the
	-- house has a cellar or an attic as well (docs/plans/level-design.md
	-- section 10.1).
	local low, high = 0, 0
	if layout.mode == "Mansion" then
		local range = layout.storeys or { 0, 1 }
		low, high = range[1], range[2]
	end
	local count = high - low + 1
	local cols = math.min(count, 2)
	local rows = math.ceil(count / cols)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, room in layout.rooms do
		minX, maxX = math.min(minX, room.x), math.max(maxX, room.x + room.w)
		minZ, maxZ = math.min(minZ, room.z), math.max(maxZ, room.z + room.d)
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
	local function toMap(x: number, z: number, floor: number)
		local left, top = corner(floor)
		return left + ((x - ox) - minX) * scale, top + ((z - oz) - minZ) * scale
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local here = root and self.ctx.state:RoomAt(root.Position)
	for floor = low, high do
		local left, top = corner(floor)
		if count > 1 then
			Ui.label(STOREY_NAMES[floor] or ("Floor " .. floor), {
				Position = UDim2.fromOffset(left, top + height * scale + 4),
				Size = UDim2.fromOffset((maxX - minX) * scale, 18),
				TextSize = 13,
				TextColor3 = Ui.Theme.textDim,
				Parent = canvas,
			})
		end
		for _, room in shown do
			local bottom = room.floor or 0
			local roof = room.tall and (room.top or bottom + 1) or bottom
			if floor >= bottom and floor <= roof then
				self:_room(canvas, room, floor, entered[room.id] == true, here, scale, minX, minZ, left, top)
			end
		end
	end
	-- The table.
	if state.table then
		local x, y = toMap(state.table.x, state.table.z, state.table.floor)
		self:_dot(
			canvas,
			x,
			y,
			14,
			Color3.fromRGB(230, 200, 120),
			string.format("%d/%d", state.table.set, state.table.places)
		)
	end
	for _, door in state.doors do
		local look = DOORS[door.kind] or DOORS.door
		local x, y = toMap(door.x, door.z, door.floor)
		local size = look.tag and 9 or 6
		Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = look.color,
			Rotation = 45,
			Parent = canvas,
		})
		if look.tag then
			Ui.label(look.tag .. (door.label and (" " .. door.label) or ""), {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(x, y + 6),
				Size = UDim2.fromOffset(120, 12),
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = look.color,
				Parent = canvas,
			})
		end
	end
	for _, note in state.notes do
		local x, y = toMap(note.x, note.z, note.floor)
		self:_dot(canvas, x, y, 8, Color3.fromRGB(230, 222, 196), "note")
	end
	for _, item in state.items do
		local x, y = toMap(item.x, item.z, item.floor)
		local color = item.kind == "heirloom" and Color3.fromRGB(230, 200, 120) or Color3.fromRGB(214, 180, 90)
		self:_dot(canvas, x, y, 8, color, item.label)
	end
	for _, mark in state.marks do
		local look = MARKS[mark.kind] or { text = mark.label or mark.kind, color = Ui.Theme.text }
		local x, y = toMap(mark.x, mark.z, mark.floor)
		local color = mark.done and Ui.Theme.textDim or look.color
		self:_dot(canvas, x, y, 8, color, look.text .. (mark.done and " (done)" or ""))
	end
	for _, down in state.downed do
		local x, y = toMap(down.x, down.z, down.floor)
		self:_dot(canvas, x, y, 12, Color3.fromRGB(220, 60, 50), down.name .. " is down")
	end
	-- You: a dot, and a stroke the way you face.
	if root then
		local floor = self.ctx.state:StoreyAt(root.Position.Y)
		local x, y = toMap(root.Position.X, root.Position.Z, floor)
		local look = root.CFrame.LookVector
		local facing = Vector2.new(look.X, look.Z)
		if facing.Magnitude > 1e-3 then
			facing = facing.Unit
			-- Map x is the world's X and map y its Z, so a bar turned by this
			-- angle points the way you face.
			Ui.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(x + facing.X * 7, y + facing.Y * 7),
				Size = UDim2.fromOffset(12, 3),
				BackgroundColor3 = Ui.Theme.accent,
				BorderSizePixel = 0,
				Rotation = math.deg(math.atan2(facing.Y, facing.X)),
				Parent = canvas,
			})
		end
		self:_dot(canvas, x, y, 10, Ui.Theme.accent, "you")
	end
	Ui.label(
		"Diamonds: doorways.  KEY, CODE, BOLT, POWER, CRANK: locks.  note: read here.  At the table: places set.",
		{
			Position = UDim2.fromOffset(0, rowPixels * rows + 4),
			Size = UDim2.fromOffset(width * scale, 18),
			TextSize = 12,
			TextColor3 = Ui.Theme.textDim,
			Parent = canvas,
		}
	)
end

function Map:_room(canvas, room, floor: number, entered: boolean, here, scale, minX, minZ, left, top)
	local x0, z0 = left + (room.x - minX) * scale, top + (room.z - minZ) * scale
	local isHere = here and here.id == room.id
	local color = isHere and Ui.Theme.accent or (room.lantern and Color3.fromRGB(90, 70, 40) or Ui.Theme.panelLight)
	if not entered then
		-- Glimpsed through a doorway: there's a room, nobody knows what.
		Ui.new("Frame", {
			Position = UDim2.fromOffset(x0 + 2, z0 + 2),
			Size = UDim2.fromOffset(room.w * scale - 4, room.d * scale - 4),
			BackgroundTransparency = 1,
			Parent = canvas,
		}, { Ui.corner(4), Ui.stroke(Ui.Theme.textDim, 1, 0.6) })
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
				BackgroundColor3 = color,
				Parent = canvas,
			}, { Ui.corner(3) })
		end
		return
	end
	local tag = room.role == "start" and " (Hall)"
		or room.role == "deliberation" and " (Table)"
		or room.kind == "stair" and " (Stairs)"
		or ""
	if room.lantern then
		tag ..= " (Lantern)"
	end
	Ui.new("TextLabel", {
		Position = UDim2.fromOffset(x0 + 2, z0 + 2),
		Size = UDim2.fromOffset(room.w * scale - 4, room.d * scale - 4),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.15,
		Text = room.name .. tag,
		TextWrapped = true,
		TextScaled = room.w * scale < 70,
		TextSize = 12,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Ui.Theme.font,
		TextColor3 = isHere and Ui.Theme.ink or Ui.Theme.text,
		Parent = canvas,
	}, { Ui.corner(4), Ui.new("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 7 }), Ui.padding(3) })
end

-- A small round mark with a word under it.
function Map:_dot(canvas, x: number, y: number, size: number, color: Color3, text: string?)
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		Parent = canvas,
	}, { Ui.corner(size) })
	if text then
		Ui.label(text, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(x, y + size / 2 + 1),
			Size = UDim2.fromOffset(140, 12),
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = color,
			Parent = canvas,
		})
	end
end

-- The journal -----------------------------------------------------------------------

function Map:_renderJournal()
	self.summary.Text = "What you've read, and the keys you carry."
	local list = Ui.new("Frame", {
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self.body,
	}, { Ui.list(10) })
	local function heading(text: string, order: number)
		Ui.label(text, {
			Size = UDim2.new(1, 0, 0, 24),
			Font = Ui.Theme.fontType,
			TextSize = 18,
			TextColor3 = Ui.Theme.accent,
			LayoutOrder = order,
			Parent = list,
		})
	end
	heading("Your keys", 1)
	local ring = player:GetAttribute(PA.KeyRing)
	local order = 2
	if typeof(ring) ~= "string" or ring == "" then
		Ui.label("None. A key you find goes on your ring; a locked door takes it.", {
			Size = UDim2.new(1, 0, 0, 20),
			TextSize = 14,
			TextColor3 = Ui.Theme.textDim,
			LayoutOrder = order,
			Parent = list,
		})
		order += 1
	else
		for line in string.gmatch(ring, "[^\n]+") do
			local token, label = string.match(line, "^([^=]+)=(.*)$")
			if token then
				local row = Ui.new("Frame", {
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 1,
					LayoutOrder = order,
					Parent = list,
				})
				order += 1
				Ui.label(label, {
					Size = UDim2.new(1, -150, 1, 0),
					TextSize = 15,
					Parent = row,
				})
				Ui.button("Leave it here", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 0),
					Size = UDim2.fromOffset(140, 28),
					TextSize = 13,
					Parent = row,
				}, function()
					Net.get("DropKey"):FireServer(token)
				end)
			end
		end
	end
	heading("Notes you've read", 100)
	local reader = self.ctx.ui.components.Reader
	local notes = reader and reader:Read() or {}
	if #notes == 0 then
		Ui.label("None yet.", {
			Size = UDim2.new(1, 0, 0, 20),
			TextSize = 14,
			TextColor3 = Ui.Theme.textDim,
			LayoutOrder = 101,
			Parent = list,
		})
	end
	for i, note in notes do
		Ui.new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(236, 228, 202),
			Text = note.text,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Font = Enum.Font.IndieFlower,
			TextSize = 20,
			TextColor3 = Color3.fromRGB(38, 44, 84),
			LayoutOrder = 101 + i,
			Parent = list,
		}, { Ui.corner(3), Ui.padding(10) })
	end
end

return Map
