#!/usr/bin/env python3
"""Mirror this project into the GitHub checkout, using the GitHub folder names.

The local project is organised by the user and is NOT a git repository. The
GitHub checkout lives in MIRROR and keeps the original folder names:

  local output/0.0.X/<x>, output/0.1.X/<x>       -> GitHub output/<x>
  local output/0.N.X/adventure game 0.N.M[.k]     -> GitHub output/0.N.M series/adventure game 0.N.M[.k]
  local output/0.N.X/<any other file>             -> GitHub output/0.N.0 series/<file>
  everything else                                 -> same path

Files are hard links, so the mirror costs no extra disk space. Every new file
of 1 MiB or more is added to the mirror's .gitattributes as Git LFS.

Usage:
  sync_github.py              sync, then print a short git status summary
  sync_github.py -m "message" sync and commit (push afterwards with
                              git -C ~/.local/share/forest-wanderer-github push origin main)
"""
import os, re, shutil, subprocess, sys
from pathlib import Path

LOCAL = Path(__file__).resolve().parents[2]
MIRROR = Path.home() / ".local/share/forest-wanderer-github"
SKIP = [".git", ".godot", ".DS_Store", "._*"]
LFS_MIN = 1024 * 1024


def rsync_dir(src: Path, dst: Path, extra: list) -> None:
    dst.mkdir(parents=True, exist_ok=True)
    cmd = ["rsync", "-a", "--delete", f"--link-dest={src}"]
    for pattern in SKIP + extra: cmd.append(f"--exclude={pattern}")
    subprocess.run(cmd + [f"{src}/", f"{dst}/"], check=True)


def link_file(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        if os.path.samefile(src, dst): return
        dst.unlink()
    os.link(src, dst)


def output_units() -> list:
    """(local path, GitHub path) pairs for everything under output/."""
    units = []
    for entry in sorted((LOCAL / "output").iterdir()):
        if entry.name.startswith("."): continue
        group = re.fullmatch(r"0\.(\d+)\.X", entry.name)
        if not group or not entry.is_dir():
            units.append((entry, Path("output") / entry.name)); continue
        minor = int(group.group(1))
        for child in sorted(entry.iterdir()):
            if child.name.startswith("."): continue
            if minor <= 1:
                units.append((child, Path("output") / child.name)); continue
            version = re.match(r"adventure game (\d+\.\d+\.\d+)", child.name)
            series = f"{version.group(1)} series" if version else f"0.{minor}.0 series"
            units.append((child, Path("output") / series / child.name))
    return units


def git(*args, capture=False):
    return subprocess.run(["git", "-C", str(MIRROR), *args], check=True,
                          text=True, capture_output=capture).stdout


def ensure_lfs() -> int:
    files = git("ls-files", "-z", "--cached", "--others", "--exclude-standard", capture=True).split("\0")
    big = [f for f in files if f and (MIRROR / f).is_file() and (MIRROR / f).stat().st_size >= LFS_MIN]
    if not big: return 0
    attrs = subprocess.run(["git", "-C", str(MIRROR), "check-attr", "-z", "filter", "--stdin", "-z"],
                           input="\0".join(big) + "\0", text=True, capture_output=True, check=True).stdout.split("\0")
    missing = [attrs[i] for i in range(0, len(attrs) - 2, 3) if attrs[i + 2] != "lfs"]
    if missing:
        with open(MIRROR / ".gitattributes", "a", encoding="utf-8") as f:
            for path in missing: f.write(f'"{path}" filter=lfs diff=lfs merge=lfs -text\n')
    return len(missing)


def main() -> None:
    if not (MIRROR / ".git").is_dir(): sys.exit(f"No GitHub checkout at {MIRROR}")
    # Root: everything except output/, plus the mirror-only git files.
    rsync_dir(LOCAL, MIRROR, ["/output", "/.gitattributes", "/.gitignore"])
    wanted = set()
    for src, rel in output_units():
        dst = MIRROR / rel
        wanted.add(rel)
        if src.is_dir(): rsync_dir(src, dst, [])
        else: link_file(src, dst)
    # Remove GitHub paths whose local folder no longer exists.
    out = MIRROR / "output"
    keep_parents = {rel.parent for rel in wanted}
    for entry in list(out.iterdir()):
        rel = entry.relative_to(MIRROR)
        if rel in wanted: continue
        if rel in keep_parents and entry.is_dir():
            for child in list(entry.iterdir()):
                if child.relative_to(MIRROR) not in wanted:
                    shutil.rmtree(child) if child.is_dir() else child.unlink()
            continue
        shutil.rmtree(entry) if entry.is_dir() else entry.unlink()
    added = ensure_lfs()
    if added: print(f"Added {added} new large files to Git LFS")
    git("add", "-A")
    if len(sys.argv) > 2 and sys.argv[1] == "-m":
        if subprocess.run(["git", "-C", str(MIRROR), "diff", "--cached", "--quiet"]).returncode == 0:
            print("Nothing to commit"); return
        git("commit", "-q", "-m", sys.argv[2])
        print(git("log", "--oneline", "-1", capture=True).strip())
    else:
        print(git("status", "--short", capture=True)[:4000] or "In sync with the last commit")


if __name__ == "__main__":
    main()
