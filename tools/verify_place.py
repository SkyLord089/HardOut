#!/usr/bin/env python3
"""
verify_place.py — проверяет собранный .rbxlx перед тем, как открывать его в Studio.

Ловит ошибки, из-за которых место открывается, но «ничего не работает»:
  1. нет Baseplate/SpawnLocation  -> игрок падает в пустоту;
  2. нет ServerBoot/ClientBoot     -> скрипты вообще не запускаются;
  3. require(...WaitForChild(...)) на несуществующий путь -> скрипт молча висит;
  4. require(script.Parent...) без папки рядом -> модуль не найден;
  5. у Part нет <CoordinateFrame name="CFrame"> или <Vector3 name="size">;
  6. у скрипта нет непустого Source;
  7. битые ссылки/дубли referent.

Запуск: python3 tools/verify_place.py HardOut.rbxlx
"""

from __future__ import annotations

import pathlib
import re
import sys
import xml.etree.ElementTree as ET

OK = "  ok  "
BAD = " FAIL "


class Node:
    def __init__(self, class_name: str, node_name: str, elem: ET.Element, parent: "Node | None"):
        self.class_name = class_name
        self.name = node_name
        self.elem = elem
        self.parent = parent
        self.children: list[Node] = []
        self.source: str | None = None

    def find(self, child_name: str) -> "Node | None":
        for child in self.children:
            if child.name == child_name:
                return child
        return None

    def path(self) -> str:
        parts, node = [], self
        while node is not None:
            parts.append(node.name)
            node = node.parent
        return ".".join(reversed(parts))


def parse(path: pathlib.Path) -> Node:
    root = ET.parse(path).getroot()
    fake_root = Node("DataModel", "DataModel", root, None)

    def walk(elem: ET.Element, parent: Node):
        for child in elem.findall("Item"):
            props = child.find("Properties")
            node_name = "?"
            source = None
            if props is not None:
                for prop in props:
                    if prop.get("name") == "Name":
                        node_name = prop.text or ""
                    if prop.get("name") == "Source":
                        source = "".join(prop.itertext())
            node = Node(child.get("class", "?"), node_name, child, parent)
            node.source = source
            parent.children.append(node)
            walk(child, node)

    walk(root, fake_root)
    return fake_root


def find_node(root: Node, path: str) -> Node | None:
    node = root
    for part in path.split("."):
        node = node.find(part)
        if node is None:
            return None
    return node


def service(root: Node, class_name: str) -> Node | None:
    for child in root.children:
        if child.class_name == class_name:
            return child
    return None


def check_structure(root: Node, results: list[tuple[bool, str]]):
    workspace = service(root, "Workspace")
    has_floor = workspace is not None and any(
        c.class_name in {"Part", "BasePart"} and c.name.lower() in {"baseplate", "floor"} for c in workspace.children
    )
    has_spawn = workspace is not None and any(c.class_name == "SpawnLocation" for c in workspace.children)
    results.append((has_floor, "Workspace: есть пол (Baseplate)"))
    results.append((has_spawn, "Workspace: есть SpawnLocation"))

    server = service(root, "ServerScriptService")
    client_scripts = find_node(root, "StarterPlayer.StarterPlayerScripts")
    has_server_boot = server is not None and server.find("ServerBoot") is not None
    has_client_boot = client_scripts is not None and client_scripts.find("ClientBoot") is not None
    results.append((has_server_boot, "ServerScriptService.ServerBoot существует"))
    results.append((has_client_boot, "StarterPlayerScripts.ClientBoot существует"))
    results.append((server is not None and server.find("Modules") is not None, "ServerScriptService.Modules существует"))
    results.append(
        (client_scripts is not None and client_scripts.find("Modules") is not None, "StarterPlayerScripts.Modules существует")
    )


def check_part_props(root: Node, results: list[tuple[bool, str]]):
    bad: list[str] = []
    for node in root.elem.iter("Item"):
        if node.get("class") not in {"Part", "SpawnLocation"}:
            continue
        props = node.find("Properties")
        names = {p.get("name") for p in props} if props is not None else set()
        label_props = []
        if "CFrame" not in names:
            label_props.append("CFrame")
        if "size" not in names:
            label_props.append("size")
        if "Anchored" not in names:
            label_props.append("Anchored")
        if label_props:
            bad.append(f"{node.get('class')}: нет {', '.join(label_props)}")
    results.append((not bad, "все Part/SpawnLocation имеют CFrame, size, Anchored" + (f"  ({'; '.join(bad[:3])})" if bad else "")))


