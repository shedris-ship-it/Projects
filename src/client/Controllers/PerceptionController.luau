-- Applies this Witness's perception profile to their own copy of the house
-- (doc section 7: "the server sends rules, not world state"). Changes made
-- here never replicate, which is what makes divergence cheap on Roblox.
--
-- Also renders other local-only things: stalker visibility, one-off scares,
-- ritual flickers and Counterfeit key descriptions.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)

local PhantomFactory = require(script.Parent.Parent.Lib.PhantomFactory)
local PropFactory = require(Shared.World.PropFactory)

local Attr = Constants.Attributes
local FLOOR_Y = Config.Level.Origin.y

local player = Players.LocalPlayer

local PerceptionController = {}

local rules = {}
local applied = {} -- rule id -> handle
local anchors = {} -- target id -> local expiry
local objectIndex = {} -- CId -> Instance
local seamIndex = {} -- SeamId -> { panels }
local seamTrimIndex = {} -- SeamId -> { trim parts that flip with the seam }
local indexDirty = true
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
	table.clear(seamIndex)
	table.clear(seamTrimIndex)
	local level = Workspace:FindFirstChild("ConsensusLevel")
	if level then
		for _, d in level:GetDescendants() do
			local id = d:GetAttribute(Attr.CId)
			if id and not objectIndex[id] then
				objectIndex[id] = d
			end
			local seamId = d:GetAttribute(Attr.SeamId)
			if seamId then
				seamIndex[seamId] = seamIndex[seamId] or {}
				table.insert(seamIndex[seamId], d)
			end
			local trimId = d:GetAttribute(Attr.SeamTrim)
			if trimId then
				seamTrimIndex[trimId] = seamTrimIndex[trimId] or {}
				table.insert(seamTrimIndex[trimId], d)
			end
		end
	end
	indexDirty = false
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

local function findSeam(id: string)
	if indexDirty or not seamIndex[id] then
		if os.clock() - lastIndex > 1 then
			rebuildIndex()
		end
	end
	return seamIndex[id]
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

local function floorCF(params): CFrame
	local p = vec(params.position)
	local base = Vector3.new(p.X, FLOOR_Y, p.Z)
	if params.normal then
		local n = vec(params.normal)
		local flat = Vector3.new(n.X, 0, n.Z)
		if flat.Magnitude > 0.1 then
			return CFrame.lookAt(base, base + flat)
		end
	end
	if params.facing then
		return CFrame.new(base) * CFrame.Angles(0, math.rad(params.facing), 0)
	end
	return CFrame.new(base)
end

local function wallCF(params): CFrame
	local p = vec(params.position)
	local n = params.normal and vec(params.normal) or Vector3.new(0, 0, 1)
	local surface = p - n * 0.5
	return CFrame.lookAt(surface, surface + n)
end

local WALL_MODELS = { DoorShadow = true, Painting = true }

local Handlers = {}

Handlers.SeamFlip = function(rule)
	local panels = findSeam(rule.target)
	if not panels then
		return nil
	end
	local saved = {}
	local doorParts = {}
	-- Trim flips with the seam (docs/ART.md rule 3): the baseboard across it
	-- shows while it's a wall, the doorway casing while it's a doorway.
	local trim = seamTrimIndex[rule.target]
	if not trim then
		rebuildIndex()
		trim = seamTrimIndex[rule.target] or {}
	end
	local savedTrim = {}
	local seamDoor = findObject("door:" .. string.sub(rule.target, 6))
	if seamDoor then
		doorParts = partsOf(seamDoor.Parent or seamDoor)
	end
	local function set(on: boolean)
		for _, panel in panels do
			if on then
				if rule.params.connected then
					-- A real doorway shown as wall. Visual only: never collidable,
					-- so a divergence can't trap anyone.
					panel.Transparency = 0
					panel.CanQuery = true
				else
					-- A real wall shown as a doorway you can walk through.
					panel.Transparency = 1
					panel.CanCollide = false
					panel.CanQuery = false
				end
			else
				local s = saved[panel]
				panel.Transparency = s.t
				panel.CanCollide = s.c
				panel.CanQuery = s.q
			end
		end
		if rule.params.connected then
			for _, p in doorParts do
				p.LocalTransparencyModifier = on and 1 or 0
			end
		end
		for _, p in trim do
			if on then
				local showsAsWall = rule.params.connected == true
				p.Transparency = (p:GetAttribute(Attr.SeamTrimRole) == "wall") == showsAsWall and 0 or 1
			else
				p.Transparency = savedTrim[p]
			end
		end
	end
	for _, panel in panels do
		saved[panel] = { t = panel.Transparency, c = panel.CanCollide, q = panel.CanQuery }
	end
	for _, p in trim do
		savedTrim[p] = p.Transparency
	end
	set(true)
	local handle = { on = true, nextFlip = os.clock() + math.random(6, 12) }
	function handle.revert()
		set(false)
	end
	if rule.params.dynamic then
		-- The room rearranges itself behind you.
		function handle.update()
			if os.clock() < handle.nextFlip then
				return
			end
			local center = panels[1].Position
			if not inView(center, 120, 90) then
				handle.on = not handle.on
				set(handle.on)
				handle.nextFlip = os.clock() + math.random(8, 16)
			end
		end
	end
	return handle
