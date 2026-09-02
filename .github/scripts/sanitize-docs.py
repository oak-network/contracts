#!/usr/bin/env python3
"""Sanitize forge-doc output: rewrite absolute machine paths in markdown links.

Some forge versions emit inter-doc links as absolute filesystem paths of the
machine that ran `forge doc` (e.g. `/Users/<name>/.../docs/src/src/interfaces/...`).
This script rewrites any link target containing `/docs/src/` to the correct
path relative to the file containing the link. Idempotent; stdlib only.

Usage: sanitize-docs.py <docs-src-dir>
Exits non-zero - without modifying any file - if a rewritten target does not
exist under <docs-src-dir> (catches upstream layout changes instead of
committing broken links). All rewrites are computed in memory first, so a
failed run leaves the tree untouched and fails the same way when re-run.
"""

from __future__ import annotations

import os
import re
import sys

# Matches links whose target is an absolute path into a forge-doc output root -
# either the committed layout (docs/src/) or the CI temp layout (.forgedoc-tmp/src/).
# Anything that slips through is caught by the grep guard in docs.yml.
LINK_PATTERN = re.compile(r"\((/[^\s)]*?/(?:docs|\.forgedoc-tmp)/src/([^\s)]+))\)")


def sanitize_file(path: str, docs_src_root: str) -> tuple[str | None, int, list[str]]:
    """Computes the rewrite of absolute /…/docs/src/… links in one file.

    Does not write anything. Returns (rewritten content, or None if no links
    matched; number of rewrites; rewritten targets that don't exist).
    """
    with open(path, encoding="utf-8") as fh:
        content = fh.read()

    broken: list[str] = []
    file_dir = os.path.dirname(path)

    def replace(match: re.Match) -> str:
        suffix = match.group(2)
        target_abs = os.path.join(docs_src_root, suffix)
        target_file = target_abs.split("#", 1)[0]
        if not os.path.exists(target_file):
            broken.append(suffix)
        relative = os.path.relpath(target_abs, file_dir)
        return f"({relative})"

    updated, count = LINK_PATTERN.subn(replace, content)
    return (updated if count > 0 else None), count, broken


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: sanitize-docs.py <docs-src-dir>", file=sys.stderr)
        return 2
    docs_src_root = os.path.abspath(sys.argv[1])
    if not os.path.isdir(docs_src_root):
        print(f"error: not a directory: {docs_src_root}", file=sys.stderr)
        return 2

    total = 0
    all_broken: list[str] = []
    pending: list[tuple[str, str]] = []
    for dirpath, _dirnames, filenames in os.walk(docs_src_root):
        for filename in filenames:
            if filename.endswith(".md"):
                path = os.path.join(dirpath, filename)
                updated, count, broken = sanitize_file(path, docs_src_root)
                total += count
                all_broken.extend(broken)
                if updated is not None:
                    pending.append((path, updated))

    if all_broken:
        print("error: rewritten links point at missing files (no files modified):",
              file=sys.stderr)
        for target in sorted(set(all_broken)):
            print(f"  - {target}", file=sys.stderr)
        return 1

    for path, updated in pending:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(updated)

    print(f"Rewrote {total} absolute link(s) under {docs_src_root}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
