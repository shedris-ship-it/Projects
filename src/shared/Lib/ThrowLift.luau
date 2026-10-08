-- A throw flies flatter for its first moment (the squad playtest, 2026-10-08:
-- "weak throws"; Config.Hands.FlightLift). A force against part of gravity,
-- on whichever machine flies the thing: the thrower's client for its own
-- throws (HandsController), the server for the ones it keeps
-- (HandsService). Logic/Throw.predict models the same lift, so the server's
-- first-arc check for a stun agrees with it. It comes off early when the
-- thing slows hard (it hit something), so nothing floats down a wall.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ThrowLift = {}

function ThrowLift.add(root: BasePart, cfg)
	if not cfg.FlightLift or cfg.FlightLift <= 0 or root.Anchored then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "ThrowLift"
	attachment.Parent = root
	local force = Instance.new("VectorForce")
	force.Name = "ThrowLift"
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.new(0, root.AssemblyMass * Workspace.Gravity * cfg.FlightLift, 0)
	force.Parent = root
	local launched = root.AssemblyLinearVelocity.Magnitude
	local started = os.clock()
	local connection
	local function done()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		force:Destroy()
		attachment:Destroy()
	end
	connection = RunService.Heartbeat:Connect(function()
		if
			not root.Parent
			or root.Anchored
			or os.clock() - started >= cfg.FlightLiftSeconds
			or root.AssemblyLinearVelocity.Magnitude < launched * 0.5
		then
			done()
		end
	end)
end

-- Take it off now (the server bounced it off him).
function ThrowLift.remove(root: BasePart)
	for _, child in root:GetChildren() do
		if child.Name == "ThrowLift" then
			child:Destroy()
		end
	end
end

return ThrowLift