def check_scripts(root: Node, results: list[tuple[bool, str]]):
    empty: list[str] = []
    for node in root.children:
        stack = [node]
        while stack:
            current = stack.pop()
            if current.class_name in {"Script", "LocalScript", "ModuleScript"}:
                if not (current.source or "").strip():
                    empty.append(current.path())
            stack.extend(current.children)
    results.append((not empty, "у всех скриптов непустой Source" + (f"  ({', '.join(empty[:3])})" if empty else "")))


def _script_nodes(root: Node):
    stack = [root]
    while stack:
        node = stack.pop()
        stack.extend(node.children)
        if node.class_name in {"Script", "LocalScript", "ModuleScript"}:
            yield node


def _clean(line: str) -> str:
    """Отрезает комментарий, не трогая строковые литералы (упрощённо, но хватает)."""
    in_string = None
    for index, char in enumerate(line):
        if in_string:
            if char == in_string:
                in_string = None
        elif char in {'"', "'"}:
            in_string = char
        elif char == "-" and line[index : index + 2] == "--":
            return line[:index]
    return line


SERVICES = {
    "ReplicatedStorage", "ServerScriptService", "StarterPlayer", "StarterPlayerScripts",
    "Workspace", "workspace", "Players", "Lighting", "SoundService", "ServerStorage",
    "ReplicatedFirst", "StarterGui", "StarterPack", "RunService", "UserInputService",
}

PROJECT_FOLDERS = {"Modules", "HardOut", "Weapon", "Net", "WeaponModels"}

TOKEN_RE = re.compile(
    r'\.Parent'
    r'|\.\w+'
    r'|:\s*WaitForChild\(\s*"([\w\s-]+)"[^)]*\)'
    r'|:\s*FindFirstChild\(\s*"([\w\s-]+)"[^)]*\)'
)


def _strip_comment(line: str) -> str:
    in_string = None
    for index, char in enumerate(line):
        if in_string:
            if char == in_string:
                in_string = None
        elif char in {'"', "'"}:
            in_string = char
        elif char == "-" and line[index : index + 2] == "--":
            return line[:index]
    return line


def resolve_expr(root: Node, script_node: Node, expr: str, aliases: dict) -> object:
    """
    Разбирает выражение иерархии, начиная с alias/script/game/сервиса.

      script.Parent:FindFirstChild("Modules")  -> Node папки Modules
      HardOut:WaitForChild("Net")              -> Node (HardOut берётся из aliases)
      script:WaitForChild("Modules")           -> False (нет такого ребёнка)

    Возвращает Node | False | None (None = не про иерархию).
    """
    expr = expr.strip()
    if not expr:
        return None

    service_call = re.match(r'game\s*[:.]\s*GetService\(\s*"(\w+)"\s*\)', expr)
    if service_call:
        base = service(root, service_call.group(1))
        rest = expr[service_call.end():]
    else:
        base_name = re.match(r"[\w.]+", expr)
        if not base_name:
            return None
        head = base_name.group(0)
        rest = expr[len(head):]
        if head == "script":
            base = script_node
        elif head in aliases:
            base = aliases[head]
            if base is False:
                return False
        elif head in SERVICES:
            base = service(root, "Workspace" if head == "workspace" else head)
            if base is None:
                return None
        else:
            return None

    current = base
    position = 0
    while position < len(rest):
        match = TOKEN_RE.match(rest, position)
        if not match:
            return None
        position = match.end()
        text = match.group(0)
        if current is None or current is False:
            return False
        if text == ".Parent":
            current = current.parent
            if current is None:
                return False
            continue
        if text.startswith("."):
            child = current.find(text[1:])
            if child is None:
                return False
            current = child
            continue
        child_name = match.group(1) or match.group(2)
        child = current.find(child_name)
        if child is None:
            return False
        current = child
    return current


