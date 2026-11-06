# Releasing

Versions, the changelog and the release notes all come from the git history: nothing is written by hand except the
commit messages. `scripts/release.py` does the rest.

## Commit messages

Commits follow [Conventional Commits](https://www.conventionalcommits.org): `type(scope): description`.

| Type | In the changelog | Version bump |
| --- | --- | --- |
| `feat` | Added | minor |
| `fix` | Fixed | patch |
| `perf`, `refactor` | Changed | patch |
| `docs`, `test`, `ci`, `build`, `chore`, `style` | not listed | none |
| any type with `!` or a `BREAKING CHANGE:` line | marked **BREAKING** | major, or minor while the version is 0.x |

Write the description for a user of the app, in the imperative ("glide in and out", not "added gliding"): it ends
up in the changelog as is. CI checks the subjects of every pull request (`release.py lint`).

## Releasing

```sh
python3 scripts/release.py prepare --dry-run    # which version, which entries
python3 scripts/release.py prepare              # bumps project.yml and App/Info.plist, rewrites CHANGELOG.md
git add -A && git commit -m "chore(release): 0.3.0"      # or run prepare with --commit
git tag v0.3.0 && git push origin main v0.3.0
```

- `prepare` picks the next version from the commits since the last `v*` tag; `--version X` forces one. It refuses
  when no commit belongs in a release. The build number goes up by one.
- The tag triggers `.github/workflows/release.yml`: version and changelog checks, tests, build, GitHub release, and
  the Homebrew tap (see `ARCHITECTURE.md`).
- The release notes are `docs/releases/<version>.md` when that file exists (use it for a hand-written text), and the
  changelog section of the version otherwise.

## What CI guards

`python3 scripts/release.py check` (run by `scripts/ci.sh`, by CI and by the release workflow) fails when:

- `App/Info.plist` and `project.yml` disagree on the version or the build number;
- the version of `project.yml` is behind the last tag, or has no section in `CHANGELOG.md`;
- the section of a released version no longer matches what the history produces, or the prepared section is stale
  because commits were added after `prepare` (run `prepare` again);
- the release workflow is started for a tag whose version differs from `project.yml`.

## Notes

- `CHANGELOG.md` is regenerated as a whole from the tags: never edit it by hand. Dates are ignored when comparing, so
  committing the day after `prepare` is fine.
- The first release is listed as "Initial release" instead of its commits.
- Only `v<major>.<minor>.<patch>` tags count. A tag pushed without a version bump makes the release workflow fail
  at its first check; delete it (`git push origin --delete vX.Y.Z`) and tag again once the version is bumped.
