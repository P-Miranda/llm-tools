# llm-tools

Run Claude Code in a microsandbox VM with one host directory mounted live, read-write.
The directory can be anything; it does not need to be a git repository.

Status: **not tested yet**. See [docs/plan.md](docs/plan.md).

| File | Purpose |
|---|---|
| `install/check-host.sh` | Check host requirements (changes nothing) |
| `install/install-msb.sh` | Install the pinned microsandbox release, SHA-256 checked |
| `image/Dockerfile` | VM image |
| `vm/Sandboxfile` | Fixed VM settings |
| `vm/allowed-dirs` | Directories that may be mounted, with their subdirectories |
| `vm/tools` | Host tools mounted read-only and added to `PATH` |
| `bin/vmwork` | Launcher |
| `tests/guest.sh` | Isolation checks, run in the VM by `vmwork test` |

Never mount this repository: the host runs these scripts.

## Setup

1. Check the host and install microsandbox in `~/.microsandbox` (program, images and VM
   disks), with a symlink in `~/.local/bin/msb`:

   ```bash
   ./install/check-host.sh
   ./install/install-msb.sh
   ```

2. Create a Claude token and save it. Paste it at the second prompt, then press Enter and Ctrl-D:

   ```bash
   claude setup-token
   mkdir -p -m 700 ~/.config/vmwork
   (umask 077; cat > ~/.config/vmwork/token)
   ```

3. Build the image (downloads Debian packages and runs Claude's installer inside the build):

   ```bash
   ./bin/vmwork build
   ```

4. Test:

   ```bash
   ./bin/vmwork dry-run ~/Documents/Work/agents-vm
   ./bin/vmwork test ~/Documents/Work/agents-vm
   ```

Optional: `ln -s "$PWD/bin/vmwork" ~/.local/bin/vmwork`

## Normal use

```bash
cd ~/Documents/Work/agents-vm
vmwork              # start the VM if needed, open a shell in it
```

In the VM: `claude --dangerously-skip-permissions`, or `tmux` first. Leaving the shell keeps the
VM running; run `vmwork` again for another shell.

Only `DIR` is mounted, and each `DIR` has its own VM: a subdirectory gets a separate one that
cannot see its parent.

| Command | Effect |
|---|---|
| `vmwork [shell] [DIR]` | Start if needed and open a shell (`DIR` defaults to the current directory) |
| `vmwork test [DIR]` | Run the isolation checks |
| `vmwork stop [DIR]` | Stop; the VM disk is kept |
| `vmwork rm [DIR]` | Delete the VM and its disk, including Claude history. `DIR` is kept |
| `vmwork dry-run [DIR]` | Print the `msb create` command |
| `vmwork build` | Build and load the image |

After changing the image or the settings: `vmwork rm`, then `vmwork`.

To add tools: packages in `image/Dockerfile` (then `vmwork build`), host directories in `vm/tools`.

## Updating microsandbox

Do not use `msb self update`: it installs the latest version, not the pinned one.

1. Read the release notes, migration guide and advisories. Stop the VMs: `vmwork stop DIR`.
2. Set `version` and `sha256` in `install/install-msb.sh`. The checksum is the
   `microsandbox-linux-x86_64.tar.gz` line of the release's `checksums.sha256`.
3. Run `./install/install-msb.sh`, then `msb doctor`.
4. Run `vmwork rm DIR`, then `vmwork test DIR`. Commit if it passes.

To go back, run `msb self downgrade VERSION` **from the newer version**, then revert the script.
An older binary may refuse newer data, so reinstalling it is not enough.

## Limits

- Agents can change or delete anything in the mounted directory. Keep a backup.
- Review what they wrote before running it, or running git there, on the host.
- Network: `api.anthropic.com` only. No pip, npm, web or git remotes.
- No host credentials in the VM. The token stays on the host and is substituted per request.
