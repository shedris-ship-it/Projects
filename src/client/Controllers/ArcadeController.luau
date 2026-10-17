-- The arcade's screens (LB5; docs/plans/lobby-rework.md, "Arcade"; the
-- server is Services/ArcadeService, the game Logic/Arcade/HouseCall).
--
-- Every HOUSE CALL cabinet near you is drawn on its screen: when nobody's
-- playing, its attract mode (the title, his three rules, this week's and
-- all-time high scores, your free play); when you play, your game, run here
-- from its seed on the server's clock, its presses sent as you go; when
-- someone else plays, their game a moment behind, run from the presses the
-- server passes on (watching over a shoulder). Playing, the camera settles
-- on the screen: arrows or WASD move, hold Space to stand still and look,
-- Backspace walks away (your score so far counts).

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local HouseCall = require(Shared.Logic.Arcade.HouseCall)
local Net = require(Shared.Net)

local C = Config.Arcade
local PA = Constants.PlayerAttributes
local player = Players.LocalPlayer

local ArcadeController = {}

-- The screen's pixels: a HUD band over the maze, 18 pixels a cell.
local CW, CH = C.Canvas[1], C.Canvas[2]
local CELL = 18
local MX = math.floor((CW - HouseCall.Width * CELL) / 2)
local MY = CH - HouseCall.Height * CELL - 1
local FONT = Enum.Font.Arcade

local BLACK = Color3.fromRGB(6, 6, 12)
local WALL = Color3.fromRGB(18, 22, 70)
local LINE = Color3.fromRGB(70, 100, 255)
local SILVER = Color3.fromRGB(226, 226, 236)
local LANTERN = Color3.fromRGB(255, 196, 90)
local YOU = Color3.fromRGB(250, 220, 40)
local HIM = Color3.fromRGB(236, 232, 222)
local FROZEN = Color3.fromRGB(150, 180, 255)
local RED = Color3.fromRGB(230, 40, 40)
local TEXT = Color3.fromRGB(230, 230, 240)

local MESSAGES = {
	ready = "READY",
	caught = "HE HAS YOU",
	cleared = "HOUSE CLEARED",
	hunt = "HE'S HUNTING",
	survived = "YOU GOT AWAY  +100",
	heirloom = "THE HEIRLOOM!",
	over = "GAME OVER",
}

local RULES = {
	"FACE HIM AND HE FREEZES",
	"(HOLD THE BUTTON TO STAND AND LOOK)",
	"",
	"DON'T STARE TOO LONG",
	"",
	"WHEN HE HUNTS, BREAK HIS SIGHT",
	"OR GET TO A LANTERN",
}

function ArcadeController:Init(controllers)
	self.controllers = controllers
	self.views = {} -- screen part -> its view
	self.mine = nil -- your game: { view, runner, started, input, events, sent, pending, ... }
	self.held = {} -- direction -> when it was pressed
end

local function new(className: string, props, parent: Instance?)
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function box(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, z: number?)
	return new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = color,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		ZIndex = z or 1,
	}, parent)
end

local function text(
	parent: Instance,
	s: string,
	x: number,
	y: number,
	w: number,
	h: number,
	size: number,
	color: Color3,
	z: number?
)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Font = FONT,
		Text = s,
		TextSize = size,
		TextColor3 = color,
		ZIndex = z or 4,
	}, parent)
end

local function round(frame: GuiObject)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)
	return frame
end

local function isWall(x: number, y: number): boolean
	if x < 0 or x >= HouseCall.Width or y < 0 or y >= HouseCall.Height then
		return true
	end
	return HouseCall.cell(x, y) == "#"
end

local function money(n: number): string
	return string.format("%06d", math.clamp(math.floor(n), 0, 999999))
end

-- Building a screen ------------------------------------------------------------------

