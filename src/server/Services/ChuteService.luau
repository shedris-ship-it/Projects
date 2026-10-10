-- The laundry chute (docs/plans/level-design.md section 10.5): a hatch in an
-- upstairs room standing over the laundry (`layout.chute`, found by
-- Logic/MansionGen with Logic/Dumbwaiter's spots). Climb in and you slide
-- down to the basket below, one way, players only (The Guest doesn't fit);
-- drop what you carry and it lands in the basket. It only goes while the
-- laundry can be walked to from the hall with the doors as they are
-- (LockService:Reachable), so nobody drops into a part of the house that is
-- still locked. Landing is loud.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local PropFactory = require(Shared.World.PropFactory)
local Sfx = require(Shared.Lib.Sfx)

local C = Config.Mansion.Chute
local BASKET = Vector3.new(C.Basket[1], C.Basket[2], C.Basket[3])
local PITCH = Config.Mansion.FloorPitch
local WALL = Config.Level.WallThickness

local ChuteService = {}

function ChuteService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.Locks = services.LockService
	self.Hands = services.HandsService
	self.PlayerState = services.PlayerStateService
	self.Noise = services.NoiseService
	self.chute = nil
end

function ChuteService:Start()
	self.World.Built:Connect(function(world)
		self:_build(world)
	end)
	self.World.Cleared:Connect(function()
		self.chute = nil
	end)
end

local function notify(player: Player, text: string, kind: string?)
	Net.get("Notify"):FireClient(player, text, kind or "info")
end

-- A point on the wall at layout x, z, a height up from the origin, `out`
-- studs out into the room.
local function onWall(spot, y: number, out: number): Vector3
	local o = Config.Level.Origin
	return Vector3.new(o.x + spot.x + spot.into.x * (WALL + out), o.y + y, o.z + spot.z + spot.into.z * (WALL + out))
end

function ChuteService:_build(world)
	local chute = world.layout.chute
	if not chute then
		return
	end
	local upper, ground = world.rooms[chute.upper], world.rooms[chute.ground]
	if not upper or not ground then
		return
	end
	local metal, steel = PropFactory.material("Metal"), Color3.fromRGB(150, 152, 150)
	local dark = Color3.fromRGB(26, 24, 22)
	local quiet = { collide = false, query = false, castShadow = false }
	if chute.floor then
		self:_buildTrapdoor(chute, upper, ground)
		return
	end
	local into = Vector3.new(chute.into.x, 0, chute.into.z)
	-- Its stretch of wall in both rooms is its own: no portrait or clock hung
	-- over the hatch or the mouth (the overlap scan, 2026-10-10: a portrait
	-- through the laundry's chute mouth).
	local spotAt = onWall(chute, 0, 0)
	for _, record in { upper, ground } do
		for _, slot in record.wallSlots or {} do
			local p = slot.cframe.Position
			if (Vector3.new(p.X, 0, p.Z) - Vector3.new(spotAt.X, 0, spotAt.Z)).Magnitude < C.Width / 2 + 2.2 then
				slot.used = true
			end
		end
	end

	-- Upstairs: a steel hatch in the wall at waist height, with a handle.
	local hatchAt = onWall(chute, PITCH + C.HatchHeight, 0.02)
	local hatchCF = CFrame.lookAt(hatchAt, hatchAt + into)
	local model = Instance.new("Model")
	model.Name = "LaundryChute"
	PropFactory.part(
		model,
		"Frame",
		Vector3.new(C.Width + 0.3, C.HatchSize + 0.3, 0.12),
		hatchCF,
		steel:Lerp(dark, 0.3),
		metal,
		quiet
	)
	local hatch = PropFactory.part(
		model,
		"Hatch",
		Vector3.new(C.Width, C.HatchSize, 0.08),
		hatchCF * CFrame.new(0, 0, -0.07),
		steel,
		metal,
		{ collide = false, castShadow = false }
	)
	PropFactory.part(
		model,
		"Handle",
		Vector3.new(0.9, 0.18, 0.18),
		hatchCF * CFrame.new(0, C.HatchSize / 2 - 0.35, -0.2),
		dark,
		metal,
		quiet
	)
	model.Parent = upper.model

	-- Downstairs: the chute's mouth near the ceiling, a flap, and the basket.
	local mouthAt = onWall(chute, C.MouthHeight, C.MouthDepth / 2)
	local mouthCF = CFrame.lookAt(mouthAt, mouthAt + into)
	local below = Instance.new("Model")
	below.Name = "ChuteMouth"
	PropFactory.part(
		below,
		"Mouth",
		Vector3.new(C.Width, 1.4, C.MouthDepth),
		mouthCF,
		steel:Lerp(dark, 0.15),
		metal,
		quiet
	)
	PropFactory.part(
		below,
		"Flap",
		Vector3.new(C.Width - 0.2, 1.1, 0.06),
		mouthCF * CFrame.new(0, -0.1, -C.MouthDepth / 2 - 0.04),
		steel,
		metal,
		quiet
	)
	local basketAt = onWall(chute, BASKET.Y / 2, BASKET.Z / 2 + 0.3)
	local basketCF = CFrame.lookAt(basketAt, basketAt + into)
	local wicker = Color3.fromRGB(156, 128, 86)
	-- (You walk through the basket: nothing here blocks the room.)
	PropFactory.part(below, "Basket", BASKET, basketCF, wicker, PropFactory.material("Fabric"), { collide = false })
	PropFactory.part(
		below,
		"Linen",
		Vector3.new(BASKET.X - 0.3, 0.3, BASKET.Z - 0.3),
		basketCF * CFrame.new(0, BASKET.Y / 2 + 0.1, 0),
		Color3.fromRGB(214, 210, 198),
		PropFactory.material("Fabric"),
		quiet
	)
	below.Parent = ground.model

	self:_prompt(hatch)

	self.chute = {
		upper = chute.upper,
		ground = chute.ground,
		hatch = hatch,
		hatchAt = hatchAt,
		mouthAt = mouthAt,
		basketTop = basketAt + Vector3.new(0, BASKET.Y / 2 + 0.6, 0),
		-- Where someone sliding down lands: in front of the basket.
		landing = basketAt + into * (BASKET.Z / 2 + 2) + Vector3.new(0, 3, 0),
		into = into,
		-- Where someone stands to use it (F2 `chute`).
		stand = Vector3.new(hatchAt.X, Config.Level.Origin.y + PITCH + 3, hatchAt.Z) + into * 3,
	}
end

function ChuteService:_prompt(hatch: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ChutePrompt"
	prompt.ObjectText = "Laundry chute"
	prompt.ActionText = "Climb in / drop"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = C.Hold
	prompt.MaxActivationDistance = C.Reach
	prompt.RequiresLineOfSight = false
	prompt.Parent = hatch
	prompt.Triggered:Connect(function(player)
		self:Use(player)
	end)
end

-- No wall the two rooms share: a trapdoor in the floor upstairs with a ring
-- to lift it, and below it the chute's mouth in the laundry's ceiling over
-- the basket.
function ChuteService:_buildTrapdoor(chute, upper, ground)
	local o = Config.Level.Origin
	local x, z = o.x + chute.x, o.z + chute.z
	local metal, steel = PropFactory.material("Metal"), Color3.fromRGB(150, 152, 150)
	local dark = Color3.fromRGB(26, 24, 22)
	local quiet = { collide = false, query = false, castShadow = false }
	local size = C.HatchSize + 0.4
	local top = o.y + PITCH
	local model = Instance.new("Model")
	model.Name = "LaundryChute"
	PropFactory.part(
		model,
		"Frame",
		Vector3.new(size + 0.3, 0.06, size + 0.3),
		CFrame.new(x, top + 0.02, z),
		steel:Lerp(dark, 0.3),
		metal,
		quiet
	)
	local hatch = PropFactory.part(
		model,
		"Hatch",
		Vector3.new(size, 0.06, size),
		CFrame.new(x, top + 0.05, z),
		steel,
		metal,
		{ collide = false, castShadow = false }
	)
	PropFactory.part(
		model,
		"Ring",
		Vector3.new(0.08, 0.6, 0.6),
		CFrame.new(x, top + 0.1, z + size / 2 - 0.5) * CFrame.Angles(0, 0, math.pi / 2),
		dark,
		metal,
		{ collide = false, query = false, castShadow = false, shape = Enum.PartType.Cylinder }
	)
	model.Parent = upper.model
	-- Below: the chute's mouth out of the ceiling, over the basket.
	local below = Instance.new("Model")
	below.Name = "ChuteMouth"
	local ceiling = o.y + Config.Level.WallHeight
	PropFactory.part(
		below,
		"Mouth",
		Vector3.new(size, 1.2, size),
		CFrame.new(x, ceiling - 0.6, z),
		steel:Lerp(dark, 0.15),
		metal,
		quiet
	)
	local basketAt = Vector3.new(x, o.y + BASKET.Y / 2, z)
	PropFactory.part(
		below,
		"Basket",
		BASKET,
		CFrame.new(basketAt),
		Color3.fromRGB(156, 128, 86),
		PropFactory.material("Fabric"),
		{ collide = false }
	)
	PropFactory.part(
		below,
		"Linen",
		Vector3.new(BASKET.X - 0.3, 0.3, BASKET.Z - 0.3),
		CFrame.new(basketAt + Vector3.new(0, BASKET.Y / 2 + 0.1, 0)),
		Color3.fromRGB(214, 210, 198),
		PropFactory.material("Fabric"),
		quiet
	)
	below.Parent = ground.model
	self:_prompt(hatch)
	-- Land beside the basket, towards the laundry's middle.
	local middle = ground.center
	local away = Vector3.new(middle.X - x, 0, middle.Z - z)
	away = away.Magnitude > 0.5 and away.Unit or Vector3.new(1, 0, 0)
	self.chute = {
		upper = chute.upper,
		ground = chute.ground,
		hatch = hatch,
		hatchAt = Vector3.new(x, top + 0.5, z),
		mouthAt = Vector3.new(x, ceiling - 0.6, z),
		basketTop = basketAt + Vector3.new(0, BASKET.Y / 2 + 0.6, 0),
		landing = basketAt + away * 2.5 + Vector3.new(0, 3, 0),
		into = away,
		floor = true,
		stand = Vector3.new(x, top + 3, z) + away * 3,
	}
end

-- Climb in, or drop down whatever you carry. Returns what happened (F2).
function ChuteService:Use(player: Player): string
	local chute = self.chute
	if not chute or not self.PlayerState:CanAct(player) then
		return "can't use it now"
	end
	local position = self.PlayerState:Position(player)
	if not position or (position - chute.hatchAt).Magnitude > C.Reach + 2 then
		return "too far from the hatch"
	end
	-- Only into a part of the house the squad can walk to already.
	if not self.Locks:Reachable(chute.ground) then
		Sfx.play("DoorBang", chute.hatchAt, 0.3, 1.5)
		notify(player, "Something is wedged in the chute below. It won't go.")
		return "wedged: the laundry is still locked away"
	end
	Sfx.play("DoorOpen", chute.hatchAt, 0.5, 1.3)
	local thing = self.Hands:Held(player)
	if thing then
		-- Down it goes, into the basket.
		self.Hands:Place(thing, CFrame.new(chute.basketTop))
		task.delay(C.SlideSeconds, function()
			Sfx.play("Thud", chute.mouthAt, 0.6, 1.1)
			self.Noise:Emit(chute.mouthAt, C.DropNoise, player, "chute")
		end)
		notify(player, "It rattles away down the chute.")
		return "dropped down"
	end
	-- A tool in your hands (the crowbar for a friend below: docs/plans/
	-- level-design.md section 11, L3.3) goes down the same way.
	local tools = self.services.ToolService
	if tools and tools:SendHeld(player, CFrame.new(chute.basketTop)) then
		task.delay(C.SlideSeconds, function()
			Sfx.play("Thud", chute.mouthAt, 0.7, 0.9)
			self.Noise:Emit(chute.mouthAt, C.DropNoise, player, "chute")
		end)
		notify(player, "It clatters away down the chute.")
		return "dropped a tool down"
	end
	-- Yourself: a short dark slide, and a landing everyone near hears.
	notify(player, "You slide down the chute.")
	task.delay(C.SlideSeconds, function()
		local character = player.Character
		if not character or not self.PlayerState:CanAct(player) then
			return
		end
		self.PlayerState:MarkTeleport(player)
		character:PivotTo(CFrame.lookAt(chute.landing, chute.landing + chute.into))
		Sfx.play("Thud", chute.mouthAt, 0.9, 0.85)
		self.Noise:Emit(chute.mouthAt, C.LandNoise, player, "chute")
	end)
	return "sliding down"
end

-- (For tests: where the chute is, if there is one.)
function ChuteService:Get()
	return self.chute
end

return ChuteService
