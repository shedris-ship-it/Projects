-- The safe room (docs/plans/level-design.md section 11.12; the owner's idea,
-- 2026-10-05): an optional objective. Behind a steel door the fuse box
-- powers (Puzzles/Breaker; the planner chose the room, Logic/LockPlanner
-- `plan.safeRoom`), a small room stocked by Logic/SafeRoom's roll: a box of
-- batteries (a fresh set for each of the squad), a lantern or a radio, the
-- plans of a floor the house's own plans don't show. Nothing the run needs:
-- going for it is the squad's gamble, time and noise at the panel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local PropFactory = require(Shared.World.PropFactory)
local SafeRoom = require(Shared.Logic.SafeRoom)
local Sfx = require(Shared.Lib.Sfx)

local SafeRoomService = {}

function SafeRoomService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.PlayerState = services.PlayerStateService
	self.Items = services.ItemService
	self.room = nil
	self.loot = nil
end

function SafeRoomService:Start()
	self.World.Cleared:Connect(function()
		self.room = nil
		self.loot = nil
	end)
end

local function notify(player: Player, text: string, kind: string?)
	Net.get("Notify"):FireClient(player, text, kind or "info")
end

-- Stock it. `squad` sizes the roll and the batteries.
function SafeRoomService:Begin(plan, rng, squad: number)
	local safe = plan.safeRoom
	if not safe then
		return
	end
	self.room = safe.room
	-- The plans it may hold: the main floor the house's own plans don't show.
	local shown = plan.housePlans and plan.housePlans.storey
	local storey = shown == 0 and 1 or 0
	local loot = SafeRoom.roll(rng:Fork("loot"), squad, Config.Progression.SafeRoom, storey)
	self.loot = loot
	local place = rng:Fork("place")
	for _, entry in loot do
		local at = self:_spot(safe.room, place, Config.Dressing.Sizes[entry.kind == "plans" and "HousePlans" or "Tool"])
		if entry.kind == "tool" then
			self.services.ToolService:PlaceTool(entry.tool, at)
		elseif entry.kind == "batteries" then
			self:_batteries(at, squad)
		elseif entry.kind == "plans" then
			self.Items:PlacePlans(safe.room, storey, place, at)
		end
	end
end

-- On a top in the room, else on the floor.
function SafeRoomService:_spot(room: number, rng, size: { number }?): CFrame
	local at = self.Items:TopSpot(room, rng, size)
	if at then
		return at
	end
	local point = self.World:ClearFloorPoint(room, rng)
	return CFrame.new(point) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
end

-- A box of torch batteries: a fresh set for each of the squad, once each.
function SafeRoomService:_batteries(at: CFrame, squad: number)
	local model = Instance.new("Model")
	model.Name = "Batteries"
	local box = PropFactory.part(
		model,
		"Box",
		Vector3.new(0.9, 0.45, 0.6),
		at * CFrame.new(0, 0.225, 0),
		Color3.fromRGB(206, 160, 40),
		PropFactory.material("SmoothPlastic"),
		{ collide = false }
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(180, 120)
	gui.LightInfluence = 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(30, 26, 20)
	label.Text = "BATTERIES\nD-CELL"
	label.Parent = gui
	gui.Parent = box
	model:SetAttribute("RunContent", true)
	model.Parent = self.World.content
	local left = math.max(1, squad)
	local took = {}
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TakePrompt"
	prompt.ActionText = "Take a set"
	prompt.ObjectText = string.format("Batteries (%d)", left)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = box
	prompt.Triggered:Connect(function(player)
		if not self.PlayerState:CanAct(player) or left <= 0 then
			return
		end
		if took[player] then
			notify(player, "You've a fresh set in already. Leave the rest for the others.")
			return
		end
		took[player] = true
		left -= 1
		self.PlayerState:RefillBattery(player)
		Sfx.play("Cloth", box.Position, 0.4, 1.4)
		notify(player, "Fresh batteries: your torch is full again.", "good")
		prompt.ObjectText = string.format("Batteries (%d)", left)
		if left <= 0 then
			prompt.Enabled = false
			prompt.ObjectText = "Batteries (empty)"
		end
	end)
end

-- For F2 `saferoom`: where it is and what's in it.
function SafeRoomService:Describe(): string
	if not self.room then
		return "no safe room this run"
	end
	local names = {}
	for _, entry in self.loot or {} do
		table.insert(names, entry.label)
	end
	return string.format("safe room in room %d: %s", self.room, table.concat(names, ", "))
end

return SafeRoomService
