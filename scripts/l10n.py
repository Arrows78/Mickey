#!/usr/bin/env python3
"""Localization tooling. See docs/LOCALIZATION.md.

    python3 scripts/l10n.py sync    rewrite the English reference table from the sources
    python3 scripts/l10n.py check   verify every language against the sources (used by scripts/ci.sh)

The English text in the code is the key. A SwiftUI literal with an interpolation looks up "%@" (strings);
for a number use trf("... %lld ...", n) so the key is spelled exactly as written. App/Resources/en.lproj is the reference table (every key maps to
itself); every other App/Resources/<lang>.lproj must translate exactly the same keys. A language needs no
entry in this script: adding its folder is enough.
"""
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
RESOURCES = os.path.join(ROOT, 'App/Resources')
PROJECT = os.path.join(ROOT, 'project.yml')
REFERENCE = 'en'
TABLE = 'Localizable.strings'
INFO_TABLE = 'InfoPlist.strings'

LIT = r'"((?:[^"\\]|\\.)*)"'
# SwiftUI calls and shared components whose first string literal is shown to the user.
UI_PATTERNS = [
    r'\bText\(', r'\bLabel\(', r'\bButton\(', r'\bToggle\(', r'\.help\(', r'\.accessibilityLabel\(',
    r'\bconfirmationDialog\(', r'\bTextField\(', r'\bFeatureCard\(title: ', r'\bPageHeader\(title: ',
    r'\bsubtitle: ', r'\bdetail: ', r'\bNoteView\(text: ', r'\bPickerRow\(title: ', r'\bSliderRow\(title: ',
    r'\bColorRow\(title: ', r'\bToggleRow\(title: ', r'\bIntSliderRow\(title: ',
    # Help content: HelpEntry(id:, group:, title:, body:).
    r'\bgroup: ', r'\btitle: ', r'\bbody: ',
    # Commonly used shortcuts named in the hotkey conflict messages: common([modifiers], "key", "use").
    r'\bcommon\(\[[^\]]*\],\s*"[^"]*",\s*',
]
# Onboarding steps: ("sf.symbol", "Title", "Detail"); only the two texts count.
TUPLE_STEP = re.compile(r'^\s*\("[a-z0-9.]+",\s*' + LIT + r',\s*' + LIT + r'\)')
# Units read the same in every language, so they are not translated.
UNITS = {'fps', 'pt'}
PLACEHOLDER = re.compile(r'%(?:lld|lf|d|f|@)')


def unescape(s):
    return s.replace('\\"', '"').replace('\\n', '\n').replace('\\\\', '\\')


def escape(s):
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')


def parse_table(path):
    table = {}
    pair = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$')
    for line in open(path, encoding='utf-8'):
        m = pair.match(line)
        if m:
            table[unescape(m.group(1))] = unescape(m.group(2))
    return table


def normalize(key):
    """Key with every placeholder spelled the same, so %lld and %@ count as one."""
    return PLACEHOLDER.sub('%@', key)


def languages():
    return sorted(os.path.basename(p)[:-len('.lproj')] for p in glob.glob(os.path.join(RESOURCES, '*.lproj')))


def table_path(lang, name=TABLE):
    return os.path.join(RESOURCES, f'{lang}.lproj', name)


def literals_in_call(line, start):
    """String literals of the call whose opening parenthesis ends just before `start`, up to its closing one."""
    found, depth, i, n = [], 1, start, len(line)
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


def first_literal(line, start):
    m = re.compile(LIT).match(line, start)
    return m.group(1) if m else None


def interpolation_to_placeholder(lit):
    out, i = [], 0
    while i < len(lit):
        if lit.startswith('\\(', i):
            depth, j = 1, i + 2
            while j < len(lit) and depth:
                depth += (lit[j] == '(') - (lit[j] == ')')
                j += 1
            out.append('%@')
            i = j
        else:
            out.append(lit[i])
            i += 1
    return ''.join(out)


def is_text(key):
    """A key worth translating: it has words of its own, not just placeholders and symbols."""
    words = PLACEHOLDER.sub('', key).strip()
    return bool(re.search(r'[A-Za-z]{3,}', words)) and words not in UNITS and not key.startswith('system')


