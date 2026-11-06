"""Tests of scripts/release.py. Run: python3 -m unittest discover -s scripts/tests"""
import contextlib
import io
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import release  # noqa: E402

C = release.Commit


class SubjectTests(unittest.TestCase):
    def test_parses_type_scope_and_description(self):
        c = C('feat(zoom): glide in and out')
        self.assertEqual((c.type, c.scope, c.description), ('feat', 'zoom', 'glide in and out'))
        self.assertFalse(c.breaking)

    def test_scope_is_optional(self):
        c = C('ci: run the tests')
        self.assertEqual((c.type, c.scope), ('ci', None))

    def test_a_bang_or_a_body_marks_a_breaking_change(self):
        self.assertTrue(C('feat(api)!: drop the old format').breaking)
        self.assertTrue(C('fix: change the file format', 'BREAKING CHANGE: old files are not read').breaking)

    def test_a_free_form_subject_has_no_type(self):
        c = C('Update readme')
        self.assertIsNone(c.type)
        self.assertEqual(c.description, 'Update readme')


class VersionTests(unittest.TestCase):
    def test_a_feature_is_a_minor_bump_and_a_fix_a_patch(self):
        self.assertEqual(release.bump_kind((1, 2, 3), [C('feat: a'), C('fix: b')]), 'minor')
        self.assertEqual(release.bump_kind((1, 2, 3), [C('fix: b'), C('docs: c')]), 'patch')
        self.assertEqual(release.bump_kind((1, 2, 3), [C('perf: b')]), 'patch')

    def test_nothing_that_belongs_in_a_release_gives_no_bump(self):
        self.assertIsNone(release.bump_kind((1, 2, 3), [C('docs: a'), C('ci: b'), C('test: c'), C('chore(release): 1.2.3')]))
        self.assertIsNone(release.bump_kind((1, 2, 3), []))

    def test_a_breaking_change_is_major_once_stable_and_minor_before(self):
        self.assertEqual(release.bump_kind((1, 2, 3), [C('fix!: a')]), 'major')
        self.assertEqual(release.bump_kind((0, 2, 3), [C('fix!: a')]), 'minor')

    def test_bumping_resets_the_lower_numbers(self):
        self.assertEqual(release.bumped((1, 2, 3), 'major'), (2, 0, 0))
        self.assertEqual(release.bumped((1, 2, 3), 'minor'), (1, 3, 0))
        self.assertEqual(release.bumped((1, 2, 3), 'patch'), (1, 2, 4))

    def test_versions_parse_and_format(self):
        self.assertEqual(release.parse_version('0.10.2'), (0, 10, 2))
        self.assertEqual(release.format_version((0, 10, 2)), '0.10.2')
        with self.assertRaises(ValueError):
            release.parse_version('1.2')


class ChangelogTests(unittest.TestCase):
    commits = [C('fix(ui): tooltips come faster'), C('docs: readme'), C('feat(zoom): glide in and out'),
               C('feat!: new format'), C('refactor(core): split a module'), C('chore(release): 1.0.0')]

    def test_entries_are_grouped_oldest_first_with_scope_and_capital(self):
        e = release.entries(self.commits)
        self.assertEqual(e['Added'], ['- **BREAKING** New format', '- **zoom**: Glide in and out'])
        self.assertEqual(e['Fixed'], ['- **ui**: Tooltips come faster'])
        self.assertEqual(e['Changed'], ['- **core**: Split a module'])

    def test_other_types_stay_out(self):
        text = release.render_section('1.0.0', '2026-01-02', self.commits)
        self.assertNotIn('readme', text)
        self.assertNotIn('chore', text)

    def test_the_sections_come_in_a_fixed_order(self):
        text = release.render_section('1.0.0', '2026-01-02', self.commits)
        self.assertLess(text.index('### Added'), text.index('### Changed'))
        self.assertLess(text.index('### Changed'), text.index('### Fixed'))
        self.assertTrue(text.startswith('## [1.0.0] - 2026-01-02\n'))

    def test_a_release_of_internal_changes_says_so(self):
        self.assertIn('Internal changes only.', release.render_section('1.0.1', '2026-01-02', [C('fix: x')][:0]))

    def test_the_first_release_is_just_announced(self):
        self.assertIn('Initial release.', release.render_section('0.1.0', '2026-01-02', self.commits, initial=True))

    def test_a_section_is_found_by_version_and_stops_at_the_next(self):
        log = '# Changelog\n\n## [1.1.0] - 2026-02-01\n\n### Added\n\n- B\n\n## [1.0.0] - 2026-01-01\n\n### Added\n\n- A\n\n[1.1.0]: x\n[1.0.0]: y\n'
        self.assertEqual(release.section_of(log, '1.1.0'), '### Added\n\n- B\n')
        self.assertEqual(release.section_of(log, '1.0.0'), '### Added\n\n- A\n')
        self.assertIsNone(release.section_of(log, '2.0.0'))
        self.assertIsNone(release.section_of(log, '1.1'))

    def test_dates_are_ignored_when_comparing(self):
        a = '## [1.0.0] - 2026-01-01\n\n- A\n'
        b = '## [1.0.0] - 2026-03-09\n\n- A\n'
        self.assertEqual(release.without_dates(a), release.without_dates(b))


