"""Minimal Dart lexer for string literals (with interpolation) and comments."""
import re

IDENT_START = re.compile(r'[A-Za-z_]')
IDENT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')

SIMPLE_ESC = {'n': '\n', 't': '\t', 'r': '\r', 'b': '\b', 'f': '\f', 'v': '\v',
              '\\': '\\', "'": "'", '"': '"', '$': '$'}


def skip_comment(src, i):
    """If a comment starts at i, return index after it, else None."""
    if src.startswith('//', i):
        j = src.find('\n', i)
        return len(src) if j < 0 else j
    if src.startswith('/*', i):
        depth = 0
        j = i
        while j < len(src):
            if src.startswith('/*', j):
                depth += 1
                j += 2
            elif src.startswith('*/', j):
                depth -= 1
                j += 2
                if depth == 0:
                    return j
            else:
                j += 1
        return len(src)
    return None


def is_string_start(src, i):
    c = src[i]
    if c in '\'"':
        return True
    if c == 'r' and i + 1 < len(src) and src[i + 1] in '\'"':
        prev = src[i - 1] if i > 0 else ' '
        return not (prev.isalnum() or prev in '_$')
    return False


def find_expr_end(src, i):
    """src[i] is the first char after '${'. Return index of matching '}'."""
    depth = 0
    j = i
    while j < len(src):
        c = src[j]
        cm = skip_comment(src, j)
        if cm is not None:
            j = cm
            continue
        if is_string_start(src, j):
            j, _ = parse_string(src, j)
            continue
        if c in '({[':
            depth += 1
        elif c in ')]':
            depth -= 1
        elif c == '}':
            if depth == 0:
                return j
            depth -= 1
        j += 1
    raise ValueError('unterminated interpolation at %d' % i)


def parse_string(src, i):
    """Parse one string literal starting at i. Returns (end, info).
    info = dict(raw, quote, triple, parts=[('lit', text) | ('expr', code, abs_start, abs_end, braced)])"""
    raw = False
    start = i
    if src[i] == 'r':
        raw = True
        i += 1
    q = src[i]
    triple = src.startswith(q * 3, i)
    ql = 3 if triple else 1
    j = i + ql
    parts = []
    buf = []
    while True:
        if j >= len(src):
            raise ValueError('unterminated string at %d' % start)
        if src.startswith(q * ql, j):
            j += ql
            break
        c = src[j]
        if not raw and c == '\\':
            n = src[j + 1]
            if n in SIMPLE_ESC:
                buf.append(SIMPLE_ESC[n]); j += 2
            elif n == 'x':
                buf.append(chr(int(src[j + 2:j + 4], 16))); j += 4
            elif n == 'u':
                if src[j + 2] == '{':
                    k = src.index('}', j)
                    buf.append(chr(int(src[j + 3:k], 16))); j = k + 1
                else:
                    buf.append(chr(int(src[j + 2:j + 6], 16))); j += 6
            elif n == '\n':
                buf.append('\n'); j += 2
            else:
                buf.append(n); j += 2
        elif not raw and c == '$':
            if src[j + 1] == '{':
                k = find_expr_end(src, j + 2)
                parts.append(('lit', ''.join(buf))); buf = []
                parts.append(('expr', src[j + 2:k], j + 2, k, True))
                j = k + 1
            else:
                m = IDENT.match(src, j + 1)
                if not m:
                    buf.append('$'); j += 1
                else:
                    parts.append(('lit', ''.join(buf))); buf = []
                    parts.append(('expr', m.group(), m.start(), m.end(), False))
                    j = m.end()
        else:
            buf.append(c); j += 1
    parts.append(('lit', ''.join(buf)))
    return j, dict(raw=raw, quote=q, triple=triple, parts=parts, start=start)


def scan_groups(src):
    """Yield string groups (adjacent literals) at top level of src.
    Each group: dict(start, end, strings=[info,...])"""
    i = 0
    n = len(src)
    while i < n:
        cm = skip_comment(src, i)
        if cm is not None:
            i = cm
            continue
        if is_string_start(src, i):
            strings = []
            gstart = i
            end = i
            while True:
                end, info = parse_string(src, i)
                info['end'] = end
                strings.append(info)
                # look ahead for adjacent string
                k = end
                while True:
                    while k < n and src[k] in ' \t\r\n':
                        k += 1
                    cm2 = skip_comment(src, k)
                    if cm2 is not None:
                        k = cm2
                        continue
                    break
                if k < n and is_string_start(src, k):
                    i = k
                    continue
                break
            yield dict(start=gstart, end=end, strings=strings)
            i = end
            continue
        i += 1


def code_mask(src):
    """Return list of booleans: True if char is code (not in string/comment)."""
    mask = [True] * len(src)
    i = 0
    n = len(src)
    while i < n:
        cm = skip_comment(src, i)
        if cm is not None:
            for k in range(i, cm):
                mask[k] = False
            i = cm
            continue
        if is_string_start(src, i):
            end, _ = parse_string(src, i)
            for k in range(i, end):
                mask[k] = False
            i = end
            continue
        i += 1
    return mask
