-- The garage's party cars (docs/plans/lobby-rework.md, "Parties: the cars in
-- the garage"; LB2). A station wagon in each bay (Data/Mall Cars): get in
-- and you're in its party; the first in drives, holds the tape and works the
-- dashboard (UI/Dashboard: difficulty, night, friends only) and honks to
-- leave; a countdown follows in which anyone can get out; then the car pulls
-- out of its own roll-up door and the squad goes to its run (Services/
-- PlaceService), or, in Studio, the run starts here. A squad coming back
-- lands in a car again with the tape still in it and a receipt for the run's
-- Marks. The rules are Logic/Cars; the way back is Logic/Homecoming.
--
-- Also: friends only (the driver's Roblox friends and party), a car kept for
-- a Roblox party that arrives together, and the payphone on the garage wall
-- (Roblox's invite-a-friend prompt).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Cars = require(Shared.Logic.Cars)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Homecoming = require(Shared.Logic.Homecoming)
local Kit = require(Shared.World.Kit)
local Locations = require(Shared.Data.Locations)
local Mall = require(Shared.Data.Mall)
local Net = require(Shared.Net)
local PropFactory = require(Shared.World.PropFactory)

local PA = Constants.PlayerAttributes
local C = Config.Cars

local CarService = {}

function CarService:Init(services)
	self.services = services
	self.cars = {} -- id -> car (Logic/Cars)
	self.bodies = {} -- id -> { model, home, seats, sign, body, prompt, door, name }
	self.seated = {} -- Player -> car id
	self.quiet = {} -- Player -> true while the server itself moves them in or out of a seat
	self.friendship = {} -- "a:b" -> boolean (Player:IsFriendsWith, asked once)
	self.arrivals = {} -- run token -> { data, players, since }
	self.receipts = {} -- Player -> { marks, case } to show once they're seated
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- The grey box's colour, under the wagon's mesh until it's in.
local MAROON = Color3.fromRGB(96, 34, 30)

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function partyOf(player: Player): string?
	local ok, id = pcall(function()
		return (player :: any).PartyId
	end)
	return (ok and type(id) == "string" and id ~= "") and id or nil
end

function CarService:_friends(player: Player, userId: number?): boolean
	if not userId or userId == player.UserId then
		return false
	end
	local key = math.min(player.UserId, userId) .. ":" .. math.max(player.UserId, userId)
	if self.friendship[key] == nil then
		local ok, yes = pcall(player.IsFriendsWith, player, userId)
		self.friendship[key] = ok and yes == true
	end
	return self.friendship[key]
end

local function playerOf(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

-- Building ------------------------------------------------------------------

-- The cars, their seats, signs and prompts, in the garage MallBuilder made
-- (LobbyService calls this once the mall stands).
function CarService:Build(parent: Instance, origin: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "Cars"
	folder.Parent = parent
	-- The garage's roll-up doors (World/MallBuilder's Door_garage models),
	-- each matched to the bay in front of it.
	local doors = {}
	for _, door in parent:GetDescendants() do
		if door:IsA("Folder") and door.Name == "Door_garage" then
			local sheet = door:FindFirstChild("Shutter")
			if sheet then
				table.insert(doors, { model = door, x = sheet.Position.X })
			end
		end
	end
	for i, bay in Mall.Cars.bays do
		local home = CFrame.new(origin + Vector3.new(bay.x, 0, bay.z)) -- its front -Z, to the door
		local door
		for _, d in doors do
			if math.abs(d.x - home.Position.X) < 3 then
				door = d.model
			end
		end
		self.cars[i] = Cars.new(i, C)
		self:_buildCar(folder, i, home, bay, door)
	end
	self:_payphone(parent, origin)
	self:_render()
end

-- The payphone on the garage wall: Roblox's invite-a-friend prompt, asked
-- of your client (UI/Dashboard; SocialService only runs there).
function CarService:_payphone(parent: Instance, origin: Vector3)
	for _, b in Mall.Blocks do
		if b.room == "garage" and b.name == "Payphone" then
			local part = PropFactory.part(
				parent,
				"PayphoneCall",
				Vector3.new(1.2, 1.8, 1.4),
				CFrame.new(origin + Vector3.new(b.x - 0.4, b.y, b.z)),
				Color3.new(0, 0, 0),
				Enum.Material.SmoothPlastic,
				{ collide = false, transparency = 1, castShadow = false }
			)
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Call a friend"
			prompt.ObjectText = "Payphone"
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt.Parent = part
			prompt.Triggered:Connect(function(player)
				Net.get("PromptInvite"):FireClient(player)
			end)
		end
	end
end

function CarService:_buildCar(folder: Instance, id: number, home: CFrame, bay, door: Instance?)
	local model = Instance.new("Model")
	model.Name = "Car" .. id
	model.Parent = folder
	local bodyAt = home * CFrame.new(0, 2.5, 0)
	local body = PropFactory.part(model, "Body", Vector3.new(7, 5, 14), bodyAt, MAROON, Enum.Material.SmoothPlastic)
	model.PrimaryPart = body
	local horn = Instance.new("Sound")
	horn.Name = "Horn"
	horn.Volume = 0.8
	horn.RollOffMinDistance = 12
	horn.RollOffMaxDistance = 120
	horn.Parent = body
	-- Its look: the house's station wagon (told apart by the bay's number).
	task.spawn(function()
		Kit.preload()
		local mesh = Kit.place(model, "MallCar", bodyAt * CFrame.Angles(0, math.pi, 0))
		if mesh then
			Kit.hide(body)
		end
	end)
	local seats = {}
	for s, spot in C.SeatSpots do
		local seat = Instance.new("Seat")
		seat.Name = "Seat" .. s
		seat.Size = Vector3.new(2, 1, 2)
		seat.CFrame = home * CFrame.new(spot[1], spot[2], spot[3])
		seat.Anchored = true
		seat.CanCollide = false
		seat.CanTouch = false -- (sat in only by the car, never by walking into it)
		seat.CanQuery = false
		seat.Transparency = 1
		seat.Parent = model
		seats[s] = seat
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			self:_occupantChanged(id, s)
		end)
	end
	-- The sign in the rear window, for strangers across the garage.
	local at = C.SignAt
	local signPart = PropFactory.part(
		model,
		"Sign",
		Vector3.new(C.SignSize[1], C.SignSize[2], 0.05),
		home * CFrame.new(at[1], at[2], at[3]) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(232, 224, 200),
		Enum.Material.SmoothPlastic,
		{ collide = false, query = false, castShadow = false }
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.4
	gui.Parent = signPart
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -16, 1, -10)
	text.Position = UDim2.fromOffset(8, 5)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.PermanentMarker
	text.TextColor3 = Color3.fromRGB(34, 28, 26)
	text.Parent = gui
	-- Get in: E on the car.
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Get in"
	prompt.ObjectText = bay.name
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function(player)
		self:Board(player, id)
	end)
	self.bodies[id] = {
		model = model,
		home = home,
		seats = seats,
		sign = text,
		body = body,
		prompt = prompt,
		door = door,
		name = bay.name,
	}
