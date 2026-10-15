-- Which job a server does (docs/plans/lobby-rework.md, "One place, runs in
-- reserved servers"; the owner, 2026-10-15, over a second place). A public
-- server is a lobby; a reserved server, a private copy of the place that
-- only the squad sent to it can enter, is a run; a paid private server is a
-- lobby for its owner's friends. Studio is both, as before the split, since
-- teleports don't work there; a Studio test can ask for either role.

local ServerRole = {}

ServerRole.Lobby = "lobby"
ServerRole.Run = "run"
ServerRole.Both = "both"

-- info = {
--   studio: boolean,
--   enabled: boolean (Config.Places.ReservedRuns),
--   privateServerId: string (game.PrivateServerId, "" on a public server),
--   privateServerOwnerId: number (game.PrivateServerOwnerId, 0 unless paid for),
--   forced: string? (Studio only: "lobby" or "run"),
-- }
function ServerRole.of(info): string
	if info.studio then
		if info.forced == ServerRole.Lobby or info.forced == ServerRole.Run then
			return info.forced
		end
		return ServerRole.Both
	end
	if not info.enabled then
		return ServerRole.Both
	end
	if (info.privateServerId or "") ~= "" and (info.privateServerOwnerId or 0) == 0 then
		return ServerRole.Run
	end
	return ServerRole.Lobby
end

-- Whether a server of this role starts runs itself (rather than sending
-- squads off, or waiting for its own squad).
function ServerRole.startsRunsHere(role: string): boolean
	return role == ServerRole.Both
end

return ServerRole
