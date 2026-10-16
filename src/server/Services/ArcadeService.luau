-- The arcade (LB5; docs/plans/lobby-rework.md, "Arcade" and "The arcade's
-- games and scores"): HOUSE CALL on its two cabinets (Data/Mall's blocks
-- with `game`; the rules in Logic/Arcade/HouseCall).
--
-- E at a cabinet plays, paid without asking by the unlimited pass, the day's
-- free play or a play bought; else the coin card offers a play for Marks or
-- Robux (Logic/Arcade/Credits, UI/Arcade). You stand at the cabinet and the
-- camera settles on its screen. Your client runs and draws the game
-- (Controllers/ArcadeController) and sends its presses as you play; the
-- server passes them to anyone watching over your shoulder, and at the end
-- replays them for the score: one the replay doesn't reproduce is dropped
-- (a worldwide board gets fake scores within days without it). High scores,
-- all-time and this week, top ten, one a player (Services/BoardService),
-- shown on the cabinets' attract screens. None of it on a run server.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Credits = require(Shared.Logic.Arcade.Credits)
local HouseCall = require(Shared.Logic.Arcade.HouseCall)
local Leaderboard = require(Shared.Logic.Leaderboard)
local Mall = require(Shared.Data.Mall)
local Net = require(Shared.Net)
local Products = require(Shared.Data.Products)
local Progression = require(Shared.Logic.Progression)

local PA = Constants.PlayerAttributes
local C = Config.Arcade

local ArcadeService = {}

local GAME = "HouseCall"

function ArcadeService:Init(services)
	self.services = services
	self.cabinets = {} -- index -> { index, frame, screen, stand, player?, seed, started, events, last, broken }
	self.playing = {} -- player -> its cabinet
	self.watching = {} -- player -> { [index] = true }
end

local function tell(player: Player, text: string)
	Net.get("Notify"):FireClient(player, text, "info")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The boards: all-time, and this week's (it starts again each Monday).
local function boards(): (string, string)
	return "Arcade_" .. GAME .. "_All", "Arcade_" .. GAME .. "_W" .. Leaderboard.week(os.time())
end

-- Building ------------------------------------------------------------------------

function ArcadeService:Build(parent: Instance, origin: Vector3)
	local places = self.services.PlaceService
	if places and places:IsRun() then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Arcade"
	folder.Parent = parent
	for _, b in Mall.Blocks do
		if b.game ~= GAME then
			continue
		end
		local index = #self.cabinets + 1
		local rot = b.rot or { 0, 0, 0 }
		local frame = CFrame.new(origin + Vector3.new(b.x, b.y, b.z))
			* CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		-- The screen: over the mesh's own (its front is the cabinet's +Z,
		-- sunk 12 degrees back in its bezel: kitlib/mall2 _cabinet).
		local screen = Instance.new("Part")
		screen.Name = "ArcadeScreen"
		screen.Anchored = true
		screen.CanCollide = false
		screen.CanQuery = false
		screen.CanTouch = false
		screen.CastShadow = false
		screen.Transparency = 1
		screen.Size = Vector3.new(C.Screen[1], C.Screen[2], 0.02)
		screen.CFrame = frame * CFrame.new(0, 0.9, 1.0) * CFrame.Angles(math.rad(-12), 0, 0) * CFrame.new(0, 0, 0.075)
		screen:SetAttribute("Cabinet", index)
		screen:SetAttribute("Game", GAME)
		CollectionService:AddTag(screen, "ArcadeScreen")
		screen.Parent = folder
		-- Its glow on the player and the carpet.
		local glow = Instance.new("SurfaceLight")
		glow.Face = Enum.NormalId.Back
		glow.Color = Color3.fromRGB(110, 130, 255)
		glow.Brightness = 0.7
		glow.Range = 9
		glow.Angle = 80
		glow.Shadows = false
		glow.Parent = screen
		-- E on its control panel.
		local panel = Instance.new("Part")
		panel.Name = "ArcadePanel"
		panel.Anchored = true
		panel.CanCollide = false
		panel.CanTouch = false
		panel.Transparency = 1
		panel.Size = Vector3.new(2.6, 1.6, 0.8)
		panel.CFrame = frame * CFrame.new(0, 0.1, 1.3)
		panel.Parent = folder
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Play"
		prompt.ObjectText = "HOUSE CALL"
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = panel
		local cab = {
			index = index,
			frame = frame,
			screen = screen,
			prompt = prompt,
			-- (Where you stand to play: at its front, facing it.)
			stand = CFrame.lookAt((frame * CFrame.new(0, 0.5, 2.8)).Position, (frame * CFrame.new(0, 0.5, 0)).Position),
		}
		self.cabinets[index] = cab
		prompt.Triggered:Connect(function(player)
			self:Approach(player, index)
		end)
	end
	if #self.cabinets == 0 then
		return
	end
	local board = self.services.BoardService
	board.Changed:Connect(function(name)
		local all, week = boards()
		if name == all or name == week then
			self:_showScores()
		end
	end)
	task.spawn(function()
		local week
		while true do
			-- (A new week: its own board.)
			local all, now = boards()
			if now ~= week then
				week = now
				board:Watch(all, C.BoardSize, false, true)
				board:Watch(now, C.BoardSize, false, true)
				self:_showScores()
			end
			task.wait(60)
		end
	end)
