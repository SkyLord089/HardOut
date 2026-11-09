--!strict
--[[
	WeaponConfig.luau
	Статы оружия. Читаются из атрибутов на модели оружия, а если атрибутов нет —
	берётся пресет по названию модели (PM / AK / M4 ...) или общий дефолт.

	Атрибуты на модели (все опциональны, числа/булевы):
		RoundsPerMinute  number  -> темп стрельбы
		Damage           number  -> урон
		HeadshotMult     number  -> множитель за голову
		MagazineSize     number  -> ёмкость магазина
		ReloadTime       number  -> секунды перезарядки
		Spread           number  -> разброс в градусах (стойка)
		Recoil           number  -> сила отдачи (градусы)
		Auto             bool    -> автоматический огонь
		AmmoType         string  -> название патронов для UI
		AdsFov           number  -> FOV в прицеле
		Penetration      number  -> 0..1, запас "пробития" (задел под броню)

	Так же можно просто поменять пресеты ниже.
]]

local WeaponConfig = {}

export type Stats = {
	RoundsPerMinute: number,
	Damage: number,
	HeadshotMult: number,
	MagazineSize: number,
	ReloadTime: number,
	Spread: number,
	SpreadAim: number,
	Recoil: number,
	RecoilVisual: number,
	Auto: boolean,
	AmmoType: string,
	AdsFov: number,
	Penetration: number,
	Range: number,
}

WeaponConfig.Defaults = {
	RoundsPerMinute = 600,
	Damage = 34,
	HeadshotMult = 2.2,
	MagazineSize = 17,
	ReloadTime = 2.2,
	Spread = 1.6,
	SpreadAim = 0.25,
	Recoil = 0.55,
	RecoilVisual = 1,
	Auto = false,
	AmmoType = "9x18",
	AdsFov = 55,
	Penetration = 0.2,
	Range = 350,
} :: Stats

-- Пресеты по подстроке в имени модели (регистр не важен).
WeaponConfig.Presets = {
	{
		match = { "pm", "пистолет", "makarov", "p226" },
		stats = {
			RoundsPerMinute = 320,
			Damage = 32,
			MagazineSize = 17,
			ReloadTime = 2.0,
			Spread = 2.4,
			SpreadAim = 0.4,
			Recoil = 0.8,
			Auto = false,
			AmmoType = "9x18",
			AdsFov = 60,
			Range = 150,
		},
	},
	{
		match = { "ak", "ak74", "akm", "ака" },
		stats = {
			RoundsPerMinute = 650,
			Damage = 42,
			MagazineSize = 30,
			ReloadTime = 2.6,
			Spread = 1.8,
			SpreadAim = 0.18,
			Recoil = 1.15,
			Auto = true,
			AmmoType = "5.45x39",
			AdsFov = 45,
			Range = 400,
		},
	},
	{
		match = { "m4", "ar15", "ar-15", "hk416" },
		stats = {
			RoundsPerMinute = 800,
			Damage = 34,
			MagazineSize = 30,
			ReloadTime = 2.4,
			Spread = 1.2,
			SpreadAim = 0.12,
			Recoil = 0.85,
			Auto = true,
			AmmoType = "5.56x45",
			AdsFov = 45,
			Range = 420,
		},
	},
	{
		match = { "mp5", "smg", "пп" },
		stats = {
			RoundsPerMinute = 900,
			Damage = 24,
			MagazineSize = 30,
			ReloadTime = 2.2,
			Spread = 2.0,
			SpreadAim = 0.3,
			Recoil = 0.7,
			Auto = true,
			AmmoType = "9x19",
			AdsFov = 55,
			Range = 200,
		},
	},
	{
		match = { "mosin", "sv98", "sniper", "свд", "svd" },
		stats = {
			RoundsPerMinute = 45,
			Damage = 120,
			MagazineSize = 10,
			ReloadTime = 3.4,
			Spread = 1.0,
			SpreadAim = 0.02,
			Recoil = 3.2,
			Auto = false,
			AmmoType = "7.62x54",
			AdsFov = 18,
			Range = 700,
		},
	},
}

local function copyStats(source: { [string]: any }): Stats
	local stats: any = {}
	for key, value in WeaponConfig.Defaults :: any do
		stats[key] = value
	end
	for key, value in source do
		stats[key] = value
	end
	return stats :: Stats
end

function WeaponConfig.fromName(name: string): Stats
	local lower = string.lower(name)
	for _, preset in WeaponConfig.Presets do
		for _, key in preset.match do
			if string.find(lower, key, 1, true) then
				return copyStats(preset.stats)
			end
		end
	end
	return copyStats({})
end

--[[ Читает атрибуты с модели и накладывает их поверх пресета. ]]
function WeaponConfig.fromModel(model: Instance): Stats
	local stats: any = WeaponConfig.fromName(model.Name)
	local attributeNames = {
		"RoundsPerMinute",
		"Damage",
		"HeadshotMult",
		"MagazineSize",
		"ReloadTime",
		"Spread",
		"SpreadAim",
		"Recoil",
		"RecoilVisual",
		"Auto",
		"AmmoType",
		"AdsFov",
		"Penetration",
		"Range",
	}
	for _, key in attributeNames do
		local value = model:GetAttribute(key)
		if value ~= nil then
			stats[key] = value
		end
	end
	return stats :: Stats
end

--[[ Сколько времени между выстрелами в секундах. ]]
function WeaponConfig.secondsPerShot(stats: Stats): number
	return 60 / math.max(stats.RoundsPerMinute, 1)
end

return WeaponConfig
