#!/usr/bin/env python3
"""
build_place.py — собирает готовый файл места Roblox (.rbxlx) БЕЗ Rojo.

Формат сериализации сверен с эталонными файлами rbx-dom/Rojo
(см. docs/BUILD_PLACE.md): Part требует <CoordinateFrame name="CFrame">,
<SpawnLocation> — форму с surface-параметрами и <token name="shape">,
скрипты пишутся как <string name="Source"> (CDATA).

Что попадает в место:
  * Workspace.Baseplate  — пол под точкой спавна (чтобы не падать в пустоту)
  * Workspace.SpawnLocation
  * ReplicatedStorage/HardOut (все shared-модули) + WeaponModels (пустая папка)
  * ServerScriptService/ServerBoot + Modules (серверные модули)
  * StarterPlayer/StarterPlayerScripts/ClientBoot + Modules

Проверка: python3 tools/verify_place.py HardOut.rbxlx
"""

from __future__ import annotations

import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

_referent = 0


def next_referent() -> str:
    global _referent
    _referent += 1
    return f"RBX{_referent:032X}"


# ------------------------------------------------------------------ значения


def xml_escape(value: str) -> str:
    return (
        value.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def cdata(value: str) -> str:
    """Текст внутри CDATA; разбиваем случай ']]>' на два блока."""
    safe = value.replace("]]>", "]]]]><![CDATA[>")
    return f"<![CDATA[{safe}]]>"


def name(value: str) -> str:
    return f'<string name="Name">{xml_escape(value)}</string>'


def boolean(prop: str, value: bool) -> str:
    return f'<bool name="{prop}">{"true" if value else "false"}</bool>'


def float_prop(prop: str, value: float) -> str:
    return f'<float name="{prop}">{value:g}</float>'


def int_prop(prop: str, value: int) -> str:
    return f'<int name="{prop}">{value}</int>'


def int64_prop(prop: str, value: int) -> str:
    return f'<int64 name="{prop}">{value}</int64>'


def token(prop: str, value: int) -> str:
    return f'<token name="{prop}">{value}</token>'


def vector3(prop: str, x: float, y: float, z: float) -> str:
    return f'<Vector3 name="{prop}"><X>{x:g}</X><Y>{y:g}</Y><Z>{z:g}</Z></Vector3>'


def color3uint8_from_rgb(r: int, g: int, b: int) -> str:
    """Тот же порядок байт, что в эталонных файлах Studio (<Color3uint8>)."""
    packed = 0xFF << 24 | (r << 16) | (g << 8) | b
    return f'<Color3uint8 name="Color3uint8">{packed}</Color3uint8>'


def cframe(prop: str, x: float, y: float, z: float) -> str:
    return (
        f'<CoordinateFrame name="{prop}">'
        f"<X>{x:g}</X><Y>{y:g}</Y><Z>{z:g}</Z>"
        "<R00>1</R00><R01>0</R01><R02>0</R02>"
        "<R10>0</R10><R11>1</R11><R12>0</R12>"
        "<R20>0</R20><R21>0</R21><R22>1</R22>"
        "</CoordinateFrame>"
    )


def empty_attributes() -> str:
    # Без этого атрибуты, выставленные скриптом, могут не читаться.
    return '<BinaryString name="AttributesSerialize"></BinaryString>'


def tags() -> str:
    return '<BinaryString name="Tags"></BinaryString>'


def physical_properties() -> str:
    return (
        '<PhysicalProperties name="CustomPhysicalProperties">'
        "<CustomPhysics>false</CustomPhysics>"
        "</PhysicalProperties>"
    )


def surfaces() -> list[str]:
    """Плоские грани: без них часть может отрисоваться с "шипами" по умолчанию."""
    out: list[str] = []
    for surface in ("Front", "Back", "Top", "Bottom", "Left", "Right"):
        out.append(float_prop(f"{surface}ParamA", -0.5))
        out.append(float_prop(f"{surface}ParamB", 0.5))
        out.append(token(f"{surface}Surface", 0))
        out.append(token(f"{surface}SurfaceInput", 0))
    return out


# ------------------------------------------------------------------ объекты


def item(class_name: str, prop_lines: list[str], children: list[str] | None = None) -> str:
    parts = [f'<Item class="{class_name}" referent="{next_referent()}">']
    parts.append("<Properties>")
    parts.extend(prop_lines)
    parts.append("</Properties>")
    if children:
        parts.extend(children)
    parts.append("</Item>")
    return "".join(parts)


def base_part_props(
    part_name: str,
    size: tuple[float, float, float],
    position: tuple[float, float, float],
    color: tuple[int, int, int],
    anchored: bool = True,
    can_collide: bool = True,
    can_query: bool = True,
    transparency: float = 0.0,
    material_token: int = 256,
) -> list[str]:
    """Полный набор свойств обычной Part/BasePart."""
    sx, sy, sz = size
    px, py, pz = position
    props = [
        boolean("Anchored", anchored),
        empty_attributes(),
    ]
    props += surfaces()
    props += [
        cframe("CFrame", px, py, pz),
        boolean("CanCollide", can_collide),
        boolean("CanQuery", can_query),
        boolean("CanTouch", True),
        boolean("CastShadow", True),
        int_prop("CollisionGroupId", 0),
        color3uint8_from_rgb(*color),
        physical_properties(),
        boolean("Locked", False),
        boolean("Massless", False),
        token("Material", material_token),
        name(part_name),
        cframe("PivotOffset", 0, 0, 0),
        float_prop("Reflectance", 0),
        int_prop("RootPriority", 0),
        vector3("RotVelocity", 0, 0, 0),
        int64_prop("SourceAssetId", -1),
        tags(),
        float_prop("Transparency", transparency),
        vector3("Velocity", 0, 0, 0),
        token("formFactorRaw", 1),
        token("shape", 1),
        vector3("size", sx, sy, sz),
    ]
    return props


def part(part_name: str, size, position, color, **kwargs) -> str:
    return item("Part", base_part_props(part_name, size, position, color, **kwargs))


def spawn_location(position: tuple[float, float, float], size=(12, 1, 12)) -> str:
    """SpawnLocation — это Part + свои свойства (neutral, duration, teamColor)."""
    props = base_part_props(
        "SpawnLocation",
        size,
        position,
        (110, 110, 110),
        anchored=True,
        can_collide=True,
    )
    props += [
        boolean("AllowTeamChangeOnTouch", False),
        int_prop("Duration", 0),
        boolean("Enabled", True),
        boolean("Neutral", True),
        int_prop("TeamColor", 194),
    ]
    return item("SpawnLocation", props)


def script_item(path: pathlib.Path, class_name: str, script_name: str) -> str:
    source = path.read_text(encoding="utf-8")
    props = [
        empty_attributes(),
        boolean("Disabled", False),
        name(script_name),
        int64_prop("SourceAssetId", -1),
        f'<string name="Source">{cdata(source)}</string>',
        tags(),
    ]
    return item(class_name, props)


def module_class(path: pathlib.Path) -> str:
    if path.name.endswith(".server.luau"):
        return "Script"
    if path.name.endswith(".client.luau"):
        return "LocalScript"
    return "ModuleScript"


def module_name(path: pathlib.Path) -> str:
    for suffix in (".server.luau", ".client.luau", ".luau", ".lua"):
        if path.name.endswith(suffix):
            return path.name[: -len(suffix)]
    return path.stem


def folder_from_dir(directory: pathlib.Path, folder_name: str) -> str:
    children: list[str] = []
    for entry in sorted(directory.iterdir(), key=lambda p: (p.is_dir(), p.name.lower())):
        if entry.is_dir():
            children.append(folder_from_dir(entry, entry.name))
        elif entry.suffix in {".luau", ".lua"}:
            children.append(script_item(entry, module_class(entry), module_name(entry)))
    return item("Folder", [empty_attributes(), name(folder_name), int64_prop("SourceAssetId", -1), tags()], children)


# ------------------------------------------------------------------ сборка


def build() -> tuple[str, dict[str, str]]:
    """Возвращает (xml, {имя_скрипта: исходник}) — второе для верификатора."""
    global _referent
    _referent = 0
    scripts: dict[str, str] = {}

    def collect(directory: pathlib.Path):
        for entry in directory.rglob("*"):
            if entry.is_file() and entry.suffix in {".luau", ".lua"}:
                scripts[str(entry.relative_to(ROOT))] = entry.read_text(encoding="utf-8")

    collect(SRC)

    workspace = item(
        "Workspace",
        [
            empty_attributes(),
            name("Workspace"),
            boolean("StreamingEnabled", False),
            float_prop("Gravity", 196.2),
        ],
        [
            # Пол, чтобы игрок не падал в пустоту даже до генерации полигона.
            part("Baseplate", (512, 20, 512), (0, -10.5, 0), (92, 92, 92)),
            spawn_location((0, 1.5, 40)),
        ],
    )

    lighting = item(
        "Lighting",
        [
            empty_attributes(),
            name("Lighting"),
            '<Color3 name="Ambient"><R>0.156863</R><G>0.156863</G><B>0.156863</B></Color3>',
            '<Color3 name="OutdoorAmbient"><R>0.392157</R><G>0.392157</G><B>0.392157</B></Color3>',
            float_prop("Brightness", 2),
            float_prop("ClockTime", 13),
            float_prop("EnvironmentDiffuseScale", 0.4),
            float_prop("EnvironmentSpecularScale", 0.6),
            boolean("GlobalShadows", True),
            float_prop("ShadowSoftness", 0.25),
            float_prop("ExposureCompensation", 0.15),
        ],
    )

    replicated = item(
        "ReplicatedStorage",
        [empty_attributes(), name("ReplicatedStorage")],
        [
            folder_from_dir(SRC / "shared" / "HardOut", "HardOut"),
            item("Folder", [empty_attributes(), name("WeaponModels"), int64_prop("SourceAssetId", -1), tags()]),
        ],
    )

    server_scripts = item(
        "ServerScriptService",
        [empty_attributes(), name("ServerScriptService")],
        [
            # Папка Modules идёт ПЕРВОЙ: Studio создаёт объекты по порядку, и
            # скрипт, запустившись раньше своей папки, не нашёл бы её.
            folder_from_dir(SRC / "server" / "modules", "Modules"),
            script_item(SRC / "server" / "init.server.luau", "Script", "ServerBoot"),
        ],
    )

    starter_player_scripts = item(
        "StarterPlayerScripts",
        [empty_attributes(), name("StarterPlayerScripts")],
        [
            # Сначала Modules, потом ClientBoot (см. комментарий выше).
            folder_from_dir(SRC / "client" / "modules", "Modules"),
            script_item(SRC / "client" / "init.client.luau", "LocalScript", "ClientBoot"),
        ],
    )

    starter_player = item(
        "StarterPlayer",
        [
            empty_attributes(),
            name("StarterPlayer"),
            float_prop("CameraMaxZoomDistance", 0.5),
            float_prop("CameraMinZoomDistance", 0.5),
            float_prop("CharacterWalkSpeed", 8),
            float_prop("CharacterJumpPower", 42),
            boolean("CharacterUseJumpPower", True),
            boolean("EnableMouseLockOption", False),
        ],
        [starter_player_scripts],
    )

    players = item(
        "Players",
        [empty_attributes(), name("Players"), float_prop("RespawnTime", 1), boolean("CharacterAutoLoads", True)],
    )

    sound_service = item(
        "SoundService",
        [empty_attributes(), name("SoundService"), boolean("RespectFilteringEnabled", True), float_prop("DistanceFactor", 3.33)],
    )

    services = [
        workspace,
        lighting,
        replicated,
        server_scripts,
        starter_player,
        players,
        sound_service,
    ]

    xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        '<Meta name="ExplicitAutoJoints">true</Meta>\n'
        "<External>null</External>\n<External>nil</External>\n"
        + "".join(services)
        + "\n</roblox>\n"
    )
    return xml, scripts


def main() -> int:
    parser = argparse.ArgumentParser(description="Собрать HardOut.rbxlx без Rojo")
    parser.add_argument("-o", "--output", default="HardOut.rbxlx")
    args = parser.parse_args()

    if not (SRC / "shared" / "HardOut").is_dir():
        print(f"Не найдена папка {SRC / 'shared' / 'HardOut'}", file=sys.stderr)
        return 1

    xml, scripts = build()
    out = ROOT / args.output
    out.write_text(xml, encoding="utf-8")
    print(f"Готово: {out}  ({out.stat().st_size / 1024:.0f} КБ, скриптов: {len(scripts)})")
    print("Дальше: python3 tools/verify_place.py " + args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
