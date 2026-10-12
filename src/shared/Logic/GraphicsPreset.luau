-- Graphics presets (the visual rework V0, 2026-10-12; the owner: PC-first,
-- lighter on phones). The Settings screen stores a number, since profiles keep
-- only booleans and numbers (Services/DataService): 0 Auto, 1 Cinematic,
-- 2 Balanced, 3 Performance. Auto picks one from Roblox's own graphics
-- quality, or from the device while that is on Automatic. Pure; spec'd in
-- GraphicsPreset.spec.

local GraphicsPreset = {}

GraphicsPreset.Auto = 0
GraphicsPreset.Order = { "Cinematic", "Balanced", "Performance" } -- settings 1, 2, 3

export type Device = {
	quality: number?, -- Roblox's saved graphics quality, 1-10; nil on Automatic
	touchOnly: boolean?, -- a phone or tablet: touch and no keyboard
	console: boolean?, -- a gamepad and no keyboard
}

-- The preset's name for a setting and a device. cfg is Config.Graphics.
function GraphicsPreset.resolve(setting: number?, device: Device, cfg): string
	local chosen = GraphicsPreset.Order[setting or 0]
	if chosen then
		return chosen
	end
	if device.quality then
		if device.quality >= cfg.AutoCinematicAt then
			return "Cinematic"
		elseif device.quality >= cfg.AutoBalancedAt then
			return "Balanced"
		end
		return "Performance"
	end
	if device.touchOnly then
		return "Performance"
	elseif device.console then
		return "Balanced"
	end
	return "Cinematic"
end

-- The next setting when the Settings button is pressed: Auto, then each
-- preset in turn, then Auto again.
function GraphicsPreset.nextSetting(setting: number?): number
	return ((setting or 0) + 1) % (#GraphicsPreset.Order + 1)
end

-- Film grain: 0 off, 1 fine, 2 film (with the faint exposure flicker).
GraphicsPreset.GrainNames = { [0] = "Off", [1] = "Fine", [2] = "Film" }

function GraphicsPreset.nextGrain(grain: number?): number
	return ((grain or 2) + 1) % 3
end

-- Settings saved before the presets (build .168 and earlier) had two
-- toggles: "Low-end graphics" and "Reduce grain". Carries them over once,
-- only where the new keys were never set. Returns the changes to make.
function GraphicsPreset.migrate(saved: { [string]: any }): { [string]: any }
	local changes = {}
	if saved.graphics == nil and saved.lowEnd == true then
		changes.graphics = 3
	end
	if saved.grain == nil and saved.reduceGrain == true then
		changes.grain = 0
	end
	return changes
end

return GraphicsPreset
