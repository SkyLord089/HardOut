# Работа без Rojo

Rojo — это удобство, а не требование. Три способа обойтись без него.

## Способ 1 (рекомендуется): просто открыть готовый файл места

В репозитории уже лежит **`HardOut.rbxlx`** — собранное место со всеми скриптами.

1. Скачай его из репозитория.
2. Двойной клик (или Studio → File → Open from File).
3. **Play**.

Всё. Ни Rojo, ни плагина, ни терминала.

> Файл лежит в корне проекта. Если качал из GitHub: открой `HardOut.rbxlx` →
> кнопка **Download** (raw). Файл текстовый (XML), это нормально — Studio его
> прекрасно открывает.

## Способ 2: пересобрать файл места самому

Если правил код и нужен свежий `.rbxlx`:

```bash
python3 tools/build_place.py                 # -> HardOut.rbxlx
python3 tools/build_place.py -o Test.rbxlx   # своё имя
```

Нужен только Python 3 (он есть на Windows/macOS/Linux «из коробки» или ставится
за 2 минуты). Роблоксовский Studio и Rojo не нужны.

Скрипт читает `src/**/*.luau` и структуру проекта, поэтому он всегда даёт
то же самое, что отдал бы Rojo.

## Способ 3: руками (если ничего запускать не хочешь)

Скриптов 27, это реально, но муторно. Порядок:

1. Studio → **New → Baseplate**.
2. В **ReplicatedStorage** создать `Folder` с именем `HardOut` и повторить
   вложенность `src/shared/HardOut/`:
   ```
   HardOut
   ├─ Config (ModuleScript)
   ├─ Animator (ModuleScript)
   ├─ ArmSolver (ModuleScript)
   ├─ Signal (ModuleScript)
   ├─ Net/Remotes (ModuleScript)
   └─ Weapon/
      ├─ AimSolver, Ballistics, GunPreset, Recoil, Spring,
      ├─ WeaponConfig, WeaponState   (все ModuleScript)
   ```
   Имя скрипта = имя файла без `.luau`. Содержимое — скопировать из файла.
3. В **ServerScriptService**:
   * `Script` с именем **`ServerBoot`** ← содержимое `src/server/init.server.luau`
   * `Folder` **`Modules`** ← `CombatService`, `RaidSandbox`, `SampleWeapon`,
     `TestRange` (ModuleScript)
4. В **StarterPlayer → StarterPlayerScripts**:
   * `LocalScript` с именем **`ClientBoot`** ← `src/client/init.client.luau`
   * `Folder` **`Modules`** ← `Camera`, `CharacterSetup`, `FirstPersonRig`, `Hud`,
     `Input`, `PlayerController`, `Tracers`, `WeaponController`, `WeaponHolder`
5. Имена `ServerBoot` / `ClientBoot` / `Modules` **важны**: код ищет `script.Modules`
   и `ReplicatedStorage.HardOut`.

Проверка: консоль при Play должна показать
`[HardOut] Сервер готов...` и `[HardOut] Клиент готов...`.

---

## Чем это хуже Rojo

| | `.rbxlx` | Rojo |
|---|---|---|
| Нужны инструменты | нет | exe + плагин |
| Правки кода | в Studio | в VS Code, автоподхват |
| Git-диффы | плохие (XML в одну строку) | нормальные (`.luau` файлы) |
| Модели оружия в проекте | руками | из `.rbxm` в папке |

Рекомендация: **сейчас** — просто открывай `HardOut.rbxlx` и работай.
Когда начнёшь активно писать код — переходи на Rojo, исходники те же, ничего
переделывать не придётся.

---

## Важно про модели оружия

Файл `.rbxlx` содержит только скрипты. Модель пушки кладётся руками:

1. Открыл место → вставил модель в `ReplicatedStorage/WeaponModels`.
2. Добавил `Attachments` + `Grip` (см. `docs/HANDS_AND_GUN.md`).
3. Play.

Чтобы модель не потерялась между запусками — **сохраняй место** (Ctrl+S), это
отдельный `.rbxl` файл на твоём компьютере. `HardOut.rbxlx` из репозитория —
это «чистый» стартовый слепок, его не надо перезаписывать своими правками.
