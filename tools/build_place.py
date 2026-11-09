#!/usr/bin/env python3
"""
build_place.py — сборка готового файла места Roblox (.rbxlx) БЕЗ Rojo.

Зачем: чтобы не требовать от пользователя Rojo/плагин. Скрипт читает те же
исходники (src/**/*.luau) и структуру из default.project.json и собирает
.xml места: DataModel → сервисы → скрипты.

Запуск:
    python3 tools/build_place.py              # -> HardOut.rbxlx в корне
    python3 tools/build_place.py -o My.rbxlx

Что попадает в файл:
  * ReplicatedStorage/HardOut            (все модули shared)
  * ReplicatedStorage/WeaponModels       (пустая папка под модели оружия)
  * ServerScriptService/ServerBoot       (Script  = src/server/init.server.luau)
  * ServerScriptService/Modules          (модули сервера)
  * StarterPlayer/StarterPlayerScripts/ClientBoot  (LocalScript)
  * StarterPlayer/StarterPlayerScripts/Modules     (модули клиента)
  * настройки Workspace/Lighting/StarterPlayer

Ограничения (осознанные): это не Rojo. Скрипты кладутся внутрь <Properties>
как <ProtectedString>, поэтому файл открывается и в свежих, и в старых версиях
Studio. Модели оружия (.rbxm) сюда не пакуются — их вставляют руками.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
import xml.sax.saxutils as sax

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

# ---------------------------------------------------------------- XML helpers


def tagged(name: str, value: str) -> str:
    return f'<string name="{name}">{sax.escape(value)}</string>' 


def protected(name: str, value: str) -> str:
    """<ProtectedString name="Source">…</ProtectedString> (так хранит Studio)."""
    return f'<ProtectedString name="{name}">{sax.escape(value)}</ProtectedString>'


def boolean(name: str, value: bool) -> str:
    return f"<bool name=\"{name}\">{'true' if value else 'false'}</bool>"


def number(name: str, value: float) -> str:
    return f'<float name="{name}">{value:g}</float>'


def vector3(name: str, x: float, y: float, z: float) -> str:
    return (
        f'<Vector3 name="{name}"><X>{x:g}</X><Y>{y:g}</Y><Z>{z:g}</Z></Vector3>'
    )


def color3(name: str, r: float, g: float, b: float) -> str:
    return (
        f'<Color3 name="{name}"><R>{r:g}</R><G>{g:g}</G><B>{b:g}</B></Color3>'
    )


_referent_counter = 0


def next_referent() -> str:
    global _referent_counter
    _referent_counter += 1
    return f"RBX{_referent_counter}"


def item(class_name: str, name: str, props: list[str], children: list[str] | None = None) -> str:
    parts = [f'<Item class="{class_name}" referent="{next_referent()}">']
    parts.append("<Properties>")
    parts.append(tagged("Name", name))
    parts.extend(props)
    parts.append("</Properties>")
    if children:
        parts.extend(children)
    parts.append("</Item>")
    return "".join(parts)


# ---------------------------------------------------------------- tree building


def read_source(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


def module_class(path: pathlib.Path) -> str:
    name = path.name
    if name.endswith(".server.luau"):
        return "Script"
    if name.endswith(".client.luau"):
        return "LocalScript"
    return "ModuleScript"


def module_name(path: pathlib.Path) -> str:
    for suffix in (".server.luau", ".client.luau", ".luau", ".lua"):
        if path.name.endswith(suffix):
            return path.name[: -len(suffix)]
    return path.stem


def script_item(path: pathlib.Path) -> str:
    return item(
        module_class(path),
        module_name(path),
        [protected("Source", read_source(path))],
    )


def folder_from_dir(directory: pathlib.Path, folder_name: str) -> str:
    """Папка, внутри которой каждый .luau -> ModuleScript/Script/LocalScript."""
    children: list[str] = []
    for entry in sorted(directory.iterdir(), key=lambda p: (p.is_dir(), p.name.lower())):
        if entry.is_dir():
            # Вложенная папка (например, Weapon/) -> вложенный Folder.
            children.append(folder_from_dir(entry, entry.name))
        elif entry.suffix in {".luau", ".lua"}:
            children.append(script_item(entry))
    return item("Folder", folder_name, [], children)


def shared_tree() -> str:
    """ReplicatedStorage/HardOut со всем содержимым shared/HardOut."""
    return folder_from_dir(SRC / "shared" / "HardOut", "HardOut")


# ---------------------------------------------------------------- service props


def meta() -> str:
    """Служебные мета-свойства места: без них Studio может включить legacy-сварки."""
    return (
        '<Meta name="ExplicitAutoJoints">true</Meta>'
    )


def workspace_props() -> list[str]:
    return [
        boolean("StreamingEnabled", False),
        number("Gravity", 196.2),
    ]


def lighting_props() -> list[str]:
    # Технология освещения (Future) намеренно не задаётся: это enum, а имя
    # перечисления в разных версиях Studio отличается. Ставится вручную одним
    # кликом в Properties, если нужен именно Future.
    return [
        color3("Ambient", 0.156863, 0.156863, 0.156863),
        color3("OutdoorAmbient", 0.392157, 0.392157, 0.392157),
        number("Brightness", 2),
        number("ClockTime", 13),
        number("EnvironmentDiffuseScale", 0.4),
        number("EnvironmentSpecularScale", 0.6),
        boolean("GlobalShadows", True),
        number("ShadowSoftness", 0.25),
        number("ExposureCompensation", 0.15),
    ]


def starter_player_props() -> list[str]:
    return [
        number("CameraMaxZoomDistance", 0.5),
        number("CameraMinZoomDistance", 0.5),
        number("CharacterWalkSpeed", 8),
        number("CharacterJumpPower", 42),
        boolean("CharacterUseJumpPower", True),
        boolean("EnableMouseLockOption", False),
    ]


def build() -> str:
    # --- StarterPlayerScripts: ClientBoot + Modules
    client_children = [
        item("LocalScript", "ClientBoot", [protected("Source", read_source(SRC / "client" / "init.client.luau"))]),
        folder_from_dir(SRC / "client" / "modules", "Modules"),
    ]
    starter_player_scripts = item(
        "StarterPlayerScripts", "StarterPlayerScripts", [], client_children
    )

    starter_player = item(
        "StarterPlayer", "StarterPlayer", starter_player_props(), [starter_player_scripts]
    )

    # --- ServerScriptService
    server_children = [
        item("Script", "ServerBoot", [protected("Source", read_source(SRC / "server" / "init.server.luau"))]),
        folder_from_dir(SRC / "server" / "modules", "Modules"),
    ]

    # --- ReplicatedStorage
    replicated = item(
        "ReplicatedStorage",
        "ReplicatedStorage",
        [],
        [
            shared_tree(),
            item("Folder", "WeaponModels", []),
        ],
    )

    services = [
        item("Workspace", "Workspace", workspace_props(), []),
        item("Lighting", "Lighting", lighting_props(), []),
        replicated,
        item("ServerScriptService", "ServerScriptService", [], server_children),
        starter_player,
        item("Players", "Players", [number("RespawnTime", 1), boolean("CharacterAutoLoads", True)], []),
        item(
            "SoundService",
            "SoundService",
            [boolean("RespectFilteringEnabled", True), number("DistanceFactor", 3.33)],
            [],
        ),
    ]

    body = "".join(services)
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        f"<External>null</External>\n<External>nil</External>\n"
        f'{meta()}\n'
        f"{body}\n"
        "</roblox>\n"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Собрать HardOut.rbxlx без Rojo")
    parser.add_argument("-o", "--output", default="HardOut.rbxlx", help="имя выходного файла")
    args = parser.parse_args()

    if not (SRC / "shared" / "HardOut").is_dir():
        print(f"Не найдена папка {SRC / 'shared' / 'HardOut'}", file=sys.stderr)
        return 1

    xml = build()
    out_path = ROOT / args.output
    out_path.write_text(xml, encoding="utf-8")

    scripts = sum(
        1
        for p in SRC.rglob("*")
        if p.is_file() and p.suffix in {".luau", ".lua"}
    )
    size_kb = out_path.stat().st_size / 1024
    print(f"Готово: {out_path}  ({size_kb:.0f} КБ, скриптов: {scripts})")
    print("Открой файл в Roblox Studio и нажми Play.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
