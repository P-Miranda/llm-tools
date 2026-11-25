# agent-vm: Claude Code in a microVM

Handoff written 2026-11-25. Research is done; **nothing is installed, built or run yet**.
"Docs" below means read in documentation, not tested.

## Goal

From a work directory, launch a microVM with that directory mounted live and a Linux image
with devtools. Run tmux inside with several Claude Code instances in
`--dangerously-skip-permissions` mode. They must not reach other host files or credentials,
and a failed run must not damage the host. No vendor account preferred (besides Claude's).

## Decisions

| Topic | Choice |
|---|---|
| VM tool | **microsandbox** (`msb`), first choice to prototype |
| Workspace | **Mount the whole bare repository live, read-write** (user's choice, "for now") |
| Mount path | **Same absolute path in the VM as on the host**; worktree pointers are absolute |
| Image | Dockerfile on `debian:trixie`, loaded with `docker save \| msb load` |
| Launcher | Small wrapper script (`vmwork`), easy to move to another tool |
| Credentials in VM | None real; token placeholder substituted by the host. No SSH keys |
| First test repo | `/home/pm/Documents/Work/SoundWire/iob-sdw-p` |

The earlier recommendation was a dedicated clone in `~/vm-work` with `git bundle` back. The
user chose the bare-repo mount for convenience. The clone remains the safer fallback.

### Why not the others

- **Firecracker:** no host-directory mount (no virtio-fs). Needs an ext4 drive + git/rsync.
- **E2B:** Firecracker with file transfer by API; hosted version puts RTL on their servers.
- **smolvm:** was the first pick. Very fast releases (5 in <15 h), one dominant contributor,
  10 high advisories published 2026-11-24, unsigned releases, no mount quota found.
- **BoxLite:** best VMM confinement (seccomp, namespaces) and signed provenance, but no CLI
  secrets flag and only `--rootfs` found for local images.
- **Docker Sandboxes (`sbx`):** needs Docker login; officially only Ubuntu 24.04+.
- **QEMU + virtiofsd:** fallback if microsandbox isn't trusted; all Debian packages, but we
  build launcher, filtering and credential proxy. `virtiofsd` 1.13.2 in apt, not installed.
- **Rootless Podman:** simplest fallback (already installed); shares the host kernel.

## Host (checked)

- Debian 13, kernel 6.12, glibc 2.41, Ryzen 5 5600 (12 threads), AMD-V.
- `/dev/kvm` read-write for `pm` through an ACL (`user:pm:rw-`), **not** the `kvm` group. A
  separate VM user would need its own access.
- 15 GiB RAM, 7.6 GiB available when checked: plan for one 4-6 GB VM.
- `/` is ext4, 152 GB free. `/home` is on it.
- Installed: docker 29.10, podman 5.4.2, qemu 10.0, passt, bwrap, nft, nix, mkfs.ext4.
- Not installed: `msb`, `virtiofsd`, `firecracker`, `jq`, `gh`.
- `pm` is uid/gid 1000, in `sudo` and `docker` groups.
- Tools in `~/opt`: verilator-v5.040 (123M), v5.034, v5.022, v4.038 (default on PATH);
  iverilog (63M); verible-v0.0-4013-gba3dc371 (42M); toolchains (1.3G);
  riscv_2023.02.25 (1.9G); Xilinx. Binaries sampled (verilator, iverilog) need glibc <= 2.38.
  Mount only the needed tool directories, read-only, at the same paths; not all of `~/opt`
  (it also holds personal apps such as KeePassXC).

## Repo layout (checked)

`/home/pm/Documents/Work/SoundWire/iob-sdw-p` **is** the bare repo (`hooks/`, `config`,
`objects/` at top level), with worktrees inside it. 2.9 GB total.

| Worktree | Branch |
|---|---|
| `dev` | `ug-review` |
| `main` | `main` |
| `fifo-datapath/fifo-datapath` | `fifo-datapath` |
| `hw-resources/hw-resources` | `hw-resources` |

- `.git` files and `worktrees/*/gitdir` are absolute; `commondir` is `../..`.
- Submodules `cast`, `tester/iob-soc-int`; per-worktree data in `worktrees/*/modules`.
- Remotes `pmiranda` and `upstream` are SSH URLs: fetch/push from the host only.
- `hooks/` has no active hooks. No `extensions.*` set (so no `config.worktree`).
- Python venvs (`.pythase-venv`, `hw-resources/.pythase-venv`) link to a host `python3`
  through an absolute path; they likely break in the VM. Recreate outside the mount.
- **`vip_test/` holds commercial VIP (amswvip)**: the mount exposes it to the agents.
- `dev/Makefile` has targets that SSH to a remote EDA server ("Delta"). They won't work in
  the VM by design.
- `~/Documents/Work/AGENTS.md` and `~/Documents/Work/ADR/` are **outside** the mount; mount
  read-only if the agents should see them.

## Draft: Dockerfile

```dockerfile
FROM debian:trixie
RUN apt-get update && apt-get install -y --no-install-recommends \
      git tmux make gcc g++ python3 python3-venv ripgrep curl ca-certificates \
      locales less procps neovim
RUN useradd -m -u 1000 -s /bin/bash agent
USER agent
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH=/home/agent/.local/bin:/usr/local/bin:/usr/bin:/bin
```

Set git `user.name`/`user.email` in the VM for commits. Also set `LANG=C.UTF-8` and `TERM`.

## Draft: launch

```bash
repo=/home/pm/Documents/Work/SoundWire/iob-sdw-p
opt=/home/pm/opt
docker build -t claude-dev . && docker save claude-dev | msb load

msb create claude-dev --name iob-sdw-p \
  --cpus 4 --memory 6G --user 1000:1000 --security restricted \
  --mount-dir "$repo:$repo:rw,nosuid,nodev,quota=20G" \
  --mount-dir "$opt/verilator-v5.040:$opt/verilator-v5.040:ro" \
  --mount-dir "$opt/iverilog:$opt/iverilog:ro" \
  --mount-file "/home/pm/Documents/Work/AGENTS.md:/home/pm/Documents/Work/AGENTS.md:ro" \
  --net-default-egress deny \
  --net-rule "allow@api.anthropic.com:tcp:443,allow@dns" \
  --secret 'CLAUDE_CODE_OAUTH_TOKEN@api.anthropic.com'

msb exec -t iob-sdw-p -- tmux new -A -s work
```

- `vmwork` should find the repo with `git rev-parse --git-common-dir` from any worktree,
  and refuse `$HOME`, `/` and any parent of `$HOME`.
- Use absolute mount paths (one advisory concerned relative paths changing on restart).
- Docs give both `--net-default-egress` and `--net-default`: check `msb run --help`.
- `--security restricted` disables sudo, so all tools go in the image.
- Check whether `quota=` counts the existing 2.9 GB or only new data.
- Don't put the VM's Claude config (`~/.claude`) on the host mount; don't mount the host's.

Claude auth: `claude setup-token` on the host prints a one-year OAuth token (model requests
only). It goes in the host's `CLAUDE_CODE_OAUTH_TOKEN`. Claude docs list `api.anthropic.com`,
`claude.ai`, `claude.com`, `platform.claude.com` as required; the last three are for sign-in,
so they may be unnecessary with a token. Set `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`.
`--dangerously-skip-permissions` is rejected as root.

## Risks of mounting the bare repo

The VM can, **without any VM escape**:

1. Write `hooks/*`, `config` (e.g. `core.fsmonitor`, `core.sshCommand`, filters), and submodule
   configs in `worktrees/*/modules/*`: these can run code on the **next host git command**.
2. Repoint `dev/.git` or `worktrees/*/commondir` at a fake repo.
3. Delete or corrupt all branches, objects, worktrees and uncommitted work.
4. Plant Makefiles, scripts, `.envrc`, `.vscode/`, `.claude/` or venv files the host later runs,
   or symlinks that host tools follow to private files.
5. Read everything in the repo, including the VIP. Allowed network hosts remain a leak channel.

Claude and the token are also usable (not readable, if substitution works) by VM code.

### Mitigations to set up

- **Backup before each session**, outside the mount: a bundle (`git bundle create
  <outside>/x.bundle --all`) plus a copy of uncommitted files. The bundle does not include
  uncommitted work or submodule repos.
- **Do git inside the VM** while agents work. On the host, avoid shell prompts and editors
  that run git automatically in this tree.
- **Before host git/push:** compare `config`, `hooks/`, all `.git` files, `worktrees/*/{gitdir,
  commondir}` and submodule configs/hooks with a baseline saved outside the mount. Use a
  standalone script that does **not** call git or code from the mount.
- Try nested read-only mounts over `hooks/` and `config`. Effectiveness is unverified, and a
  read-only `config` breaks `git config`, branch tracking and submodule init. Partial: it
  doesn't cover items 2-5.
- Review diffs before building or running anything on the host; prefer building in the VM.
- Don't rely on msb alone: no VMM jail/seccomp found in its docs, and its advisories include
  allowlist bypasses and guest-to-host file bugs. Add nftables as a second filter.
- Running msb as a separate Linux user limits a VM escape, but conflicts with a live mount of
  files owned by `pm` (needs ACLs). Decide later; with msb as `pm`, an escape gets `pm`'s access,
  including passwordless-root-equivalent `docker` group membership.
- Pin the msb version (latest seen: v0.8.2, 2026-11-24, beta) and check its SHA-256.

## Live behaviour

Files in the mount are the same files on both sides, including commits and untracked files.
Anything elsewhere in the VM stays on its disk. No merging: last save wins. Change
notifications across the mount are unconfirmed. Parallel agents should use separate worktrees;
create them inside the mounted repo so the paths work on both sides.

## Next steps

1. Get user approval, then install a pinned msb; verify checksum. Official installer:
   `curl -fsSL https://install.microsandbox.dev | sh` (read it first).
2. Check `msb --help` flags against the draft.
3. **Prototype on a scratch bare repo with worktrees**, not the real one.
4. Test, in this order (a failure in the first four may rule msb out):
   - [ ] Mount at the same path; uid 1000 ownership correct both ways
   - [ ] `git status`/`commit` in worktrees and submodules, on both sides
   - [ ] Claude login via `--secret` substitution, with only `api.anthropic.com` allowed
   - [ ] tmux survives detach; reattach with `msb exec -t`; behaviour after stop/start
   - [ ] Host files outside mounts, host services and LAN unreachable; other domains blocked
   - [ ] `quota=` works; symlink to `~/.ssh` doesn't resolve from the VM
   - [ ] `--user` + `--security restricted` usable for normal work
   - [ ] Verilator/iverilog run from read-only `~/opt` mounts; build speed vs host
   - [ ] Which other tools the repo's `make` flow needs (check `setup.mk`, possible nix use)
5. Write `vmwork`, the backup script and the integrity check.
6. Take a backup, then use the real repo.

## Open questions for the user

- Is exposing `vip_test/` (commercial VIP) acceptable, licence-wise and otherwise?
- Which tools are needed in the VM (verilator version, RISC-V toolchain, Vivado)?
- Separate Linux user for msb, or run as `pm` at first?
- Extra allowed domains (PyPI, GitHub over HTTPS, nix cache)?
- Keep one VM per repo, or one per task/worktree?

## Sources

- https://docs.microsandbox.dev/cli/sandbox-commands.md
- https://docs.microsandbox.dev/sandboxes/volumes.md
- https://docs.microsandbox.dev/sandboxes/secrets.md
- https://docs.microsandbox.dev/networking/overview.md
- https://docs.microsandbox.dev/how-to/docker/local-images.md
- https://docs.microsandbox.dev/security/isolation.md and `/security/hardening.md`
- https://github.com/superradcompany/microsandbox/security/advisories
- https://github.com/containers/libkrun/blob/main/docs/security-model.md
- https://code.claude.com/docs/en/authentication and `/network-config`, `/devcontainer`
- Not read yet: microsandbox `security/filesystem`, `security/secrets`, `networking/dns`,
  `cli/configuration`
