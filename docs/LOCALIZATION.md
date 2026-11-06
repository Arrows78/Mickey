# Localization

Mickey is available in English (reference) and French. Adding a language needs no code change.

## How it works

- **The English text in the code is the key.** SwiftUI literals (`Text("Spotlight")`, `.help("…")`) are looked up
  automatically. Text built in code goes through `tr("…")`, or `trf("… %@ …", value)` when it holds values
  (`MickeyDomain/Localization.swift`). Display names of enums and settings (`title`, `detail`, `reason`…) call `tr`
  where they are defined, so every screen shows them translated.
- **Fallback chain.** A text without a translation is shown in English, so nothing is ever blank. The app's
  development language is `en` (`project.yml`).
- **Numbers in a text:** SwiftUI looks up `%@` for an interpolated literal. For a number, use
  `trf("Step %lld of %lld", a, b)` so the key is spelled exactly as written.
- **Never translate** identifiers, SF Symbol names, file names or log messages: they are not shown to the user.

## Files (`App/Resources`)

| File | Role |
| --- | --- |
| `en.lproj/Localizable.strings` | Reference table, generated from the code: every key maps to itself. Do not edit. |
| `<lang>.lproj/Localizable.strings` | The translations of every key of the reference table. |
| `<lang>.lproj/InfoPlist.strings` | Translations of the permission prompts (`NS…UsageDescription` of `project.yml`). |

## Everyday work

```sh
python3 scripts/l10n.py sync    # after adding or editing English text: regenerates en.lproj
python3 scripts/l10n.py check   # what CI runs: lists missing, obsolete or inconsistent translations
```

Editing an English text changes its key: `check` then reports the old key as unknown and the new one as missing in
every language, which is the list of translations to update.

## Adding a language

1. Create `App/Resources/<lang>.lproj/` (e.g. `es.lproj`) with `Localizable.strings` and `InfoPlist.strings`.
2. Add the code to `CFBundleLocalizations` in `project.yml`.
3. Run `python3 scripts/l10n.py check` and fill in what it lists. Keep the placeholders (`%@`, `%lld`) of each key.
4. Run `sh scripts/ci.sh`.
