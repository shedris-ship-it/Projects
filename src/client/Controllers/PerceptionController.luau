-- Applies this Witness's perception profile to their own copy of the house
-- (doc section 7: "the server sends rules, not world state"). Changes made
-- here never replicate, which is what makes divergence cheap on Roblox. The
-- rules are atmosphere only (Logic/Atmosphere): a portrait's eyes, writing in
-- your torch beam, a sound from nowhere, a friend glimpsed late, a colour.
--
-- Also renders one-off scares. The Guest himself is GuestController's.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)

local PhantomFactory = require(script.Parent.Parent.Lib.PhantomFactory)

local Attr = Constants.Attributes

local player = Players.LocalPlayer

local PerceptionController = {}

-- The floor of the storey a point is on (a storey starts just below its
-- level; the old house is all ground floor).
local function floorY(y: number): number
	local o = Config.Level.Origin.y
	return o + PerceptionController.state:StoreyAt(y) * Config.Mansion.FloorPitch
end

local rules = {}
local applied = {} -- rule id -> handle
local objectIndex = {} -- CId -> Instance
local lastIndex = 0

local function vec(t): Vector3
	return Vector3.new(t.x, t.y, t.z)
end

local function camera(): Camera
	return Workspace.CurrentCamera
end

-- Is a world position on screen and roughly in the middle of the view?
local function inView(position: Vector3, coneDegrees: number?, range: number?): boolean
	local cam = camera()
	local offset = position - cam.CFrame.Position
	if offset.Magnitude > (range or 80) then
		return false
	end
	return cam.CFrame.LookVector:Dot(offset.Unit) > math.cos(math.rad((coneDegrees or 90) / 2))
end

local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Index ------------------------------------------------------------------------

local function rebuildIndex()
	table.clear(objectIndex)
	local level = Workspace:FindFirstChild("ConsensusLevel")
	if level then
		for _, d in level:GetDescendants() do
			local id = d:GetAttribute(Attr.CId)
			if id and not objectIndex[id] then
				objectIndex[id] = d
			end
		end
	end
	lastIndex = os.clock()
end

local function findObject(id: string)
	local found = objectIndex[id]
	if found and found.Parent then
		return found
	end
	if os.clock() - lastIndex > 1 then
		rebuildIndex()
	end
	return objectIndex[id]
end

local function partsOf(instance: Instance): { BasePart }
	local list = {}
	if instance:IsA("BasePart") then
		table.insert(list, instance)
	end
	for _, d in instance:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- Handlers -------------------------------------------------------------------------
-- apply(rule) -> handle with revert() and optional update(dt), or nil if the
-- target isn't available yet (it will be retried).

local function phantomFolder()
	local folder = Workspace:FindFirstChild("LocalPhantoms")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LocalPhantoms"
		folder.Parent = Workspace
	end
	return folder
end

local function wallCF(params): CFrame
	local p = vec(params.position)
	local n = params.normal and vec(params.normal) or Vector3.new(0, 0, 1)
	local surface = p - n * 0.5
	return CFrame.lookAt(surface, surface + n)
end

local Handlers = {}

Handlers.PortraitEyes = function(rule)
	local model = findObject(rule.target)
	local eyes = {}
	for _, name in { "EyeL", "EyeR" } do
		local eye = model and model:FindFirstChild(name)
		if eye then
			table.insert(eyes, { part = eye, base = eye.CFrame })
		end
	end
	if #eyes == 0 then
		return nil
	end
	return {
		update = function()
			local camPos = camera().CFrame.Position
			for _, e in eyes do
				local localDir = e.base:VectorToObjectSpace((camPos - e.base.Position).Unit)
				local offset =
					Vector3.new(math.clamp(localDir.X, -1, 1) * 0.07, math.clamp(localDir.Y, -1, 1) * 0.06, 0)
				e.part.CFrame = e.base * CFrame.new(offset)
			end
		end,
		revert = function()
			for _, e in eyes do
				e.part.CFrame = e.base
			end
		end,
	}
end

Handlers.HiddenWriting = function(rule)
	local cf = wallCF(rule.params)
	local panel = Instance.new("Part")
	panel.Name = "Writing"
	panel.Anchored = true
	panel.CanCollide = false
	panel.CanTouch = false
	panel.CanQuery = false
	panel.Transparency = 1
	panel.Size = Vector3.new(5, 3, 0.05)
	panel.CFrame = cf * CFrame.new(0, 0, -0.06)
	panel.Parent = phantomFolder()
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = panel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.SpecialElite
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(150, 20, 20)
	label.TextTransparency = 1
	label.Text = rule.params.text or ""
	label.Parent = gui
	return {
		update = function()
			local lit = player:GetAttribute(Constants.PlayerAttributes.Flashlight) == true
				and inView(panel.Position, 36, 32)
			local target = lit and 0.1 or 1
			label.TextTransparency += (target - label.TextTransparency) * 0.15
		end,
		revert = function()
			panel:Destroy()
		end,
	}
