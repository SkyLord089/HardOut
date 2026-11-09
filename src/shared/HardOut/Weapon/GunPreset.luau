--!strict
--[[
	GunPreset.luau
	Как выглядит "правильная" модель оружия для этого стенда + хелперы,
	чтобы быстро проверить твою модель и починить её, если что-то не так.

	СОГЛАШЕНИЕ ПО МОДЕЛИ (все пункты опциональны, кроме Attachments):
	  Model / Tool
	    └─ Attachments (Model или Folder)      -- обязательная папка с точками крепления
	         ├─ Grip        (Attachment)       -- куда приходит правая рука
	         ├─ Support     (Attachment)       -- куда приходит левая рука (опционально)
	         ├─ Muzzle      (Attachment)       -- срез ствола (опционально, но нужен для выстрела)
	         └─ Sight       (Attachment)       -- центр прицела для ADS (опционально)
	    └─ ... любые MeshPart'ы твоей модели ...

	Конвенция осей (важно!):
	  - Модель привязывается к руке через Grip.
	  - Смотрит стволом в -Z (вперёд), "вверх" оружия = +Y.
	  - Т.е. если голова оружия смотрит не туда — меняй CFrame самого Grip,
	    а не крути всю модель.
]]

local GunPreset = {}

GunPreset.AttachmentNames = {
	Grip = "Grip",
	Support = "Support",
	Muzzle = "Muzzle",
	Sight = "Sight",
}

-- Стандартные размеры модели оружия для авто-масштабирования.
GunPreset.ReferenceSize = Vector3.new(0.9, 1.9, 3.2) -- X,Y,Z; Z = длина ствола

function GunPreset.findAttachmentsFolder(model: Instance): Instance?
	for _, descendant in model:GetDescendants() do
		if descendant.Name == "Attachments" and (descendant:IsA("Model") or descendant:IsA("Folder")) then
			return descendant
		end
	end
	return nil
end

function GunPreset.getAttachment(model: Instance, name: string): Attachment?
	local folder = GunPreset.findAttachmentsFolder(model)
	local candidates: Instance? = folder
	if not candidates then
		candidates = model
	end
	local found = (candidates :: Instance):FindFirstChild(name, true)
	if found and found:IsA("Attachment") then
		return found
	end
	return nil
end

--[[
	Диагностика модели. Возвращает список проблем (строк) и таблицу с найденным.
	Используется стендом при загрузке и печатается в консоль.
]]
function GunPreset.diagnose(model: Instance): (string?, { [string]: Attachment })
	local issues: { string } = {}
	local found: { [string]: Attachment } = {}

	if not model:IsA("Model") then
		table.insert(issues, "это не Model: стенд ждёт Model (Tool не поддерживается)")
	end

	for key, attachmentName in GunPreset.AttachmentNames do
		local attachment = GunPreset.getAttachment(model, attachmentName)
		if attachment then
			found[key] = attachment
		elseif key == "Grip" then
			table.insert(
				issues,
				`нет обязательной точки "{attachmentName}" (рука не найдёт оружие)`
			)
		end
	end

	local folder = GunPreset.findAttachmentsFolder(model)
	if not folder then
		table.insert(
			issues,
			"нет папки Attachments — оружие всё равно загрузится, но без сокетов"
		)
	end

	local hasPrimary = false
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			hasPrimary = true
			break
		end
	end
	if not hasPrimary then
		table.insert(issues, "в модели нет ни одной BasePart")
	end

	if #issues == 0 then
		return nil, found
	end
	return table.concat(issues, "; "), found
end

function GunPreset.computeSize(model: Instance): Vector3
	local ok, size = pcall(function()
		return model:GetExtentsSize()
	end)
	if ok then
		return size
	end
	return Vector3.zero
end

--[[
	Возвращает масштаб, который нужно применить к модели, чтобы попасть в ReferenceSize.
	0.5..2.5 ограничение, чтобы модель не улетела в бесконечность.
]]
function GunPreset.computeScale(model: Instance): number
	local size = GunPreset.computeSize(model)
	if size.Magnitude <= 0 then
		return 1
	end
	local longest = math.max(size.X, size.Y, size.Z)
	local reference = math.max(GunPreset.ReferenceSize.X, GunPreset.ReferenceSize.Y, GunPreset.ReferenceSize.Z)
	local scale = reference / longest
	return math.clamp(scale, 0.5, 2.5)
end

--[[
	Безопасно масштабирует модель.
	Использует штатный Model:ScaleTo, который корректно масштабирует и части,
	и сварки, и Attachment'ы. Если API недоступен — откат на ручной вариант.
]]
function GunPreset.applyScale(model: Instance, scale: number)
	if math.abs(scale - 1) < 0.01 then
		return
	end

	if not model:IsA("Model") then
		warn(
			`[HardOut] Автомасштаб поддерживается только для Model (не "${model.ClassName}").`
		)
		return
	end

	local succeeded = pcall(function()
		model:ScaleTo(scale)
	end)
	if succeeded then
		return
	end

	-- Откат: масштабируем части относительно пивота и Attachment'ы.
	warn("[HardOut] Model:ScaleTo недоступен, масштабирую вручную.")
	local pivot = model:GetPivot()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Size = part.Size * scale
			local offset = pivot:ToObjectSpace(part.CFrame)
			part.CFrame = pivot * CFrame.new(offset.Position * scale) * offset.Rotation
		elseif descendant:IsA("Attachment") then
			local attachment = descendant :: Attachment
			attachment.Position = attachment.Position * scale
		end
	end
end

return GunPreset
