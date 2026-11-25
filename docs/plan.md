# Plan

Replaces the sdw-p-specific plan in `~/Documents/Work/agents-vm/agent-vm.md`, which is still
valid for tool choice, host facts and risks. Copy it here before the first VM session: it is
in the mounted directory.

## Decisions

| Topic | Choice |
|---|---|
| VM tool | microsandbox, pinned to v0.8.2 |
| Workspace | One generic directory per VM, read-write, same absolute path as on the host |
| First directory | `~/Documents/Work/agents-vm` only, enforced by `vm/allowed-dirs` |
| Configuration | This repository, outside every mount |
| Network | `api.anthropic.com:443` and DNS only |
| Credentials | Token substituted by the host; no SSH keys, no host `~/.claude` |
| Tools | Packages in the image; verilator, xezim, verible, RISC-V read-only from `~/opt` |
| Excluded | libreoffice, texlive, gtkwave, doxygen, iverilog |
| Resources | 4 CPUs, 4 GB RAM, 5 GB mount quota |
| Backups | None exist for `Work`, so no wider mount until they do |

## Phase 1: agents-vm

Each item can rule out or change the design. `vmwork test` covers those marked (t).

- [ ] The flags and Sandboxfile are accepted by v0.8.2
- [ ] (t) Files are read-write on both sides, host owner stays `pm`
- [ ] (t) `chmod +x` in the VM reaches the host (`host-perms=mirror`)
- [ ] (t) Host home, host services and LAN unreachable; other domains blocked
- [ ] (t) The token is a placeholder in the VM
- [ ] (t) Claude answers with `--secret` and TLS interception
- [ ] (t) Mounted tools run and are read-only
- [ ] A tmux session survives leaving the shell; claude usable in `--security restricted`
- [ ] `git init`, commit and status in a scratch subdirectory, from both sides
- [ ] Files edited on the host show up in the VM, and the reverse
- [ ] Filling the mount stops at the quota

All (t) items passed on 2026-11-25 with v0.8.2, after correcting two network checks that failed
because msb accepts TCP on ports 80 and 443 locally before denying the request.

Known leak: `allow@dns` resolves any domain, so data can leave encoded in DNS names. Look for
a way to limit it before mounting confidential directories.

Fallbacks: rootless podman (shared kernel) or QEMU with virtiofsd.

## Phase 2: other directories

Before adding each directory to `vm/allowed-dirs`:

- Backup outside the mount, with one restore tested.
- Look for credentials and host-executed files. Known: `~/Documents/Work/.envrc` holds a
  `GITHUB_TOKEN`; hide it before mounting `Work`.
- Worktrees need their bare repository in the mount too.
- `vmwork` refuses any directory containing this repository, so mounting `Work` needs a
  deliberate change: a nested read-only mount here.

## Phase 3: as needed

- pyenv read-only (most venvs link to it).
- Wider network allowlist, host nftables as a second filter.
- Other agents (pi).
