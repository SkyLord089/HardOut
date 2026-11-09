--!nonstrict
--[[
	Hud.luau
	Минималистичный HUD в духе Таркова: точка/крестик, патроны, слоты,
	полоска перезарядки, подсказки. Всё строится кодом — ассеты не нужны.

	Крестик динамический: расходится от движения, сходится в прицел.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("HardOut"):WaitForChild("Config"))

local Hud = {}
Hud.__index = Hud

local COLOR_TEXT = Color3.fromRGB(228, 226, 216)
local COLOR_DIM = Color3.fromRGB(140, 138, 128)
local COLOR_ACCENT = Color3.fromRGB(198, 160, 94)
local COLOR_DANGER = Color3.fromRGB(206, 96, 74)

local SLOT_COUNT = Config.Inventory.Slots
local SLOT_SIZE = 42

local function label(parent, name, size, position, textSize, anchor)
	local instance = Instance.new("TextLabel")
	instance.Name = name
	instance.BackgroundTransparency = 1
	instance.Size = size
	instance.Position = position
	instance.AnchorPoint = anchor or Vector2.new(0, 0)
	instance.Font = Enum.Font.Code
	instance.TextSize = textSize
	instance.TextColor3 = COLOR_TEXT
	instance.TextXAlignment = Enum.TextXAlignment.Left
	instance.TextYAlignment = Enum.TextYAlignment.Center
	instance.Text = ""
	instance.Parent = parent
	return instance
end

function Hud.new()
	local self = setmetatable({}, Hud)

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "HardOutHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	self.gui = gui

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui
	self.root = root

	self:buildCrosshair()
	self:buildAmmo()
	self:buildHotbar()
	self:buildReloadBar()
	self:buildHints()

	self.aimFactor = 0
	self.spreadVisual = 0
	self.slots = {}
	return self
end

function Hud:buildCrosshair()
	local container = Instance.new("Frame")
	container.Name = "Crosshair"
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.Size = UDim2.fromOffset(120, 120)
	container.BackgroundTransparency = 1
	container.Parent = self.root
	self.crossContainer = container

	local function bar(name, size)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundColor3 = COLOR_TEXT
		frame.BackgroundTransparency = 0.15
		frame.BorderSizePixel = 0
		frame.Size = size
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.Parent = container
		return frame
	end

	self.bars = {
		top = bar("Top", UDim2.fromOffset(1, 7)),
		bottom = bar("Bottom", UDim2.fromOffset(1, 7)),
		left = bar("Left", UDim2.fromOffset(7, 1)),
		right = bar("Right", UDim2.fromOffset(7, 1)),
	}

	self.dot = bar("Dot", UDim2.fromOffset(2, 2))
	self.dot.BackgroundTransparency = 0.35
end

function Hud:buildAmmo()
	local holder = Instance.new("Frame")
	holder.Name = "Ammo"
	holder.AnchorPoint = Vector2.new(1, 1)
	holder.Position = UDim2.new(1, -26, 1, -26)
	holder.Size = UDim2.fromOffset(240, 76)
	holder.BackgroundTransparency = 1
	holder.Parent = self.root

	self.weaponLabel =
		label(holder, "WeaponName", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 0), 14, Vector2.new(1, 0))
	self.weaponLabel.TextXAlignment = Enum.TextXAlignment.Right
	self.weaponLabel.TextColor3 = COLOR_DIM

	self.ammoLabel = label(holder, "AmmoCount", UDim2.new(1, 0, 0, 48), UDim2.fromOffset(0, 20), 42, Vector2.new(1, 0))
	self.ammoLabel.TextXAlignment = Enum.TextXAlignment.Right
	self.ammoLabel.Text = "—"

	self.ammoTypeLabel =
		label(holder, "AmmoType", UDim2.new(1, 0, 0, 14), UDim2.fromOffset(0, 66), 12, Vector2.new(1, 0))
	self.ammoTypeLabel.TextXAlignment = Enum.TextXAlignment.Right
	self.ammoTypeLabel.TextColor3 = COLOR_DIM
end

function Hud:buildHotbar()
	local holder = Instance.new("Frame")
	holder.Name = "Hotbar"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -20)
	holder.Size = UDim2.fromOffset(SLOT_COUNT * (SLOT_SIZE + 4), SLOT_SIZE)
	holder.BackgroundTransparency = 1
	holder.Parent = self.root

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = holder

	self.slotFrames = {}
	for index = 1, SLOT_COUNT do
		local slot = Instance.new("Frame")
		slot.Name = "Slot" .. index
		slot.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
		slot.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
		slot.BackgroundTransparency = 0.45
		slot.BorderSizePixel = 0
		slot.Parent = holder

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(66, 64, 58)
		stroke.Thickness = 1
		stroke.Transparency = 0.5
		stroke.Parent = slot

		local number = label(slot, "Number", UDim2.fromOffset(16, 14), UDim2.fromOffset(3, 1), 11)
		number.Text = tostring(index)
		number.TextColor3 = COLOR_DIM

		local name = label(slot, "Name", UDim2.new(1, -6, 1, -18), UDim2.fromOffset(3, 16), 10)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextYAlignment = Enum.TextYAlignment.Bottom

		self.slotFrames[index] = { frame = slot, stroke = stroke, name = name }
	end
