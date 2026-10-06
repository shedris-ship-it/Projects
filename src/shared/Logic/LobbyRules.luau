-- When the hub goes into the house (the owner, 2026-10-06: a majority or a
-- timer, so one friend fetching a drink doesn't hold three). Pure
-- (tests/specs/LobbyRules.spec); Services/LobbyService asks it.
--
--   LobbyRules.start(total, ready, sinceFirstReady, cfg)
--     cfg: { MinPlayers, LobbyMajoritySeconds }
--     -> "all"       everyone in the hub is ready (and enough of them)
--     -> "majority"  at least half are ready and the timer has run
--     -> nil         not yet

local LobbyRules = {}

function LobbyRules.start(total: number, ready: number, sinceFirstReady: number?, cfg): string?
	if total <= 0 or ready <= 0 or total < (cfg.MinPlayers or 1) then
		return nil
	end
	if ready >= total then
		return "all"
	end
	local needed = math.ceil(total / 2)
	local wait = cfg.LobbyMajoritySeconds or 30
	if ready >= needed and sinceFirstReady ~= nil and sinceFirstReady >= wait then
		return "majority"
	end
	return nil
end

-- How many must be ready for a majority start.
function LobbyRules.needed(total: number): number
	return math.max(1, math.ceil(total / 2))
end

return LobbyRules
