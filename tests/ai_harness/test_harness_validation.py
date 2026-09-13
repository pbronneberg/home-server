"""Exercise packaging failures against disposable repositories."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def module(filename):
    spec = importlib.util.spec_from_file_location(filename, ROOT / 'scripts' / filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class HarnessValidationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.skills = module('check-agent-skills.py')
        self.skills.ROOT = self.root
        self.skills.SKILLS_ROOT = self.root / '.agents/skills'

    def write(self, path, text):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)
        return target

    def skill(self, extra='', body='Use this workflow.'):
        return self.write('.agents/skills/example/SKILL.md',
                          '---\nname: example\ndescription: Example workflow.\n'
                          + extra + '---\n' + body).parent

    def errors(self, skill):
        errors = []
        self.skills.validate_skill(skill, errors)
        return errors

    def test_complete_skill(self):
        self.assertEqual([], self.errors(self.skill()))

    def test_malformed_frontmatter_returns_error(self):
        skill = self.skill()
        (skill / 'SKILL.md').write_text('No frontmatter.')
        self.assertTrue(self.errors(skill))

    def test_reference_dependency_and_nested_reference(self):
        skill = self.skill(body='Read [reference](references/guide.md).')
        self.write('.agents/skills/example/references/guide.md',
                   'Read [missing](missing.md).')
        self.assertTrue(any('missing local file' in e for e in self.errors(skill)))

    def test_missing_skill_dependency(self):
        skill = self.skill('metadata:\n  requires-skills: absent\n')
        self.assertTrue(any('absent' in e for e in self.errors(skill)))

    def test_dependency_after_delimiter_in_scalar(self):
        skill = self.skill('metadata:\n  note: "Shape --- deliver"\n  requires-skills: absent\n')
        self.assertTrue(any('absent' in e for e in self.errors(skill)))

    def test_dependency_with_four_space_indent(self):
        skill = self.skill('metadata:\n    requires-skills: absent\n')
        self.assertTrue(any('absent' in e for e in self.errors(skill)))

    def test_valid_skill_dependency(self):
        skill = self.skill('metadata:\n  requires-skills: helper\n')
        self.write('.agents/skills/helper/SKILL.md',
                   '---\nname: helper\ndescription: Helper.\n---\nHelp.')
        self.assertEqual([], self.errors(skill))

    def test_invalid_invocation_policy(self):
        skill = self.skill()
        self.write('.agents/skills/example/agents/openai.yaml',
                   'policy:\n  allow_implicit_invocation: maybe\n')
        self.assertTrue(any('allow_implicit_invocation' in e for e in self.errors(skill)))

    def test_explicit_invocation_policy(self):
        skill = self.skill()
        self.write('.agents/skills/example/agents/openai.yaml',
                   'policy:\n  allow_implicit_invocation: false\n')
        self.assertEqual([], self.errors(skill))

    def test_missing_pipeline_agents(self):
        pipeline = module('check-agent-pipeline.py')
        errors = pipeline.validate(self.root)
        self.assertTrue(any('missing agent' in e for e in errors))

    def test_independent_reviewer_is_required(self):
        pipeline = module('check-agent-pipeline.py')
        self.assertTrue(any('reviewer: missing agent' in e
                            for e in pipeline.validate(self.root)))

    def test_unregistered_agent_is_rejected(self):
        pipeline = module('check-agent-pipeline.py')
        self.write('.github/agents/duplicate-review.agent.md', '# Obsolete role')
        self.assertTrue(any('unregistered agent: duplicate-review' in e
                            for e in pipeline.validate(self.root)))

    def test_platform_rules_are_required_without_selecting_specialist(self):
        pipeline = module('check-agent-pipeline.py')
        self.write('.github/instructions/agent-pipeline.instructions.md', 'Shared contract.')
        self.assertTrue(any('home-platform.instructions.md' in e
                            for e in pipeline.validate(self.root)))

    def test_platform_instruction_references_are_checked(self):
        pipeline = module('check-agent-pipeline.py')
        self.write('.github/instructions/home-platform.instructions.md',
                   'Read [authentication](platform-auth.instructions.md).')
        self.assertTrue(any('missing or external local reference platform-auth.instructions.md' in e
                            for e in pipeline.validate(self.root)))

    def pipeline_fixture(self):
        pipeline = module('check-agent-pipeline.py')
        for slug in pipeline.AGENTS:
            self.write('.codex/agents/' + slug + '.toml',
                       f'name = "{slug}"\ndescription = "Example."\n'
                       + 'model_reasoning_effort = "medium"\n'
                       + 'developer_instructions = """\n'
                       + 'Read .github/instructions/repository.instructions.md\n'
                       + '\n'.join('## ' + h + '\nDetails.' for h in pipeline.HEADINGS)
                       + '\n"""\n')
            self.write('.github/agents/' + slug + '.agent.md',
                       f'---\nname: {slug}\ndescription: Example.\n---\n'
                       + f'Read [role](../../.codex/agents/{slug}.toml).')
        for name in pipeline.REQUIRED_INSTRUCTIONS:
            self.write('.github/instructions/' + name + '.instructions.md', 'Shared contract.')
        for entry in ('AGENTS.md', '.github/copilot-instructions.md'):
            self.write(entry, 'Read .github/instructions/repository.instructions.md')
        return pipeline

    def test_complete_pipeline(self):
        self.assertEqual([], self.pipeline_fixture().validate(self.root))

    def test_pipeline_rejects_missing_skill(self):
        pipeline = self.pipeline_fixture()
        path = self.root / '.codex/agents/coder.toml'
        path.write_text(path.read_text().replace('Details.', 'Use skill:absent.'))
        self.assertTrue(any('absent' in e for e in pipeline.validate(self.root)))

    def test_reasoning_effort_required_and_valid(self):
        pipeline = self.pipeline_fixture()
        path = self.root / '.codex/agents/coder.toml'
        original = path.read_text()
        for replacement in ('', 'model_reasoning_effort = "expensive"\n',
                            'model_reasoning_effort = 42\n'):
            with self.subTest(replacement=replacement):
                path.write_text(original.replace('model_reasoning_effort = "medium"\n', replacement))
                self.assertTrue(any('reasoning effort' in e for e in pipeline.validate(self.root)))

    def test_missing_stage_contract(self):
        pipeline = self.pipeline_fixture()
        path = self.root / '.codex/agents/coder.toml'
        path.write_text(path.read_text().replace('## Handoff', '## Omitted'))
        self.assertTrue(any('missing Handoff' in e for e in pipeline.validate(self.root)))

    def test_malformed_codex_agent(self):
        pipeline = self.pipeline_fixture()
        self.write('.codex/agents/coder.toml', 'name = [')
        self.assertTrue(any('invalid TOML' in e for e in pipeline.validate(self.root)))

    def test_copilot_must_load_own_role(self):
        pipeline = self.pipeline_fixture()
        self.write('.github/agents/coder.agent.md',
                   '---\nname: coder\ndescription: Example.\n---\nRead another role.')
        self.assertTrue(any('missing canonical role reference' in e
                            for e in pipeline.validate(self.root)))

    def test_missing_copilot_adapter(self):
        pipeline = self.pipeline_fixture()
        (self.root / '.github/agents/coder.agent.md').unlink()
        self.assertTrue(any('missing Copilot adapter' in e for e in pipeline.validate(self.root)))

    def test_broken_role_reference(self):
        pipeline = self.pipeline_fixture()
        path = self.root / '.codex/agents/coder.toml'
        path.write_text(path.read_text().replace('Details.', 'Read [missing](missing.md).'))
        self.assertTrue(any('missing or external local reference' in e
                            for e in pipeline.validate(self.root)))

    def test_shared_contract_dependencies(self):
        pipeline = module('check-agent-pipeline.py')
        self.write('.github/instructions/agent-pipeline.instructions.md', 'Use `skill:absent`.')
        self.assertTrue(any('unresolved skill dependency absent' in e for e in pipeline.validate(self.root)))


if __name__ == '__main__':
    unittest.main()
