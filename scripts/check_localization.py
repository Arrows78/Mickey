#!/usr/bin/env python3
"""Checks the French strings file against the sources.

- every key used by tr()/trf() or a SwiftUI text literal has a French translation;
- every translation keeps the placeholders (%@, %lld) of its key;

Run from anywhere: python3 scripts/check_localization.py
"""
import glob
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
STRINGS = os.path.join(ROOT, 'App/Resources/fr.lproj/Localizable.strings')

# Keys that are the same in French (brand names, units, symbols) and need no entry.
SAME_IN_FRENCH = {
    'Mickey', 'Zoom', 'Microsoft Teams', 'FaceTime', 'Keynote', 'PowerPoint', 'QuickTime Player', 'OBS', 'Loom',
    'Webex', 'Discord', 'Mickey Settings.json', 'Space', '4K (3840 px)',
}

LIT = r'"((?:[^"\\]|\\.)*)"'
PATTERNS = [
    r'\bText\(' + LIT, r'\bLabel\(' + LIT, r'\bButton\(' + LIT, r'\bToggle\(' + LIT,
    r'\.help\(' + LIT, r'\.accessibilityLabel\(' + LIT, r'\bconfirmationDialog\(' + LIT,
    r'\bTextField\(' + LIT, r'\bFeatureCard\(title: ' + LIT, r'\bPageHeader\(title: ' + LIT,
    r'\bsubtitle: ' + LIT, r'\bdetail: ' + LIT, r'\bNoteView\(text: ' + LIT, r'\bPickerRow\(title: ' + LIT,
    r'\bSliderRow\(title: ' + LIT, r'\bColorRow\(title: ' + LIT, r'\bToggleRow\(title: ' + LIT,
    r'\bIntSliderRow\(title: ' + LIT, r'\bPermissionRow\(',
]


def parse_strings(path):
    table = {}
    pair = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$')
    for line in open(path, encoding='utf-8'):
        m = pair.match(line)
        if m:
            table[unescape(m.group(1))] = unescape(m.group(2))
    return table


def unescape(s):
    return s.replace('\\"', '"').replace('\\n', '\n').replace('\\\\', '\\')


def placeholders(s):
    return sorted(re.findall(r'%(?:lld|@|d|f)', s))


def tr_literals(line):
    """Every string literal inside tr(...) and trf(...) calls, including both branches of a ternary."""
    found = []
    for m in re.finditer(r'\btrf?\(', line):
        depth, i, n = 1, m.end(), len(line)
        while i < n and depth:
            c = line[i]
            if c == '"':
                j = i + 1
                while j < n and line[j] != '"':
                    j += 2 if line[j] == '\\' else 1
                found.append(line[i + 1:j])
                i = j
            elif c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
            i += 1
    return found


def main():
    table = parse_strings(STRINGS)
    used = {}
    sources = glob.glob(os.path.join(ROOT, 'Packages/MickeyKit/Sources/**/*.swift'), recursive=True)
    sources += glob.glob(os.path.join(ROOT, 'App/Sources/*.swift'))
    for path in sources:
        for n, line in enumerate(open(path, encoding='utf-8'), 1):
            if line.strip().startswith('//'):
                continue
            candidates = tr_literals(line)
            for pattern in PATTERNS:
                candidates += [m.group(1) for m in re.finditer(pattern, line) if m.groups()]
            for lit in candidates:
                if '\\(' in lit:
                    continue  # interpolated literals are checked through their trf() key
                if not re.search(r'[A-Za-z]{3,}', lit) or lit.startswith('system'):
                    continue
                used.setdefault(lit, f'{os.path.relpath(path, ROOT)}:{n}')

    problems = []
    for key, where in sorted(used.items()):
        if key in table or key in SAME_IN_FRENCH:
            continue
        problems.append(f'missing translation: "{key}" ({where})')
    for key, value in sorted(table.items()):
        if placeholders(key) != placeholders(value):
            problems.append(f'placeholders differ: "{key}"')
        if not value.strip():
            problems.append(f'empty translation: "{key}"')
    if problems:
        print('\n'.join(problems))
        print(f'\n{len(problems)} problem(s)')
        return 1
    print(f'Localization OK: {len(table)} French strings')
    return 0


if __name__ == '__main__':
    sys.exit(main())
