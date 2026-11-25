---
name: worktree
description: Create a git worktree (new branch) at the standard <root>/<name>/<name> layout, or switch to it if it already exists, and move the session into it. Use only when the user explicitly asks to create or switch to a worktree.
argument-hint: "<name> [base]"
---

Create or switch to the git worktree for branch `<name>`.

Arguments: `$ARGUMENTS` (`<name> [base]`). If no name was given, ask for one.

1. Run the script from the current working directory, passing the arguments unchanged:

   ```
   python3 ~/.claude/skills/worktree/scripts/new_worktree.py <name> [base]
   ```

2. If it exits non-zero, show the user the error from stderr and stop. Do not retry with different arguments, prune worktrees, delete branches or remove directories to work around it.

3. Otherwise read the last stdout line, `RESULT: created|switched|partial <abs path>`.
   - If the session is already inside a worktree entered with `EnterWorktree`, call `ExitWorktree` with `action: "keep"` first.
   - Call `EnterWorktree` with `path: <abs path>`.

4. Report what happened: created (with the base branch) or switched, and the path. For `partial`, relay the submodule warning and its retry command.