end

Handlers.PhantomProp = function(rule)
	local params = rule.params
	local cf = WALL_MODELS[params.model] and wallCF(params) or floorCF(params)
	local model = PhantomFactory.build(params.model, cf, phantomFolder(), rule.target)
	local bobbing = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Bob") then
			table.insert(bobbing, { part = d, base = d.CFrame })
		end
	end
	local handle = {}
	function handle.revert()
		model:Destroy()
	end
	if #bobbing > 0 then
		function handle.update()
			local t = os.clock()
			for _, b in bobbing do
				b.part.CFrame = b.base * CFrame.new(math.sin(t * 1.3) * 0.15, 0, 0)
			end
		end
	end
	return handle
end

Handlers.PhantomDecor = function(rule)
	local model = PhantomFactory.build(rule.params.model, floorCF(rule.params), phantomFolder(), rule.target)
	return {
		revert = function()
			model:Destroy()
		end,
	}
end

-- Variant props: each model knows how to show a value.
local Variants = {}
local function textLabel(model: Instance, path: { string })
	local node = model
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	return node
end

Variants.Clock = function(model, value)
	local label = textLabel(model, { "Dial", "Face", "Time" })
	if label then
		local old = label.Text
		label.Text = tostring(value)
		PropFactory.setClockHands(model, value)
		return function()
			label.Text = old
			PropFactory.setClockHands(model, old)
		end
	end
end
Variants.Note = function(model, value)
	local label = textLabel(model, { "Paper", "Writing", "Text" })
	if label then
		local old = label.Text
		label.Text = tostring(value)
		return function()
			label.Text = old
		end
	end
end
Variants.Nametag = function(model, value)
	local label = textLabel(model, { "Badge", "Card", "Name" })
	if label then
		local old = label.Text
		label.Text = tostring(value)
		return function()
			label.Text = old
		end
	end
end
Variants.KeyTag = function(model, value)
	local label = textLabel(model, { "Tag", "Label", "Tag" })
	if label then
		local old = label.Text
		label.Text = tostring(value)
		return function()
			label.Text = old
		end
	end
end
Variants.TapeMark = function(model, value)
	local label = textLabel(model, { "Strip", "Pencil", "Marks" })
	if label then
		local old = label.Text
		label.Text = tostring(value)
		return function()
			label.Text = old
		end
	end
end
Variants.Fusebox = function(model, value)
	local indicator = model:FindFirstChild("Indicator")
	if indicator then
		local old = indicator.Color
		indicator.Color = value == "live" and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(60, 20, 20)
		return function()
			indicator.Color = old
		end
	end
end
Variants.Window = function(model, value)
	local bricks = model:FindFirstChild("Bricks")
	if bricks then
		-- The night sky glow draws over anything just in front of it, so it goes
		-- out while the window is bricked.
		local night = model:FindFirstChild("Night", true)
		local old, oldNight = bricks.Transparency, night and night.Enabled
		bricks.Transparency = value == "bricked" and 0 or 1
		if night then
			night.Enabled = value ~= "bricked"
		end
		return function()
			bricks.Transparency = old
			if night then
				night.Enabled = oldNight
			end
		end
	end