end

local function characterOf(userIdString: string)
	local other = Players:GetPlayerByUserId(tonumber(userIdString) or 0)
	return other and other.Character
end

Handlers.GhostTrail = function(rule)
	local site = vec(rule.params.position)
	local history = {}
	local ghost = nil
	local sampleClock = 0
	return {
		update = function(dt)
			local character = characterOf(rule.params.subject)
			local root = character and character:FindFirstChild("HumanoidRootPart")
			sampleClock += dt
			if root and sampleClock >= 0.1 then
				sampleClock = 0
				table.insert(history, { t = os.clock(), cf = root.CFrame })
				while #history > 0 and os.clock() - history[1].t > 3 do
					table.remove(history, 1)
				end
			end
			local near = root and (root.Position - site).Magnitude < 30
			local delayed = history[1]
			if near and delayed and os.clock() - delayed.t > 2.2 then
				local cf = CFrame.new(delayed.cf.Position - Vector3.new(0, 3, 0)) * delayed.cf.Rotation
				if not ghost then
					ghost = PhantomFactory.build("Ghost", cf, phantomFolder(), rule.target)
				else
					ghost:PivotTo(cf)
				end
			elseif ghost then
				ghost:Destroy()
				ghost = nil
			end
		end,
		revert = function()
			if ghost then
				ghost:Destroy()
			end
		end,
	}
end

Handlers.Recolor = function(rule)
	local model = findObject(rule.target)
	if not model then
		return nil
	end
	local saved = {}
	local biggest, size = nil, 0
	for _, p in partsOf(model) do
		local volume = p.Size.X * p.Size.Y * p.Size.Z
		if volume > size then
			biggest, size = p, volume
		end
	end
	if not biggest then
		return nil
	end
	local c = rule.params.color
	for _, p in partsOf(model) do
		if p.Color == biggest.Color then
			saved[p] = p.Color
			p.Color = Color3.fromRGB(c[1], c[2], c[3])
		end
	end
	return {
		revert = function()
			for p, color in saved do
				p.Color = color
			end
		end,
	}
end

Handlers.PhantomSound = function(rule)
	local audio = PerceptionController.controllers.AudioController
	local params = rule.params
	local site = vec(params.position)
	local nextPlay = os.clock() + math.random(3, 10)
	local loop = nil
	if params.sound == "Radio" then
		loop = audio:Loop("RadioStatic", site, 0.35)
	end
	return {
		update = function()
			local root = myRoot()
			if not root or os.clock() < nextPlay then
				return
			end
			local distance = (root.Position - site).Magnitude
			local sound = params.sound
			if sound == "Footsteps" and params.follow then
				local speed = root.AssemblyLinearVelocity.Magnitude
				if distance < 35 and speed > 3 then
					nextPlay = os.clock() + math.random(14, 26)
					audio:Steps(function()
						local r = myRoot()
						return r and (r.Position - r.CFrame.LookVector * 5) or site
					end, 5, 0.42)
					audio:Caption("[footsteps behind you]")
				else
					nextPlay = os.clock() + 2
				end
			elseif sound == "FootstepsOffset" then
				if distance < 28 then
					nextPlay = os.clock() + math.random(12, 22)
					audio:Steps(function()
						local r = myRoot()
						return r and (r.Position + r.CFrame.RightVector * 7) or site
					end, 6, 0.5)
					audio:Caption("[footsteps to your side]")
				else
					nextPlay = os.clock() + 2
				end
			elseif sound == "Slam" or sound == "DoorSlam" then
				if distance < 40 then
					nextPlay = os.clock() + math.random(25, 45)
					audio:PlayAt("Thud", site + Vector3.new(0, 4, 0), 1, 0.7)
					audio:Caption("[a door slams]")
				else
					nextPlay = os.clock() + 3
				end
			elseif sound == "KnockLoop" or sound == "Knock" then
				if distance < 40 then
					nextPlay = os.clock() + (sound == "KnockLoop" and 12 or math.random(25, 40))
					audio:Knock(site + Vector3.new(0, 4, 0))
					audio:Caption("[three knocks]")
				else
					nextPlay = os.clock() + 3
				end
			elseif sound == "Drip" then
				if distance < 22 then
					nextPlay = os.clock() + 1.3
					audio:PlayAt("Drip", site + Vector3.new(0, 6, 0), 0.35, 1)
				else
					nextPlay = os.clock() + 2
				end
			elseif sound == "Footsteps" then
				if distance < 40 then
					nextPlay = os.clock() + math.random(20, 35)
					audio:Steps(function()
						return site
					end, 6, 0.5)
					audio:Caption("[footsteps nearby]")
				else
					nextPlay = os.clock() + 3
				end
			else
				nextPlay = os.clock() + 10
			end
		end,
		revert = function()
			if loop then
				loop:Destroy()
			end
		end,
	}
