#!/usr/bin/env python3
"""Validate Codex roles and Copilot discovery; not model behavior or human gates."""
from pathlib import Path
import re
import sys
import tomllib

ROOT = Path(__file__).resolve().parents[1]
AGENTS = ('pipeline-coordinator', 'specifier', 'coder', 'reviewer')
HEADINGS = ('Stage contract', 'Inputs', 'Work', 'Exit criteria', 'Handoff')
REQUIRED_INSTRUCTIONS = ('repository', 'agent-pipeline', 'home-platform', 'platform-auth')


def validate(root: Path) -> list[str]:
    errors = []
    for directory, suffix in (('.codex/agents', '.toml'), ('.github/agents', '.agent.md')):
        for path in sorted((root / directory).rglob('*' + suffix)):
            name = path.name.removesuffix(suffix)
            if name not in AGENTS or path.parent != root / directory:
                errors.append(f'unregistered agent: {name}; update the role registry deliberately')
    for slug in AGENTS:
        path = root / '.codex/agents' / (slug + '.toml')
        if not path.is_file():
            errors.append(f'{slug}: missing agent')
        else:
            try:
                fields = tomllib.loads(path.read_text(encoding='utf-8'))
            except tomllib.TOMLDecodeError as error:
                errors.append(f'{slug}: invalid TOML: {error}')
                fields = {}
            if set(fields) != {'name', 'description', 'developer_instructions', 'model_reasoning_effort'}:
                errors.append(f'{slug}: expected name, description, developer_instructions, model_reasoning_effort only')
            effort = fields.get('model_reasoning_effort')
            if not isinstance(effort, str) or effort not in ('low', 'medium', 'high', 'xhigh', 'max', 'ultra'):
                errors.append(f'{slug}: missing or invalid reasoning effort')
            if fields.get('name') != slug:
                errors.append(f'{slug}: expected name {slug}')
            if not isinstance(fields.get('description'), str) or not fields.get('description', '').strip():
                errors.append(f'{slug}: missing description')
            body = fields.get('developer_instructions', '')
            if not isinstance(body, str):
                errors.append(f'{slug}: instructions must be text')
            else:
                for heading in HEADINGS:
                    if not re.search(r'^## ' + re.escape(heading) + r'\s*$', body, re.M):
                        errors.append(f'{slug}: missing {heading}')
                if '.github/instructions/repository.instructions.md' not in body:
                    errors.append(f'{slug}: missing repository instruction routing')
                validate_references(root, path, body, errors)
        adapter = root / '.github/agents' / (slug + '.agent.md')
        if not adapter.is_file():
            errors.append(f'{slug}: missing Copilot adapter')
            continue
        text = adapter.read_text(encoding='utf-8')
        header = re.match(r'\A---\n(.*?)\n---\n', text, re.S)
        fields = dict(re.findall(r'^([\w-]+):\s*(.+)$', header[1], re.M)) if header else {}
        if set(fields) != {'name', 'description'} or fields.get('name', '').strip('"\'') != slug:
            errors.append(f'{slug}: invalid Copilot metadata')
        if not fields.get('description', '').strip('"\' '):
            errors.append(f'{slug}: missing Copilot description')
        target = f'../../.codex/agents/{slug}.toml'
        if target not in re.findall(r'\[[^\]]*\]\(([^)]+)\)', text):
            errors.append(f'{slug}: missing canonical role reference')
        validate_references(root, adapter, text, errors)
    instructions = root / '.github/instructions'
    for name in REQUIRED_INSTRUCTIONS:
        path = instructions / (name + '.instructions.md')
        if not path.is_file():
            errors.append(f'missing shared contract: {path.relative_to(root)}')
    for path in sorted(instructions.glob('*.instructions.md')):
        validate_references(root, path, path.read_text(encoding='utf-8'), errors)
    for entry in ('AGENTS.md', '.github/copilot-instructions.md'):
        path = root / entry
        if not path.is_file():
            errors.append(f'{entry}: missing host entry point')
        else:
            text = path.read_text(encoding='utf-8')
            if '.github/instructions/repository.instructions.md' not in text:
                errors.append(f'{entry}: missing repository instruction routing')
            validate_references(root, path, text, errors)
    return errors


def validate_references(root: Path, path: Path, text: str, errors: list[str]) -> None:
    label = str(path.relative_to(root))
    for dependency in re.findall(r'\bskill:([a-z0-9-]+)', text):
        if not (root / '.agents/skills' / dependency / 'SKILL.md').is_file():
            errors.append(f'{label}: unresolved skill dependency {dependency}')
    for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', text):
        if target.startswith(('https://', 'http://', '#')):
            continue
        resolved = (path.parent / target.split('#')[0]).resolve()
        if not resolved.is_relative_to(root.resolve()) or not resolved.exists():
            errors.append(f'{label}: missing or external local reference {target}')


def main() -> int:
    errors = validate(ROOT)
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        return 1
    print(f'Validated {len(AGENTS)} Codex roles and Copilot entry points (structure only).')
    return 0


if __name__ == '__main__':
    sys.exit(main())
