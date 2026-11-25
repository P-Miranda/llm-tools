#!/usr/bin/env python3
"""Create a git worktree at a fixed layout, or locate an existing one.

Usage: new_worktree.py <name> [base]

Layout:
  bare repo:   <bare-root>/<name>/<name>
  normal repo: <parent>/<repo>-worktrees/<name>/<name>

The doubled <name> directory isolates build dirs that projects create one
level above the checkout.

Last stdout line on success:
  RESULT: created|switched|partial <absolute path>
Errors go to stderr with a non-zero exit code.
"""

import os
import subprocess
import sys


def git(*args, cwd=None, check=True):
    proc = subprocess.run(
        ["git", *args], cwd=cwd, capture_output=True, text=True
    )
    if check and proc.returncode != 0:
        die(f"git {' '.join(args)} failed:\n{proc.stderr.strip()}")
    return proc


def die(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


def warn(msg):
    print(f"warning: {msg}", file=sys.stderr)


def same_path(a, b):
    return os.path.realpath(a) == os.path.realpath(b)


def parse_worktrees():
    out = git("worktree", "list", "--porcelain").stdout
    worktrees = []
    for block in out.strip().split("\n\n"):
        entry = {}
        for line in block.splitlines():
            key, _, value = line.partition(" ")
            entry[key] = value
        if "worktree" in entry:
            worktrees.append(entry)
    return worktrees


def main():
    if len(sys.argv) not in (2, 3):
        die("usage: new_worktree.py <name> [base]")
    name = sys.argv[1]
    base = sys.argv[2] if len(sys.argv) == 3 else None

    # 1. Validate the name.
    if "/" in name:
        die(f"'{name}': names containing '/' are not supported")
    if name.startswith("-") or git(
        "check-ref-format", "--branch", name, check=False
    ).returncode != 0:
        die(f"'{name}' is not a valid branch name")

    # 2. Find the repository root and the target path.
    if git("rev-parse", "--git-dir", check=False).returncode != 0:
        die("not inside a git repository")
    common = git(
        "rev-parse", "--path-format=absolute", "--git-common-dir"
    ).stdout.strip()
    bare = (
        git("--git-dir", common, "config", "--bool", "core.bare", check=False)
        .stdout.strip() == "true"
    )
    if bare:
        container = os.path.join(common, name)
    else:
        main_root = os.path.dirname(common)
        repo = os.path.basename(main_root)
        container = os.path.join(
            os.path.dirname(main_root), f"{repo}-worktrees", name
        )
    target = os.path.join(container, name)

    # 3. Existing worktree: match by branch first, then by path.
    worktrees = parse_worktrees()
    match = next(
        (w for w in worktrees if w.get("branch") == f"refs/heads/{name}"), None
    ) or next(
        (w for w in worktrees if same_path(w["worktree"], target)), None
    )
    if match:
        path = match["worktree"]
        if not os.path.isdir(path):
            die(
                f"worktree for '{name}' is registered at {path} but its "
                "directory is missing (stale record).\n"
                "Run 'git worktree prune' to clear stale records, then retry."
            )
        if base is not None:
            die(
                f"'{name}' already exists at {path}; refusing to use base "
                f"'{base}'. Run without a base to switch to it."
            )
        print(f"'{name}' already exists; switching to it.")
        print(f"RESULT: switched {path}")
        return

    # 4. Refuse existing branch or directory.
    if git(
        "show-ref", "--verify", "--quiet", f"refs/heads/{name}", check=False
    ).returncode == 0:
        die(
            f"branch '{name}' already exists but has no worktree.\n"
            f"To check it out in a worktree yourself:\n"
            f"  git worktree add {target} {name}"
        )
    if os.path.exists(container):
        die(f"{container} already exists but is not a registered worktree")

    # 5. Resolve the base.
    if base is not None:
        if git(
            "rev-parse", "--verify", "--quiet", f"{base}^{{commit}}",
            check=False,
        ).returncode != 0:
            die(f"base '{base}' is not a valid commit or branch")
    else:
        branch = git("symbolic-ref", "--short", "-q", "HEAD", check=False)
        if branch.returncode == 0:
            base = branch.stdout.strip()
        else:
            base = git("rev-parse", "HEAD").stdout.strip()
            warn(f"HEAD is detached; branching from commit {base[:12]}")

    # 6. Create the branch and worktree.
    print(f"Creating branch '{name}' from '{base}' at {target}")
    git("worktree", "add", "-b", name, target, base)

    # 7. Submodules, if any.
    result = "created"
    if os.path.isfile(os.path.join(target, ".gitmodules")):
        print("Initialising submodules...")
        sub = git(
            "submodule", "update", "--init", "--recursive",
            cwd=target, check=False,
        )
        if sub.returncode != 0:
            warn(
                "submodule update failed; worktree kept.\n"
                f"{sub.stderr.strip()}\n"
                f"Retry with: git -C {target} submodule update --init --recursive"
            )
            result = "partial"

    print(f"RESULT: {result} {target}")


if __name__ == "__main__":
    main()