def code_keys():
    """Every user-visible text of the sources: {key: 'file:line'}."""
    keys = {}
    sources = glob.glob(os.path.join(ROOT, 'Packages/MickeyKit/Sources/**/*.swift'), recursive=True)
    sources += glob.glob(os.path.join(ROOT, 'App/Sources/*.swift'))
    for path in sorted(sources):
        for n, line in enumerate(open(path, encoding='utf-8'), 1):
            if line.strip().startswith('//'):
                continue
            found = []
            for m in re.finditer(r'\b(?:trf?|tooltip)\(', line):
                found += literals_in_call(line, m.end())  # both branches of a ternary count
            step = TUPLE_STEP.match(line)
            if step:
                found += list(step.groups())
            for pattern in UI_PATTERNS:
                for m in re.finditer(pattern, line):
                    lit = first_literal(line, m.end())
                    if lit is not None:
                        found.append(lit)
            for lit in found:
                key = interpolation_to_placeholder(lit)
                if is_text(key):
                    keys.setdefault(key, f'{os.path.relpath(path, ROOT)}:{n}')
    return keys


def write_table(path, header, table):
    lines = [header, '']
    lines += [f'"{escape(k)}" = "{escape(v)}";' for k, v in sorted(table.items())]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')


def sync():
    keys = code_keys()
    path = table_path(REFERENCE)
    table = {key: key for key in keys}
    write_table(path, '/* Reference table: generated by scripts/l10n.py sync. Do not edit by hand. */', table)
    print(f'{REFERENCE}: {len(table)} keys')
    return 0


def check():
    problems = []
    langs = languages()
    if REFERENCE not in langs:
        print(f'{REFERENCE}.lproj is missing: run scripts/l10n.py sync')
        return 1

    code = {normalize(k): where for k, where in code_keys().items()}
    reference = parse_table(table_path(REFERENCE))
    ref = {normalize(k): k for k in reference}
    for key, where in sorted(code.items()):
        if key not in ref:
            problems.append(f'{REFERENCE}: not in the reference table: "{key}" ({where}); run sync')
    for key in sorted(ref):
        if key not in code:
            problems.append(f'{REFERENCE}: unused key: "{ref[key]}"; run sync')

    for lang in langs:
        if lang == REFERENCE:
            continue
        table = parse_table(table_path(lang))
        norm = {normalize(k): k for k in table}
        for key in sorted(ref):
            if key not in norm:
                problems.append(f'{lang}: missing translation: "{ref[key]}"')
        for key in sorted(norm):
            if key not in ref:
                problems.append(f'{lang}: unknown key (renamed or removed in English?): "{norm[key]}"')
        for k, v in sorted(table.items()):
            if not v.strip():
                problems.append(f'{lang}: empty translation: "{k}"')
            elif PLACEHOLDER.findall(k) != PLACEHOLDER.findall(v):
                problems.append(f'{lang}: placeholders differ: "{k}"')
        for key in sorted(ref):
            if key in norm and norm[key] != ref[key]:
                problems.append(f'{lang}: key spelled differently from the reference: "{norm[key]}" vs "{ref[key]}"')

    # Languages declared to macOS must be exactly the ones that have a folder.
    declared = re.search(r'CFBundleLocalizations:\s*\[([^\]]*)\]', open(PROJECT, encoding='utf-8').read())
    declared = {s.strip() for s in declared.group(1).split(',')} if declared else set()
    if declared != set(langs):
        problems.append(f'project.yml CFBundleLocalizations {sorted(declared)} differs from the folders {langs}')

    # Permission prompts: every non-reference language translates each usage description of project.yml.
    usage = set(re.findall(r'\b(NS\w+UsageDescription)\b', open(PROJECT, encoding='utf-8').read()))
    for lang in langs:
        if lang == REFERENCE:
            continue
        path = table_path(lang, INFO_TABLE)
        have = set(parse_table(path)) if os.path.exists(path) else set()
        for key in sorted(usage - have):
            problems.append(f'{lang}: {INFO_TABLE} lacks {key}')
        for key in sorted(have - usage):
            problems.append(f'{lang}: {INFO_TABLE} has unknown {key}')

    for path in sorted(glob.glob(os.path.join(RESOURCES, '*.lproj', '*.strings'))):
        lint = subprocess.run(['plutil', '-lint', path], capture_output=True, text=True)
        if lint.returncode != 0:
            problems.append(lint.stdout.strip() or lint.stderr.strip())

    if problems:
        print('\n'.join(problems))
        print(f'\n{len(problems)} problem(s)')
        return 1
    others = [l for l in langs if l != REFERENCE]
    print(f'Localization OK: {len(reference)} keys, languages: {REFERENCE} (reference), {", ".join(others) or "none"}')
    return 0


if __name__ == '__main__':
    commands = {'sync': sync, 'check': check}
    if len(sys.argv) != 2 or sys.argv[1] not in commands:
        print(__doc__)
        sys.exit(2)
    sys.exit(commands[sys.argv[1]]())
