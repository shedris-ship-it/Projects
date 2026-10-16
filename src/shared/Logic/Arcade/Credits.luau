-- Paying for an arcade play (LB5; docs/plans/lobby-rework.md, "Arcade"): the
-- unlimited pass needs nothing, then everyone's free play of the day
-- (midnight UTC, Logic/Progression.day), then a play bought for Robux (a
-- credit, Data/Products ArcadePlay and ArcadeTen), and last Marks, priced so
-- Robux is the better deal (Config.Arcade.PlayMarks). Services/ArcadeService
-- asks; the server alone spends.

local Credits = {}

-- Whether today's free play is still yours.
function Credits.freeToday(data, today: number): boolean
	return (data.ArcadeFreeDay or 0) ~= today
end

-- How a play is paid for without asking: "pass", "free", "credit", or nil
-- (then it's Marks or Robux, the player's choice).
function Credits.how(data, today: number, pass: boolean): string?
	if pass then
		return "pass"
	elseif Credits.freeToday(data, today) then
		return "free"
	elseif (data.ArcadeCredits or 0) > 0 then
		return "credit"
	end
	return nil
end

-- Pays for one play `how` ("pass", "free", "credit" or "marks", at `price`
-- Marks). False, and nothing spent, when it can't.
function Credits.pay(data, how: string, today: number, price: number, pass: boolean?): boolean
	if how == "pass" then
		return pass == true
	elseif how == "free" then
		if not Credits.freeToday(data, today) then
			return false
		end
		data.ArcadeFreeDay = today
		return true
	elseif how == "credit" then
		if (data.ArcadeCredits or 0) < 1 then
			return false
		end
		data.ArcadeCredits -= 1
		return true
	elseif how == "marks" then
		if (data.Marks or 0) < price then
			return false
		end
		data.Marks -= price
		return true
	end
	return false
end

return Credits
