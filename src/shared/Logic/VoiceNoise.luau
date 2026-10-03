-- How loud the squad is, as the stalker hears it (doc section 5, "Hearing").
-- Mic loudness and typed lines go through the same radii, so typing is never
-- a quieter way to talk. Pure maths; the server turns the result into
-- NoiseService events at the speaker's real position.

local VoiceNoise = {}

-- 0 silent, 1 talking, 2 loud. prev gives hysteresis so a flickering mic
-- doesn't toggle buckets every report.
function VoiceNoise.bucket(level: number, prev: number, cfg): number
	local talk, loud = cfg.TalkLevel, cfg.LoudLevel
	local h = cfg.Hysteresis
	if level >= loud or (prev == 2 and level >= loud * h) then
		return 2
	end
	if level >= talk or (prev >= 1 and level >= talk * h) then
		return 1
	end
	return 0
end

function VoiceNoise.radius(bucket: number, cfg): number
	if bucket >= 2 then
		return cfg.LoudRadius
	elseif bucket == 1 then
		return cfg.TalkRadius
	end
	return 0
end

-- A typed line: returns the cleaned text (nil if empty), the noise radius and
-- whether it was a whisper ("/w ...").
function VoiceNoise.fromText(raw: string, cfg): (string?, number, boolean)
	local text = string.gsub(raw, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	local whisper = false
	local rest = string.match(text, "^/[wW]%s+(.*)$") or (string.match(text, "^/[wW]$") and "")
	if rest then
		whisper, text = true, rest
	end
	text = string.sub(text, 1, cfg.MaxChars)
	if #text == 0 then
		return nil, 0, whisper
	end
	local radius = math.min(cfg.TextBaseRadius + #text * cfg.TextPerChar, cfg.TextMaxRadius)
	local letters, upper = 0, 0
	for ch in string.gmatch(text, "%a") do
		letters += 1
		if ch == string.upper(ch) then
			upper += 1
		end
	end
	if letters >= 4 and upper / letters > 0.7 then
		radius *= cfg.ShoutScale
	end
	local _, bangs = string.gsub(text, "!", "")
	radius *= 1 + math.min(bangs, 3) * cfg.ExclaimScale
	if whisper then
		radius *= cfg.WhisperScale
	end
	return text, radius, whisper
end

return VoiceNoise
