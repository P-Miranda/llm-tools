#!/usr/bin/env bash
set -u
fail=0
ok()  { echo "ok    $1"; }
bad() { echo "FAIL  $1"; fail=1; }

[ "$(uname -sm)" = "Linux x86_64" ] && ok "Linux x86_64" || bad "Linux x86_64 required"
[ -r /dev/kvm ] && [ -w /dev/kvm ] && ok "/dev/kvm" || bad "/dev/kvm not read-write for $USER"
for c in curl tar sha256sum docker claude; do
  command -v "$c" >/dev/null && ok "$c" || bad "$c not found"
done
docker info >/dev/null 2>&1 && ok "docker daemon" || bad "docker daemon not reachable"
mem=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
[ "$mem" -ge 5000 ] && ok "$mem MiB available" || echo "warn  $mem MiB available; the VM can use 4096"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ok "~/.local/bin on PATH" ;;
  *) bad "~/.local/bin not on PATH" ;;
esac
exit $fail
