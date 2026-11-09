# Контракт: руки, ноги и модель оружия

Документ для случаев «хочу заменить процедурные руки на свои» и «хочу понять,
почему моя пушка встала криво».

---

## 1. Модель оружия (главное)

Стенд сам найдёт любую `Model`/`Tool` в `ReplicatedStorage.WeaponModels`.
Единственное, что реально нужно — **сокет `Grip`**.

```
МояПушка (Model)
├─ Body / Slide / Barrel / ...   ← любые Part / MeshPart
└─ Attachments (Folder)
   ├─ Grip      Attachment       ← ОБЯЗАТЕЛЬНО
   ├─ Support   Attachment
   ├─ Muzzle    Attachment
   └─ Sight     Attachment
```

### Система координат

```
        +Y (верх оружия)
         ↑
         │
         │      −Z (ствол смотрит туда)
         │    ╱
         │  ╱
         └────────→ +X (вправо от оружия)
        Grip
```

* **`Grip`** — центр правой ладони. Оружие поворачивается этим сокетом.
  Если пушка смотрит вверх/вбок — правь `CFrame` у `Grip`, а не модель.
* **`Support`** — куда встаёт левая рука (цевьё). Не влияет на хват,
  используется для позы левой руки и будущих анимаций.
* **`Muzzle`** — срез ствола. Ось **−Z** сокета = направление пули.
  Отсюда берётся вспышка и старт трассера.
* **`Sight`** — точка, куда «смотрит» глаз в ADS (центр прицела).

### Если сокетов нет

| Чего нет | Что будет |
|---|---|
| `Attachments` | оружие наденется по центру, в консоль придёт `warn` |
| `Grip` | оружие наденется по центру модели + предупреждение |
| `Muzzle` | вспышка/трассер из центра модели |
| `Support` | левая рука встанет по умолчанию (не сломает ничего) |

Стенд никогда не «падает» из-за кривой модели — он деградирует и пишет в консоль.

### Масштаб

`Config.Weapons.AutoScale = true` подгоняет модель под эталон
`GunPreset.ReferenceSize` (0.9 × 1.9 × 3.2 studs). Масштабируются `Size`
частей, позиции `Attachment` и относительные смещения — модель не «разъезжается».

---

## 2. Замена рук/ног на свои модели

Сейчас руки и ноги **процедурные** (`client/modules/FirstPersonRig.luau`):
два сегмента на руку/ногу, IK-поза. Это сделано, чтобы стенд работал без ассетов.

Если захочешь свои модели (например, риги брони из Таркова), есть два пути.

### Путь A — оставить IK, подменить визуал (проще)

Замени в `FirstPersonRig:build()` создание `Part` на свои `MeshPart`, но сохрани:

* имена: `RightUpperArm`, `RightLowerArm`, `LeftUpperArm`, `LeftLowerArm`,
  `RightUpperLeg`, `RightLowerLeg`, `LeftUpperLeg`, `LeftLowerLeg`,
  `RightBoot`, `LeftBoot`, `Chest`;
* `handAnchor` (Attachment `HandAnchor`) на конце правого нижнего сегмента —
  это точка крепления оружия.

Позиционирование сегментов идёт через `placeSegment(part, from, to)`:
часть должна быть ориентирована так, что её **ось Z = длина**.
Если меш «лежит» иначе — оберни его во `Part` с нужным `Size` и повесь меш
через `SpecialMesh`/`MeshPart` с `CFrame`-смещением.

### Путь B — полноценные анимации (R15-риг в Camera)

1. Создай риг (`Model` + `Humanoid` + `Animator`) в `workspace.Camera`.
2. Дай ему `HumanoidDescription`/анимации (`Animation` + `Animator:LoadAnimation`).
3. Каждый кадр ставь риг по `Camera.CFrame` (`Model:PivotTo`).
4. Привяжи оружие к `RightHand` через `Motor6D`, используя `Grip` как `C1`.
5. Отключи `Config.ViewModel.Enabled` у процедурного рига.

Важные подводные камни Path B:

* `Humanoid` в `Camera` не должен иметь `Humanoid.WalkSpeed > 0` — иначе он
  попытается идти и «съест» позу;
* анимации проигрываются в пространстве рига, поэтому камера должна двигать риг,
  а не наоборот;
* `Camera.HeadLocked`/`CameraSubject` держи в покое — камера скриптовая.

---

## 3. Где менять поведение

| Что | Файл |
|---|---|
| Скорости, FOV, покачивание, слоты | `shared/HardOut/Config.luau` |
| Статы оружия и пресеты | `shared/HardOut/Weapon/WeaponConfig.luau` |
| Разброс, падение пули, паттерн отдачи | `shared/HardOut/Weapon/Ballistics.luau` |
| Зоны урона | `shared/HardOut/Weapon/AimSolver.luau` |
| Поза рук/ног | `client/modules/FirstPersonRig.luau` |
| Крепление оружия к кисти | `client/modules/WeaponHolder.luau` |
| Серверная проверка выстрела | `server/modules/CombatService.luau` |
