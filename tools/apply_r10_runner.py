#!/usr/bin/env python3
"""Run apply_r10.py with a guarded whitespace-tolerant replace_once fallback."""
from pathlib import Path

src_path = Path('tools/apply_r10.py')
src = src_path.read_text(encoding='utf-8')
old = '''def replace_once(path, old, new):
    p = ROOT / path
    text = p.read_text(encoding='utf-8-sig')
    n = text.count(old)
    if n != 1:
        raise SystemExit(f'{path}: expected exactly one match, found {n}: {old[:100]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8', newline='\\n')
    print('patched', path)
'''
new = '''def replace_once(path, old, new):
    import re
    p = ROOT / path
    text = p.read_text(encoding='utf-8-sig')
    n = text.count(old)
    if n == 1:
        result = text.replace(old, new, 1)
    elif n == 0:
        parts = old.split()
        pattern = re.compile(r"\\s+".join(re.escape(part) for part in parts), re.MULTILINE)
        matches = list(pattern.finditer(text))
        if len(matches) != 1:
            raise SystemExit(f'{path}: exact=0, whitespace-normalized={len(matches)}: {old[:100]!r}')
        result = pattern.sub(lambda _m: new, text, count=1)
    else:
        raise SystemExit(f'{path}: expected exactly one match, found {n}: {old[:100]!r}')
    p.write_text(result, encoding='utf-8', newline='\\n')
    print('patched', path)
'''
if src.count(old) != 1:
    raise SystemExit('Could not replace guarded helper in apply_r10.py')
src = src.replace(old, new, 1)
exec(compile(src, str(src_path), 'exec'), {'__name__': '__main__', '__file__': str(src_path)})
