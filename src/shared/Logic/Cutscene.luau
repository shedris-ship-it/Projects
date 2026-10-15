-- The three cutscenes (the visual rework V8; the plan: "a few short ones,
-- letterboxed and skippable (3-6 s each), never during danger"): the front
-- door slamming and locking behind the squad as the night begins, the lights
-- dying as he takes his seat at the dinner, and the last shot out of the
-- front door into the storm.
--
-- Pure: each is a few shots (where the camera stands and what it looks at,
-- eased from one to the next over the shot) and beats (a sound, the door
-- swinging, a jolt), worked out from where things are. Controllers/
-- CutsceneController plays them through Controllers/CinemaController, and
-- brings a camera in towards what it films if a wall stands in the way.
--
-- Points are { x, y, z }; a flat way is { x, z }.

local Cutscene = {}

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function lerp3(a, b, k: number)
	return { a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k }
end

local function flat(x: number, z: number)
	local l = math.sqrt(x * x + z * z)
	if l < 1e-6 then
		return 0, -1
	end
	return x / l, z / l
end

-- Points round a spot on the floor: `out` along a way, `side` across it
-- (to its right), `up` over the floor.
local function frame(at, wx: number, wz: number)
	local sx, sz = -wz, wx
	return function(out: number, side: number, up: number)
		return { at[1] + wx * out + sx * side, at[2] + up, at[3] + wz * out + sz * side }
	end
end

-- The night begins (RunOrchestrator, the squad in the hall): from the drive,
-- the house in the fog and the front door swinging shut on its own; inside,
-- close on the lock as it turns; then high over the door, the squad small in
-- the hall. `door` is the front door's middle, `floor` its floor, `outward`
-- the way out of the house, `knob` its inside knob (or none), `hall` the
-- hall's middle.
function Cutscene.arrival(g)
	local ox, oz = flat(g.outward[1], g.outward[2])
	local at = frame({ g.door[1], g.floor, g.door[3] }, ox, oz)
	local knob = g.knob or at(-0.35, 1.1, 3.4)
	local inside = frame({ knob[1], knob[2], knob[3] }, ox, oz)
	local hall = g.hall or at(-12, 0, 0)
	return {
		kind = "arrival",
		length = 5.4,
		axis = { ox, oz },
		shots = {
			{
				t = { 0, 1.9 },
				from = { at = at(11, 3.2, 1.5), look = at(0, 0, 3.8) },
				to = { at = at(9.6, 2.6, 1.6), look = at(0, 0, 3.6) },
				fov = 50,
			},
			{
				t = { 1.9, 3.1 },
				from = { at = inside(-2.3, -0.9, 0.35), look = inside(-0.35, 0, 0) },
				to = { at = inside(-1.9, -0.75, 0.3), look = inside(-0.35, 0, 0) },
				fov = 44,
			},
			{
				t = { 3.1, 5.4 },
				from = { at = at(-1.6, 0, 7.2), look = { hall[1], hall[2] + 2, hall[3] } },
				to = { at = at(-2.8, 0, 6.8), look = { hall[1], hall[2] + 1.6, hall[3] } },
				fov = 62,
			},
		},
		beats = {
			-- The door swings shut by itself, faster and faster, and slams.
			{ t = 0.55, door = { from = 1, to = 0, seconds = 0.9 } },
			{ t = 1.45, sound = "DoorSlam", volume = 1, pitch = 0.82, jolt = 0.09 },
			-- The lock, close: a latch and a bolt.
			{ t = 2.25, sound = "DoorLatch", volume = 0.9, pitch = 0.7, jolt = 0.03 },
			{ t = 2.4, sound = "LockClick", volume = 1, pitch = 0.6 },
		},
		-- Out of the dark at the start (the loading screen lifting), into it
		-- for a moment at the end.
		black = { { 0, 0.5, 1, 0 }, { 5.05, 5.4, 0, 1 } },
		-- (The night's title card stays over it.)
		keep = { "ConsensusOverlays" },
	}
end

-- The dinner is served (FinaleService:Serve): every light in the house goes
-- out; from the foot of the table, along it to his empty chair; then on him,
-- seated at the head, his hands on the cloth, as the final hunt is called.
-- `centre` is the table's middle on the floor, `head` his place.
function Cutscene.dinner(g)
	local ux, uz = flat(g.head[1] - g.centre[1], g.head[3] - g.centre[3])
	local reach = math.sqrt((g.head[1] - g.centre[1]) ^ 2 + (g.head[3] - g.centre[3]) ^ 2)
	local table_ = frame({ g.centre[1], g.head[2], g.centre[3] }, ux, uz)
	local head = frame(g.head, ux, uz)
	return {
		kind = "dinner",
		length = 3.3,
		axis = { ux, uz },
		shots = {
			{
				t = { 0, 1.4 },
				from = { at = table_(-(reach + 2.2), 0.6, 4.6), look = head(0, 0, 3.4) },
				to = { at = table_(-(reach + 1.5), 0.5, 4.4), look = head(0, 0, 3.6) },
				fov = 55,
			},
			{
				t = { 1.4, 3.3 },
				from = { at = head(-4.4, 2.2, 4.6), look = head(0, 0, 5.1) },
				to = { at = head(-3.5, 1.7, 4.8), look = head(0, 0, 5.3) },
				fov = 50,
			},
		},
		beats = {},
		-- His face in the candlelight: a warm light low in front of him, the
		-- table's candles' (on each client, for the shot: never light the
		-- rules count).
		key = { at = head(-1.6, 0.4, 3.9), range = 8, brightness = 1.1, from = 1.4 },
		-- (A blink as the camera comes back to you: the hunt is coming.)
		black = { { 3.15, 3.3, 0, 1 } },
	}
end

-- The last shot (RunOrchestrator, you're out): from the drive, low, on the
-- open front door; you burst out of it and run past the lens into the storm,
-- and the house stands there with its door open, lit by the lightning; the
-- dark. `door`, `floor`, `outward` as for the arrival.
function Cutscene.escape(g)
	local ox, oz = flat(g.outward[1], g.outward[2])
	local at = frame({ g.door[1], g.floor, g.door[3] }, ox, oz)
	return {
		kind = "escape",
		length = 3.6,
		axis = { ox, oz },
		shots = {
			{
				t = { 0, 3.6 },
				from = { at = at(11.5, 4.4, 1.3), look = at(1, 0, 3.2) },
				to = { at = at(12.8, 4.6, 1.1), look = at(1, 0, 3.4) },
				fov = 55,
			},
		},
		beats = {
			{ t = 0.35, sound = "ThunderNear1", volume = 0.9, pitch = 1, flash = true },
		},
		-- Where you run to: out past the lens.
		run = at(17, 1.5, 0),
		black = { { 2.8, 3.5, 0, 1 } },
	}
end

-- Where else a shot's camera may stand if a wall or a tree is in its way:
-- the same on the other side of the scene's axis, higher, both; in that
-- order. Each variant moves `from` and `to` together, so the shot keeps its
-- side. Returns { { from = at, to = at }, ... } (the shot's own first).
function Cutscene.variants(scene, shot)
	local ax, az = scene.axis and scene.axis[1] or 0, scene.axis and scene.axis[2] or 1
	local sx, sz = -az, ax
	local function mirror(at, look)
		local d = (at[1] - look[1]) * sx + (at[3] - look[3]) * sz
		return { at[1] - 2 * d * sx, at[2], at[3] - 2 * d * sz }
	end
	local function raise(at, h: number)
		return { at[1], at[2] + h, at[3] }
	end
	local f, t = shot.from, shot.to
	return {
		{ from = f.at, to = t.at },
		{ from = mirror(f.at, f.look), to = mirror(t.at, t.look) },
		{ from = raise(f.at, 1.6), to = raise(t.at, 1.6) },
		{ from = raise(mirror(f.at, f.look), 1.6), to = raise(mirror(t.at, t.look), 1.6) },
	}
end

-- The camera at `t`: where it stands, what it looks at, its field of view,
-- which shot it is (the shots ease from `from` to `to`; the cut between them
-- is hard).
function Cutscene.camera(scene, t: number)
	local shots = scene.shots
	local shot = shots[#shots]
	local index = #shots
	for i, s in shots do
		if t < s.t[2] then
			shot, index = s, i
			break
		end
	end
	local k = smooth((t - shot.t[1]) / (shot.t[2] - shot.t[1]))
	return lerp3(shot.from.at, shot.to.at, k), lerp3(shot.from.look, shot.to.look, k), shot.fov, index
end

-- How black the screen is at `t` (fades { from, to, black at from, black at to }).
function Cutscene.black(scene, t: number): number
	local most = 0
	for _, f in scene.black or {} do
		if t >= f[1] and t <= f[2] then
			local k = smooth((t - f[1]) / (f[2] - f[1]))
			most = math.max(most, f[3] + (f[4] - f[3]) * k)
		end
	end
	return most
end

return Cutscene
