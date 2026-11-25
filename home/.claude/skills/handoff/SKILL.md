---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "[@output.md] [focus for next session]"
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work.

## Arguments

Arguments: `$ARGUMENTS`

- The first word starting with `@` is the proposed output path (strip the `@`). Ignore any further `@` words for the path; treat them as focus text.
- All remaining text describes what the next session will focus on. Tailor the document to it.
- No `@` word: save to `${TMPDIR:-/tmp}/handoff-<YYYYMMDD-HHMM>-<slug>.md` (`%TEMP%` on Windows), not the workspace.

## Output path

Treat the path as a proposal:
- Resolve relative paths from the current working directory.
- If it is a directory, create a `handoff-<YYYYMMDD-HHMM>-<slug>.md` file inside it.
- If it has no `.md` extension, add one.
- Create missing parent directories.
- If the file already exists, ask the user to overwrite it or to write `<name>-2.md` beside it.

## Content

- Goal, current state, decisions made, and what was tried and rejected.
- Open questions and concrete next steps.
- Reference existing artifacts (specs, plans, ADRs, issues, commits, diffs) by path or URL; do not duplicate them.
- List the ADRs found in the current directory or the git repository (`ADR/`, `adr/`, `adrs/` or `decisions/`) and tell the next agent to read them first.
- A "Suggested skills" section naming the skills the next agent should load with the Skill tool.
- Redact secrets, API keys, passwords and personally identifiable information.

## Finish

Print the absolute path of the document and a ready-to-paste starting line:
`Read <absolute path> and continue the work described there.`
Do not launch another agent. Do not stage or commit the file.
