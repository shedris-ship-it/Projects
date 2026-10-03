-- Witnessing (doc section 6): hold Witness on something to open a 4-second
-- window; if a second Witness joins inside it, the thing is Anchored for 90
-- seconds. Divergences on it collapse to the truth for everyone, evidence on
-- it is confirmed, and a stalker caught in it freezes.
--
-- Also owns Focus (the social-sanity meter), camera view reports used by the
-- observation rule, pings and structured callouts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Signal = require(Shared.Lib.Signal)
local Pings = require(Shared.Data.Pings)

local PA = Constants.PlayerAttributes
local W = Config.Witness

local WitnessService = {
	Anchored = Signal.new(), -- (id, entry, witnessNames)
	SoloWitnessed = Signal.new(), -- (player, id, entry)
	WindowOpened = Signal.new(), -- (id, entry, player)
	Witnessed = Signal.new(), -- (player or "companion", id, entry)
}

local registry: { [string]: any } = {}
local windows: { [string]: any } = {}
local anchors: { [string]: number } = {}
local views: { [Player]: { cframe: CFrame, t: number } } = {}
local focus: { [Player]: number } = {}
local lastWitness: { [Player]: number } = {}
local lastCallout: { [Player]: number } = {}

function WitnessService:Init(services)
	self.services = services
	self.PlayerState = services.PlayerStateService
	self.World = services.WorldService
	self.Drift = services.DriftService
end

local function feedback(target: Player?, payload)
	if target then
		Net.get("WitnessFeedback"):FireClient(target, payload)
	else
		Net.get("WitnessFeedback"):FireAllClients(payload)
	end
end

function WitnessService:Start()
	self.World.Built:Connect(function(world)
		for id, seam in world.seams do
			self:Register(id, {
				kind = "seam",
				position = seam.position,
				label = "Wall seam",
				radius = 5,
			})
		end
	end)
	self.World.Cleared:Connect(function()
		table.clear(registry)
		table.clear(windows)
		table.clear(anchors)
	end)

	Players.PlayerRemoving:Connect(function(player)
		views[player] = nil
		focus[player] = nil
		lastWitness[player] = nil
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
		"Witness",
		{ interval = W.MinInterval, burst = 4, types = { "string?", "Vector3" } },
		function(player, targetId, position)
			self:HandleWitness(player, targetId, position)
		end
	)
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

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.1 then
			self:_tick(accumulator)
			accumulator = 0
		end
	end)
end

-- Registry -------------------------------------------------------------------

-- entry: { kind, position = Vector3 | () -> Vector3, label, radius?,
--          divergent?, anchorSeconds?, required? () -> number, hidden? }
function WitnessService:Register(id: string, entry)
	entry.id = id
	registry[id] = entry
end

function WitnessService:Unregister(id: string)
	registry[id] = nil
	windows[id] = nil
end

function WitnessService:Entry(id: string)
	return registry[id]
end

function WitnessService:MarkDivergent(id: string)
	local entry = registry[id]
	if entry then
		entry.divergent = true
	end
end

local function positionOf(entry): Vector3
	if type(entry.position) == "function" then
		return entry.position()
	end
	return entry.position
end
WitnessService.PositionOf = positionOf

function WitnessService:IsAnchored(id: string): boolean
	local untilTime = anchors[id]
	return untilTime ~= nil and os.clock() < untilTime
end

-- Focus ------------------------------------------------------------------------

function WitnessService:Focus(player: Player): number
	return focus[player] or W.FocusMax
end

function WitnessService:SetFocus(player: Player, value: number)
	focus[player] = math.clamp(value, 0, W.FocusMax)
	player:SetAttribute(PA.Focus, math.floor(focus[player] + 0.5))
end

function WitnessService:SpendFocus(player: Player, amount: number): boolean
	local current = self:Focus(player)
	if current < amount then
		return false
	end
	self:SetFocus(player, current - amount)
	return true
end

function WitnessService:DrainFocus(player: Player, amount: number)
	self:SetFocus(player, self:Focus(player) - amount)
end

function WitnessService:ResetFocus(players: { Player })
	for _, player in players do
		self:SetFocus(player, W.FocusMax)
	end
end

function WitnessService:WitnessCost(): number
	local cost = W.Cost
	if self.Drift:Value() >= 60 then
		cost *= W.CostMultiplierWhenBreaking
	end
	return cost
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

-- True if nothing solid blocks the line from `from` to `to`. Solid seam
-- panels don't count: a Witness may be looking through a doorway that is
-- real for them (doc section 7: tolerate divergent geometry).
function WitnessService:ClearLine(from: Vector3, to: Vector3, extraIgnore: { Instance }?): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList(extraIgnore)
	params.RespectCanCollide = true
	local origin = from
	for _ = 1, 4 do
		local delta = to - origin
		if delta.Magnitude < 0.5 then
			return true
		end
		local result = Workspace:Raycast(origin, delta, params)
		if not result then
			return true
		end
		if (result.Position - to).Magnitude < 1.5 then
			return true
		end
		if result.Instance:GetAttribute(Constants.Attributes.SeamId) == nil then
			return false
		end
		origin = result.Position + delta.Unit * 0.8
	end
	return false
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

-- Witnessing ------------------------------------------------------------------

function WitnessService:Resolve(player: Player, targetId: any, position: any)
	if typeof(position) ~= "Vector3" then
		return nil
	end
	local head = self.PlayerState:Head(player)
	if not head then
		return nil
	end
	if (position - head.Position).Magnitude > W.MaxRange + 8 then
		return nil
	end
	-- Some targets (The Guest) are only visible to some players.
	local function seen(entry)
		return not entry.visibleTo or entry.visibleTo(player)
	end
	if type(targetId) == "string" and registry[targetId] and seen(registry[targetId]) then
		local entry = registry[targetId]
		if (positionOf(entry) - position).Magnitude <= (entry.radius or W.ResolveRadius) * 2 then
			return entry
		end
	end
	local best, bestDistance = nil, math.huge
	for _, entry in registry do
		if not entry.hidden and seen(entry) then
			local d = (positionOf(entry) - position).Magnitude
			if d <= (entry.radius or W.ResolveRadius) and d < bestDistance then
				best, bestDistance = entry, d
			end
		end
	end
	return best
