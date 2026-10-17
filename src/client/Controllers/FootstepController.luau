-- Footsteps for everyone (owner, 2026-10-03): yours and your teammates', from
-- their real feet, replacing Roblox's default character sounds (see
-- client_overrides/RbxCharacterSounds). A body seen from outside (yours in the
-- lobby's third person, everyone else's always) steps when a foot touches
-- down, so you hear the feet you watch land (2026-10-16: paced by distance,
-- they drifted against the walk and sounded like someone following you). Your
-- own steps in first person are paced by distance, in time with the camera's
-- bob, so a slow walk is slow and a sprint is a rush. Each floor has its own sample set,
-- played from a shuffled bag so nothing repeats back to back, with pitch and
-- volume varied every step. Rooms colour them through the global reverb and
-- walls muffle other people's (the room's own reverb comes from the global
-- preset in AudioController, never from the steps). All client-side: the server's noise for the
-- stalker still comes from velocity (PlayerStateService), not from these.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Feel = require(Shared.Logic.Feel)
local Footsteps = require(Shared.Data.Footsteps)
local Rng = require(Shared.Lib.Rng)

local P, F = Config.Player, Config.Feel
local localPlayer = Players.LocalPlayer

local FootstepController = {}

local tracks = {} -- player -> { dist, foot, bags }
local rng = Rng.new(os.time())

-- Samples that never loaded are left out for good (a community asset can be
-- taken down or never approved for the place), so the floor doesn't go silent;
-- a surface with none left plays the stock step that ships with the client.
local badIds: { [string]: boolean } = {}
local badVersion = 0
local goodCache: { [string]: { version: number, ids: { string } } } = {}
local SURFACES = { "Wood", "Carpet", "Tile", "Concrete" }

function FootstepController:Init(controllers)
	self.controllers = controllers
	self.state = controllers.StateController
end

-- Your own body in first person: its steps keep the stride, in time with the
-- camera's bob, at full volume. Every other body is seen from outside.
local function ownFirstPerson(player: Player): boolean
	return player == localPlayer and localPlayer.CameraMode == Enum.CameraMode.LockFirstPerson
end

local function trackFor(player: Player)
	local track = tracks[player]
	if not track then
		-- (feet: each foot's memory for Feel.footDown; movingFor: seconds on
		-- the move; lastLift: when a foot was last up.)
		track = { dist = 0, foot = 1, bags = {}, feet = { {}, {} }, movingFor = 0, lastLift = -math.huge }
		tracks[player] = track
	end
	return track
end

-- The ids worth playing for a surface (never empty).
local function goodIds(surface: string): { string }
	local cached = goodCache[surface]
	if cached and cached.version == badVersion then
		return cached.ids
	end
	local ids = {}
	for _, id in Assets.Footsteps[surface] or {} do
		if not badIds[id] then
			table.insert(ids, id)
		end
	end
	if #ids == 0 then
		ids[1] = Assets.StockFootstep
	end
	goodCache[surface] = { version = badVersion, ids = ids }
	return ids
end

-- A sample that never loads is dead. Slow is not dead: a cold cache on a bad
-- connection can take many seconds, so this only drops one when Roblox itself
-- reports the fetch failed or timed out, or when it is still not there 20 s
-- after it was first asked for.
local watching: { [string]: boolean } = {}
local function judge(sound: Sound?, id: string)
	if not sound or id == Assets.StockFootstep or watching[id] then
		return
	end
	watching[id] = true
	task.spawn(function()
		local waited = 0
		while waited < 20 do
			task.wait(2.5)
			waited += 2.5
			if sound.IsLoaded or badIds[id] then
				watching[id] = nil
				return
			end
			if not sound.Parent then
				-- This step's sound is gone (it was cleaned up); ask again next time.
				watching[id] = nil
				return
			end
			local ok, status = pcall(function()
				return ContentProvider:GetAssetFetchStatus(id)
			end)
			if ok and (status == Enum.AssetFetchStatus.Failure or status == Enum.AssetFetchStatus.TimedOut) then
				break
			end
		end
		watching[id] = nil
		if not sound.IsLoaded and not badIds[id] then
			badIds[id] = true
			badVersion += 1
			warn("[Consensus] footstep sample never loaded, dropping it: " .. id)
		end
	end)
end

