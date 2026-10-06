-- What each Witness sees, and how they talk without a voice (doc section 6).
-- Owns the camera view reports the observation rule runs on (two players
-- watching The Guest freeze him), line-of-sight checks, pings and
-- structured callouts. Witness windows, anchoring and Focus retired with the
-- clue loop (docs/plans/gameplay-rework.md, R2c); the two-watcher freeze and
-- the co-stare live on in StalkerService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Pings = require(Shared.Data.Pings)

local PA = Constants.PlayerAttributes

local WitnessService = {}

local views: { [Player]: { cframe: CFrame, t: number } } = {}
local lastCallout: { [Player]: number } = {}

function WitnessService:Init(services)
	self.services = services
	self.PlayerState = services.PlayerStateService
	self.World = services.WorldService
end

function WitnessService:Start()
	Players.PlayerRemoving:Connect(function(player)
		views[player] = nil
		lastCallout[player] = nil
	end)

	Net.get("ReportView").OnServerEvent:Connect(function(player, cf)
		if typeof(cf) ~= "CFrame" then
			return
		end
		local previousView = views[player]
		if previousView and os.clock() - previousView.t < 1 / 30 then
			return -- clients report at ~12 Hz; anything much faster is spam
		end
		local head = self.PlayerState:Head(player)
		if head and (cf.Position - head.Position).Magnitude > 30 then
			return
		end
		local previous = views[player]
		if previous and (previous.cframe.LookVector - cf.LookVector).Magnitude > 0.02 then
			self.PlayerState:Touch(player)
		end
		views[player] = { cframe = cf, t = os.clock() }
	end)

	Net.onServer(
		"Ping",
		{ interval = Config.Social.PingCooldown, burst = 3, types = { "string", "Vector3" } },
		function(player, pingType, position)
			self:HandlePing(player, pingType, position)
		end
	)
	Net.onServer(
		"Callout",
		{ interval = Config.Social.CalloutCooldown, types = { "string", "Vector3" } },
		function(player, calloutType, position)
			self:HandleCallout(player, calloutType, position)
		end
	)
end

-- Views and line of sight --------------------------------------------------

function WitnessService:GetView(player: Player): (CFrame?, number)
	local view = views[player]
	if not view then
		return nil, math.huge
	end
	return view.cframe, os.clock() - view.t
end

local function ignoreList(extra)
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	for _, instance in extra or {} do
		table.insert(list, instance)
	end
	return list
end

-- True if nothing solid blocks the line from `from` to `to`. A wall is a wall
-- for everyone now: the divergences that once made a doorway real for one
-- Witness alone are gone (R2c), so nothing sees through a solid seam panel.
function WitnessService:ClearLine(from: Vector3, to: Vector3, extraIgnore: { Instance }?): boolean
	local delta = to - from
	if delta.Magnitude < 0.5 then
		return true
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList(extraIgnore)
	params.RespectCanCollide = true
	local result = Workspace:Raycast(from, delta, params)
	return result == nil or (result.Position - to).Magnitude < 1.5
end

-- Is the player's camera pointed at `position` within `coneDegrees` (full
-- cone angle), within range, with a clear line?
function WitnessService:IsLookingAt(
	player: Player,
	position: Vector3,
	coneDegrees: number,
	maxRange: number,
	extraIgnore
): boolean
	local cf, age = self:GetView(player)
	if not cf or age > 0.6 then
		return false
	end
	local offset = position - cf.Position
	local distance = offset.Magnitude
	if distance > maxRange or distance < 0.1 then
		return false
	end
	local cosHalf = math.cos(math.rad(coneDegrees / 2))
	if cf.LookVector:Dot(offset.Unit) < cosHalf then
		return false
	end
	return self:ClearLine(cf.Position, position, extraIgnore)
end

-- Pings and callouts ------------------------------------------------------------

function WitnessService:HandlePing(player: Player, pingType, position)
	if type(pingType) ~= "string" or not Pings.TypeById[pingType] or typeof(position) ~= "Vector3" then
		return
	end
	local root = self.PlayerState:Root(player)
	if not root or (root.Position - position).Magnitude > 400 then
		return
	end
	local state = self.PlayerState:State(player)
	local isEcho = state == Constants.PlayerStates.Lost
	if isEcho then
		if not self.PlayerState:CanEchoHint(player) then
			Net.get("Notify"):FireClient(player, "Your next Echo hint is not ready yet.", "warning")
			return
		end
		self.PlayerState:MarkEchoHint(player)
		-- An Echo's job (WP2): a knock on the nearest shut door draws him there.
		self:_echoKnock(player, root.Position)
	elseif
		state ~= Constants.PlayerStates.Active
		and state ~= Constants.PlayerStates.Downed
		and state ~= Constants.PlayerStates.Lobby
	then
		return
	end
	local profile = self.services.SquadProfileService
	if profile and not isEcho then
		profile:Record("pings", 1)
	end
	Net.get("Pinged"):FireAllClients({
		from = player.UserId,
		name = player.DisplayName,
		type = pingType,
		position = position,
		radio = player:GetAttribute(PA.Tool) == "Radio",
		echo = isEcho,
	})
end

-- Lost, you can still knock: the nearest shut door within ten studs sounds
-- three knocks and he hears a lure there (NoiseService), once a hint.
function WitnessService:_echoKnock(player: Player, from: Vector3)
	local world = self.World.World
	local best, bestDistance = nil, 10
	for _, door in world and world.doors or {} do
		if not door.open and door.position then
			local d = (door.position - from).Magnitude
			if d < bestDistance then
				best, bestDistance = door, d
			end
		end
	end
	if best then
		self.services.DoorService:Knock(best)
		self.services.NoiseService:Emit(best.position, 25, nil, "lure")
		Net.get("Notify"):FireClient(player, "You knock. He heard it.", "warning")
	end
end

-- Used by the stalker's FakePing tactic (doc: "Fakes pings to lure players").
function WitnessService:FakePing(impersonate: Player, pingType: string, position: Vector3)
	Net.get("Pinged"):FireAllClients({
		from = impersonate.UserId,
		name = impersonate.DisplayName,
		type = pingType,
		position = position,
		-- Deliberately indistinguishable from a real ping on the client.
	})
end

function WitnessService:HandleCallout(player: Player, calloutType, position)
	if type(calloutType) ~= "string" or not Pings.CalloutById[calloutType] or typeof(position) ~= "Vector3" then
		return
	end
	local root = self.PlayerState:Root(player)
	if not root or (root.Position - position).Magnitude > 200 then
		return
	end
	if not self.PlayerState:IsActive(player) and self.PlayerState:State(player) ~= Constants.PlayerStates.Downed then
		return
	end
	local now = os.clock()
	if lastCallout[player] and now - lastCallout[player] < Config.Social.CalloutCooldown then
		return
	end
	lastCallout[player] = now
	Net.get("CalloutHeard"):FireAllClients({
		from = player.UserId,
		name = player.DisplayName,
		type = calloutType,
		position = position,
	})
end

return WitnessService
