#!/usr/bin/env bash
# Claude Code status line: model + context window usage (no dependencies)
input=$(cat)

# Print the first numeric value for a JSON key
num() {
  printf '%s' "$input" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*[0-9]*" \
    | head -1 | grep -o '[0-9]*$'
}

# Print the first string value for a JSON key
str() {
  printf '%s' "$input" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 | sed 's/.*"\([^"]*\)"$/\1/'
}

model=$(str display_name)
size=$(num context_window_size)
in=$(num input_tokens)
cc=$(num cache_creation_input_tokens)
cr=$(num cache_read_input_tokens)

if [ -n "$size" ] && [ "$size" -gt 0 ] && [ -n "$in" ]; then
  used=$(( ${in:-0} + ${cc:-0} + ${cr:-0} ))
  pct=$(( used * 100 / size ))
  printf '%s | ctx: %dk/%dk (%d%%)' "$model" $((used/1000)) $((size/1000)) "$pct"
else
  printf '%s | ctx: n/a' "$model"
fi
