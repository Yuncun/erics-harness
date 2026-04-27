#!/bin/bash
# Post-edit hook: runs ast-grep on the edited file if the project has .ast-grep/ rules.
# Outputs JSON {"decision": "block", "reason": "..."} on findings so Claude sees and fixes.

FILE="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then exit 0; fi

# Find project root by walking up looking for marker files
find_project_root() {
  local dir="$1"
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    if [ -d "$dir/.git" ] || [ -f "$dir/sgconfig.yml" ] || [ -f "$dir/pyproject.toml" ] || \
       [ -f "$dir/package.json" ] || [ -f "$dir/Cargo.toml" ] || [ -f "$dir/go.mod" ]; then
      echo "$dir"; return
    fi
    dir=$(dirname "$dir")
  done
}

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(find_project_root "$(dirname "$FILE")")}"
[ -z "$PROJECT_ROOT" ] && exit 0
[ ! -f "$PROJECT_ROOT/sgconfig.yml" ] && [ ! -d "$PROJECT_ROOT/.ast-grep" ] && exit 0
[[ "$FILE" != "$PROJECT_ROOT/"* ]] && exit 0

# Find ast-grep binary
AST_GREP=""
if command -v ast-grep >/dev/null 2>&1; then
  AST_GREP=ast-grep
elif command -v sg >/dev/null 2>&1; then
  AST_GREP=sg
else
  exit 0
fi

# Run from project root so sgconfig.yml is found, time the scan
cd "$PROJECT_ROOT"
START_NS=$(date +%s%N 2>/dev/null || echo 0)
OUT=$("$AST_GREP" scan --report-style short "$FILE" 2>&1)
RC=$?
END_NS=$(date +%s%N 2>/dev/null || echo 0)
SCAN_MS=$(( (END_NS - START_NS) / 1000000 ))

if [ $RC -ne 0 ] && [ -n "$OUT" ]; then
  # Extract rule IDs from ast-grep output: lines like "error[<id>]:" or "warning[<id>]:"
  RULE_IDS=$(echo "$OUT" | grep -oE '\[(error|warning|info)\]?\[[^]]+\]|\b(error|warning|info)\[[^]]+\]' | grep -oE '\[[^]]+\]$' | tr -d '[]' | sort -u | paste -sd, -)
  if [ -z "$RULE_IDS" ]; then
    PREFIX="[ast-checker]"
  else
    PREFIX="[ast-checker:$RULE_IDS]"
  fi

  # Append scorecard log entry (per-project, gitignored)
  mkdir -p "$PROJECT_ROOT/.ast-grep" 2>/dev/null
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  REL_FILE="${FILE#$PROJECT_ROOT/}"
  RULES_JSON="\"$(echo "$RULE_IDS" | sed 's/,/","/g')\""
  echo "{\"ts\":\"$TS\",\"rules\":[$RULES_JSON],\"file\":\"$REL_FILE\",\"scan_ms\":$SCAN_MS}" >> "$PROJECT_ROOT/.ast-grep/log.jsonl"

  ESCAPED=$(echo "$OUT" | head -20 | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
  echo "{\"decision\": \"block\", \"reason\": \"$PREFIX ast-grep findings in $FILE: $ESCAPED\"}"
fi

exit 0