class LintTests(unittest.TestCase):
    def test_valid_subjects(self):
        for s in ('feat: a', 'fix(ui): b', 'chore(release): 1.0.0', 'refactor(i18n)!: c', 'Merge branch main'):
            self.assertIsNone(release.lint_subject(s), s)

    def test_invalid_subjects(self):
        for s in ('Update readme', 'feature: a', 'fix:no space', 'fix(ui) a', 'feat: ' + 'x' * 100):
            self.assertIsNotNone(release.lint_subject(s), s)


class VersionFilesTests(unittest.TestCase):
    yml = '    info:\n      properties:\n        CFBundleShortVersionString: "0.2.0"\n        CFBundleVersion: "3"\n        LSUIElement: true\n'

    def test_project_yml_is_read_and_updated(self):
        self.assertEqual(release.project_version(self.yml), ('0.2.0', '3'))
        out = release.set_project_version(self.yml, '0.3.0', '4')
        self.assertEqual(release.project_version(out), ('0.3.0', '4'))
        self.assertIn('LSUIElement: true', out)

    def test_project_yml_without_versions_is_refused(self):
        with self.assertRaises(SystemExit):
            release.set_project_version('name: Mickey\n', '1.0.0', '1')

    def test_the_plist_keeps_its_keys_and_order(self):
        raw = plistlib.dumps({'CFBundleName': 'Mickey', 'CFBundleShortVersionString': '0.2.0', 'CFBundleVersion': '3', 'Z': 1}, sort_keys=False)
        out = plistlib.loads(release.set_plist_version(raw, '0.3.0', '4'))
        self.assertEqual(list(out), ['CFBundleName', 'CFBundleShortVersionString', 'CFBundleVersion', 'Z'])
        self.assertEqual((out['CFBundleShortVersionString'], out['CFBundleVersion']), ('0.3.0', '4'))


