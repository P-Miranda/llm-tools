#!/usr/bin/env bash
# Runs in the VM, in the mounted directory. The host side checks and removes .vmwork-probe.
fail=0
check() {
  local desc=$1
  shift
  if "$@" >/dev/null 2>&1 </dev/null; then echo "ok    $desc"; else echo "FAIL  $desc"; fail=1; fi
}
not() { ! "$@"; }
tcp() { timeout 5 bash -c "exec 3<>/dev/tcp/$1/$2"; }
http() { curl -s --cacert /.msb/tls/ca.pem -m 15 -o /dev/null -w '%{http_code}' "$1"; }
reaches_anthropic() { case $(http https://api.anthropic.com/) in 000|403) return 1 ;; esac; }
# msb accepts ports 80 and 443 locally and answers denied requests itself, so a TCP
# connection there proves nothing. No answer at all also counts as blocked.
blocked() {
  local body
  body=$(curl -sk -m 15 "$1") || return 0
  [[ $body == *network_policy_denied* ]]
}
xezim_works() {
  echo 'module t; initial begin $display("xezim-ok"); $finish; end endmodule' > /tmp/t.v
  timeout 20 xezim /tmp/t.v | grep -q xezim-ok
}
claude_works() { timeout 90 claude -p 'Reply with exactly: pong' | grep -qi pong; }

check "uid 1000" test "$(id -u)" = 1000
check "no new privileges" grep -q '^NoNewPrivs:[[:space:]]*1' /proc/self/status
check "workspace writable" bash -c 'echo x > .vmwork-probe && chmod 755 .vmwork-probe'
check "host home hidden" not test -e /home/pm/.ssh
check "host .claude hidden" not test -e /home/pm/.claude
check "rest of Work hidden" not test -e /home/pm/Documents/Work/AGENTS.md
check "rest of ~/opt hidden" not test -e /home/pm/opt/KeePassXC
check "tools read-only" not touch /opt/riscv/.vmwork-probe
check "xezim runs" xezim -V
check "xezim simulates" xezim_works
for tool in verilator verible-verilog-lint riscv64-unknown-elf-gcc \
            riscv64-unknown-linux-gnu-gcc clang-format mypy black; do
  check "$tool runs" "$tool" --version
done
check "python packages" python3 -c 'import matplotlib, numpy, scipy, parse, serial, wavedrom'
check "tmux starts non-login shells" bash -c 'tmux -L probe new -d "sleep 5" && tmux -L probe show -gv default-command | grep -qx bash'
check "docker socket hidden" not test -e /var/run/docker.sock
check "token is a placeholder" bash -c '[[ $CLAUDE_CODE_OAUTH_TOKEN == \$MSB_* ]]'
check "Anthropic API reachable" reaches_anthropic
check "example.com blocked" blocked https://example.com/
check "github.com blocked" blocked https://github.com/
check "public IP blocked" blocked https://1.1.1.1/
check "public IP, other port blocked" not tcp 1.1.1.1 8443
check "LAN gateway blocked" blocked http://192.168.1.254/
check "LAN gateway, other port blocked" not tcp 192.168.1.254 22
check "host blocked" blocked http://host.microsandbox.internal/
check "host, other port blocked" not tcp host.microsandbox.internal 22
check "claude answers" claude_works
exit $fail
