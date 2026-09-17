#!/usr/bin/env python3
"""Source-level audit for TravelRef data that Lua parsing cannot detect.

Lua silently accepts duplicate keys inside a table constructor, keeping only the
last value.  This scanner catches those mistakes before TR_Data.lua is executed.
"""
from __future__ import annotations

import re
from pathlib import Path

DATA = Path("Dusk/TravelRef/TR_Data.lua")
text = DATA.read_text(encoding="utf-8-sig")
lines = text.splitlines()

errors: list[str] = []
warnings: list[str] = []

field_re = re.compile(r"(?<![\[\w])([A-Za-z_][A-Za-z0-9_]*)\s*=")
row_re = re.compile(r'^\s*\[(["\']).+?\1\]\s*=\s*\{(.*)\}\s*,?\s*(?:--.*)?$')

for lineno, line in enumerate(lines, 1):
    match = row_re.match(line)
    if not match:
        continue
    body = match.group(2)
    seen: dict[str, int] = {}
    duplicates: list[str] = []
    for field in field_re.findall(body):
        seen[field] = seen.get(field, 0) + 1
        if seen[field] == 2:
            duplicates.append(field)
    if duplicates:
        errors.append(
            f"line {lineno}: duplicate field(s) {', '.join(duplicates)} :: {line.strip()}"
        )

    # Destination rows with swift-time but no swift cost are often a mistyped
    # `s=...` field.  Some legitimate metadata rows exist, so keep this a warning.
    fields = set(seen)
    if "st" in fields and "s" not in fields and "mt" not in fields and "n" not in fields:
        warnings.append(f"line {lineno}: st without s/mt/n :: {line.strip()}")

print(f"SOURCE_AUDIT: {len(lines)} lines, {len(errors)} errors, {len(warnings)} warnings")
for item in warnings:
    print("WARNING: " + item)
for item in errors:
    print("ERROR: " + item)

if errors:
    raise SystemExit(1)
