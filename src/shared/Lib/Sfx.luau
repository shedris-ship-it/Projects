-- Server -> client sound effects. The server used to make Sound instances
-- itself (doors, the stalker), which bypassed the volume sliders, wall
-- muffling and rolloff. Now it asks clients to play a key from Assets.Sounds
-- at a position, and Controllers/AudioController does it like any other sound.

local Players = game:GetService("Players")

local Net = require(script.Parent.Parent.Net)

local Sfx = {}

function Sfx.play(key: string, position: Vector3, volume: number?, pitch: number?)
	Net.get("Sfx"):FireAllClients(key, position, volume or 0.6, pitch or 1)
end

-- For everyone but `except`, who already heard it on their own client (a
-- piano key plays the moment it's pressed, before the server knows).
function Sfx.playExcept(except: Player?, key: string, position: Vector3, volume: number?, pitch: number?)
	local remote = Net.get("Sfx")
	for _, player in Players:GetPlayers() do
		if player ~= except then
			remote:FireClient(player, key, position, volume or 0.6, pitch or 1)
		end
	end
end

return Sfx