function ArcadeController:_build(screen: BasePart)
	local gui = new("SurfaceGui", {
		Name = "ArcadeScreen",
		Adornee = screen,
		Face = Enum.NormalId.Back,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Vector2.new(CW, CH),
		LightInfluence = 0,
		Brightness = 1.4,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		ClipsDescendants = true,
		MaxDistance = C.Draw + 10,
	}, player:WaitForChild("PlayerGui"))
	local bg = box(gui, 0, 0, CW, CH, BLACK, 0)
	bg.Size = UDim2.fromScale(1, 1)
	local view = { screen = screen, gui = gui }

	-- The attract mode.
	local attract = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, gui)
	view.attract = attract
	text(attract, "HOUSE CALL", 0, 18, CW, 40, 34, YOU)
	-- (Read from a few steps away: the attract text as big as its longest
	-- line allows, the rules' 350 pixels at 18.)
	view.page = text(attract, "", 0, 64, CW, 20, 16, LINE)
	local lines = {}
	for i = 1, 7 do
		lines[i] = text(attract, "", 20, 88 + (i - 1) * 25, CW - 40, 22, 18, TEXT)
	end
	view.lines = lines
	view.footer = text(attract, "", 0, CH - 32, CW, 24, 18, TEXT)

	-- The game: the house's walls once, its silver and lanterns, him and you.
	local game =
		new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Visible = false }, gui)
	view.game = game
	for y = 0, HouseCall.Height - 1 do
		local x = 0
		while x < HouseCall.Width do
			if isWall(x, y) then
				local x0 = x
				while x < HouseCall.Width and isWall(x, y) do
					x += 1
				end
				box(game, MX + x0 * CELL, MY + y * CELL, (x - x0) * CELL, CELL, WALL, 2)
			else
				x += 1
			end
		end
	end
	-- (The walls' edges where they meet the way round: the blue lines.)
	for y = 0, HouseCall.Height - 1 do
		for x = 0, HouseCall.Width - 1 do
			if isWall(x, y) then
				local px, py = MX + x * CELL, MY + y * CELL
				if not isWall(x, y - 1) then
					box(game, px, py, CELL, 2, LINE, 3)
				end
				if not isWall(x, y + 1) then
					box(game, px, py + CELL - 2, CELL, 2, LINE, 3)
				end
				if not isWall(x - 1, y) then
					box(game, px, py, 2, CELL, LINE, 3)
				end
				if not isWall(x + 1, y) then
					box(game, px + CELL - 2, py, 2, CELL, LINE, 3)
				end
			end
		end
	end
	view.silver = {}
	for y = 0, HouseCall.Height - 1 do
		for x = 0, HouseCall.Width - 1 do
			local c = HouseCall.cell(x, y)
			local px, py = MX + x * CELL, MY + y * CELL
			if c == "." then
				view.silver[HouseCall.index(x, y)] = box(game, px + 7, py + 7, 4, 4, SILVER, 3)
			elseif c == "o" then
				local halo = box(game, px - 4, py - 4, CELL + 8, CELL + 8, LANTERN, 2)
				halo.BackgroundTransparency = 0.8
				round(halo)
				box(game, px + 5, py + 4, 8, 10, LANTERN, 3)
			elseif c == "=" then
				box(game, px, py + 7, CELL, 4, Color3.fromRGB(240, 130, 190), 3)
			end
		end
	end
	view.heirloom = box(game, MX + HouseCall.Start.x * CELL + 4, MY + HouseCall.Start.y * CELL + 4, 10, 10, LANTERN, 4)
	view.heirloom.Rotation = 45
	view.beam = box(game, 0, 0, 0, 0, Color3.fromRGB(255, 240, 160), 4)
	view.beam.BackgroundTransparency = 0.78
	view.you = round(box(game, 0, 0, 14, 14, YOU, 6))
	view.him = round(box(game, 0, 0, 15, 15, HIM, 6))
	view.eyes = {
		box(view.him, 3, 5, 3, 3, BLACK, 7),
		box(view.him, 9, 5, 3, 3, BLACK, 7),
	}
	view.red = box(game, MX, MY, HouseCall.Width * CELL, HouseCall.Height * CELL, RED, 5)
	view.red.BackgroundTransparency = 1
	-- The HUD.
	view.score = text(game, "", 8, 4, 150, 18, 14, TEXT)
	view.score.TextXAlignment = Enum.TextXAlignment.Left
	view.hi = text(game, "", CW / 2 - 80, 4, 160, 18, 14, LINE)
	view.house = text(game, "", CW - 168, 4, 90, 18, 12, TEXT)
	view.lives = {}
	for i = 1, 5 do
		view.lives[i] = round(box(game, CW - 72 + (i - 1) * 13, 8, 9, 9, YOU, 4))
	end
	view.patience = box(game, MX, MY - 4, 0, 3, RED, 4)
	view.message = text(game, "", MX, MY + 6 * CELL + 2, HouseCall.Width * CELL, 22, 18, YOU, 8)
	view.messageBack = box(game, MX + 60, MY + 6 * CELL, HouseCall.Width * CELL - 120, 26, BLACK, 7)
	view.messageBack.BackgroundTransparency = 0.15
	view.name = text(game, "", MX, CH - 16, HouseCall.Width * CELL, 14, 10, Color3.fromRGB(150, 150, 170), 8)

	-- Scanlines over it all.
	for y = 0, CH, 3 do
		local line = box(gui, 0, y, CW, 1, Color3.new(0, 0, 0), 20)
		line.BackgroundTransparency = 0.78
	end
	self.views[screen] = view
	return view
end

-- Drawing -----------------------------------------------------------------------------------

local function scoresOf(screen: BasePart, attribute: string)
	local ok, list = pcall(HttpService.JSONDecode, HttpService, screen:GetAttribute(attribute) or "[]")
	return ok and list or {}
end

function ArcadeController:_drawAttract(view, now: number)
	view.attract.Visible = true
	view.game.Visible = false
	local page = math.floor(now / 6) % 3
	local lines
	if page == 0 then
		view.page.Text = "HIS RULES"
		lines = RULES
	else
		local list = scoresOf(view.screen, page == 1 and "Week" or "All")
		view.page.Text = page == 1 and "THIS WEEK'S BEST" or "THE BEST EVER"
		lines = {}
		for i = 1, C.Shown do
			local entry = list[i]
			lines[i] = entry
					and string.format(
						"%d  %-12s %s",
						i,
						string.upper(string.sub(tostring(entry[1]), 1, 12)),
						money(entry[2])
					)
				or string.format("%d  ------------ ------", i)
		end
	end
	for i, label in view.lines do
		label.Text = lines[i] or ""
	end
	local name = view.screen:GetAttribute("PlayerName")
	local profile = self.controllers.StateController and self.controllers.StateController.profile
	local blink = math.floor(now * 2) % 2 == 0
	if name then
		view.footer.Text = "NOW PLAYING: " .. string.upper(tostring(name))
	elseif profile and profile.arcadeFree then
		view.footer.Text = blink and "1 FREE PLAY TODAY - PRESS E" or ""
	elseif profile and (profile.arcadeCredits or 0) > 0 then
		view.footer.Text = blink and string.format("%d PLAYS LEFT - PRESS E", profile.arcadeCredits) or ""
	else
		view.footer.Text = blink and "INSERT COIN - PRESS E" or ""
	end
end

-- Where a mover is drawn: between the cell it left and the one it's in.
local function drawnAt(m, step: number, frac: number): (number, number)
	local f = 1
	if m.wait > 0 and step > 0 then
		f = math.clamp(1 - (m.wait - frac) / step, 0, 1)
	end
	local x, y = m.x, m.y
	if math.abs(m.x - m.px) <= 1 then
		x = m.px + (m.x - m.px) * f
	end
	y = m.py + (m.y - m.py) * f
	return MX + x * CELL, MY + y * CELL
end

function ArcadeController:_drawGame(view, s, frac: number, name: string?)
	view.attract.Visible = false
	view.game.Visible = true
	-- (The silver only when some has gone or come back.)
	if view.left ~= s.left or view.level ~= s.level then
		view.left, view.level = s.left, s.level
		for i, dot in view.silver do
			dot.Visible = s.silver[i] == true
		end
	end
	view.heirloom.Visible = s.heirloom > 0 and math.floor(s.tick / 4) % 2 == 0
	local p, g = s.player, s.guest
	local yx, yy = drawnAt(p, HouseCall.PlayerStep, frac)
	view.you.Position = UDim2.fromOffset(yx + 2, yy + 2)
	local hx, hy = drawnAt(g, g.step or 1, frac)
	local shake = s.hunt and s.hunt.phase == "warn" and (math.random() - 0.5) * 3 or 0
	view.him.Position = UDim2.fromOffset(hx + 1.5 + shake, hy + 1.5)
	view.him.BackgroundColor3 = s.seen and FROZEN or HIM
	for _, eye in view.eyes do
		eye.BackgroundColor3 = s.hunt and RED or BLACK
	end
	-- Your torch: down the way you face, to the wall or its reach.
	local reach = 0
	local x, y = p.x, p.y
	for _ = 1, HouseCall.Gaze do
		x, y = (x + HouseCall.DX[p.face]) % HouseCall.Width, y + HouseCall.DY[p.face]
		local c = HouseCall.cell(x, y)
		if c == "#" or c == "=" then
			break
		end
		reach += 1
	end
	local len = reach * CELL
	local cx, cy = yx + CELL / 2, yy + CELL / 2
	local dx, dy = HouseCall.DX[p.face], HouseCall.DY[p.face]
	if dx ~= 0 then
		view.beam.Size = UDim2.fromOffset(len, 8)
		view.beam.Position = UDim2.fromOffset(dx > 0 and cx or cx - len, cy - 4)
	else
		view.beam.Size = UDim2.fromOffset(8, len)
		view.beam.Position = UDim2.fromOffset(cx - 4, dy > 0 and cy or cy - len)
	end
	view.beam.BackgroundTransparency = s.seen and 0.6 or 0.8
	view.beam.Visible = not s.over
	view.red.BackgroundTransparency = s.hunt and (0.82 + 0.06 * math.sin(s.tick * 0.5)) or 1
	-- The HUD.
	view.score.Text = "SCORE " .. money(s.score)
	local all = scoresOf(view.screen, "All")
	view.hi.Text = "HI " .. money(math.max(all[1] and all[1][2] or 0, s.score))
	view.house.Text = "HOUSE " .. s.level
	for i, life in view.lives do
		life.Visible = i < s.lives
	end
	view.patience.Size = UDim2.fromOffset(math.floor(HouseCall.Width * CELL * s.pester / HouseCall.Pester), 3)
	local message = s.message and MESSAGES[s.message]
	view.message.Text = message or ""
	view.messageBack.Visible = message ~= nil
	view.name.Text = name and string.upper(name) or ""
end

-- Your game ---------------------------------------------------------------------------------

-- The way you're pushing: the last direction pressed that's still held.
function ArcadeController:_stick(): number
	local best, at = 0, -math.huge
	for dir, t in self.held do
		if t > at then
			best, at = dir, t
		end
	end
	-- (A gamepad's thumbstick, when no key is held.)
	if best == 0 then
		for _, pad in UserInputService:GetConnectedGamepads() do
			for _, input in UserInputService:GetGamepadState(pad) do
				if input.KeyCode == Enum.KeyCode.Thumbstick1 and input.Position.Magnitude > 0.5 then
					local v = input.Position
					if math.abs(v.X) > math.abs(v.Y) then
						best = v.X > 0 and 2 or 4
					else
						best = v.Y > 0 and 1 or 3
					end
				end
			end
		end
	end
	return best
end

function ArcadeController:_bind()
	local keys = {
		[1] = { Enum.KeyCode.W, Enum.KeyCode.Up, Enum.KeyCode.DPadUp },
		[2] = { Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.DPadRight },
		[3] = { Enum.KeyCode.S, Enum.KeyCode.Down, Enum.KeyCode.DPadDown },
		[4] = { Enum.KeyCode.A, Enum.KeyCode.Left, Enum.KeyCode.DPadLeft },
	}
	local titles = { "Up", "Right", "Down", "Left" }
	local spots = {
		UDim2.new(1, -150, 1, -190),
		UDim2.new(1, -95, 1, -135),
		UDim2.new(1, -150, 1, -80),
		UDim2.new(1, -205, 1, -135),
	}
	for dir, codes in keys do
		local name = "ConsensusArcade" .. titles[dir]
		ContextActionService:BindActionAtPriority(name, function(_, state)
			if state == Enum.UserInputState.Begin then
				self.held[dir] = os.clock()
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				self.held[dir] = nil
			end
			return Enum.ContextActionResult.Sink
		end, true, Enum.ContextActionPriority.High.Value, table.unpack(codes))
		ContextActionService:SetTitle(name, titles[dir])
		ContextActionService:SetPosition(name, spots[dir])
	end
	ContextActionService:BindActionAtPriority("ConsensusArcadeLook", function(_, state)
		self.look = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Sink
	end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	ContextActionService:SetTitle("ConsensusArcadeLook", "Look")
	ContextActionService:SetPosition("ConsensusArcadeLook", UDim2.new(0, 60, 1, -140))
	ContextActionService:BindActionAtPriority("ConsensusArcadeLeave", function(_, state)
		if state == Enum.UserInputState.Begin then
			self:_walkAway()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("ConsensusArcadeLeave", "Leave")
	ContextActionService:SetPosition("ConsensusArcadeLeave", UDim2.new(0, 60, 0, 80))
end

function ArcadeController:_unbind()
	for _, name in { "Up", "Right", "Down", "Left", "Look", "Leave" } do
		ContextActionService:UnbindAction("ConsensusArcade" .. name)
	end
	self.held = {}
	self.look = false
end

function ArcadeController:_play(info)
	local screen
	for _, part in CollectionService:GetTagged("ArcadeScreen") do
		if part:GetAttribute("Cabinet") == info.index then
			screen = part
		end
	end
	if not screen then
		return
	end
	local view = self.views[screen] or self:_build(screen)
	self.mine = {
		screen = screen,
		view = view,
		runner = HouseCall.runner(info.seed),
		started = info.started,
		input = 0,
		pending = {},
		sent = 0,
		lastSend = os.clock(),
	}
	self:_bind()
	local camera = Workspace.CurrentCamera
	self.fov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 50
	-- (Square on the screen, a little above it, as you'd stand at a cabinet.)
	local eye = screen.Position - screen.CFrame.LookVector * 2.6 + screen.CFrame.UpVector * 0.2
	camera.CFrame = CFrame.lookAt(eye, screen.Position)
end

function ArcadeController:_flush()
	local mine = self.mine
	if mine and #mine.pending > 0 then
		Net.get("ArcadePress"):FireServer(mine.sent + 1, mine.pending)
		mine.sent += #mine.pending / 2
		mine.pending = {}
	end
	if mine then
		mine.lastSend = os.clock()
	end
end

-- Your game over, or you walked away: the score so far counts.
function ArcadeController:_end()
	local mine = self.mine
	if not mine or mine.ending then
		return
	end
	mine.ending = os.clock()
	self:_flush()
	local s = mine.runner.state
	Net.get("ArcadeEnd"):FireServer(s.tick, s.score)
	self:_unbind()
end

function ArcadeController:_walkAway()
	self:_end()
	self:_release()
end

-- The camera back, the cabinet to its attract mode.
function ArcadeController:_release()
	local mine = self.mine
	if not mine then
		return
	end
	self.mine = nil
	self:_unbind()
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = self.fov or 70
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

function ArcadeController:_stepMine()
	local mine = self.mine
	if not mine then
		return
	end
	local runner = mine.runner
	local s = runner.state
	if not mine.ending then
		local value = HouseCall.encode(self:_stick(), self.look == true)
		if value ~= mine.input then
			mine.input = value
			local t = s.tick + 1
			runner:feed({ t, value })
			table.insert(mine.pending, t)
			table.insert(mine.pending, value)
			if #mine.pending >= 2 * C.MaxBatch then
				self:_flush()
			end
		end
		local now = (Workspace:GetServerTimeNow() - mine.started) * HouseCall.Rate
		runner:advance(math.max(0, math.floor(now)))
		if os.clock() - mine.lastSend >= C.Batch then
			self:_flush()
		end
		if s.over then
			self:_end()
		end
	elseif os.clock() - mine.ending > 5 then
		self:_release()
	end
	local frac = 0
	if not s.over then
		local now = (Workspace:GetServerTimeNow() - mine.started) * HouseCall.Rate
		frac = math.clamp(now - s.tick, 0, 1)
	end
	self:_drawGame(mine.view, s, frac, nil)
	if mine.result then
		local r = mine.result
		local where = r.dropped and "NOT COUNTED"
			or (r.all and string.format("NO. %d EVER!", r.all))
			or (r.week and string.format("NO. %d THIS WEEK", r.week))
			or ("SCORE " .. money(r.score or s.score))
		mine.view.name.Text = where
	end
end

-- Watching --------------------------------------------------------------------------------

function ArcadeController:_feed(index: number, feed)
	for screen, view in self.views do
		if screen:GetAttribute("Cabinet") == index then
			if feed.over then
				view.runner = nil
			elseif feed.seed then
				view.runner = HouseCall.runner(feed.seed)
				view.started = feed.started
				view.count = 0
				view.who = feed.name
			end
			if view.runner and feed.events and feed.from == view.count + 1 then
				view.runner:feed(feed.events)
				view.count += #feed.events / 2
			elseif view.runner and feed.events then
				-- (A batch missed: ask for the whole game again.)
				view.runner = nil
				Net.get("ArcadeWatch"):FireServer(index, true)
			end
		end
	end
end

function ArcadeController:_frame()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local now = Workspace:GetServerTimeNow()
	for _, screen in CollectionService:GetTagged("ArcadeScreen") do
		local index = screen:GetAttribute("Cabinet")
		local distance = root and (root.Position - screen.Position).Magnitude or math.huge
		local view = self.views[screen]
		if distance > C.Draw and not (self.mine and self.mine.screen == screen) then
			if view then
				view.gui.Enabled = false
				if view.watching then
					view.watching = false
					view.runner = nil
					Net.get("ArcadeWatch"):FireServer(index, false)
				end
			end
			continue
		end
		view = view or self:_build(screen)
		view.gui.Enabled = true
		if self.mine and self.mine.screen == screen then
			continue
		end
		local playing = screen:GetAttribute("Player")
		local near = distance <= C.Watch
		if playing and near and playing ~= player.UserId then
			if not view.watching then
				view.watching = true
				Net.get("ArcadeWatch"):FireServer(index, true)
			end
		elseif view.watching then
			view.watching = false
			view.runner = nil
			Net.get("ArcadeWatch"):FireServer(index, false)
		end
		if playing and view.runner then
			local tick = (now - view.started - C.Behind) * HouseCall.Rate
			local s = view.runner:advance(math.max(0, math.floor(tick)))
			self:_drawGame(view, s, math.clamp(tick - s.tick, 0, 1), view.who)
		else
			self:_drawAttract(view, os.clock())
		end
	end
end

function ArcadeController:Start()
	Net.get("ArcadeStart").OnClientEvent:Connect(function(info)
		self:_play(info)
	end)
	Net.get("ArcadeFeed").OnClientEvent:Connect(function(index, feed)
		self:_feed(index, feed)
	end)
	Net.get("ArcadeResult").OnClientEvent:Connect(function(result)
		if self.mine then
			self.mine.result = result
		end
	end)
	-- The server let you go (a game it ended for you): the camera back.
	player:GetAttributeChangedSignal(PA.Arcade):Connect(function()
		if player:GetAttribute(PA.Arcade) == nil and self.mine and not self.mine.ending then
			self:_release()
		end
	end)
	-- (On Heartbeat, not RenderStepped: a 20-tick game needs no more, and it
	-- keeps running while Studio's window isn't drawing, for tests.)
	RunService.Heartbeat:Connect(function()
		local ok, err = pcall(function()
			self:_stepMine()
			self:_frame()
		end)
		if not ok then
			warn("[Consensus] arcade screen failed: " .. tostring(err))
		end
	end)
end

return ArcadeController