end
Variants.Lamp = function(model, value)
	local light = model:FindFirstChild("TellLight", true)
	if light then
		local old = light.Enabled
		light.Enabled = value == "on"
		return function()
			light.Enabled = old
		end
	end
end
Variants.ScaleChair = function(model, value, truth)
	if model:IsA("Model") and type(value) == "number" then
		model:ScaleTo(value)
		return function()
			model:ScaleTo(tonumber(truth) or 1)
		end
	end
end
Variants.Mannequin = function(model, value, truth)
	if model:IsA("Model") then
		local pivot = model:GetPivot()
		local delta = math.rad((tonumber(value) or 0) - (tonumber(truth) or 0))
		model:PivotTo(pivot * CFrame.Angles(0, delta, 0))
		return function()
			model:PivotTo(pivot)
		end
	end
end
Variants.Corkboard = function(model, value)
	local layouts = {
		{ Vector3.new(-1.2, 0.6, 0), Vector3.new(0.4, -0.5, 0), Vector3.new(1.1, 0.7, 0), Vector3.new(-0.3, -0.2, 0) },
		{ Vector3.new(1.2, -0.6, 0), Vector3.new(-0.9, 0.2, 0), Vector3.new(0.2, 0.8, 0), Vector3.new(0.8, -0.1, 0) },
		{ Vector3.new(0, 0, 0), Vector3.new(-1.3, -0.7, 0), Vector3.new(1.3, -0.7, 0), Vector3.new(0, 0.8, 0) },
	}
	local layoutPins = layouts[tonumber(value) or 1] or layouts[1]
	local board = model:FindFirstChild("Board")
	if not board then
		return nil
	end
	local saved = {}
	for i = 1, 4 do
		local pin = model:FindFirstChild("Pin" .. i)
		if pin then
			saved[pin] = pin.CFrame
			local offset = layoutPins[i]
			pin.CFrame = board.CFrame * CFrame.new(offset.X, offset.Y, -0.2)
		end
	end
	return function()
		for pin, cf in saved do
			pin.CFrame = cf
		end
	end
end

Handlers.VariantProp = function(rule)
	local model = findObject(rule.target)
	local variant = Variants[rule.params.model]
	if not model or not variant then
		return nil
	end
	local params = rule.params
	local undo = variant(model, params.value, params.truth)
	if not undo then
		return nil
	end
	local handle = { showing = params.value, nextShift = os.clock() + 6 }
	function handle.revert()
		undo()
	end
	if params.shift then
		-- Solo: the object won't hold still while you aren't looking at it.
		local pivot = model:IsA("Model") and model:GetPivot().Position or (model :: any).Position
		function handle.update()
			if os.clock() < handle.nextShift or inView(pivot, 70, 60) then
				return
			end
			handle.nextShift = os.clock() + math.random(6, 10)
			undo()
			handle.showing = handle.showing == params.value and params.truth or params.value
			undo = variant(model, handle.showing, params.truth) or function() end
		end
	end
	return handle
end

Handlers.UnobservedShift = function(rule)
	local model = findObject(rule.target)
	if not model or not model:IsA("Model") then
		return nil
	end
	local origin = model:GetPivot()
	local spots = {
		origin,
		origin * CFrame.new(3, 0, 1) * CFrame.Angles(0, math.rad(40), 0),
		origin * CFrame.new(-2, 0, 3) * CFrame.Angles(0, math.rad(-70), 0),
		origin * CFrame.new(1, 0, -3) * CFrame.Angles(0, math.rad(180), 0),
	}
	local index = 1
	local unseenFor = 0
	return {
		update = function(dt)
			local pos = model:GetPivot().Position + Vector3.new(0, 2, 0)
			if inView(pos, 100, 70) then
				unseenFor = 0
			else
				unseenFor += dt
				if unseenFor > 1.5 then
					unseenFor = -math.random(3, 8)
					index = index % #spots + 1
					model:PivotTo(spots[index])
				end
			end
		end,
		revert = function()
			model:PivotTo(origin)
		end,
	}
end

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

