# Запуск за 5 минут

> **Самый быстрый путь — без Rojo:** скачай `HardOut.rbxlx`, открой в Studio,
> нажми Play. См. `docs/WITHOUT_ROJO.md`.

## Вариант без Rojo

> Первый раз с Rojo? См. `docs/INSTALL_ROJO.md` — там пошагово про `rojo.exe`,
> PATH и подключение плагина.

## Вариант с Rojo

```bash
# из корня проекта (там, где лежит default.project.json)
rojo serve
```

В Roblox Studio: **Plugins → Rojo → Connect → Play**.

Нет Rojo? Собери файл места:

```bash
rojo build default.project.json -o HardOut.rbxlx
```

и открой `HardOut.rbxlx` в Studio.

## 2. Что ты должен увидеть

* Первое лицо, видны руки, при взгляде вниз — ноги.
* В руках демо-пушка `HYBRID-9` (если папка `WeaponModels` пуста).
* Мишени на 10 / 25 / 50 / 60 м, по ним считается урон.
* HUD: прицел, патроны справа снизу, хотбар снизу.

Если консоль пишет `ReplicatedStorage.WeaponModels пуста` — значит сервер
не успел подложить демо; подожди кадр или перезапусти Play.

## 3. Первый тест со своей моделью

1. Explorer → `ReplicatedStorage` → `WeaponModels` → **вставь свою модель**.
2. Внутри модели: `Folder` с именем `Attachments`, в нём `Attachment` с именем `Grip`.
3. Нажми **Play**.

Подробнее — `docs/HANDS_AND_GUN.md`.

## 3.5. Руки, ноги, курсор и камера

Всё это крутится в `Config` (файл `src/shared/HardOut/Config.luau`):

| Что | Где | По умолчанию |
|---|---|---|
| Руки и ноги — настоящий персонаж со штатными анимациями | `ViewModel.Mode = "Character"` | включено |
| Прятать голову/шляпы, чтобы не мешали обзору | `ViewModel.HideHead` | `true` |
| Курсор мыши в центре экрана | `Camera.HideCursor` | `false` = спрятан |
| Свой прицел | `Camera.ShowCrosshair` | `false` = без прицела |
| Покачивание головы | `Camera.HeadBob.Amplitude` | `0.045` (мягко) |
| Наклон в стрейфе | `Camera.LeanAngle` | `1.2` |
| Сглаживание поворота | `Camera.Smoothing` | `0.3` |
| Тряска от выстрела | `Camera.ShakeScale` | `0.35` |

Хочешь процедурные руки-бруски вместо аватара (нет анимаций Roblox):
`ViewModel.Mode = "Procedural"`.

Хочешь «мёртвый» кадр без качания: `HeadBob.Amplitude = 0`, `ShakeScale = 0`,
`Smoothing = 0`.

## 4. Если что-то не так

| Симптом | Что проверить |
|---|---|
| Оружие не в руках | в консоли `warn` про `Grip`; модель должна быть `Model`, не `Tool` |
| Оружие смотрит вбок/вверх | поверни `CFrame` у `Attachment Grip` |
| Рук не видно | `Config.ViewModel.Enabled = true`, камера FOV 75 |
| Мышь не крутит камеру | `CharacterSetup` отключает дефолтные контроллы; проверь, что `ClientBoot` запустился |
| Персонаж «плывёт» | это стрейф-наклон (`Config.Camera.LeanAngle`) — уменьши, если мешает |
| Мишени не получают урон | они должны иметь `Humanoid`; серверный `CombatService` пишет ошибки в консоль |