end

-- Rule evaluation ----------------------------------------------------------------------

local function shouldBeActive(rule, drift: number): boolean
	return drift >= (rule.minDrift or 0)
end

local function revertRule(id: string)
	local handle = applied[id]
	if handle then
		applied[id] = nil
		local ok, err = pcall(handle.revert)
		if not ok then
			warn("[Consensus] revert failed: " .. tostring(err))
		end
	end
end

local function revertAll()
	for id in table.clone(applied) do
		revertRule(id)
	end
end

function PerceptionController:_evaluate(dt: number)
	-- Rules wake with Dread (Logic/Dread), so a squad that plays well meets
	-- them too, deeper in the house.
	local drift = self.state:Dread()
	for _, rule in rules do
		local active = shouldBeActive(rule, drift)
		local handle = applied[rule.id]
		if active and not handle then
			local handler = Handlers[rule.kind]
			if handler then
				local ok, result = pcall(handler, rule)
				if ok and result then
					applied[rule.id] = result
				elseif not ok then
					warn("[Consensus] " .. rule.kind .. " failed: " .. tostring(result))
				end
			end
		elseif not active and handle then
			revertRule(rule.id)
		elseif handle and handle.update then
			local ok, err = pcall(handle.update, dt)
			if not ok then
				warn("[Consensus] " .. rule.kind .. " update failed: " .. tostring(err))
				revertRule(rule.id)
			end
		end
	end
end

-- Public -------------------------------------------------------------------------------------

function PerceptionController:Init(controllers)
	self.controllers = controllers
	PerceptionController.controllers = controllers
	self.state = controllers.StateController
end

function PerceptionController:Start()
	Net.get("PerceptionProfile").OnClientEvent:Connect(function(profile)
		revertAll()
		rules = profile.rules or {}
		lastIndex = 0
	end)
	Net.get("Scare").OnClientEvent:Connect(function(payload)
		self:_scare(payload)
	end)
	self.state.PhaseChanged:Connect(function(phase)
		if phase == Constants.Phases.Lobby or phase == Constants.Phases.Generating then
			revertAll()
			rules = {}
			local folder = Workspace:FindFirstChild("LocalPhantoms")
			if folder then
				folder:ClearAllChildren()
			end
		end
	end)

	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		accumulator += dt
		-- Per-frame handlers (eyes, ghosts) need smooth updates; the rest are
		-- cheap to evaluate at the same rate.
		if accumulator >= 1 / 30 then
			self:_evaluate(accumulator)
			accumulator = 0
		end
	end)
end

function PerceptionController:_scare(payload)
	local audio = self.controllers.AudioController
	local effects = self.controllers.EffectsController
	local kind = payload.kind
	if kind == "windowFace" then
		-- His face at a window, for you alone (Lib/GuestReflection).
		self.controllers.GuestController:WindowFace(payload.glass)
	elseif kind == "steps" then
		audio:Steps(function()
			return payload.position
		end, 6, 0.5)
		audio:Caption("[distant footsteps]")
	elseif kind == "flicker" then
		effects:FlickerRoom(payload.roomId, payload.duration or 2)
	elseif kind == "coldSpot" then
		local cf = CFrame.new(Vector3.new(payload.position.X, floorY(payload.position.Y), payload.position.Z))
		local model = PhantomFactory.build("BreathFog", cf, phantomFolder())
		task.delay(7, function()
			model:Destroy()
		end)
		audio:Caption("[the air goes cold]")
	elseif kind == "whisper" then
		audio:PlayAt("Whisper", payload.position + Vector3.new(0, 4, 0), 0.5, 0.9)
		audio:Caption("[a whisper behind you]")
	elseif kind == "silence" then
		audio:Duck(payload.duration or 1.5)
	end
end

-- Expose for the Witness reticle: is this instance part of a local phantom?
function PerceptionController:LabelFor(instance: Instance): (string?, string?)
	local node = instance
	while node and node ~= Workspace do
		local id = node:GetAttribute(Attr.CId)
		if id then
			return id, node:GetAttribute(Attr.Label)
		end
		local seam = node:GetAttribute(Attr.SeamId)
		if seam then
			return seam, "Wall"
		end
		node = node.Parent
	end
	return nil, nil
end

return PerceptionController
