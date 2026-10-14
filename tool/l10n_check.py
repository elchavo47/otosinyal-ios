#!/usr/bin/env python3
"""OTOSINYAL localization check.

1. Every tx('...') key used under lib/ must have an English entry in
   lib/l10n/en_strings.dart.
2. No Turkish user-facing string literal may exist outside tx(...),
   except the allowlisted ones in tool/l10n_allow.txt.

Run from the repository root:  python3 tool/l10n_check.py
"""
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dartlex import scan_groups  # noqa: E402

TR = re.compile(r"[çğıöşüÇĞİÖŞÜ]")
SKIP_FILES = {'lib/data/vehicle_brands.dart', 'lib/data/brand_assets.dart', 'lib/l10n/en_strings.dart'}
SKIP_CALLEES = {'RegExp', 'log', 'debugPrint', 'print', 'replaceAll', 'replaceFirst', 'contains',
                'startsWith', 'endsWith', 'split', 'indexOf', 'containsKey', 'assert'}

try:
    from wordfreq import zipf_frequency as _z
except Exception:  # wordfreq is optional; character check still runs
    _z = None


def looks_turkish(text):
    if TR.search(text):
        return True
    if _z is None:
        return False
    for w in re.findall(r"[A-Za-z]{2,}", text):
        lw = w.replace('I', 'ı').lower()
        tz = max(_z(lw, 'tr'), _z(w.lower(), 'tr'))
        ez = _z(w.lower(), 'en')
        if tz >= 2.0 and tz > ez + 0.8:
            return True
    return False


def group_text(g):
    text, n = '', 0
    for s in g['strings']:
        for p in s['parts']:
            if p[0] == 'lit':
                text += p[1]
            else:
                text += '{%d}' % n
                n += 1
    return text, n


def callee_before(src, pos):
    depth = 0
    i = pos - 1
    while i >= 0:
        c = src[i]
        if c in ')]}':
            depth += 1
        elif c in '([{':
            if depth == 0:
                if c != '(':
                    return None
                m = re.search(r'([A-Za-z_][\w.]*)\s*$', src[:i])
                return m.group(1) if m else None
            depth -= 1
        elif c == ';':
            return None
        i -= 1
    return None


def load_en(path):
    src = open(path, encoding='utf8').read()
    body = src[src.index('{', src.index('enStrings')):]
    groups = [group_text(g)[0] for g in scan_groups(body)]
    if len(groups) % 2:
        raise SystemExit('en_strings.dart: odd number of literals')
    return dict(zip(groups[0::2], groups[1::2]))


def walk(src, rel, en, allow, problems, used):
    for g in scan_groups(src):
        text, nexpr = group_text(g)
        before = src[max(0, g['start'] - 3):g['start']]
        line = src.count('\n', 0, g['start']) + 1
        if before == 'tx(':
            if nexpr:
                problems.append(f'{rel}:{line}: tx() key must not contain interpolation: {text!r}')
            elif text not in en:
                problems.append(f'{rel}:{line}: missing English translation: {text!r}')
            used.add(text)
        else:
            prefix = src[src.rfind('\n', 0, g['start']) + 1:g['start']].lstrip()
            callee = callee_before(src, g['start'])
            annotation = re.search(r'@[A-Za-z_][\w.]*\s*\(\s*$', src[max(0, g['start'] - 80):g['start']])
            skip = (prefix.startswith(('import ', 'export ', 'part ')) or annotation
                    or (callee and callee.split('.')[-1] in SKIP_CALLEES)
                    or text in allow or not text.strip())
            if not skip and looks_turkish(text):
                problems.append(f'{rel}:{line}: untranslated Turkish literal: {text!r}')
        for s in g['strings']:
            for p in s['parts']:
                if p[0] == 'expr':
                    walk(p[1], rel, en, allow, problems, used)


def main():
    root = os.getcwd()
    en = load_en(os.path.join(root, 'lib/l10n/en_strings.dart'))
    allow_path = os.path.join(root, 'tool/l10n_allow.txt')
    allow = set()
    if os.path.exists(allow_path):
        for ln in open(allow_path, encoding='utf8'):
            ln = ln.rstrip('\n')
            if ln and not ln.startswith('#'):
                allow.add(ln.encode('utf8').decode('unicode_escape').encode('latin1').decode('utf8'))
    problems, used = [], set()
    for f in sorted(glob.glob(os.path.join(root, 'lib/**/*.dart'), recursive=True)):
        rel = os.path.relpath(f, root)
        if rel in SKIP_FILES:
            continue
        walk(open(f, encoding='utf8').read(), rel, en, allow, problems, used)
    for k, v in en.items():
        if TR.search(v):
            problems.append(f'en_strings.dart: English value contains Turkish characters: {v!r}')
        a = sorted(set(re.findall(r'\{\d+\}', k)))
        b = sorted(set(re.findall(r'\{\d+\}', v)))
        if a != b:
            problems.append(f'en_strings.dart: placeholder mismatch for {k!r}')
    print(f'{len(used)} keys used, {len(en)} translations, {len(set(en) - used)} unused')
    for p in problems:
        print(p)
    if problems:
        print(f'{len(problems)} localization problems')
        sys.exit(1)
    print('Localization OK')


if __name__ == '__main__':
    main()