-- Is there a wall between the camera and this point? The target is lifted off
-- the floor: a ray that ends exactly on the floor hits the floor itself, which
-- made every teammate's step sound muffled.
local function blocked(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local lifted = to + Vector3.new(0, 2, 0)
	return Workspace:Raycast(from, lifted - from, params) ~= nil
end

-- Where this character's foot is on the floor (alternating left and right).
local function footPosition(humanoid: Humanoid, root: BasePart, side: number): Vector3
	local down = Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	return root.Position - down + root.CFrame.RightVector * (side == 1 and -0.35 or 0.35)
end

function FootstepController:_surface(humanoid: Humanoid): string
	return Footsteps.Materials[humanoid.FloorMaterial.Name] or Footsteps.Default
end

-- Which foot of a body seen from outside touched down this frame (1 left,
-- 2 right) and where its sole is, or nil (Logic/Feel footDown). Keeps when a
-- foot last lifted, so a body with no walk playing falls back to the stride.
local FEET = { "LeftFoot", "RightFoot" }
local CORNERS = {}
for _, x in { -0.5, 0.5 } do
	for _, y in { -0.5, 0.5 } do
		for _, z in { -0.5, 0.5 } do
			table.insert(CORNERS, Vector3.new(x, y, z))
		end
	end
end

-- The lowest point of a foot's box, as it rolls heel to toe.
local function lowestPoint(foot: BasePart): Vector3
	local best = nil
	for _, corner in CORNERS do
		local at = foot.CFrame:PointToWorldSpace(corner * foot.Size)
		if not best or at.Y < best.Y then
			best = at
		end
	end
	return best
end

function FootstepController:_feet(
	track,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	dt: number,
	now: number
): (number?, Vector3?)
	local side, sole = nil, nil
	-- (The floor the body stands on: Roblox holds the root HipHeight above it.)
	local floor = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	for i, name in FEET do
		local foot = character:FindFirstChild(name)
		if foot and foot:IsA("BasePart") then
			local memory = track.feet[i]
			local low = lowestPoint(foot)
			if Feel.footDown(memory, low.Y - floor, foot.Position.Y - floor, dt, F) and not side then
				side, sole = i, low
			end
			if memory.up then
				track.lastLift = now
			end
		end
	end
	return side, sole
end

-- One step from `character`: on `side`'s foot where it landed (`position`),
-- or the next foot of the stride where it would be. `local` steps are never
-- muffled; teammates' are when a wall is in the way.
function FootstepController:_step(
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	speed: number,
	side: number?,
	position: Vector3?
)
	local track = trackFor(player)
	local audio = self.controllers.AudioController
	local surface = self:_surface(humanoid)
	local set = Footsteps.Surfaces[surface] or Footsteps.Surfaces[Footsteps.Default]
	local ids = goodIds(surface)
	local entry = track.bags[surface]
	if not entry or entry.version ~= badVersion then
		entry = { version = badVersion, bag = Feel.newBag(#ids) }
		track.bags[surface] = entry
	end
	local key = ids[Feel.draw(entry.bag, rng)]
	track.foot = side or 3 - track.foot
	local volume = Feel.stepVolume(speed, P, F) * set.volume * Feel.jitter(rng, F.FootstepVolumeSpread)
	if not ownFirstPerson(player) then
		-- Seen from outside: softer (Config.Feel FootstepVolumeSeen; F2 `stepvolume`).
		local share = self.state:Run(Constants.RunState.StepVolume)
		volume *= type(share) == "number" and share or F.FootstepVolumeSeen
	end
	local pitch = set.pitch * Feel.jitter(rng, F.FootstepPitchSpread) * (track.foot == 1 and 1 or 0.97)
	position = position or footPosition(humanoid, root, track.foot)
	local muffled = false
	local camera = Workspace.CurrentCamera
	if player ~= localPlayer and camera then
		muffled = blocked(camera.CFrame.Position, position, { character, localPlayer.Character or character })
	end
	-- On the foot that made it, moving with it (left where it landed, a
	-- sprint's steps trailed behind you like someone running after you).
	local offset = root.CFrame:PointToObjectSpace(position)
	judge(audio:PlayOn(key, root, offset, volume, pitch, muffled, F.FootstepRollOffMin), key)
	-- Running adds a low thump under each footfall, for weight.
	if speed > P.SprintSpeedThreshold then
		audio:PlayOn("Thud", root, offset, 0.25 * volume, 0.55 * Feel.jitter(rng, 0.05), muffled, F.FootstepRollOffMin)
	end
end

-- A heavy landing for the local player (called by FeelController).
function FootstepController:Land(fallSpeed: number)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) or fallSpeed < F.LandMinSpeed * 0.5 then
		return
	end
	local audio = self.controllers.AudioController
	local strength = math.clamp(fallSpeed / F.LandMaxSpeed, 0.2, 1)
	local offset = root.CFrame:PointToObjectSpace(footPosition(humanoid, root, 1))
	local ids = goodIds(self:_surface(humanoid))
	audio:PlayOn(ids[rng:NextInteger(1, #ids)], root, offset, 0.6 + 0.4 * strength, 0.75, false)
	audio:PlayOn("Thud", root, offset, 0.3 + 0.6 * strength, 0.6, false)
end

-- F2 console, "steps": plays every sample once and reports whether it loaded,
-- how long it is and how loud it came out, so a silent floor can be traced to
-- one dead asset. Lines go to the Output window; `report` gets a summary.
function FootstepController:Diagnose(report: (string) -> ())
	task.spawn(function()
		local list = {}
		for _, surface in SURFACES do
			for i, id in Assets.Footsteps[surface] or {} do
				table.insert(list, { label = surface .. " #" .. i, id = id })
			end
		end
		table.insert(list, { label = "Stock fallback", id = Assets.StockFootstep })
		local dead = 0
		for _, entry in list do
			local sound = Instance.new("Sound")
			sound.SoundId = entry.id
			sound.Volume = 1
			sound.Parent = SoundService
			local waited = os.clock()
			while not sound.IsLoaded and os.clock() - waited < 5 do
				task.wait()
			end
			local peak = 0
			if sound.IsLoaded then
				sound:Play()
				local started = os.clock()
				while os.clock() - started < math.min(sound.TimeLength, 1.2) do
					peak = math.max(peak, sound.PlaybackLoudness)
					task.wait()
				end
			else
				dead += 1
			end
			print(
				string.format(
					"[steps] %-14s %s loaded=%s length=%.2fs loudness=%.0f%s",
					entry.label,
					entry.id,
					tostring(sound.IsLoaded),
					sound.TimeLength,
					peak,
					badIds[entry.id] and " (dropped)" or ""
				)
			)
			sound:Destroy()
			task.wait(0.15)
		end
		report(string.format("steps: %d of %d samples failed to load (details in Output)", dead, #list))
	end)
end

function FootstepController:Start()
	-- Warm every sample so the first steps in a room aren't silent while they load.
	-- Through Sounds, never bare id strings: PreloadAsync fetches a string as an
	-- image, so every audio id failed ("Asset type does not match requested
	-- type", 2026-10-16) and was marked Failure, which `judge` reads as dead.
	task.spawn(function()
		local all = { Assets.StockFootstep }
		for _, surface in SURFACES do
			for _, id in Assets.Footsteps[surface] or {} do
				table.insert(all, id)
			end
		end
		local sounds = {}
		for _, id in all do
			local sound = Instance.new("Sound")
			sound.SoundId = id
			table.insert(sounds, sound)
		end
		pcall(function()
			ContentProvider:PreloadAsync(sounds)
		end)
		for _, sound in sounds do
			sound:Destroy()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		tracks[player] = nil
	end)
	local function play(player, character, humanoid, root, speed, side, position)
		local ok, err = pcall(self._step, self, player, character, humanoid, root, speed, side, position)
		if not ok then
			warn("[Consensus] footstep failed: " .. tostring(err))
		end
	end
	RunService.Heartbeat:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if humanoid and root and humanoid.Health > 0 then
				local track = trackFor(player)
				local velocity = root.AssemblyLinearVelocity
				local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
				-- (Read every frame, so each foot's lowest is known before it moves.)
				local side, sole = self:_feet(track, character, humanoid, root, dt, now)
				-- Only worth playing if it can be heard.
				local heard = (root.Position - camera.CFrame.Position).Magnitude <= F.FootstepRange
				if grounded and speed >= F.FootstepMinSpeed and not root.Anchored then
					track.movingFor += dt
					if Feel.stepsFromFeet(ownFirstPerson(player), track.movingFor, now - track.lastLift, F) then
						-- What you see land is what you hear (Config.Feel FootLift).
						if side and heard then
							play(player, character, humanoid, root, speed, side, sole)
						end
						track.dist = Feel.stride(P.WalkSpeed, P, F) * 0.6
					else
						local stride = Feel.stride(speed, P, F)
						track.dist += speed * dt
						if track.dist >= stride then
							track.dist -= stride
							if heard then
								play(player, character, humanoid, root, speed)
							end
						end
					end
				else
					track.movingFor = 0
					-- A foot settling after you stop isn't a step.
					track.feet[1].up = false
					track.feet[2].up = false
					-- Prime it so the first step comes soon after setting off.
					track.dist = Feel.stride(P.WalkSpeed, P, F) * 0.6
				end
			end
		end
	end)
end

return FootstepController