class RepositoryTests(unittest.TestCase):
    """The whole flow on a throwaway git repository."""

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.root = Path(self.dir.name)
        self.addCleanup(self.dir.cleanup)
        for name, value in (('ROOT', self.root), ('CHANGELOG', self.root / 'CHANGELOG.md'), ('PROJECT', self.root / 'project.yml'),
                            ('INFO_PLIST', self.root / 'Info.plist')):
            patcher = mock.patch.object(release, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.git('init', '-q', '-b', 'main')
        self.git('config', 'user.name', 'Test')
        self.git('config', 'user.email', 'test@example.com')
        self.git('remote', 'add', 'origin', 'git@github.com:acme/app.git')
        (self.root / 'project.yml').write_text(VersionFilesTests.yml.replace('0.2.0', '0.1.0').replace('"3"', '"1"'))
        (self.root / 'Info.plist').write_bytes(plistlib.dumps(
            {'CFBundleShortVersionString': '0.1.0', 'CFBundleVersion': '1'}, sort_keys=False))
        self.commit('feat: first version')
        self.git('tag', 'v0.1.0')

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.root, capture_output=True, text=True, check=True).stdout

    def commit(self, subject, body=''):
        path = self.root / 'work.txt'
        path.write_text(path.read_text() + subject + '\n' if path.exists() else subject + '\n')
        self.git('add', '-A')
        self.git('commit', '-q', '-m', subject + ('\n\n' + body if body else ''))

    def run_cmd(self, *argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            code = release.main(list(argv))
        return code, out.getvalue()

    def test_tags_are_sorted_as_versions(self):
        self.git('tag', 'v0.10.0')
        self.git('tag', 'v0.9.0')
        self.git('tag', 'not-a-release')
        self.assertEqual(release.release_tags(), ['v0.1.0', 'v0.9.0', 'v0.10.0'])

    def test_the_next_version_follows_the_commits(self):
        self.commit('docs: words')
        self.assertEqual(self.run_cmd('next')[0], 1)
        self.commit('fix(ui): a bug')
        self.assertEqual(self.run_cmd('next'), (0, '0.1.1\n'))
        self.commit('feat(zoom): a feature')
        self.assertEqual(self.run_cmd('next'), (0, '0.2.0\n'))

    def test_prepare_bumps_every_file_and_check_agrees(self):
        self.commit('feat(zoom): a feature')
        self.commit('fix(ui): a bug')
        code, out = self.run_cmd('prepare', '--commit')
        self.assertEqual(code, 0, out)
        self.assertEqual(release.project_version(), ('0.2.0', '2'))
        plist = plistlib.loads((self.root / 'Info.plist').read_bytes())
        self.assertEqual((plist['CFBundleShortVersionString'], plist['CFBundleVersion']), ('0.2.0', '2'))
        log = (self.root / 'CHANGELOG.md').read_text()
        self.assertIn('## [0.2.0]', log)
        self.assertIn('- **zoom**: A feature', log)
        self.assertIn('[0.2.0]: https://github.com/acme/app/compare/v0.1.0...v0.2.0', log)
        self.assertEqual(self.git('log', '-1', '--format=%s').strip(), 'chore(release): 0.2.0')
        code, out = self.run_cmd('check')
        self.assertEqual(code, 0, out)
        self.git('tag', 'v0.2.0')
        code, out = self.run_cmd('check')
        self.assertEqual(code, 0, out)
        self.assertEqual(self.run_cmd('notes', '0.2.0')[0], 0)

    def test_notes_are_the_section_of_the_version(self):
        self.commit('feat: a feature')
        self.run_cmd('prepare')
        code, out = self.run_cmd('notes', '0.2.0')
        self.assertEqual(code, 0)
        self.assertTrue(out.startswith('### Added'))
        self.assertEqual(self.run_cmd('notes', '9.9.9')[0], 1)

    def test_prepare_refuses_when_there_is_nothing_to_release(self):
        self.commit('docs: words')
        code, out = self.run_cmd('prepare')
        self.assertEqual(code, 1)
        self.assertIn('nothing to release', out)
        self.assertEqual(release.project_version()[0], '0.1.0')

    def test_prepare_refuses_a_version_that_is_not_newer(self):
        self.commit('feat: a feature')
        self.assertEqual(self.run_cmd('prepare', '--version', '0.1.0')[0], 1)

    def test_a_dry_run_changes_nothing(self):
        self.commit('feat: a feature')
        code, out = self.run_cmd('prepare', '--dry-run')
        self.assertEqual(code, 0)
        self.assertIn('0.1.0 -> 0.2.0', out)
        self.assertFalse((self.root / 'CHANGELOG.md').exists())
        self.assertEqual(release.project_version()[0], '0.1.0')

    def test_check_catches_a_changelog_that_went_stale(self):
        self.commit('feat: a feature')
        self.run_cmd('prepare')
        self.commit('fix: one more thing after the changelog was written')
        code, out = self.run_cmd('check')
        self.assertEqual(code, 1)
        self.assertIn('out of date', out)

    def test_check_catches_a_plist_that_differs_from_the_project(self):
        self.commit('feat: a feature')
        self.run_cmd('prepare')
        (self.root / 'Info.plist').write_bytes(plistlib.dumps(
            {'CFBundleShortVersionString': '0.1.0', 'CFBundleVersion': '1'}, sort_keys=False))
        code, out = self.run_cmd('check')
        self.assertEqual(code, 1)
        self.assertIn('differs from project.yml', out)

    def test_check_catches_a_version_without_a_changelog_section(self):
        (self.root / 'CHANGELOG.md').write_text(release.build_changelog().replace('## [0.1.0]', '## [0.0.9]'))
        code, out = self.run_cmd('check')
        self.assertEqual(code, 1)
        self.assertIn('no section', out)

    def test_lint_reports_the_bad_subjects_of_a_range(self):
        self.commit('feat: fine')
        self.commit('Fixed a thing')
        code, out = self.run_cmd('lint', 'v0.1.0..HEAD')
        self.assertEqual(code, 1)
        self.assertIn('Fixed a thing', out)
        self.assertNotIn('"feat: fine"', out)

    def test_the_first_release_is_announced_not_listed(self):
        text = release.build_changelog()
        self.assertIn('Initial release.', text)
        self.assertNotIn('first version', text)


if __name__ == '__main__':
    unittest.main()