def _aliases(root: Node, script_node: Node, source: str) -> dict:
    """Разрешает локальные переменные, ссылающиеся на объекты иерархии (несколько проходов)."""
    aliases: dict = {}
    lines = [_strip_comment(line) for line in source.splitlines()]

    for _ in range(5):
        changed = False
        for line in lines:
            match = re.match(r"\s*local\s+(\w+)\s*=\s*(.+)$", line)
            if not match:
                continue
            var, rhs = match.group(1), match.group(2).strip()

            # require(X) -> тот же объект, что X
            require_match = re.match(r"require\(\s*(.+?)\s*\)$", rhs)
            if require_match:
                inner = resolve_expr(root, script_node, require_match.group(1), aliases)
                if inner is not None and aliases.get(var, "__") != inner:
                    aliases[var] = inner
                    changed = True
                continue

            resolved: object = None
            for piece in re.split(r"\s+(?:and|or)\s+", rhs):
                candidate = resolve_expr(root, script_node, piece.strip(), aliases)
                if candidate is not None:
                    resolved = candidate
            if resolved is not None and aliases.get(var, "__") != resolved:
                aliases[var] = resolved
                changed = True
        if not changed:
            break
    return aliases


def check_paths(root: Node, results: list[tuple[bool, str]]):
    """
    Проверяет, что каждый X:WaitForChild("Y") / X:FindFirstChild("Y") и каждый
    require(...) ведут на реально существующий объект в файле места.
    Ловит баг `script:WaitForChild("Modules")` вместо `script.Parent:...`.
    """
    problems: list[str] = []

    for script_node in _script_nodes(root):
        source = script_node.source or ""
        aliases = _aliases(root, script_node, source)

        for match in re.finditer(
            r'((?:\w+\.)*\w+)\s*:\s*(WaitForChild|FindFirstChild)\(\s*"([\w\s-]+)"', source
        ):
            receiver, method, child_name = match.group(1), match.group(2), match.group(3)
            if "." in receiver:
                resolved_receiver = resolve_expr(root, script_node, receiver, aliases)
                if resolved_receiver is False:
                    problems.append(f'{script_node.path()}: {receiver} — битый путь')
                    continue
                if resolved_receiver is None:
                    continue
                if resolved_receiver.find(child_name) is None:  # type: ignore[union-attr]
                    problems.append(f'{script_node.path()}: у {receiver} нет "{child_name}"')
                continue
            target = aliases.get(receiver, "__missing__")

            if target == "__missing__":
                if receiver == "script":
                    problems.append(f'{script_node.path()}: script:{method}("{child_name}") — дети скрипта, а не соседи')
                elif child_name in PROJECT_FOLDERS:
                    problems.append(f'{script_node.path()}: {receiver}:{method}("{child_name}") — получатель не прослеживается')
                continue

            if target is False:
                problems.append(f'{script_node.path()}: {receiver} — битый путь, из него берут "{child_name}"')
                continue
            if target is None:
                continue
            if target.find(child_name) is None:  # type: ignore[union-attr]
                problems.append(f'{script_node.path()}: у {receiver} ({target.name}) нет "{child_name}"')

        for match in re.finditer(r"require\(\s*(.+?)\s*\)", source):
            expr = match.group(1).strip()
            if resolve_expr(root, script_node, expr, aliases) is False:
                problems.append(f"{script_node.path()}: require({expr}) не разрешается")

    seen = set()
    unique = [p for p in problems if not (p in seen or seen.add(p))]
    results.append(
        (
            not unique,
            "все WaitForChild/FindFirstChild/require ведут на существующие объекты"
            + (f"  ({'; '.join(unique[:4])})" if unique else ""),
        )
    )


def check_referents(root: Node, results: list[tuple[bool, str]]):
    seen: dict[str, int] = {}
    for node in root.elem.iter("Item"):
        ref = node.get("referent", "")
        seen[ref] = seen.get(ref, 0) + 1
    duplicates = [ref for ref, count in seen.items() if count > 1]
    results.append((not duplicates, "referent уникальны" + (f"  (дубли: {duplicates[:3]})" if duplicates else "")))


def main() -> int:
    path = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "HardOut.rbxlx")
    if not path.exists():
        print(f"Файл не найден: {path}")
        return 2

    try:
        root = parse(path)
    except ET.ParseError as error:
        print(f"{BAD} XML битый: {error}")
        return 1

    results: list[tuple[bool, str]] = []
    check_structure(root, results)
    check_part_props(root, results)
    check_scripts(root, results)
    check_referents(root, results)
    check_paths(root, results)

    print(f"Проверка {path.name}:\n")
    failed = 0
    for ok, message in results:
        print(OK + message if ok else BAD + message)
        if not ok:
            failed += 1

    print()
    if failed:
        print(f"Провалено проверок: {failed}. Файл лучше не открывать — сначала починить.")
        return 1
    print("Всё чисто: место должно запуститься.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
