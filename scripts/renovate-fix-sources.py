#!/usr/bin/env python3
"""Repair flatpak manifest sources after Renovate bumps versions.

Renovate (see renovate.json) only rewrites the version inside `url:` and
`tag:` lines of manifest sources. This script inspects the diff of the last
commit and fixes everything that must follow the version:

- archive/file sources: re-download the changed URL and update `sha256:`
- PyPI sources (files.pythonhosted.org): resolve the real download URL
  (its path contains a per-file hash) and `sha256:` from the PyPI API
- git sources: resolve the changed `tag:` to a commit and update `commit:`

Only sha256/commit values and pythonhosted URL paths are ever modified, and
the version encoded in a rewritten PyPI file name is asserted unchanged, so
the dependency versions picked by Renovate cannot drift.

Usage: scripts/renovate-fix-sources.py [base-ref]   (default: HEAD~1)
"""

import hashlib
import json
import re
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

USER_AGENT = "wine-flatpak-renovate-fix/1.0"
HTTP_ATTEMPTS = 3


def run(*cmd):
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


def changed_lines(base_ref):
    """Return {file: [line numbers]} of added url:/tag: lines since base_ref."""
    diff = run("git", "diff", "--unified=0", "--no-color", base_ref, "--", "*.yml")
    changes = {}
    current = None
    lineno = 0
    for line in diff.splitlines():
        if line.startswith("+++ b/"):
            current = line[6:]
        elif line.startswith("@@"):
            m = re.match(r"@@ -\S+ \+(\d+)", line)
            lineno = int(m.group(1))
        elif line.startswith("+") and not line.startswith("+++"):
            if current and re.match(r"\+\s*(url|tag):\s", line):
                changes.setdefault(current, []).append(lineno)
            lineno += 1
    return changes


def indent_of(line):
    return len(line) - len(line.lstrip(" "))


def block_bounds(lines, idx):
    """Bounds [start, end) of the source list item containing line idx."""
    key_indent = indent_of(lines[idx])
    marker_indent = key_indent - 2
    marker = re.compile(r"^ {%d}- " % marker_indent)
    start = idx
    while start > 0 and not marker.match(lines[start]):
        start -= 1
    end = start + 1
    while end < len(lines):
        line = lines[end]
        if line.strip() and indent_of(line) < key_indent and not marker.match(line):
            break
        if marker.match(line):
            break
        end += 1
    return start, end


def find_key(lines, start, end, key, key_indent):
    pattern = re.compile(r"^(?: {%d}| {%d}- )%s:\s*(.*)$" % (key_indent, key_indent - 2, key))
    for i in range(start, end):
        m = pattern.match(lines[i])
        if m:
            return i, m.group(1).strip()
    return None, None