end

-- Seats -----------------------------------------------------------------------

function CarService:CarOf(player: Player)
	local id = self.seated[player]
	return id and self.cars[id] or nil, id
end

-- Puts a player in a seat of car `id` by the server's hand (boarding, the
-- wheel changing hands, coming back).
function CarService:_sit(player: Player, id: number, seat: number)
	local humanoid = humanoidOf(player)
	local part = self.bodies[id].seats[seat]
	if not humanoid or not part then
		return
	end
	self.quiet[player] = true
	if humanoid.SeatPart and humanoid.SeatPart ~= part then
		local weld = (humanoid.SeatPart :: Seat):FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		humanoid.Sit = false
	end
	self.services.PlayerStateService:MarkTeleport(player)
	part:Sit(humanoid)
	task.defer(function()
		self.quiet[player] = nil
	end)
end

-- Takes a player out of their seat by the server's hand, beside the car.
function CarService:_unseat(player: Player, id: number, seat: number?, place: boolean)
	local humanoid = humanoidOf(player)
	local b = self.bodies[id]
	self.quiet[player] = true
	if humanoid then
		local seatPart = humanoid.SeatPart
		if seatPart then
			local weld = seatPart:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
		end
		humanoid.Sit = false
	end
	if place and player.Character and b then
		local spot = C.SeatSpots[seat or 1]
		local side = spot[1] < 0 and -C.ExitSide or C.ExitSide
		local at = b.home * CFrame.new(side, 3, spot[3]) * CFrame.Angles(0, math.rad(spot[1] < 0 and 90 or -90), 0)
		self.services.PlayerStateService:MarkTeleport(player)
		player.Character:PivotTo(at)
		-- Their client can hold them in the seat a moment longer, and standing
		-- up from it puts them on the roof: set down again once it's let go.
		task.delay(C.ExitSettle, function()
			local character = player.Character
			if
				character
				and not self.seated[player]
				and (character:GetPivot().Position - at.Position).Magnitude > 2
			then
				self.services.PlayerStateService:MarkTeleport(player)
				character:PivotTo(at)
			end
		end)
	end
	task.defer(function()
		self.quiet[player] = nil
	end)