end

function Hud:buildReloadBar()
	local holder = Instance.new("Frame")
	holder.Name = "ReloadBar"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, 0.5, 52)
	holder.Size = UDim2.fromOffset(150, 2)
	holder.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	holder.BackgroundTransparency = 0.35
	holder.BorderSizePixel = 0
	holder.Visible = false
	holder.Parent = self.root

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = COLOR_ACCENT
	fill.BorderSizePixel = 0
	fill.Parent = holder

	self.reloadBar = holder
	self.reloadFill = fill
end

function Hud:buildHints()
	local hint = label(self.root, "Hints", UDim2.fromOffset(560, 70), UDim2.new(0, 20, 1, -104), 12)
	hint.TextColor3 = COLOR_DIM
	hint.TextYAlignment = Enum.TextYAlignment.Top
	hint.TextWrapped = true
	hint.Text = "WASD — движение   SHIFT — бег   C — присед   ПРОБЕЛ — прыжок\n"
		.. "ЛКМ — огонь   ПКМ — прицел   R — перезарядка   1–9 — слоты   X — убрать оружие\n"
		.. "Своё оружие: ReplicatedStorage.WeaponModels (см. docs/HANDS_AND_GUN.md)"
	self.hint = hint
end

--[[ Список слотов (модели оружия). ]]
function Hud:setSlots(slots)
	self.slots = slots or {}
	for index, entry in self.slotFrames do
		local weapon = self.slots[index]
		entry.name.Text = weapon and weapon.Name or ""
		entry.name.TextColor3 = weapon and COLOR_TEXT or COLOR_DIM
	end
end

function Hud:setWeapon(holder, slot)
	self.weaponLabel.Text = holder and string.upper(holder.sourceName) or ""
	self.ammoTypeLabel.Text = holder and holder.stats.AmmoType or ""

	self.activeSlot = slot
	for index, entry in self.slotFrames do
		local isActive = index == slot
		entry.stroke.Color = isActive and COLOR_ACCENT or Color3.fromRGB(66, 64, 58)
		entry.stroke.Transparency = isActive and 0.05 or 0.5
		entry.frame.BackgroundTransparency = isActive and 0.25 or 0.45
	end

	if holder then
		self:setAmmo(holder.stats.MagazineSize, holder.stats.MagazineSize)
	else
		self.ammoLabel.Text = "—"
		self:setReload(false, 1)
	end
end

function Hud:setAmmo(current, maximum)
	self.ammoLabel.Text = string.format("%d / %d", current, maximum)
	local low = current <= math.max(1, math.floor(maximum * 0.25))
	self.ammoLabel.TextColor3 = low and COLOR_DANGER or COLOR_TEXT
end

function Hud:setReload(reloading, progress)
	self.reloadBar.Visible = reloading == true and progress < 1
	self.reloadFill.Size = UDim2.fromScale(math.clamp(progress or 0, 0, 1), 1)
end

--[[ Показать/скрыть свой прицел целиком. ]]
function Hud:setCrosshairVisible(isVisible)
	if self.crossContainer then
		self.crossContainer.Visible = isVisible
	end
	if self.dot then
		self.dot.Visible = isVisible
	end
end

--[[ Прицел: в ADS крестик сходится и гаснет, остаётся точка. ]]
function Hud:setAim(aimFactor)
	self.aimFactor = aimFactor or 0
	local alpha = 1 - math.clamp(self.aimFactor, 0, 1)
	local gap = 4 + 10 * (1 - alpha)

	self.bars.top.Position = UDim2.new(0.5, 0, 0.5, -gap)
	self.bars.bottom.Position = UDim2.new(0.5, 0, 0.5, gap)
	self.bars.left.Position = UDim2.new(0.5, -gap, 0.5, 0)
	self.bars.right.Position = UDim2.new(0.5, gap, 0.5, 0)

	for _, bar in self.bars do
		bar.BackgroundTransparency = 1 - alpha * 0.85
	end
	self.dot.BackgroundTransparency = 0.35 + 0.55 * (1 - alpha)
end

return Hud
