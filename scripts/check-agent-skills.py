#!/usr/bin/env python3
"""Validate repository Agent Skills without third-party Python dependencies."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
SKILLS_ROOT = ROOT / ".agents" / "skills"
NAME_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
TOP_LEVEL_KEY = re.compile(r"^([a-z][a-z0-9-]*):(?:\s*(.*))?$")
MARKDOWN_LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
ALLOWED_KEYS = {
    "name",
    "description",
    "license",
    "compatibility",
    "metadata",
    "allowed-tools",
}


def fail(errors: list[str], path: Path, message: str) -> None:
    errors.append(f"{path.relative_to(ROOT)}: {message}")


def parse_frontmatter(path: Path, errors: list[str]) -> tuple[dict[str, str], str]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        fail(errors, path, "must start with YAML frontmatter delimited by '---'")
        return {}, ""

    try:
        closing = lines.index("---", 1)
    except ValueError:
        fail(errors, path, "frontmatter has no closing '---' delimiter")
        return {}, ""

    values: dict[str, str] = {}
    for line_number, line in enumerate(lines[1:closing], start=2):
        if not line or line[0].isspace() or line.lstrip().startswith("#"):
            continue
        match = TOP_LEVEL_KEY.match(line)
        if not match:
            fail(errors, path, f"line {line_number}: unsupported top-level YAML syntax")
            continue
        key, raw_value = match.groups()
        if key not in ALLOWED_KEYS:
            fail(errors, path, f"line {line_number}: unknown frontmatter key '{key}'")
        values[key] = (raw_value or "").strip().strip('"\'')

    body = "\n".join(lines[closing + 1 :]).strip()
    return values, body


def validate_links(skill_dir: Path, skill_file: Path, body: str, errors: list[str]) -> None:
    for target in MARKDOWN_LINK.findall(body):
        target = target.strip().split("#", 1)[0]
        if not target or target.startswith(("http://", "https://", "mailto:")):
            continue
        relative = Path(unquote(target))
        if relative.is_absolute():
            fail(errors, skill_file, f"uses absolute local link '{target}'")
            continue
        resolved = (skill_file.parent / relative).resolve()
        try:
            resolved.relative_to(skill_dir.resolve())
        except ValueError:
            fail(errors, skill_file, f"link escapes the skill directory: '{target}'")
            continue
        if not resolved.exists():
            fail(errors, skill_file, f"references missing local file '{target}'")


def validate_skill(skill_dir: Path, errors: list[str]) -> None:
    skill_file = skill_dir / "SKILL.md"
    if not skill_file.is_file():
        fail(errors, skill_dir, "missing required SKILL.md")
        return

    values, body = parse_frontmatter(skill_file, errors)
    name = values.get("name", "")
    description = values.get("description", "")
    compatibility = values.get("compatibility", "")

    if not name:
        fail(errors, skill_file, "frontmatter requires a non-empty 'name'")
    elif len(name) > 64 or not NAME_PATTERN.fullmatch(name):
        fail(errors, skill_file, "name must be 1-64 lowercase alphanumeric or hyphen characters")
    elif name != skill_dir.name:
        fail(errors, skill_file, f"name '{name}' must match directory '{skill_dir.name}'")

    if not description:
        fail(errors, skill_file, "frontmatter requires a non-empty 'description'")
    elif len(description) > 1024:
        fail(errors, skill_file, "description exceeds the 1024-character specification limit")

    if len(compatibility) > 500:
        fail(errors, skill_file, "compatibility exceeds the 500-character specification limit")

    if not body:
        fail(errors, skill_file, "Markdown instruction body must not be empty")
    else:
        validate_links(skill_dir, skill_file, body, errors)


def main() -> int:
    errors: list[str] = []
    if not SKILLS_ROOT.is_dir():
        fail(errors, SKILLS_ROOT, "skills root does not exist")
    else:
        skill_dirs = sorted(path for path in SKILLS_ROOT.iterdir() if path.is_dir())
        if not skill_dirs:
            fail(errors, SKILLS_ROOT, "no skill directories found")
        for skill_dir in skill_dirs:
            validate_skill(skill_dir, errors)

    if errors:
        print("Agent Skill validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    count = len([path for path in SKILLS_ROOT.iterdir() if path.is_dir()])
    print(f"Validated {count} Agent Skill(s) against repository rules.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
