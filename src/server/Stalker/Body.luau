-- The Guest's physical body (owner, 2026-10-03: "he always takes up a
-- physical space on the map"). Once he has arrived he is never anchored,
-- parked or teleported again: he walks, creeps, backs away, and is yanked
-- out of sight, all as a real body in the house.
--
-- Facing is separate from moving. Humanoid.AutoRotate is off and a single
-- AlignOrientation turns him, so he can walk backwards while staring at you
-- ("instead of turning around and running away, slowly back up and not look
-- away"). Clients animate the joints from the attributes written here
-- (Controllers/GuestController); the server's joints never move, so what
-- Witnesses can see of him comes from Logic/GuestPose.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local GuestPose = require(Shared.Logic.GuestPose)

local G = Config.Guest
local Poses = GuestPose.Poses

local Body = {}
Body.__index = Body

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- built: StalkerModel.build's result; navigator: Stalker/Navigator.
function Body.new(built, navigator)
	local root = built.root
	local attachment = Instance.new("Attachment")
	attachment.Name = "FacingAttachment"
	attachment.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = "Facing"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.RigidityEnabled = false
	align.MaxTorque = 1e7
	align.Responsiveness = 18
	align.MaxAngularVelocity = 3
	align.Enabled = false
	align.Parent = root
	built.humanoid.AutoRotate = false
	return setmetatable({
		built = built,
		model = built.model,
		humanoid = built.humanoid,
		root = root,
		navigator = navigator,
		align = align,
		face = nil, -- { kind = "move" | "point" | "player", point, player }
		special = nil, -- an active zoom or lunge
		pose = Poses.Idle,
		lean = 0,
		gaze = nil, -- the player he's looking at
	}, Body)
end

-- Attributes -------------------------------------------------------------------

function Body:_attr(name: string, value: any)
	if self.model:GetAttribute(name) ~= value then
		self.model:SetAttribute(name, value)
	end
end

function Body:SetPose(pose: string, lean: number?)
	self.pose = pose
	self.lean = lean or 0
	self:_attr("GuestPose", pose)
	self:_attr("GuestLean", pose == Poses.Peek and self.lean or nil)
end

-- Who he's looking at: his head stays on them whatever his body does.
function Body:SetGaze(player: Player?)
	self.gaze = player
	self:_attr("GuestGaze", (player and player.Parent) and player.UserId or 0)
end

-- Where you can see him ----------------------------------------------------------

-- His head and chest in the world for the current pose, as clients draw
-- them (a peeking head is two studs out from his body).
function Body:ExposedPoints(): { Vector3 }
	local head, chest = GuestPose.exposed(self.pose, self.lean)
	local cf = self.root.CFrame
	return {
		cf:PointToWorldSpace(Vector3.new(head[1], head[2], head[3])),
		cf:PointToWorldSpace(Vector3.new(chest[1], chest[2], chest[3])),
	}
end

function Body:EyePosition(): Vector3
	return self:ExposedPoints()[1] + Vector3.new(0, 0.1, 0)
end

-- The point a Witness aims at to anchor him: his head while peeking, else
-- his chest.
function Body:WitnessPoint(): Vector3
	local points = self:ExposedPoints()
	return self.pose == Poses.Peek and points[1] or points[2]
end

-- Moving ---------------------------------------------------------------------------

function Body:_unanchor()
	local root = self.root
	if root.Anchored then
		root.Anchored = false
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	self.align.Enabled = true
end

-- Put the body somewhere outright. Only for his arrival in the house and
-- for the debug console: never in front of anyone.
function Body:Place(position: Vector3, lookAt: Vector3?)
	local base = Vector3.new(position.X, Config.Level.Origin.y + self.built.groundOffset, position.Z)
	local target = lookAt and Vector3.new(lookAt.X, base.Y, lookAt.Z) or (base + Vector3.new(0, 0, -1))
	if (target - base).Magnitude < 0.1 then
		target = base + Vector3.new(0, 0, -1)
	end
	self.special = nil
	self.navigator:Stop()
	self.root.Anchored = true
	self.model:PivotTo(CFrame.lookAt(base, target))
	self:_unanchor()
	self.align.CFrame = CFrame.lookAt(Vector3.zero, flat(target - base))
	self:Hold()
end

function Body:Park(cframe: CFrame)
	self.special = nil
	self.navigator:Stop()
	self.align.Enabled = false
	self.root.Anchored = true
	self.model:PivotTo(cframe)
end

-- Stand still (never by anchoring: that would snap him).
function Body:Hold()
	self.special = nil
	self.navigator:Stop()
	if not self.root.Anchored then
		self.humanoid:MoveTo(self.root.Position)
	end
end

-- Facing: "move" faces where he's going; a point or a player turns him to
-- face it while he moves any way he likes.
function Body:FaceMovement()
	self.face = { kind = "move" }
end

function Body:FacePoint(point: Vector3)
	self.face = { kind = "point", point = point }
end

function Body:FacePlayer(player: Player)
	self.face = { kind = "player", player = player }
end

-- Walk a route on the room graph (Navigator) at a speed. Facing is
-- whatever was last set; FaceMovement for an ordinary walk.
function Body:Go(destination: Vector3, speed: number, avoid)
	if self.special then
		return
	end
	self:_unanchor()
	self.navigator:SetDestination(destination, { speed = speed, avoid = avoid })
end

-- Step straight towards a point nearby (stealth steering within a room).
function Body:Step(point: Vector3, speed: number)
	if self.special then
		return
	end
	self:_unanchor()
	self.navigator:Stop()
	self.humanoid.WalkSpeed = speed
	self.humanoid:MoveTo(point)
end

function Body:Arrived(): boolean
	return self.navigator:Arrived()
end

-- Yanked out of sight: a short, very fast straight glide, still facing
-- you. Returns immediately; Busy() is true until it ends.
function Body:Zoom(point: Vector3)
	self:_unanchor()
	self.navigator:Stop()
	self.special = { kind = "zoom", point = point, untilT = os.clock() + 0.9 }
	self:SetPose(Poses.Zoom)
	self.humanoid.WalkSpeed = G.ZoomSpeed
	self.humanoid:MoveTo(point)
end

-- The lunge: a wind-up, then a dash at the target. onLand(player) is
-- called when the dash ends (the caller decides whether it connected);
-- returns false if it was cancelled (two Witnesses locked eyes on him).
function Body:Lunge(player: Player, onLand: (Player) -> (), windup: number?)
	self:_unanchor()
	self.navigator:Stop()
	self.humanoid:MoveTo(self.root.Position)
	self.special = { kind = "windup", player = player, at = os.clock() + (windup or G.LungeWindup), onLand = onLand }
	self:SetPose(Poses.Lunge)
	self:FacePlayer(player)
	self:SetGaze(player)
end

function Body:CancelSpecial()
	if self.special then
		self.special = nil
		self:Hold()
	end
end

function Body:Busy(): boolean
	return self.special ~= nil
end

-- Per body tick: follow the route, run zooms and lunges, turn to face.
function Body:Update(now: number, playerPosition: (Player) -> Vector3?)
	if self.root.Anchored then
		return
	end
	local special = self.special
	if special then
		if special.kind == "zoom" then
			if (flat(special.point) - flat(self.root.Position)).Magnitude < 1 or now >= special.untilT then
				self.special = nil
				self:Hold()
			end
		elseif special.kind == "windup" then
			if now >= special.at then
				local target = playerPosition(special.player)
				if not target then
					self.special = nil
					self:Hold()
				else
					local here = self.root.Position
					local direction = flat(target - here)
					local reach = math.min(direction.Magnitude + 1.5, G.LungeRadius + 2)
					local goal = here + (direction.Magnitude > 0.1 and direction.Unit or Vector3.zAxis) * reach
					self.special = {
						kind = "dash",
						player = special.player,
						point = goal,
						untilT = now + reach / G.LungeSpeed + 0.15,
						onLand = special.onLand,
					}
					self.humanoid.WalkSpeed = G.LungeSpeed
					self.humanoid:MoveTo(goal)
				end
			end
		elseif special.kind == "dash" then
			if (flat(special.point) - flat(self.root.Position)).Magnitude < 1.2 or now >= special.untilT then
				self.special = nil
				self:Hold()
				special.onLand(special.player)
			end
		end
	elseif not self.navigator:Arrived() then
		self.navigator:Step(now)
	end

	-- Turn to face.
	local face = self.face or { kind = "move" }
	local here = self.root.Position
	local direction = nil
	if face.kind == "point" then
		direction = flat(face.point - here)
	elseif face.kind == "player" then
		local pos = face.player and face.player.Parent and playerPosition(face.player)
		direction = pos and flat(pos - here) or nil
	else
		local velocity = flat(self.root.AssemblyLinearVelocity)
		if velocity.Magnitude > 0.5 then
			direction = velocity
		end
	end
	if direction and direction.Magnitude > 0.1 then
		self.align.CFrame = CFrame.lookAt(Vector3.zero, direction.Unit)
	end
	-- Turn speed by pose: slow and deliberate, snapping only to lunge.
	self.align.MaxAngularVelocity = (self.pose == Poses.Lunge or self.pose == Poses.Run) and 12
		or (self.pose == Poses.Zoom and 0.5 or 2.2)
end

-- Is a point on the floor free for his body (no furniture in the way)?
function Body:Fits(position: Vector3, ignore: { Instance }?): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { self.model }
	for _, instance in ignore or {} do
		table.insert(list, instance)
	end
	params.FilterDescendantsInstances = list
	params.RespectCanCollide = true
	local centre = Vector3.new(position.X, Config.Level.Origin.y + 4.2, position.Z)
	local parts = Workspace:GetPartBoundsInBox(CFrame.new(centre), Vector3.new(1.6, 7.6, 1.2), params)
	-- Only what would really stop him: not doors (he opens them) or people.
	local passes = {
		[Constants.CollisionGroups.Door] = true,
		[Constants.CollisionGroups.Players] = true,
		[Constants.CollisionGroups.Echo] = true,
		[Constants.CollisionGroups.Phantom] = true,
	}
	for _, part in parts do
		if part.CanCollide and not passes[part.CollisionGroup] then
			return false
		end
	end
	return true
end

return Body
