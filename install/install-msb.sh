#!/usr/bin/env bash
# Same file layout as the official installer, with a fixed version and checksum.
set -euo pipefail

version=v0.8.2
sha256=581672ca8981e2a5732df0b215fb540ef7d5d4d708d7c9bcfb650ab413bd6836
url=https://github.com/superradcompany/microsandbox/releases/download/$version/microsandbox-linux-x86_64.tar.gz

prefix=$HOME/.microsandbox
link=$HOME/.local/bin/msb

if [ -e "$link" ] && [ ! -L "$link" ]; then
  echo "$link exists and is not a symlink" >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fL --proto '=https' -o "$tmp/msb.tar.gz" "$url"
echo "$sha256  $tmp/msb.tar.gz" | sha256sum -c -

# Stop if a release changes the layout this script knows.
files=$(tar -tzf "$tmp/msb.tar.gz" | sort)
if [[ ! $files =~ ^libkrunfw\.so\.([0-9]+)\.[0-9]+\.[0-9]+$'\n'msb$ ]]; then
  echo "unexpected release contents:" >&2
  echo "$files" >&2
  exit 1
fi
abi=${BASH_REMATCH[1]}
lib=${files%%$'\n'*}
tar -xzf "$tmp/msb.tar.gz" -C "$tmp" msb "$lib"

mkdir -p "$prefix/bin" "$prefix/lib" "$HOME/.local/bin"
install -m 755 "$tmp/msb" "$prefix/bin/msb"
install -m 644 "$tmp/$lib" "$prefix/lib/$lib"
ln -sf "$lib" "$prefix/lib/libkrunfw.so.$abi"
ln -sf "libkrunfw.so.$abi" "$prefix/lib/libkrunfw.so"
ln -sf "$prefix/bin/msb" "$link"
"$prefix/bin/msb" --version