end

-- The top scores on each screen, for its attract mode (the client reads them).
function ArcadeService:_showScores()
	local all, week = boards()
	local function short(list)
		local out = {}
		for i = 1, math.min(#list, C.Shown) do
			table.insert(out, { list[i].name or "?", list[i].value })
		end
		return HttpService:JSONEncode(out)
	end
	local a, w = short(self.services.BoardService:Get(all)), short(self.services.BoardService:Get(week))
	for _, cab in self.cabinets do
		cab.screen:SetAttribute("All", a)
		cab.screen:SetAttribute("Week", w)
	end
end

-- Playing ---------------------------------------------------------------------------

-- E at a cabinet.
function ArcadeService:Approach(player: Player, index: number)
	local cab = self.cabinets[index]
	if not cab or self.playing[player] then
		return
	end
	if cab.player then
		tell(player, "Someone's playing HOUSE CALL: watch over their shoulder.")
		return
	end
	if player:GetAttribute(PA.Car) ~= nil or player:GetAttribute(PA.Trying) ~= nil then
		return
	end
	local data = self.services.DataService:Get(player)
	if not data then
		return
	end
	local how = Credits.how(data, Progression.day(os.time()), self:_pass(player))
	if how then
		self:_start(player, cab, how)
	else
		self:_coin(player, cab)
	end
end

function ArcadeService:_pass(player: Player): boolean
	local money = self.services.MonetizationService
	return money ~= nil and money:OwnsPass(player, "ArcadeUnlimited")
end

-- The coin card: a play for Marks, or for Robux.
function ArcadeService:_coin(player: Player, cab)
	local data = self.services.DataService:Get(player)
	if not data then
		return
	end
	local robux = {}
	for _, name in { "ArcadePlay", "ArcadeTen" } do
		local product = Products.Products[name]
		table.insert(robux, {
			name = name,
			label = product.label,
			robux = product.robux,
			can = type(product.id) == "number",
		})
	end
	local pass = Products.Passes.ArcadeUnlimited
	table.insert(
		robux,
		{ name = "ArcadeUnlimited", label = "Unlimited plays", robux = 250, can = type(pass.id) == "number" }
	)
	Net.get("ArcadeCoin"):FireClient(player, {
		index = cab.index,
		marks = data.Marks,
		price = C.PlayMarks,
		credits = data.ArcadeCredits,
		robux = robux,
	})
end

-- The coin card's choice: "marks", or a product or pass to buy.
function ArcadeService:Pay(player: Player, index: number, how: string)
	local cab = self.cabinets[index]
	local root = rootOf(player)
	if not cab or not root or (root.Position - cab.stand.Position).Magnitude > 14 then
		return
	end
	if how == "marks" then
		if cab.player then
			tell(player, "Someone got there first: watch over their shoulder.")
		elseif not self.playing[player] then
			self:_start(player, cab, "marks")
		end
		return
	end
	if how ~= "ArcadePlay" and how ~= "ArcadeTen" and how ~= "ArcadeUnlimited" then
		return
	end
	local money = self.services.MonetizationService
	if not money or not money:Prompt(player, how) then
		tell(player, "Not for sale yet: coming soon.")
	end
end

function ArcadeService:_start(player: Player, cab, how: string)
	local data = self.services.DataService:Get(player)
	local root = rootOf(player)
	if not data or not root then
		return
	end
	local today = Progression.day(os.time())
	if not Credits.pay(data, how, today, C.PlayMarks, self:_pass(player)) then
		if how == "marks" then
			tell(player, "Not enough Marks for a play yet.")
		end
		return
	end
	if how ~= "pass" then
		self.services.DataService:Send(player)
		task.spawn(self.services.DataService.SaveNow, self.services.DataService, player)
	end
	cab.player = player
	cab.seed = Random.new():NextInteger(1, 2147483646)
	-- (Tick 0 a moment from now, so the player's client has it first.)
	cab.started = Workspace:GetServerTimeNow() + C.Lead
	cab.events = {}
	cab.last = 0
	cab.broken = nil
	cab.deadline = os.clock() + C.Lead + HouseCall.MaxTicks / HouseCall.Rate + 30
	self.playing[player] = cab
	self.services.PlayerStateService:MarkTeleport(player)
	player.Character:PivotTo(cab.stand)
	root.Anchored = true
	player:SetAttribute(PA.Arcade, cab.index)
	cab.screen:SetAttribute("Player", player.UserId)
	cab.screen:SetAttribute("PlayerName", player.DisplayName)
	local say = {
		free = "Your free play today.",
		credit = string.format("A play of yours: %d left.", data.ArcadeCredits),
		marks = string.format("%d Marks for a play.", C.PlayMarks),
		pass = "Unlimited plays.",
	}
	tell(player, say[how])
	Net.get("ArcadeStart"):FireClient(player, { index = cab.index, seed = cab.seed, started = cab.started })
	for watcher, cabs in self.watching do
		if cabs[cab.index] and watcher ~= player then
			self:_sendAll(watcher, cab)
		end
	end
	if self.services.Telemetry then
		self.services.Telemetry:Log("ArcadePlay", { game = GAME, how = how }, player)
	end
end

-- A watcher gets the whole game so far.
function ArcadeService:_sendAll(watcher: Player, cab)
	Net.get("ArcadeFeed"):FireClient(watcher, cab.index, {
		seed = cab.seed,
		started = cab.started,
		name = cab.player and cab.player.DisplayName,
		from = 1,
		events = cab.events,
	})
end

-- The player's presses, in batches as they play: `from` is the first's
-- place in the game (a gap or a repeat breaks the game: no score).
function ArcadeService:Press(player: Player, from: number, events)
	local cab = self.playing[player]
	if not cab or cab.broken then
		return
	end
	if type(events) ~= "table" or #events > 2 * C.MaxBatch or from ~= #cab.events / 2 + 1 then
		cab.broken = "batch"
		return
	end
	if not HouseCall.valid(events, cab.last) then
		cab.broken = "presses"
		return
	end
	local now = (Workspace:GetServerTimeNow() - cab.started) * HouseCall.Rate
	if #events > 0 and events[#events - 1] > now + C.Slack * HouseCall.Rate then
		cab.broken = "ahead"
		return
	end
	for _, v in events do
		table.insert(cab.events, v)
	end
	if #events > 0 then
		cab.last = events[#events - 1]
	end
	for watcher, cabs in self.watching do
		if cabs[cab.index] and watcher ~= player then
			Net.get("ArcadeFeed"):FireClient(watcher, cab.index, { from = from, events = events })
		end
	end
end

-- The game's end (or the player walked away from it): `tick` and `score`
-- as their client has them.
function ArcadeService:End(player: Player, tick: number, score: number)
	local cab = self.playing[player]
	if cab then
		self:_finish(cab, tick, score, "done")
	end
end

function ArcadeService:_finish(cab, tick: number?, score: number?, reason: string)
	local player = cab.player :: Player
	local seed, started, events, broken = cab.seed, cab.started, cab.events, cab.broken
	cab.player, cab.events = nil, {}
	self.playing[player] = nil
	cab.screen:SetAttribute("Player", nil)
	cab.screen:SetAttribute("PlayerName", nil)
	for watcher, cabs in self.watching do
		if cabs[cab.index] and watcher ~= player then
			Net.get("ArcadeFeed"):FireClient(watcher, cab.index, { over = true })
		end
	end
	if player.Parent then
		player:SetAttribute(PA.Arcade, nil)
		local root = rootOf(player)
		if root then
			root.Anchored = false
		end
	end
	if reason ~= "done" or not player.Parent then
		return
	end
	-- The replay check.
	local why = broken
	local elapsed = (Workspace:GetServerTimeNow() - started) * HouseCall.Rate
	if not why then
		if type(tick) ~= "number" or tick ~= math.floor(tick) or tick < 0 then
			why = "tick"
		elseif tick < (cab.last or 0) or tick > elapsed + C.Slack * HouseCall.Rate then
			why = "clock"
		end
	end
	local replay
	if not why then
		why, replay = self:Check(seed, events, tick :: number, score)
	end
	if why then
		warn(string.format("[Consensus] arcade: %s's score dropped (%s)", player.Name, why))
		Net.get("ArcadeResult"):FireClient(player, { score = score, dropped = true })
		return
	end
	local final = replay.score
	local result = { score = final }
	if final > 0 then
		result.week, result.all = self:PostScore(tostring(player.UserId), player.DisplayName, final)
	end
	if player.Parent then
		Net.get("ArcadeResult"):FireClient(player, result)
	end
	if self.services.Telemetry then
		self.services.Telemetry:Log("ArcadeScore", {
			game = GAME,
			score = final,
			house = replay.level,
			seconds = math.floor((tick :: number) / HouseCall.Rate),
		}, player)
	end
end

-- The replay check: the game from its seed and presses to `tick`, against
-- the score claimed. Returns why it's refused (nil when it stands) and the
-- replayed game.
function ArcadeService:Check(seed: number, events, tick: number, score: number?)
	local replay = HouseCall.run(seed, events, math.min(tick, HouseCall.MaxTicks))
	if replay.score ~= score then
		return string.format("replay %d, client %s", replay.score, tostring(score)), replay
	end
	return nil, replay
end

-- Posts a checked score to this week's board and the all-time one; returns
-- its places there.
function ArcadeService:PostScore(key: string, name: string, score: number): (number?, number?)
	local all, week = boards()
	local entry = { value = score, key = key, name = name, at = os.time() }
	local w = self.services.BoardService:Post(week, entry, C.BoardSize, false, true)
	local a = self.services.BoardService:Post(all, entry, C.BoardSize, false, true)
	return w, a
end

-- Near a cabinet: its game, live, for watching over a shoulder.
function ArcadeService:Watch(player: Player, index: number, on: boolean)
	local cab = self.cabinets[index]
	if not cab then
		return
	end
	local root = rootOf(player)
	if on and (not root or (root.Position - cab.screen.Position).Magnitude > C.Watch + 8) then
		return
	end
	self.watching[player] = self.watching[player] or {}
	self.watching[player][index] = on or nil
	if on and cab.player and cab.player ~= player then
		self:_sendAll(player, cab)
	end
end

function ArcadeService:Start()
	Net.onServer("ArcadePay", { interval = 0.5, types = { "number", "string" } }, function(player, index, how)
		self:Pay(player, index, how)
	end)
	Net.onServer(
		"ArcadePress",
		{ interval = 0, burst = 30, types = { "number", "table" } },
		function(player, from, events)
			self:Press(player, from, events)
		end
	)
	Net.onServer("ArcadeEnd", { interval = 0.5, types = { "number", "number" } }, function(player, tick, score)
		self:End(player, tick, score)
	end)
	Net.onServer(
		"ArcadeWatch",
		{ interval = 0, burst = 10, types = { "number", "boolean" } },
		function(player, index, on)
			self:Watch(player, index, on)
		end
	)
	Players.PlayerRemoving:Connect(function(player)
		local cab = self.playing[player]
		if cab then
			self:_finish(cab, nil, nil, "left")
		end
		self.watching[player] = nil
	end)
	-- A game that never ends (a client gone quiet) is ended for it.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, cab in self.cabinets do
				if cab.player and (os.clock() > cab.deadline or not cab.player.Character) then
					self:_finish(cab, nil, nil, "timeout")
				end
			end
		end
	end)
end

return ArcadeService