def http_get(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(1, HTTP_ATTEMPTS + 1):
        try:
            return urllib.request.urlopen(req, timeout=300)
        except OSError as err:
            if attempt == HTTP_ATTEMPTS:
                raise
            print(f"  attempt {attempt} failed ({err}), retrying")
            time.sleep(5 * attempt)


def sha256_of_url(url):
    print(f"  downloading {url}")
    digest = hashlib.sha256()
    with http_get(url) as resp:
        for chunk in iter(lambda: resp.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def resolve_pypi(url):
    """Resolve the canonical URL and sha256 for a files.pythonhosted.org file."""
    filename = url.rsplit("/", 1)[1]
    m = re.match(r"(?P<name>.+?)-(?P<version>\d[\w.]*?)(?P<suffix>-py3-none-any\.whl|\.tar\.gz)$", filename)
    if not m:
        raise RuntimeError(f"cannot parse PyPI file name: {filename}")
    name, version = m.group("name"), m.group("version")
    api = f"https://pypi.org/pypi/{name}/{version}/json"
    print(f"  querying {api}")
    with http_get(api) as resp:
        data = json.load(resp)
    files = data["urls"]
    entry = next((f for f in files if f["filename"] == filename), None)
    if entry is None and filename.endswith(".whl"):
        entry = next((f for f in files if f["packagetype"] == "bdist_wheel"
                      and f["filename"].endswith("none-any.whl")), None)
    if entry is None and filename.endswith(".tar.gz"):
        entry = next((f for f in files if f["packagetype"] == "sdist"), None)
    if entry is None:
        raise RuntimeError(f"no matching file on PyPI for {filename}")
    new_name = entry["filename"]
    if not re.search(r"-%s[-.]" % re.escape(version), f"{new_name}."):
        raise RuntimeError(f"PyPI resolved {new_name}, version {version} drifted")
    return entry["url"], entry["digests"]["sha256"]


def resolve_git_tag(repo_url, tag):
    print(f"  resolving tag {tag} in {repo_url}")
    out = run("git", "ls-remote", repo_url, f"refs/tags/{tag}", f"refs/tags/{tag}^{{}}")
    refs = {}
    for line in out.splitlines():
        sha, ref = line.split(None, 1)
        refs[ref] = sha
    commit = refs.get(f"refs/tags/{tag}^{{}}") or refs.get(f"refs/tags/{tag}")
    if not commit:
        raise RuntimeError(f"tag {tag} not found in {repo_url}")
    return commit


def replace_value(lines, idx, key, value):
    old = lines[idx]
    lines[idx] = re.sub(r"(%s:\s*).*$" % key, r"\g<1>%s" % value, old)
    return lines[idx] != old


def process_file(path, linenos):
    lines = Path(path).read_text().splitlines()
    modified = False

    for lineno in linenos:
        idx = lineno - 1
        line = lines[idx]
        key_indent = indent_of(line)
        start, end = block_bounds(lines, idx)
        stripped = line.strip()

        if stripped.startswith("url:"):
            url = stripped.split(None, 1)[1]
            if url.endswith(".git"):
                continue  # git URL itself changed; tag handling covers the rest
            sha_idx, _ = find_key(lines, start, end, "sha256", key_indent)
            if "files.pythonhosted.org" in url:
                new_url, sha = resolve_pypi(url)
                modified |= replace_value(lines, idx, "url", new_url)
                if sha_idx is None:
                    raise RuntimeError(f"{path}:{lineno}: no sha256 for {url}")
                modified |= replace_value(lines, sha_idx, "sha256", sha)
                print(f"{path}:{lineno}: updated PyPI url + sha256")
            elif sha_idx is not None:
                sha = sha256_of_url(url)
                modified |= replace_value(lines, sha_idx, "sha256", sha)
                print(f"{path}:{lineno}: updated sha256 for {url}")
            else:
                print(f"{path}:{lineno}: no sha256 in source block, skipping {url}")

        elif stripped.startswith("tag:"):
            tag = stripped.split(None, 1)[1].strip("'\"")
            url_idx, repo_url = find_key(lines, start, end, "url", key_indent)
            commit_idx, _ = find_key(lines, start, end, "commit", key_indent)
            if url_idx is None or commit_idx is None:
                raise RuntimeError(f"{path}:{lineno}: git source missing url/commit")
            commit = resolve_git_tag(repo_url, tag)
            modified |= replace_value(lines, commit_idx, "commit", commit)
            print(f"{path}:{lineno}: tag {tag} -> commit {commit}")

    if modified:
        Path(path).write_text("\n".join(lines) + "\n")
    return modified


def main():
    base_ref = sys.argv[1] if len(sys.argv) > 1 else "HEAD~1"
    changes = changed_lines(base_ref)
    if not changes:
        print("no url/tag changes found, nothing to do")
        return
    any_modified = False
    for path, linenos in changes.items():
        any_modified |= process_file(path, linenos)
    print("done" + ("" if any_modified else " (no fixes needed)"))


if __name__ == "__main__":
    main()