end

function WitnessService:HandleWitness(player: Player, targetId, position)
	if not self.PlayerState:IsActive(player) then
		return
	end
	local entry = self:Resolve(player, targetId, position)
	if not entry then
		feedback(player, { type = "nothing" })
		return
	end
	local head = self.PlayerState:Head(player)
	local targetPos = positionOf(entry)
	if (targetPos - head.Position).Magnitude > W.MaxRange then
		feedback(player, { type = "tooFar", label = entry.label })
		return
	end
	if not self:ClearLine(head.Position, targetPos, entry.ignore) then
		feedback(player, { type = "blocked", label = entry.label })
		return
	end
	self:AddWitness(player, entry)
end

function WitnessService:RequiredWitnesses(entry): number
	if entry.required then
		return entry.required()
	end
	local available = #self.PlayerState:ActivePlayers()
	local companion = self.services.CompanionService
	if companion and companion:IsPresent() then
		available += 1
	end
	return math.clamp(available, 1, 2)
end

-- witness: a Player, or the string "companion".
function WitnessService:AddWitness(witness: any, entry)
	local id = entry.id
	local now = os.clock()
	local isPlayer = typeof(witness) == "Instance"
	if self:IsAnchored(id) and not entry.reanchor then
		if isPlayer then
			feedback(witness, { type = "alreadyAnchored", label = entry.label, id = id })
		end
		return
	end
	local windowSeconds = entry.windowSeconds or W.WindowSeconds
	local window = windows[id]
	if window and now - window.opened > windowSeconds then
		window = nil
	end
	local key = isPlayer and witness.UserId or "companion"
	if window and window.keys[key] then
		if isPlayer then
			feedback(witness, { type = "waiting", label = entry.label, id = id })
		end
		return
	end
	if isPlayer then
		if lastWitness[witness] and now - lastWitness[witness] < W.MinInterval then
			return
		end
		if not self:SpendFocus(witness, self:WitnessCost()) then
			feedback(witness, { type = "noFocus" })
			return
		end
		lastWitness[witness] = now
	end
	if not window then
		window = { opened = now, keys = {}, players = {}, names = {}, seconds = windowSeconds }
		windows[id] = window
	end
	window.keys[key] = true
	if isPlayer then
		table.insert(window.players, witness)
		table.insert(window.names, witness.DisplayName)
	else
		table.insert(window.names, "your companion")
	end
	self.Witnessed:Fire(witness, id, entry)

	local count = 0
	for _ in window.keys do
		count += 1
	end
	if count >= self:RequiredWitnesses(entry) then
		windows[id] = nil
		self:Anchor(id, window.names)
	else
		self.WindowOpened:Fire(id, entry, witness)
		feedback(nil, {
			type = "window",
			id = id,
			label = entry.label,
			by = window.names[#window.names],
			position = positionOf(entry),
			expires = workspace:GetServerTimeNow() + (window.seconds - (now - window.opened)),
			count = count,
			required = self:RequiredWitnesses(entry),
		})
	end
end

function WitnessService:Anchor(id: string, names: { string }?)
	local entry = registry[id]
	if not entry then
		return
	end
	local duration = entry.anchorSeconds or W.AnchorSeconds
	anchors[id] = os.clock() + duration
	Net.get("PerceptionAnchor"):FireAllClients(id, duration)
	if entry.divergent then
		self.Drift:Apply("Anchor")
	end
	feedback(nil, {
		type = "anchored",
		id = id,
		label = entry.label,
		by = names or {},
		position = positionOf(entry),
		duration = duration,
	})
	local profile = self.services.SquadProfileService
	if profile then
		profile:Record("anchors", 1)
	end
	self.Anchored:Fire(id, entry, names or {})
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

-- Tick -------------------------------------------------------------------------

function WitnessService:_tick(dt: number)
	local now = os.clock()
	-- Expire windows that nobody joined.
	for id, window in windows do
		if now - window.opened > window.seconds then
			windows[id] = nil
			local entry = registry[id]
			if entry then
				for _, player in window.players do
					self.SoloWitnessed:Fire(player, id, entry)
				end
				feedback(nil, { type = "expired", id = id, label = entry.label })
			end
		end
	end

	-- Focus regeneration: much faster near a teammate (doc section 6).
	if not self.PlayerState.inRun then
		return
	end
	local living = self.PlayerState:LivingPlayers()
	local companion = self.services.CompanionService
	local companionPos = companion and companion:GetPosition()
	for _, player in self.PlayerState:ActivePlayers() do
		local pos = self.PlayerState:Position(player)
		if pos then
			local near = false
			for _, other in living do
				if other ~= player then
					local otherPos = self.PlayerState:Position(other)
					if otherPos and (otherPos - pos).Magnitude <= W.TeammateRadius then
						near = true
						break
					end
				end
			end
			if not near and companionPos and (companionPos - pos).Magnitude <= W.CompanionRadius then
				near = true
			end
			local rate = near and W.RegenNearTeammate or W.RegenAlone
			if self.World:IsLanternRoom(self.World:RoomAt(pos)) then
				rate += W.RegenLanternBonus
			end
			local current = self:Focus(player)
			if current < W.FocusMax then
				self:SetFocus(player, current + rate * dt)
			end
		end
	end
end

return WitnessService
