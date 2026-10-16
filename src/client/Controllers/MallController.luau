-- The lobby mall's life between runs (Data/Mall; the owner's picks of
-- 2026-10-15): its sounds, and the generator's brownouts. Sounds come from
-- the emitters the mall builds (tag MallSound, attribute Role): the
-- generator idling, the fluorescents, the leak dripping into its bucket,
-- the CB radio, the arcade; each plays the candidate RunState MallSound<Role>
-- picks from Assets.Mall (F2 `mallsound`). When the server says the
-- generator browns out (RunState MallBrownout, a server time;
-- Services/MallService), everything on its power (tag MallPower: lights,
-- glowing parts, neon letters) follows Logic/Brownout's level, the same
-- for everyone, and the generator coughs. "Reduce flicker" gets one smooth
-- dip. Lightning in the hub is Controllers/WeatherController's. Looks and
-- sound only.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Brownout = require(Shared.Logic.Brownout)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)

local RS = Constants.RunState
local Tags = Constants.Tags

local MallController = {}

function MallController:Init(controllers)
	self.state = controllers.StateController
end

local function ambientGroup(): SoundGroup?
	return SoundService:FindFirstChild("ConsensusAmbient") :: SoundGroup?
end

-- The candidate a role plays now (Assets.Mall; RunState MallSound<Role>).
local function soundId(runState: Instance, role: string): string?
	local list = Assets.Mall[role]
	if not list or #list == 0 then
		return nil
	end
	local pick = runState:GetAttribute(RS.MallSound .. role)
	if type(pick) ~= "number" or not list[pick] then
		pick = 1
	end
	return list[pick]
end

function MallController:Start()
	local runState = ReplicatedStorage:WaitForChild("RunState")
	local emitters = {} -- emitter part -> its Sound
	local hum: BasePart? = nil

	local function attach(emitter: Instance)
		if not emitter:IsA("BasePart") or emitters[emitter] then
			return
		end
		local role = emitter:GetAttribute("Role")
		local look = Config.Mall.Sounds[role]
		if not look then
			return
		end
		local sound = Instance.new("Sound")
		sound.Name = "Mall" .. role
		sound.SoundId = soundId(runState, role) or ""
		sound.Volume = look.volume
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = look.near
		sound.RollOffMaxDistance = look.reach
		sound.Looped = look.every == nil
		sound.SoundGroup = ambientGroup()
		sound.Parent = emitter
		emitters[emitter] = sound
		if role == "Hum" then
			hum = emitter
		end
		if sound.Looped then
			-- Each loop from its own point, so two of a kind don't drone in step.
			sound.TimePosition = math.random() * 5 -- (cosmetic: client timing only)
			sound:Play()
		else
			task.spawn(function()
				while sound.Parent do
					task.wait(look.every[1] + (look.every[2] - look.every[1]) * math.random())
					if sound.Parent then
						sound.PlaybackSpeed = 0.9 + 0.2 * math.random()
						sound:Play()
					end
				end
			end)
		end
		emitter.Destroying:Connect(function()
			emitters[emitter] = nil
		end)
	end
	for _, emitter in CollectionService:GetTagged(Tags.MallSound) do
		attach(emitter)
	end
	CollectionService:GetInstanceAddedSignal(Tags.MallSound):Connect(function(emitter)
		task.defer(attach, emitter)
	end)

	-- F2 `mallsound <role> <n>`: the role's sounds switch candidate at once.
	runState.AttributeChanged:Connect(function(name)
		if name:sub(1, #RS.MallSound) ~= RS.MallSound then
			return
		end
		local role = name:sub(#RS.MallSound + 1)
		for emitter, sound in emitters do
			if emitter:GetAttribute("Role") == role then
				sound.SoundId = soundId(runState, role) or ""
				if sound.Looped then
					sound:Play()
				end
			end
		end
	end)

	-- The brownout: everything on the generator's power, at its base.
	local base = {} -- instance -> what full power looks like
	local function remember(thing: Instance)
		if base[thing] ~= nil then
			return
		end
		if thing:IsA("Light") or thing:IsA("SurfaceGui") then -- an ad lightbox's unlit face too
			base[thing] = thing.Brightness
		elseif thing:IsA("BasePart") then
			base[thing] = thing.Color
		elseif thing:IsA("TextLabel") then
			base[thing] = thing.TextTransparency
		end
	end
	local function apply(level: number)
		for _, thing in CollectionService:GetTagged(Tags.MallPower) do
			remember(thing)
			local full = base[thing]
			if thing:IsA("Light") then
				thing.Brightness = full * level
			elseif thing:IsA("BasePart") then
				thing.Color = full:Lerp(Color3.new(0, 0, 0), (1 - level) * 0.85)
			elseif thing:IsA("TextLabel") then
				thing.TextTransparency = full + (1 - full) * (1 - level) * 0.85
			elseif thing:IsA("SurfaceGui") then
				thing.Brightness = full * (1 - (1 - level) * 0.85) -- an ad lightbox's unlit face
			end
		end
	end

	local running = false
	local function brownout(at: number)
		if running then
			return
		end
		local cfg = Config.Mall.Brownout
		local into = Workspace:GetServerTimeNow() - at
		if into < 0 or into > cfg.Seconds then
			return -- an old one (a late join), or not yet
		end
		running = true
		local gentle = self.state and self.state.settings and self.state.settings.reduceFlicker == true
		local seed = math.floor(at * 10) % 100000
		-- The cough, from the generator.
		local sound = hum and emitters[hum]
		local id = soundId(runState, "Sputter")
		if hum and id then
			local look = Config.Mall.Sounds.Sputter
			local cough = Instance.new("Sound")
			cough.Name = "MallSputter"
			cough.SoundId = id
			cough.Volume = look.volume
			cough.RollOffMode = Enum.RollOffMode.InverseTapered
			cough.RollOffMinDistance = look.near
			cough.RollOffMaxDistance = look.reach
			cough.SoundGroup = ambientGroup()
			cough.Parent = hum
			cough:Play()
			task.delay(cfg.Seconds + 1, function()
				cough:Destroy()
			end)
		end
		local humVolume = sound and sound.Volume
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local t = Workspace:GetServerTimeNow() - at
			local level = Brownout.level(t, cfg.Seconds, seed, cfg, gentle)
			apply(level)
			if sound and humVolume then
				-- The hum labours with it.
				sound.Volume = humVolume * (0.4 + 0.6 * level)
				sound.PlaybackSpeed = 0.85 + 0.15 * level
			end
			if t >= cfg.Seconds then
				connection:Disconnect()
				apply(1)
				if sound and humVolume then
					sound.Volume = humVolume
					sound.PlaybackSpeed = 1
				end
				running = false
			end
		end)
	end
	runState:GetAttributeChangedSignal(RS.MallBrownout):Connect(function()
		local at = runState:GetAttribute(RS.MallBrownout)
		if type(at) == "number" then
			brownout(at)
		end
	end)
end

return MallController
