# Запуск за 5 минут

> Первый раз с Rojo? См. `docs/INSTALL_ROJO.md` — там пошагово про `rojo.exe`,
> PATH и подключение плагина.

## 1. Rojo

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

## 4. Если что-то не так

| Симптом | Что проверить |
|---|---|
| Оружие не в руках | в консоли `warn` про `Grip`; модель должна быть `Model`, не `Tool` |
| Оружие смотрит вбок/вверх | поверни `CFrame` у `Attachment Grip` |
| Рук не видно | `Config.ViewModel.Enabled = true`, камера FOV 75 |
| Мышь не крутит камеру | `CharacterSetup` отключает дефолтные контроллы; проверь, что `ClientBoot` запустился |
| Персонаж «плывёт» | это стрейф-наклон (`Config.Camera.LeanAngle`) — уменьши, если мешает |
| Мишени не получают урон | они должны иметь `Humanoid`; серверный `CombatService` пишет ошибки в консоль |
