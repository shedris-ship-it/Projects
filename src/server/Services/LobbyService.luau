-- The hub (doc section 2, "Briefing"): a lit safehouse where the squad picks
-- a contract and difficulty, chooses a tool and readies up. A single place
-- holds both the hub and the run for the vertical slice; split them into two
-- places with TeleportService when matchmaking arrives (doc section 7).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Locations = require(Shared.Data.Locations)
local LobbyRules = require(Shared.Logic.LobbyRules)
local PropFactory = require(Shared.World.PropFactory)

local PA = Constants.PlayerAttributes

local LobbyService = {}

function LobbyService:Init(services)
	self.services = services
	self.difficulty = "Normal"
	self.location = Locations.Default
	self.countdownThread = nil
end

local function lobbyOrigin(): Vector3
	local o = Config.Level.LobbyOrigin
	return Vector3.new(o.x, o.y, o.z)
end

function LobbyService:SpawnCFrame(index: number?): CFrame
	local i = (index or 1) - 1
	return CFrame.new(lobbyOrigin() + Vector3.new(-6 + (i % 4) * 4, 3, 14))
end

function LobbyService:_build()
	local folder = Instance.new("Folder")
	folder.Name = "ConsensusLobby"
	folder.Parent = Workspace
	local o = lobbyOrigin()
	local floorColor = Color3.fromRGB(96, 70, 52)
	local wallColor = Color3.fromRGB(122, 104, 84)
	local plaster = PropFactory.material("Plaster")
	PropFactory.part(
		folder,
		"Floor",
		Vector3.new(56, 1, 56),
		CFrame.new(o - Vector3.new(0, 0.5, 0)),
		floorColor,
		PropFactory.material("WoodPlanks")
	)
	PropFactory.part(
		folder,
		"Ceiling",
		Vector3.new(56, 1, 56),
		CFrame.new(o + Vector3.new(0, 14.5, 0)),
		Color3.fromRGB(80, 70, 60),
		plaster
	)
	for _, wall in
		{
			{ Vector3.new(0, 7, -28), Vector3.new(56, 14, 1) },
			{ Vector3.new(0, 7, 28), Vector3.new(56, 14, 1) },
			{ Vector3.new(-28, 7, 0), Vector3.new(1, 14, 56) },
			{ Vector3.new(28, 7, 0), Vector3.new(1, 14, 56) },
		}
	do
		PropFactory.part(folder, "Wall", wall[2], CFrame.new(o + wall[1]), wallColor, plaster)
	end
	PropFactory.build("Rug", CFrame.new(o), folder)

	-- Warm, safe lighting: the contrast with the house is the point.
	for _, x in { -14, 14 } do
		local lamp = PropFactory.part(
			folder,
			"Lamp",
			Vector3.new(3, 0.6, 3),
			CFrame.new(o + Vector3.new(x, 13.8, 0)),
			Color3.fromRGB(255, 230, 190),
			PropFactory.material("Neon"),
			{ collide = false }
		)
		local light = Instance.new("PointLight")
		light.Range = 40
		light.Brightness = 1.6
		light.Color = Color3.fromRGB(255, 214, 160)
		light.Shadows = true
		light.Parent = lamp
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 6)
	spawn.CFrame = CFrame.new(o + Vector3.new(0, 0.05, 14))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	-- Contract table: toggles difficulty.
	local tableCF = CFrame.new(o + Vector3.new(20, 0, 0)) * CFrame.Angles(0, math.rad(-90), 0)
	local contract = PropFactory.build("Table", tableCF, folder, { name = "ContractTable" })
	local paper = PropFactory.part(
		folder,
		"Contract",
		Vector3.new(3, 0.1, 2),
		tableCF * CFrame.new(0, 3.5, 0),
		Color3.fromRGB(226, 216, 186),
		PropFactory.material("SmoothPlastic"),
		{ collide = false }
	)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Change difficulty"
	prompt.ObjectText = "Contract: " .. Locations.ById[self.location].name
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = paper
	prompt.Triggered:Connect(function(player)
		self:SetDifficulty(player, self.difficulty == "Normal" and "Hard" or "Normal")
	end)
	self.contractPrompt = prompt
	self.folder = folder
	return contract
end

function LobbyService:Start()
	self:_build()
	local data = self.services.DataService

	local function onPlayer(player: Player)
		-- Respawn on death (nothing in the game kills players, but resets happen).
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")
			humanoid.Died:Connect(function()
				task.wait(2)
				if player.Parent then
					player:LoadCharacter()
				end
			end)
		end)
		player:SetAttribute(PA.Ready, false)
		if data then
			data:WaitForProfile(player, 8)
		end
		if player.Parent then
			player:LoadCharacter()
		end
		self:Broadcast()
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			self:Broadcast()
			self:_checkStart()
		end)
	end)

	Net.onServer("SetReady", { interval = 0.2, types = { "boolean" } }, function(player, ready)
		self:SetReady(player, ready == true)
	end)
	Net.onServer("SetNight", { interval = 0.3, types = { "string" } }, function(_, night)
		-- The next run's length (WP8), from the hub's Night button.
		if self:InLobby() and self.services.RunOrchestrator:SetNight(night) then
			self:Broadcast()
		end
	end)
	Net.onServer("SetDifficulty", { interval = 0.3, types = { "string" } }, function(player, difficulty)
		self:SetDifficulty(player, difficulty)
	end)
end

function LobbyService:InLobby(): boolean
	local orchestrator = self.services.RunOrchestrator
	return orchestrator == nil or orchestrator:Phase() == Constants.Phases.Lobby