Handlers.HiddenTeammate = function(rule)
	local site = vec(rule.params.position)
	local hidden = {}
	local function restore()
		for _, p in hidden do
			if p.Parent then
				p.LocalTransparencyModifier = 0
			end
		end
		table.clear(hidden)
	end
	return {
		update = function()
			local character = characterOf(rule.params.subject)
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - site).Magnitude < 18 then
				if #hidden == 0 then
					for _, d in character:GetDescendants() do
						if d:IsA("BasePart") or d:IsA("Decal") then
							d.LocalTransparencyModifier = 1
							table.insert(hidden, d)
						end
					end
				end
			elseif #hidden > 0 then
				restore()
			end
		end,
		revert = restore,
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
					audio:PlayAt("Drip", site + Vector3.new(0, 6, 0), 0.25, 1.6)
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

local function anchored(target: string): boolean
	local expiry = anchors[target]
	return expiry ~= nil and os.clock() < expiry
end

local function shouldBeActive(rule, drift: number): boolean
	return drift >= (rule.minDrift or 0) and not anchored(rule.target)
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
	local drift = self.state:Drift()
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

-- Stalker visibility ---------------------------------------------------------------------

local stalkerVisible = false
local stalkerFade = nil

local function stalkerModel(): Model?
	local tagged = CollectionService:GetTagged(Constants.Tags.Stalker)
	return tagged[1]
end

local function setStalkerModifier(value: number)
	local model = stalkerModel()
	if not model then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = value
		end
	end
end

-- Ritual visuals ---------------------------------------------------------------------------

local flickerParts = {}
local itemLabels = {}

local function clearFlickers()
	for _, p in flickerParts do
		p:Destroy()
	end
	table.clear(flickerParts)
end

local function showFlickers(seamIds)
	clearFlickers()
	for _, id in seamIds do
		local panels = findSeam(id)
		if panels and panels[1] then
			local panel = panels[1]
			local glow = Instance.new("Part")
			glow.Name = "SeamFlicker"
			glow.Anchored = true
			glow.CanCollide = false
			glow.CanQuery = false
			glow.CanTouch = false
			glow.CastShadow = false
			glow.Material = Enum.Material.Neon
			glow.Color = Color3.fromRGB(190, 210, 255)
			glow.Size = Vector3.new(math.max(panel.Size.X, 0.15), panel.Size.Y, math.max(panel.Size.Z, 0.15))
			glow.CFrame = panel.CFrame
			glow.Transparency = 0.6
			glow:SetAttribute(Attr.CId, id)
			glow:SetAttribute(Attr.Label, "Flickering seam")
			glow.Parent = phantomFolder()
			table.insert(flickerParts, glow)
		end
	end
end