end

-- A seat's occupant changed by the player's own doing: they jumped out.
function CarService:_occupantChanged(id: number, seat: number)
	local car = self.cars[id]
	local userId = car and car.seats[seat]
	if not userId then
		return
	end
	local player = playerOf(userId :: number)
	if not player or self.quiet[player] then
		return
	end
	local occupant = self.bodies[id].seats[seat].Occupant
	if occupant and occupant.Parent == player.Character then
		return
	end
	if car.away then
		return -- (unseated for the run, Studio: they're still its squad)
	end
	self:Leave(player, true)
end

-- Gets in: the first free seat of car `id`, the wheel first.
function CarService:Board(player: Player, id: number): (boolean, string?)
	local car = self.cars[id]
	if not car or not self.services.LobbyService:InLobby() then
		return false, "lobby"
	end
	if player:GetAttribute(PA.State) ~= nil and player:GetAttribute(PA.State) ~= Constants.PlayerStates.Lobby then
		return false, "state"
	end
	if self.seated[player] then
		if self.seated[player] == id then
			return false, "seated"
		end
		self:Leave(player, false)
	end
	local ok, why = Cars.canBoard(car, {
		userId = player.UserId,
		partyId = partyOf(player),
		friendOfDriver = self:_friends(player, Cars.driver(car)),
	}, now())
	if not ok then
		local say = {
			full = "That car's full.",
			friends = "That car is friends only.",
			held = "That car is saved for a party that came together.",
			away = "That car's out.",
		}
		if say[why] then
			Net.get("Notify"):FireClient(player, say[why], "info")
		end
		return false, why
	end
	local seat = Cars.board(car, player.UserId) :: number
	self.seated[player] = id
	player:SetAttribute(PA.Car, id)
	-- The tape in your hand goes in the deck if it's empty.
	local tape = player:GetAttribute(PA.Tape)
	if Cars.insertTape(car, tape) then
		self.services.RentalService:Take(player)
	end
	self:_sit(player, id, seat)
	if seat == 1 then
		Net.get("Notify"):FireClient(
			player,
			car.tape and "You're driving. Honk when your squad's in."
				or "You're driving. No tape yet: rent one in the video store.",
			"info"
		)
	end
	self:_render()
	return true
end

-- Gets out (`place`: beside the car, when the server takes them out).
function CarService:Leave(player: Player, place: boolean)
	local id = self.seated[player]
	local car = id and self.cars[id]
	if not car then
		return
	end
	local seat = Cars.seatOf(car, player.UserId)
	-- The last one out of a car in the garage takes its tape out of the deck.
	local tape = Cars.count(car) == 1 and not car.away and car.tape or nil
	local moves = Cars.leave(car, player.UserId, C)
	self.seated[player] = nil
	player:SetAttribute(PA.Car, nil)
	if player.Parent then
		self:_unseat(player, id, seat, place)
		if tape and player:GetAttribute(PA.Tape) == nil then
			self.services.RentalService:Give(player, tape)
		end
	end
	for _, move in moves do
		local who = playerOf(move[1])
		if who then
			self:_sit(who, id, move[3])
			Net.get("Notify"):FireClient(who, "You've taken the wheel.", "info")
		end
	end
	if car.away and Cars.count(car) == 0 then
		self:_comeHome(id, nil)
	end
	self:_render()
end

-- A car's horn: the one the owner picked by ear (Assets.Mall.Horn; F2
-- `mallsound horn <n>` sounds the nearest car's, `id` nil).
function CarService:Sound(id: number?, near: Vector3?)
	if not id and near then
		local best = math.huge
		for i, b in self.bodies do
			local d = (b.body.Position - near).Magnitude
			if d < best then
				id, best = i, d
			end
		end
	end
	local b = id and self.bodies[id]
	local horn = b and b.body:FindFirstChild("Horn") :: Sound?
	local list = Assets.Mall.Horn
	if horn and list and #list > 0 then
		local pick = ReplicatedStorage.RunState:GetAttribute(Constants.RunState.MallSound .. "Horn")
		horn.SoundId = list[math.clamp(tonumber(pick) or 1, 1, #list)]
		horn:Play()
	end
end

-- The dashboard ------------------------------------------------------------

-- key and value arrive as text (the dashboard's switches, F2 `car set`),
-- matched without regard to case: "difficulty" Hard, "night" full,
-- "friendsOnly" true.
function CarService:Set(player: Player, key: string, value: string)
	local car = self:CarOf(player)
	if not car then
		return
	end
	local function among(list)
		for _, name in list do
			if string.lower(name) == string.lower(value) then
				return name
			end
		end
		return nil
	end
	local k, v = string.lower(key), nil
	if k == "difficulty" then
		key, v = "difficulty", among(C.Difficulty)
	elseif k == "night" then
		key, v = "night", among(C.Night)
	elseif k == "friendsonly" then
		key, v = "friendsOnly", string.lower(value) == "true"
	end
	if v ~= nil and Cars.set(car, player.UserId, key, v, C) then
		self:_render()
	end
end

function CarService:Honk(player: Player)
	local car, id = self:CarOf(player)
	if not car then
		return
	end
	local orchestrator = self.services.RunOrchestrator
	local places = self.services.PlaceService
	if places and places:IsRun() then
		Net.get("Notify"):FireClient(player, "The house is waiting on the rest of your squad.", "info")
		return
	end
	if not places or not places:IsLobby() then
		-- (Studio plays the run in this server: one at a time.)
		if orchestrator:Phase() ~= Constants.Phases.Lobby then
			Net.get("Notify"):FireClient(player, "Another squad's run is on in this server.", "info")
			return
		end
	end
	local ok, why = Cars.honk(car, player.UserId, now(), C)
	if not ok then
		if why == "tape" then
			Net.get("Notify"):FireClient(player, "No tape in the deck: rent a case in the video store.", "info")
		end
		return
	end
	self:Sound(id)
	self:_render()
	task.spawn(function()
		while car.leavingAt and not Cars.due(car, now()) do
			task.wait(0.25)
			self:_render()
		end
		if Cars.due(car, now()) then
			self:_depart(id :: number)
		end
	end)
end

-- Leaving ----------------------------------------------------------------------

-- Lifts (or lowers) a car's roll-up door.
function CarService:_door(id: number, up: boolean)
	local door = self.bodies[id].door
	if not door then
		return
	end
	local rise = up and C.DoorRise or -C.DoorRise
	local parts = {}
	for _, p in door:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(parts, { part = p, from = p.CFrame })
		end
	end
	local t0 = os.clock()
	while true do
		local a = math.clamp((os.clock() - t0) / C.DoorSeconds, 0, 1)
		for _, e in parts do
			e.part.CFrame = e.from + Vector3.new(0, rise * a, 0)
			if e.part.Name == "Shutter" then
				e.part.CanCollide = not up
			end
		end
		if a >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
end

-- Drives a car between its bay and the night beyond its door (`out`).
function CarService:_drive(id: number, out: boolean)
	local b = self.bodies[id]
	local from = b.model:GetPivot()
	local to = out and (b.home * CFrame.new(0, 0, -C.DriveDistance)) or b.home
	-- (Its pivot is its body's middle, 2.5 up.)
	from = CFrame.new(from.Position.X, b.home.Position.Y, from.Position.Z)
	b.body.CanCollide = false
	local t0 = os.clock()
	while true do
		local a = math.clamp((os.clock() - t0) / C.DriveSeconds, 0, 1)
		local eased = out and a * a or 1 - (1 - a) * (1 - a)
		b.model:PivotTo(from:Lerp(to, eased) * CFrame.new(0, 2.5, 0))
		if a >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	b.body.CanCollide = not out
end

function CarService:_depart(id: number)
	local car = self.cars[id]
	local squad = {}
	for _, userId in Cars.riders(car) do
		local player = playerOf(userId)
		if player then
			table.insert(squad, player)
		end
	end
	if #squad == 0 then
		return
	end
	car.away = true
	car.leavingAt = nil
	-- (Any other tapes in hand stay in the car: nobody takes one into the house.)
	for _, player in squad do
		self.services.RentalService:Take(player)
	end
	self:_render()
	self:_door(id, true)
	self:_drive(id, true)
	local settings = {
		difficulty = car.difficulty,
		location = car.tape or Locations.Default,
		night = car.night,
		lobby = game.JobId,
	}
	local places = self.services.PlaceService
	if places and places:IsLobby() then
		if places:SendSquad(squad, settings) then
			-- They go; the car comes back empty once they have (Leave).
			task.delay(30, function()
				-- (Anyone still here after the teleport: bring them home.)
				if car.away and Cars.count(car) > 0 then
					self:_comeHome(id, nil)
				end
			end)
			return
		end
		for _, player in squad do
			Net.get("Notify"):FireClient(player, "The car wouldn't start. Honk to try again.", "info")
		end
		self:_comeHome(id, nil)
		return
	end
	-- Studio (and a hub that couldn't send its squad back): the run starts
	-- in this server. Out of their seats for it, still the car's squad.
	for _, player in squad do
		self:_unseat(player, id, nil, false)
	end
	self.services.RunOrchestrator:SetNight(car.night)
	self.services.RunOrchestrator:StartRun(squad, car.difficulty, settings.location)
end

-- Brings a car back to its bay; `riders` (players) are seated again in
-- their seats (back from their run, in Studio), the rest let go.
function CarService:_comeHome(id: number, riders: { Player }?)
	local car = self.cars[id]
	if not car.away then
		return
	end
	if riders == nil then
		-- An empty car, or one whose squad didn't go: back in the bay.
		local still = {}
		for _, userId in Cars.riders(car) do
			local player = playerOf(userId)
			if player and self.seated[player] == id then
				table.insert(still, player)
			else
				Cars.leave(car, userId, C)
			end
		end
		riders = still
	end
	task.spawn(function()
		if #riders == 0 then
			task.wait(C.BackSeconds)
		end
		self:_drive(id, false)
		self:_door(id, false)
		car.away = false
		if #riders == 0 then
			for _, userId in Cars.riders(car) do
				Cars.leave(car, userId, C)
			end
		end
		self:_render()
	end)
end

-- Back from a run in this server (Studio; LobbyService:Return): each
-- player whose car is away goes back in their seat and the car home.
-- Returns the players it seated.
function CarService:Return(players: { Player }, receipts): { Player }
	local seatedNow = {}
	for id, car in self.cars do
		if car.away then
			local riders = {}
			for _, player in players do
				local seat = Cars.seatOf(car, player.UserId)
				if seat then
					table.insert(riders, player)
					table.insert(seatedNow, player)
				end
			end
			-- Those who didn't come back give up their seats.
			for _, userId in Cars.riders(car) do
				local player = playerOf(userId)
				if not player or not table.find(riders, player) then
					Cars.leave(car, userId, C)
				end
			end
			if #riders > 0 then
				car.away = false
				local b = self.bodies[id]
				b.model:PivotTo(b.home * CFrame.new(0, 2.5, 0))
				b.body.CanCollide = true
				task.spawn(self._door, self, id, false)
				for _, player in riders do
					self.seated[player] = id
					player:SetAttribute(PA.Car, id)
					self:_sit(player, id, Cars.seatOf(car, player.UserId) :: number)
					self:_receipt(player, receipts and receipts[player], car.tape)
				end
			elseif Cars.count(car) == 0 then
				self:_comeHome(id, nil)
			end
		end
	end
	self:_render()
	return seatedNow
end

function CarService:_receipt(player: Player, marks: number?, tape: string?)
	if marks == nil then
		return
	end
	local location = tape and Locations.ById[tape]
	Net.get("Receipt"):FireClient(player, { marks = marks, case = location and location.name or nil })
end

-- A squad coming back from its run server (Logic/Homecoming): seated in a
-- car together once all of it is here (or after a while), its tape in the
-- deck, each with a receipt.
function CarService:_arrived(player: Player)
	local ok, joinData = pcall(player.GetJoinData, player)
	local raw = ok and joinData and joinData.TeleportData
	local known = { difficulty = {}, location = {}, night = {} }
	for _, name in C.Difficulty do
		known.difficulty[name] = true
	end
	for _, location in Locations.List do
		known.location[location.id] = true
	end
	for _, name in C.Night do
		known.night[name] = true
	end
	local data = Homecoming.read(raw, known)
	if not data or not table.find(data.squad, player.UserId) then
		return
	end
	local group = self.arrivals[data.token]
	if not group then
		group = { data = data, players = {}, since = os.clock() }
		self.arrivals[data.token] = group
		task.delay(C.ArrivalWait, function()
			self:_seatArrivals(data.token)
		end)
	end
	table.insert(group.players, player)
	if #group.players >= #group.data.squad then
		self:_seatArrivals(data.token)
	end
end

function CarService:_seatArrivals(token: string)
	local group = self.arrivals[token]
	if not group then
		return
	end
	self.arrivals[token] = nil
	self:_seatSquad(group.players, group.data)
end

-- Seats a squad together in the first empty car, with their tape in its deck
-- and their settings; data = { tape, difficulty?, night?, receipts? } (a
-- receipt each when there's one: Logic/Homecoming).
function CarService:_seatSquad(players: { Player }, data)
	local id = Cars.firstEmpty(self.cars, now())
	local car = id and self.cars[id]
	if not car then
		return -- (no free car: they stand in the garage, as before)
	end
	for _, player in players do
		if player.Parent then
			-- (Their body has to be in before they can sit.)
			if not player.Character then
				player.CharacterAdded:Wait()
			end
			local root = player.Character and player.Character:WaitForChild("HumanoidRootPart", 10)
			if root and not self.seated[player] then
				local seat = Cars.board(car, player.UserId)
				if seat then
					self.seated[player] = id
					player:SetAttribute(PA.Car, id)
					self:_sit(player, id :: number, seat)
					self:_receipt(player, data.receipts and data.receipts[player.UserId], data.tape)
				end
			end
		end
	end
	if Cars.count(car) > 0 then
		car.tape = data.tape
		car.difficulty = data.difficulty or car.difficulty
		car.night = data.night or car.night
	end
	self:_render()
end

-- A run server that couldn't send its squad back becomes their hub
-- (PlaceService:ReturnSquad). It has only the garage, no tapes to rent, so
-- the squad goes back in a car with their case still in the deck: a honk
-- plays it again here. receipts: { [userId] = Marks }.
function CarService:Strand(players: { Player }, settings, receipts)
	task.spawn(function()
		self:_seatSquad(players, {
			tape = settings.location or Locations.Default,
			difficulty = settings.difficulty,
			night = settings.night,
			receipts = receipts,
		})
	end)
end

-- A teleport that failed after it began (PlaceService): the car brings them
-- home, still seated.
function CarService:TeleportFailed(player: Player)
	local id = self.seated[player]
	if id and self.cars[id].away then
		self:_comeHome(id, nil)
	end
end

-- What everyone sees ------------------------------------------------------------

-- The signs, the prompts, and each rider's dashboard.
function CarService:_render()
	local t = now()
	local names = {}
	for _, player in Players:GetPlayers() do
		names[player.UserId] = player.DisplayName
	end
	for id, car in self.cars do
		local b = self.bodies[id]
		if b then
			local location = car.tape and Locations.ById[car.tape]
			b.sign.Text = table.concat(Cars.sign(car, names, location and location.name, t, C), "\n")
			b.prompt.Enabled = not car.away and Cars.count(car) < #car.seats
			b.prompt.ObjectText = b.name .. (car.friendsOnly and " · friends only" or "")
			local riders = {}
			for s, userId in car.seats do
				riders[s] = userId and (names[userId] or "?") or false
			end
			local state = {
				id = id,
				name = b.name,
				riders = riders,
				tape = location and location.name or nil,
				difficulty = car.difficulty,
				night = car.night,
				nightName = C.NightNames[car.night] or car.night,
				friendsOnly = car.friendsOnly,
				leavingIn = car.leavingAt and math.max(0, math.ceil(car.leavingAt - t)) or nil,
				away = car.away,
			}
			for _, userId in Cars.riders(car) do
				local player = playerOf(userId)
				if player then
					state.driver = Cars.driver(car) == userId
					Net.get("CarState"):FireClient(player, state)
				end
			end
		end
	end
	-- The hub's squad list only when someone changed cars (not every tick of
	-- a countdown).
	local who = {}
	for id, car in self.cars do
		table.insert(who, id .. "=" .. table.concat(Cars.riders(car), ","))
	end
	local signature = table.concat(who, ";")
	if signature ~= self.lastRiders then
		self.lastRiders = signature
		self.services.LobbyService:Broadcast()
	end
end

-- Who's in which car, by name (LobbyService's hub list).
function CarService:CarName(player: Player): string?
	local id = self.seated[player]
	return id and self.bodies[id] and self.bodies[id].name or nil
end

-- Start --------------------------------------------------------------------------

function CarService:Start()
	Net.onServer("CarSet", { interval = 0.15, types = { "string", "string" } }, function(player, key, value)
		self:Set(player, key, value)
	end)
	Net.onServer("CarHonk", { interval = 0.5 }, function(player)
		self:Honk(player)
	end)
	Net.onServer("CarGetOut", { interval = 0.3 }, function(player)
		local car = self:CarOf(player)
		if car and not car.away then
			self:Leave(player, true)
		end
	end)
	local function onPlayer(player: Player)
		task.spawn(self._arrived, self, player)
		-- A Roblox party arriving together is kept a car of its own.
		local party = partyOf(player)
		if party then
			task.delay(5, function()
				local together = 0
				for _, other in Players:GetPlayers() do
					if partyOf(other) == party then
						together += 1
					end
				end
				if together >= 2 and player.Parent and not self.seated[player] then
					local id = Cars.holdFor(self.cars, party, now(), C.PartyHold)
					if id then
						Net.get("Notify")
							:FireClient(
								player,
								"Your party has " .. self.bodies[id].name .. ": get in together.",
								"info"
							)
						self:_render()
					end
				end
			end)
		end
		player.CharacterRemoving:Connect(function()
			local car = self:CarOf(player)
			if car and not car.away then
				self:Leave(player, false)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		if self.seated[player] then
			self:Leave(player, false)
		end
		self.seated[player] = nil
		self.quiet[player] = nil
	end)
end

return CarService
