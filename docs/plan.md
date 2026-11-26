# Plan

Replaces the sdw-p-specific plan `~/Documents/Work/agents-vm/agent-vm.md`, which is no
longer there.

## Decisions

| Topic | Choice |
|---|---|
| VM tool | microsandbox, pinned to v0.8.2 |
| Workspace | One generic directory per VM, read-write, same absolute path as on the host |
| First directory | `~/Documents/Work/agents-vm` only, enforced by `vm/allowed-dirs` |
| Configuration | This repository, outside every mount |
| Network | `api.anthropic.com:443` and DNS only |
| Credentials | Token substituted by the host; no SSH keys, no host `~/.claude` |
| Tools | Packages in the image; verilator, xezim, verible, RISC-V, Vivado 2024.2 (xsim) read-only from `~/opt` |
| Config | `home/`, copied into the image; not shared with the host's `~/.claude` |
| Excluded | libreoffice, texlive, gtkwave, doxygen, iverilog |
| Resources | 4 CPUs, 8 GB RAM, 5 GB mount quota |
| Backups | Required before each new directory is allowed |
| Clipboard | Paste through the terminal; VM to host only by OSC 52 through tmux, no shared channel |

## Status

Implemented: `vmwork` (shell, test, stop, rm, dry-run, build), image with Claude Code and the
iob-soc-int Python packages, `home/` config (Claude settings and skills, tmux, readline, git
identity), tool mounts from `vm/tools`, isolation checks in `tests/guest.sh`.

Added 2026-11-26 and checked in the VM: xsim (Vivado mount, bookworm `libtinfo5`,
`en_US.UTF-8` locale) with its check, 8 GB RAM, OSC 52 clipboard (host terminal changed to kitty;
`kitty-terminfo` in the image).

Left: the open Phase 1 items and the DNS leak.

## Phase 1: agents-vm

Each item can rule out or change the design. `vmwork test` covers those marked (t).

- [x] The flags and Sandboxfile are accepted by v0.8.2
- [x] (t) Files are read-write on both sides, host owner stays `pm`
- [x] (t) `chmod +x` in the VM reaches the host (`host-perms=mirror`)
- [x] (t) Host home, host services and LAN unreachable; other domains blocked
- [x] (t) The token is a placeholder in the VM
- [x] (t) Claude answers with `--secret` and TLS interception
- [x] (t) Mounted tools run and are read-only
- [ ] A tmux session survives leaving the shell; claude usable in `--security restricted`
- [x] `git init`, commit and status in a scratch subdirectory, from both sides
- [x] Files edited on the host show up in the VM, and the reverse
- [ ] Filling the mount stops at the quota
- [x] (t) xsim simulates; a real iob-soc-int simulation fits in 8 GB
- [x] Copying from VM tmux, neovim and Claude `/copy` reaches the host clipboard (needs
  `set-clipboard on` in the host tmux and OSC 52 support in the host terminal: kitty, since
  xfce4-terminal ignores OSC 52)

The (t) items except xsim passed on 2026-11-25 with v0.8.2, after correcting two network
checks that failed because msb accepts TCP on ports 80 and 443 locally before denying the
request. xsim passed on 2026-11-26.

Known leak: `allow@dns` resolves any domain, so data can leave encoded in DNS names. Look for
a way to limit it before mounting confidential directories.

Fallbacks: rootless podman (shared kernel) or QEMU with virtiofsd.

## Phase 2: other directories

Before adding each directory to `vm/allowed-dirs`:

- Backup outside the mount, with one restore tested.
- Look for credentials and host-executed files.

`Work` itself is not mounted.

## Phase 3: as needed

- pyenv read-only (most venvs link to it).
- Wider network allowlist, host nftables as a second filter.
- Other agents (pi).