local function applyItemLabels()
	for id, info in itemLabels do
		local part = findObject(id)
		if part and part:IsA("BasePart") then
			local gui = part:FindFirstChild("KeyLabel")
			if not gui then
				gui = Instance.new("BillboardGui")
				gui.Name = "KeyLabel"
				gui.Size = UDim2.fromOffset(240, 40)
				gui.StudsOffset = Vector3.new(0, 1.6, 0)
				gui.MaxDistance = 26
				gui.AlwaysOnTop = false
				gui.Parent = part
				local label = Instance.new("TextLabel")
				label.Name = "Text"
				label.BackgroundTransparency = 0.4
				label.BackgroundColor3 = Color3.fromRGB(20, 18, 16)
				label.TextColor3 = Color3.fromRGB(240, 226, 190)
				label.Font = Enum.Font.SpecialElite
				label.TextScaled = true
				label.Size = UDim2.fromScale(1, 1)
				label.Parent = gui
			end
			gui.Text.Text = info.label
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
		table.clear(anchors)
		rules = profile.rules or {}
		indexDirty = true
		lastIndex = 0
	end)
	Net.get("PerceptionAnchor").OnClientEvent:Connect(function(id, duration)
		anchors[id] = os.clock() + (tonumber(duration) or 90)
		for _, rule in rules do
			if rule.target == id then
				revertRule(rule.id)
			end
		end
	end)
	Net.get("StalkerVisibility").OnClientEvent:Connect(function(visible)
		stalkerVisible = visible == true
		stalkerFade = nil
		setStalkerModifier(stalkerVisible and 0 or 1)
	end)
	Net.get("HuntState").OnClientEvent:Connect(function(payload)
		if payload.state == "dissolve" then
			stalkerFade = { started = os.clock(), duration = 1.5 }
		end
	end)
	Net.get("Scare").OnClientEvent:Connect(function(payload)
		self:_scare(payload)
	end)
	Net.get("RitualState").OnClientEvent:Connect(function(payload)
		if payload.anomaly == "PhantomArchitecture" then
			showFlickers(payload.flickers or {})
		end
	end)
	Net.get("ItemLabels").OnClientEvent:Connect(function(labels)
		itemLabels = labels or {}
		applyItemLabels()
	end)
	CollectionService:GetInstanceAddedSignal(Constants.Tags.Stalker):Connect(function()
		task.defer(function()
			setStalkerModifier(stalkerVisible and 0 or 1)
		end)
	end)
	self.state.PhaseChanged:Connect(function(phase)
		if phase == Constants.Phases.Lobby or phase == Constants.Phases.Generating then
			revertAll()
			rules = {}
			clearFlickers()
			itemLabels = {}
			local folder = Workspace:FindFirstChild("LocalPhantoms")
			if folder then
				folder:ClearAllChildren()
			end
		end
	end)

	local accumulator = 0
	local shiftClock = 0
	RunService.RenderStepped:Connect(function(dt)
		accumulator += dt
		-- Per-frame handlers (eyes, ghosts) need smooth updates; the rest are
		-- cheap to evaluate at the same rate.
		if accumulator >= 1 / 30 then
			self:_evaluate(accumulator)
			accumulator = 0
		end
		-- Stalker: keep hidden parts hidden (new parts, animations).
		if stalkerFade then
			local t = math.clamp((os.clock() - stalkerFade.started) / stalkerFade.duration, 0, 1)
			setStalkerModifier(t)
			if t >= 1 then
				stalkerFade = nil
				stalkerVisible = false
			end
		end
		-- Flicker pulse
		local pulse = 0.45 + 0.4 * math.abs(math.sin(os.clock() * 7))
		for _, p in flickerParts do
			p.Transparency = pulse
		end
		-- Solo Counterfeit: copies won't hold their description.
		shiftClock += dt
		if shiftClock > 3.5 then
			shiftClock = 0
			local changed = false
			for _, info in itemLabels do
				if info.shift then
					info.index = (info.index or 1) % #info.shift + 1
					info.label = info.shift[info.index]
					changed = true
				end
			end
			if changed then
				applyItemLabels()
			end
		end
	end)
end

function PerceptionController:_scare(payload)
	local audio = self.controllers.AudioController
	local effects = self.controllers.EffectsController
	local kind = payload.kind
	if kind == "steps" then
		audio:Steps(function()
			return payload.position
		end, 6, 0.5)
		audio:Caption("[distant footsteps]")
	elseif kind == "flicker" then
		effects:FlickerRoom(payload.roomId, payload.duration or 2)
	elseif kind == "coldSpot" then
		local cf = CFrame.new(Vector3.new(payload.position.X, FLOOR_Y, payload.position.Z))
		local model = PhantomFactory.build("BreathFog", cf, phantomFolder())
		task.delay(7, function()
			model:Destroy()
		end)
		audio:Caption("[the air goes cold]")
	elseif kind == "whisper" then
		audio:PlayAt("Groan", payload.position + Vector3.new(0, 4, 0), 0.25, 0.4)
		audio:Caption("[a whisper behind you]")
	elseif kind == "figure" then
		local root = myRoot()
		local pos = Vector3.new(payload.position.X, FLOOR_Y, payload.position.Z)
		local cf = root
				and CFrame.lookAt(pos, Vector3.new(root.Position.X, FLOOR_Y, root.Position.Z)) * CFrame.Angles(
					0,
					math.pi,
					0
				)
			or CFrame.new(pos)
		local model = PhantomFactory.build("Figure", cf, phantomFolder())
		local started = os.clock()
		local seenFor = 0
		local connection
		connection = RunService.RenderStepped:Connect(function(dt)
			if not model.Parent then
				connection:Disconnect()
				return
			end
			if inView(pos + Vector3.new(0, 4, 0), 60, 90) then
				seenFor += dt
			end
			-- Gone the moment you get a proper look at it.
			if seenFor > 0.35 or os.clock() - started > (payload.duration or 1.6) + 4 then
				model:Destroy()
				connection:Disconnect()
			end
		end)
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
