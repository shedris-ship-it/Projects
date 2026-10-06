-- The servants' bell board (docs/plans/level-design.md section 4, L3.6): a
-- row of bells on a wall of the service corridor (else the kitchen, the
-- servants' room, the pantry or the mudroom), each with a little flag and the
-- name of a room with a bell pull. When something walks into one of those
-- rooms, its bell rings and its flag drops: whoever stands at the board knows
-- where he is, and can call it out. Only him: the squad's own comings and
-- goings would drown it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Interactables = require(Shared.Data.Interactables)
local PropFactory = require(Shared.World.PropFactory)
local Rooms = require(Shared.Data.Rooms)
local RoomPurpose = require(Shared.Logic.RoomPurpose)
local Sfx = require(Shared.Lib.Sfx)

local B = Config.BellBoard

local BellBoardService = {}

function BellBoardService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.board = nil -- { room, bells = { [room id] = { flag, up, label, downUntil } }, position }
	self.lastRoom = nil
end

function BellBoardService:Start()
	self.World.Cleared:Connect(function()
		self.board = nil
		self.lastRoom = nil
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < B.CheckSeconds or not self.board then
			return
		end
		elapsed = 0
		self:_watch()
	end)
end

-- The rooms with bell pulls: the family's own (living rooms, bedrooms, the
-- dining room), up to `B.Bells`, chosen from the seed.
local function bellRooms(world, ids: { number }, boardRoom: number, rng): { number }
	local pool = {}
	for _, id in ids do
		local record = world.rooms[id]
		local family = record and record.template and record.template.family
		if id ~= boardRoom and (family == "living" or family == "bedroom" or id == world.layout.deliberation) then
			table.insert(pool, id)
		end
	end
	rng:Shuffle(pool)
	local out = {}
	for i = 1, math.min(B.Bells, #pool) do
		out[i] = pool[i]
	end
	table.sort(out)
	return out
end

function BellBoardService:Begin(rng)
	local world = self.World.World
	if not world or world.layout.mode ~= "Mansion" then
		return
	end
	local templates = Rooms.MansionById
	-- A wall spot no open door swings back over (clear of every hinge).
	local function clear(at: Vector3): boolean
		for _, door in world.doors do
			local hinge = door.hinge
			if
				hinge
				and math.abs(hinge.Y - at.Y) < 6
				and (Vector3.new(hinge.X, at.Y, hinge.Z) - at).Magnitude < B.DoorClear
			then
				return false
			end
		end
		return true
	end
	local slot, room = nil, nil
	for _, id in RoomPurpose.placedRooms(world.layout, templates, "BellBoard") do
		for _ = 1, 6 do
			local try = self.World:TakeWallSlot(id, rng)
			if not try then
				break
			end
			slot, room = slot or try, room or id
			if clear(try.cframe.Position) then
				slot, room = try, id
				break
			end
		end
		if slot and clear(slot.cframe.Position) then
			break
		end
	end
	if not slot then
		return
	end
	local ids = bellRooms(world, self.World:RoomIds(), room, rng)
	if #ids == 0 then
		return
	end
	-- The board: dark wood, two rows of three, a brass bell and a flag over
	-- each room's name (narrow enough for a picture's place on the wall).
	local cf = slot.cframe * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, -0.4, 0)
	local model = Instance.new("Model")
	model.Name = "BellBoard"
	local cols = 3
	local width = cols * 0.85 + 0.3
	local wood = PropFactory.material("Wood")
	local board = PropFactory.part(
		model,
		"Board",
		Vector3.new(width, 3, 0.15),
		cf * CFrame.new(0, 0, 0.08),
		Color3.fromRGB(70, 48, 32),
		wood,
		{
			collide = false,
		}
	)
	local bells = {}
	for i, id in ids do
		local col, row = (i - 1) % cols, (i - 1) // cols
		local x = -width / 2 + 0.15 + 0.85 * (col + 0.5)
		local y = row == 0 and 0.75 or -0.7
		local bell = PropFactory.part(
			model,
			"Bell",
			Vector3.new(0.28, 0.28, 0.28),
			cf * CFrame.new(x, y + 0.45, 0.3),
			Color3.fromRGB(190, 160, 80),
			PropFactory.material("Metal"),
			{ collide = false, shape = Enum.PartType.Ball }
		)
		local up = cf * CFrame.new(x, y + 0.08, 0.22)
		local flag = PropFactory.part(
			model,
			"Flag",
			Vector3.new(0.36, 0.26, 0.03),
			up,
			Color3.fromRGB(226, 218, 196),
			PropFactory.material("SmoothPlastic"),
			{
				collide = false,
			}
		)
		local label = PropFactory.part(
			model,
			"Label",
			Vector3.new(0.78, 0.3, 0.02),
			cf * CFrame.new(x, y - 0.32, 0.17),
			Color3.fromRGB(226, 218, 196),
			PropFactory.material("SmoothPlastic"),
			{ collide = false }
		)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.CanvasSize = Vector2.new(156, 60)
		gui.LightInfluence = 1
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.Garamond
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(40, 32, 24)
		text.Text = string.upper(world.rooms[id].name or ("Room " .. id))
		text.Parent = gui
		gui.Parent = label
		bells[id] = { bell = bell, flag = flag, up = up, downUntil = 0 }
	end
	model:SetAttribute("RunContent", true)
	model.Parent = self.World.content
	self.board = { room = room, bells = bells, position = board.Position, model = model }
end

-- Where he is: a bell rings if he's just walked into its room; flags that
-- have been down long enough go back up.
function BellBoardService:_watch()
	local now = os.clock()
	for _, entry in self.board.bells do
		if entry.down and now >= entry.downUntil then
			entry.down = false
			entry.flag.CFrame = entry.up
		end
	end
	local stalker = self.services.StalkerService
	local position = stalker and stalker:GetPosition()
	local room = position and self.World:RoomAt(position)
	if room == self.lastRoom then
		return
	end
	self.lastRoom = room
	local entry = room and self.board.bells[room]
	if entry then
		self:Ring(room)
	end
end

-- Its bell rings and its flag drops (F2 `bell <room>`).
function BellBoardService:Ring(room: number): boolean
	local entry = self.board and self.board.bells[room]
	if not entry then
		return false
	end
	entry.down = true
	entry.downUntil = os.clock() + B.DownSeconds
	-- The flag swings down to show red behind it.
	entry.flag.CFrame = entry.up * CFrame.new(0, -0.12, 0.02) * CFrame.Angles(math.rad(80), 0, 0)
	entry.flag.Color = Color3.fromRGB(170, 40, 34)
	task.delay(B.DownSeconds, function()
		if entry.flag.Parent then
			entry.flag.Color = Color3.fromRGB(226, 218, 196)
		end
	end)
	Sfx.play("ServiceBell", entry.bell.Position, 0.7, 1.15)
	return true
end

function BellBoardService:Describe(): string
	if not self.board then
		return "no bell board this run"
	end
	local ids = {}
	for id in self.board.bells do
		table.insert(ids, tostring(id))
	end
	table.sort(ids)
	return string.format("bell board in room %d; bells for rooms %s", self.board.room, table.concat(ids, " "))
end

-- (Data/Interactables BellBoard says where it goes.)
BellBoardService.Info = Interactables.BellBoard

return BellBoardService
