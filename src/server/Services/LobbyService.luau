-- The hub (doc section 2, "Briefing"; docs/plans/lobby-rework.md): the dead
-- mall's lit corner. A squad rents a tape in the video store, gets in a car
-- in the garage, and the driver honks (Services/RentalService, Services/
-- CarService, LB2: the cars are the ready-up). In a live lobby the car's
-- squad goes to a reserved server of its own for the run (Services/
-- PlaceService); in Studio, and with Config.Places.ReservedRuns off, the run
-- is played in this server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Locations = require(Shared.Data.Locations)
local Mall = require(Shared.Data.Mall)

local MallBuilder = require(script.Parent.Parent.World.MallBuilder)

local PA = Constants.PlayerAttributes

local LobbyService = {}

function LobbyService:Init(services)
	self.services = services
	-- (F2 `start` plays these: a car's own settings go with its squad.)
	self.difficulty = "Normal"
	self.location = Locations.Default
end

local function lobbyOrigin(): Vector3
	local o = Config.Level.LobbyOrigin
	return Vector3.new(o.x, o.y, o.z)
end

-- Where the index-th player stands when they come back from a run: the
-- garage, by the cars (Data/Mall Returns; a run server's waiting room).
function LobbyService:SpawnCFrame(index: number?): CFrame
	local spots = self.returns
	if not spots or #spots == 0 then
		local i = (index or 1) - 1
		return CFrame.new(lobbyOrigin() + Vector3.new(-6 + (i % 4) * 4, 3, 14))
	end
	return spots[((index or 1) - 1) % #spots + 1]
end

function LobbyService:_build()
	local folder = Instance.new("Folder")
	folder.Name = "ConsensusLobby"
	folder.Parent = Workspace
	local o = lobbyOrigin()
	-- The dead mall's lit corner (Data/Mall, World/MallBuilder; LB1a's grey
	-- box). A run server builds only the squad's waiting room.
	local places = self.services.PlaceService
	local waiting = places ~= nil and places:IsRun()
	local built = MallBuilder.build(folder, o, waiting and Mall.Waiting.rooms or nil)
	self.returns = built.returns

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 6)
	spawn.CFrame = built.spawn + Vector3.new(0, 0.05, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	-- The party cars in the garage and the tapes to rent (LB2).
	self.services.CarService:Build(folder, o)
	self.services.RentalService:Build(folder, o)
	self.folder = folder
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
					self.services.OutfitService:LoadCharacter(player)
				end
			end)
		end)
		if data then
			data:WaitForProfile(player, 8)
		end
		if player.Parent then
			self.services.OutfitService:LoadCharacter(player)
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
		end)
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

-- Return players to the hub after a run played here (Studio): back in the
-- car they left in (CarService), or by the cars. receipts: { [Player] =
-- Marks }, for the slip in the car.
function LobbyService:Return(players: { Player }, receipts)
	local seated = self.services.CarService:Return(players, receipts)
	for i, player in players do
		local character = player.Character
		if character and not table.find(seated, player) then
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
			car = self.services.CarService:CarName(player),
			state = player:GetAttribute(PA.State),
		})
	end
	table.sort(list, function(a, b)
		return a.userId < b.userId
	end)
	local location = Locations.ById[self.location]
	Net.get("LobbyState"):FireAllClients({
		players = list,
		location = { id = location.id, name = location.name, blurb = location.blurb },
		locations = Locations.List,
		inLobby = self:InLobby(),
	})
end

return LobbyService