end

function LobbyService:LobbyPlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute(PA.State) == Constants.PlayerStates.Lobby or player:GetAttribute(PA.State) == nil then
			table.insert(list, player)
		end
	end
	return list
end

function LobbyService:SetDifficulty(player: Player, difficulty)
	if type(difficulty) ~= "string" or not Config.Difficulty[difficulty] or not self:InLobby() then
		return
	end
	self.difficulty = difficulty
	Net.get("Notify"):FireAllClients(player.DisplayName .. " set the contract to " .. difficulty .. ".", "info")
	self:Broadcast()
end

function LobbyService:SetReady(player: Player, ready: boolean)
	if not self:InLobby() then
		return
	end
	player:SetAttribute(PA.Ready, ready)
	-- The majority's clock runs from the first Ready (Logic/LobbyRules) and
	-- stops when nobody is ready any more.
	local anyReady = false
	for _, other in self:LobbyPlayers() do
		if other:GetAttribute(PA.Ready) then
			anyReady = true
		end
	end
	if anyReady and not self.firstReadyAt then
		self.firstReadyAt = os.clock()
		-- Look again when the timer runs out, with nobody pressing anything.
		task.delay((Config.Run.LobbyMajoritySeconds or 30) + 0.1, function()
			self:_checkStart()
		end)
	elseif not anyReady then
		self.firstReadyAt = nil
	end
	self:Broadcast()
	self:_checkStart()
end

-- Who is ready, and who isn't, among the hub's players.
function LobbyService:_readiness(): ({ Player }, { Player })
	local ready, waiting = {}, {}
	for _, player in self:LobbyPlayers() do
		if player:GetAttribute(PA.Ready) then
			table.insert(ready, player)
		else
			table.insert(waiting, player)
		end
	end
	return ready, waiting
end

function LobbyService:_checkStart()
	if not self:InLobby() then
		return
	end
	local runState = ReplicatedStorage.RunState
	local players = self:LobbyPlayers()
	local ready, waiting = self:_readiness()
	local since = self.firstReadyAt and (os.clock() - self.firstReadyAt) or nil
	local how = LobbyRules.start(#players, #ready, since, Config.Run)
	-- The hub's word on it: who it waits for, and when it stops waiting.
	if how == nil and #ready >= LobbyRules.needed(#players) and #waiting > 0 and self.firstReadyAt then
		local names = {}
		for _, player in waiting do
			table.insert(names, player.DisplayName)
		end
		runState:SetAttribute(Constants.RunState.LobbyWaiting, table.concat(names, ", "))
		runState:SetAttribute(
			Constants.RunState.LobbyStartsAt,
			workspace:GetServerTimeNow() + math.max(0, (Config.Run.LobbyMajoritySeconds or 30) - (since or 0))
		)
	else
		runState:SetAttribute(Constants.RunState.LobbyWaiting, nil)
		runState:SetAttribute(Constants.RunState.LobbyStartsAt, nil)
	end
	if how and not self.countdownThread then
		-- The squad is whoever is ready now (everyone, when everyone is);
		-- the rest stay in the hub (Logic/LobbyRules "majority").
		local squad = table.clone(ready)
		self.countdownThread = task.spawn(function()
			for t = Config.Run.LobbyCountdown, 1, -1 do
				runState:SetAttribute(Constants.RunState.LobbyCountdown, t)
				task.wait(1)
				local stillReady = #squad >= 1
				for _, player in squad do
					if not player.Parent or not player:GetAttribute(PA.Ready) then
						stillReady = false
					end
				end
				if not stillReady then
					runState:SetAttribute(Constants.RunState.LobbyCountdown, nil)
					self.countdownThread = nil
					self:_checkStart()
					return
				end
			end
			runState:SetAttribute(Constants.RunState.LobbyCountdown, nil)
			runState:SetAttribute(Constants.RunState.LobbyWaiting, nil)
			runState:SetAttribute(Constants.RunState.LobbyStartsAt, nil)
			self.countdownThread = nil
			self.firstReadyAt = nil
			while #squad > Config.Run.MaxPlayers do
				table.remove(squad)
			end
			self.services.RunOrchestrator:StartRun(squad, self.difficulty, self.location)
		end)
	elseif not how and self.countdownThread then
		runState:SetAttribute(Constants.RunState.LobbyCountdown, nil)
	end
end

-- Return players to the hub after a run.
function LobbyService:Return(players: { Player })
	for i, player in players do
		player:SetAttribute(PA.Ready, false)
		local character = player.Character
		if character then
			self.services.PlayerStateService:MarkTeleport(player)
			character:PivotTo(self:SpawnCFrame(i))
		end
	end
	self:Broadcast()
end

function LobbyService:Broadcast()
	local list = {}
	for _, player in Players:GetPlayers() do
		table.insert(list, {
			userId = player.UserId,
			name = player.DisplayName,
			ready = player:GetAttribute(PA.Ready) == true,
			state = player:GetAttribute(PA.State),
		})
	end
	table.sort(list, function(a, b)
		return a.userId < b.userId
	end)
	local location = Locations.ById[self.location]
	if self.contractPrompt then
		self.contractPrompt.ObjectText = location.name .. " · " .. self.difficulty
	end
	Net.get("LobbyState"):FireAllClients({
		players = list,
		difficulty = self.difficulty,
		night = self.services.RunOrchestrator:Night(),
		location = { id = location.id, name = location.name, blurb = location.blurb },
		locations = Locations.List,
		inLobby = self:InLobby(),
	})
end

return LobbyService
