-- Server -> client sound effects. The server used to make Sound instances
-- itself (doors, the stalker), which bypassed the volume sliders, wall
-- muffling and rolloff. Now it asks clients to play a key from Assets.Sounds
-- at a position, and Controllers/AudioController does it like any other sound.

local Net = require(script.Parent.Parent.Net)

local Sfx = {}

function Sfx.play(key: string, position: Vector3, volume: number?, pitch: number?)
	Net.get("Sfx"):FireAllClients(key, position, volume or 0.6, pitch or 1)
end

return Sfx
