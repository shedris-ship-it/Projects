-- Your hands (docs/plans/gameplay-rework.md section 4): what a player's bare
-- hands may take hold of, checked here on the server. Today that's doors,
-- dragged Amnesia-style (Controllers/HandsController streams where the hand
-- wants the door; DoorService turns it). Drawers, carried things, throws and
-- pushing heavy furniture join this service in the next steps.
--
-- Every message is checked: the player can act, the door is within reach of
-- their head and nothing solid stands between them. A client can only ask for
-- an angle; the door moves at its own rate and stops against The Guest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local H = Config.Hands

local HandsService = {}

function HandsService:Init(services)
	self.World = services.WorldService
	self.Doors = services.DoorService
	self.PlayerState = services.PlayerStateService
	self.Witness = services.WitnessService
end

function HandsService:Start()
	Net.onServer("Drag", {
		interval = 1 / (H.DragSendHz + 10),
		burst = H.DragSendHz + 15,
		types = { "string", "number" },
	}, function(player, id, value)
		self:_drag(player, id, value)
	end)
end

-- A door within reach of the player's head, with a clear line to it.
function HandsService:_canReach(player: Player, part: BasePart, ignore: Instance): boolean
	local head = self.PlayerState:Head(player)
	if not head then
		return false
	end
	if (head.Position - part.Position).Magnitude > H.DragReach then
		return false
	end
	return self.Witness:ClearLine(head.Position, part.Position, { ignore })
end

function HandsService:_drag(player: Player, id: string, value: number)
	local world = self.World.World
	if not world or not self.PlayerState:CanAct(player) then
		return
	end
	local door = world.doors[id]
	if not door or not door.slab.Parent then
		return
	end
	if not self:_canReach(player, door.slab, door.model) then
		return
	end
	self.Doors:Drag(door, value, player)
end

return HandsService
