-- F2 `guest reel`: The Guest performs every way he moves, near you, one
-- after another with a caption each (the animation pass, 2026-10-11: the
-- owner reviews his animations by watching this). Debug only: he's held out
-- of his own behaviour (StalkerService.debugHold) while it runs, a lamp
-- hangs over the place so he can be seen, and nothing he does here can
-- catch anyone. `guest reel stop` or `guest off` ends it, and the lamp goes.
-- `guest reel <beat>` plays one beat over and over (walk, door, peek, ...),
-- to look at it closely.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local GuestPose = require(Shared.Logic.GuestPose)
local Net = require(Shared.Net)

local G = Config.Guest
local Poses = GuestPose.Poses

local Reel = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- The nearest doorway on your floor (open, or a door that isn't locked),
-- within 40 studs.
local function doorwayNear(service, at: Vector3)
	local world = service.services.WorldService.World
	local best, bestD = nil, 40
	for id, seam in world and world.seams or {} do
		local usable = seam.connected and (not seam.door or not seam.door.locked)
		local c = seam.floorPosition
		if usable and c and math.abs(c.Y - (at.Y - 3)) < 4 then
			local d = (flat(c) - flat(at)).Magnitude
			if d < bestD then
				best, bestD = id, d
			end
		end
	end
	return best
end

function Reel.stop(service)
	local reel = service.reel
	if reel then
		reel.cancelled = true
		if reel.light then
			reel.light:Destroy()
		end
		service.reel = nil
	end
end

function Reel.run(service, player: Player, only: string?): string
	local root = service.services.PlayerStateService:Root(player)
	local body = service.bodyCtl
	if not root or not body then
		return "no character or no Guest"
	end
	Reel.stop(service)
	local reel = { cancelled = false }
	service.reel = reel
	service.debugHold = true
	service.parked = false
	service.arrived = true
	service:_setVisible("all")

	local p = root.Position
	local view = service.services.WitnessService:GetView(player)
	local look = flat(view and view.LookVector or root.CFrame.LookVector)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	local right = Vector3.new(-look.Z, 0, look.X)

	-- A lamp over the place, so he can be seen in a dark house.
	local lamp = Instance.new("Part")
	lamp.Name = "ReelLamp"
	lamp.Anchored, lamp.CanCollide, lamp.CanQuery, lamp.CanTouch = true, false, false, false
	lamp.Transparency = 1
	lamp.Size = Vector3.one * 0.2
	lamp.Position = p + look * 8 + Vector3.new(0, 5, 0)
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color = 28, 1.6, Color3.fromRGB(255, 232, 204)
	light.Shadows = true
	light.Parent = lamp
	lamp.Parent = Workspace
	reel.light = lamp

	local beats = {}
	local function beat(key: string, text: string, act)
		if not only or only == key then
			table.insert(beats, { key = key, text = text, act = act })
		end
	end
	local function wait(seconds: number)
		local untilT = os.clock() + seconds
		while os.clock() < untilT do
			if reel.cancelled or not body.root.Parent then
				error("cancelled", 0)
			end
			-- The lamp keeps over him.
			lamp.Position = body.root.Position + Vector3.new(0, 5, 0) - look * 3
			task.wait(0.1)
		end
	end
	local function walk(goal: Vector3, speed: number, timeout: number)
		body:Go(goal, speed)
		local untilT = os.clock() + timeout
		task.wait(0.2)
		while os.clock() < untilT and not body:Arrived() do
			wait(0.1)
		end
	end
	-- A place in front of you he fits (never through a wall or off the
	-- floor: closer in, until one fits).
	local function front(distance: number, side: number?)
		side = side or 0
		for _, k in { 1, 0.8, 0.6, 0.45, 0.3, 0.15 } do
			local at = p + look * (distance * (0.4 + 0.6 * k)) + right * (side * k)
			if body:Fits(at) then
				return at
			end
		end
		return p + look * 4
	end

	beat("stand", "Standing: breathing, the head tipping, a twitch now and then", function()
		body:Place(front(9), p)
		body:SetPose(Poses.Idle)
		body:SetGaze(player)
		body:FacePlayer(player)
		wait(5)
	end)
	beat("walk", "Walking across you: heavy steps, the feet planted, the hips lurching", function()
		body:Place(front(11, -13), front(11, 13))
		body:SetPose(Poses.Walk)
		body:FaceMovement()
		walk(front(11, 13), G.WalkSpeed, 6)
	end)
	beat("approach", "Walking up to you and stopping: he finishes his step", function()
		body:SetPose(Poses.Walk)
		body:FaceMovement()
		walk(front(5), G.WalkSpeed, 6)
		body:SetPose(Poses.Idle)
		body:FacePlayer(player)
		wait(2.5)
	end)
	beat("turn", "Turning on the spot: he steps round", function()
		body:FacePoint(front(20))
		wait(3)
		body:FacePlayer(player)
		wait(3)
	end)
	beat("back", "Backing away, his eyes on you", function()
		body:SetPose(Poses.BackAway)
		body:FacePlayer(player)
		body:Step(front(13), G.BackAwaySpeed)
		wait(3)
		body:Hold()
	end)
	beat("creep", "The creep", function()
		body:SetPose(Poses.Creep)
		body:FacePlayer(player)
		body:Step(front(6), 2.4)
		wait(3.5)
		body:Hold()
	end)
	beat("side", "Sideways, facing you: steps, not a glide", function()
		body:SetPose(Poses.Walk)
		body:FacePlayer(player)
		body:Step(front(7, 6), 3)
		wait(2.5)
		body:Step(front(7, -4), 3)
		wait(3)
		body:Hold()
		body:SetPose(Poses.Idle)
		wait(1)
	end)
	beat("run", "Running", function()
		body:Place(front(14, -18), front(14, 18))
		body:SetPose(Poses.Run)
		body:FaceMovement()
		walk(front(14, 18), 17, 4)
		body:SetPose(Poses.Idle)
		wait(1)
	end)
	local seamId = doorwayNear(service, p)
	local seam = seamId and service.services.WorldService.World.seams[seamId]
	if seam then
		local c = seam.floorPosition
		local n = flat(seam.normal).Unit
		-- (He only ever peeks through an open doorway.)
		local function opened()
			if seam.door and not seam.door.open then
				service.services.DoorService:SetOpen(seam.door, true)
				wait(1)
			end
		end
		beat("door", "Through a doorway: he ducks for the frame, and unfolds after", function()
			opened()
			-- From well back on one side to the other, where he fits.
			local reach = 4
			for _, d in { 7, 5.5 } do
				if body:Fits(c + n * d) and body:Fits(c - n * d) then
					reach = d
					break
				end
			end
			body:Place(c + n * reach, c)
			body:SetPose(Poses.Walk)
			body:FaceMovement()
			walk(c - n * reach, G.WalkSpeed, 6)
			wait(0.6)
			walk(c + n * reach, G.WalkSpeed, 6)
			body:SetPose(Poses.Idle)
			wait(1)
		end)
		local spots = {}
		for _, spot in service.stalk:_peekSpots() do
			if spot.seam == seamId then
				table.insert(spots, spot)
			end
		end
		-- Peek from the side you're not on.
		table.sort(spots, function(a, b)
			return (a.position - p).Magnitude > (b.position - p).Magnitude
		end)
		local spot = spots[1]
		if spot then
			beat("peek", "Peeking round the frame, his hand on it", function()
				opened()
				body:Place(spot.position, spot.position + spot.face * 10)
				body:FacePoint(spot.position + spot.face * 10)
				body:SetPose(Poses.Peek, spot.lean, service.stalk:_gripFor(spot))
				body:SetGaze(player)
				wait(6)
			end)
			beat("fingers", "Only his fingers round the frame", function()
				opened()
				body:Place(spot.position, spot.position + spot.face * 10)
				body:FacePoint(spot.position + spot.face * 10)
				body:SetGaze(player)
				body:SetPose(Poses.FingersPeek, spot.lean >= 0 and 1 or -1, service.stalk:_gripFor(spot, true))
				wait(5)
			end)
		end
	end
	beat("listen", "Listening", function()
		body:Place(front(8), p)
		body:FacePlayer(player)
		body:SetGaze(player)
		body:SetPose(Poses.Listen)
		wait(3.5)
	end)
	beat("bow", "The bow", function()
		body:SetPose(Poses.Bow)
		wait(3.5)
	end)
	beat("usher", "After you: making way", function()
		body:SetPose(Poses.Usher)
		wait(3.5)
	end)
	beat("stagger", "Hit by something thrown", function()
		body:SetPose(Poses.Idle)
		wait(1)
		body:SetPose(Poses.Stagger)
		wait(1.2)
		body:SetPose(Poses.Idle)
		wait(1.5)
	end)
	beat("duck", "The duck (seen, early in the night)", function()
		body:SetPose(Poses.Duck)
		wait(1)
		body:SetPose(Poses.Idle)
		wait(1.5)
	end)
	beat("lunge", "The lunge's wind-up (it can't catch you here)", function()
		body:SetPose(Poses.Lunge)
		wait(1.2)
		body:SetPose(Poses.Idle)
		wait(1.5)
	end)
	beat("reach", "Coming for whoever tailed him, a hand out (it can't catch you here)", function()
		body:Place(front(16), p)
		body:FacePlayer(player)
		body:SetGaze(player)
		body:SetPose(Poses.Idle)
		wait(0.8)
		body:SetPose(Poses.Reach)
		wait(1)
		body:Step(front(6), G.ReachSpeed)
		wait(2.2)
		body:Hold()
		wait(1)
		body:SetPose(Poses.Idle)
		wait(1.5)
	end)
	beat("yank", "Yanked away out of sight", function()
		body:Zoom(front(15))
		wait(1.5)
		body:SetPose(Poses.Idle)
		wait(1)
	end)
	beat("crawl", "On all fours", function()
		body:Place(front(9, -3), p)
		body:SetPose(Poses.Crawl)
		body:FaceMovement()
		body:Step(front(9, 5), 3)
		wait(4)
		body:Hold()
		body:SetPose(Poses.Idle)
		wait(1)
	end)

	local function tell(text: string)
		Net.get("Notify"):FireClient(player, text, "info")
	end
	if #beats == 0 then
		Reel.stop(service)
		return "no beat called " .. tostring(only) .. " here (try walk, door, peek, fingers, run, crawl...)"
	end
	task.spawn(function()
		local ok, err = pcall(function()
			repeat
				for i, b in beats do
					tell(string.format("[guest reel %d/%d] %s", i, #beats, b.text))
					b.act()
				end
			until not only
		end)
		if not ok and err ~= "cancelled" then
			warn("[Consensus] guest reel failed: " .. tostring(err))
		end
		if service.reel == reel then
			Reel.stop(service)
			body:Hold()
			body:SetPose(Poses.Idle)
			tell("[guest reel] done. F2 `guest reel` again, or `guest off` to let him go")
		end
	end)
	return string.format("guest reel: %d beats", #beats)
end

return Reel
