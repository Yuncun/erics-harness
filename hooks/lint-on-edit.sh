#!/bin/bash
# Post-edit hook: runs the right linter for the edited file type.
# Outputs JSON {"decision": "block", "reason": "..."} on errors so Claude
# sees them and fixes them in the next turn.
#
# Project-aware: auto-detects project root, Python venv, and frontend dir.
# Optional per-project overrides via .claude-lint.json at the project root.

FILE="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then exit 0; fi

# --- Project root detection ---
find_project_root() {
  local dir="$1"
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    if [ -d "$dir/.git" ] || [ -f "$dir/pyproject.toml" ] || [ -f "$dir/package.json" ]; then
      echo "$dir"
      return
    fi
    dir=$(dirname "$dir")
  done
}

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(find_project_root "$(dirname "$FILE")")}"
[ -z "$PROJECT_ROOT" ] && exit 0
[ ! -d "$PROJECT_ROOT" ] && exit 0

# --- Python venv detection ---
find_venv_bin() {
  for candidate in "$1/.venv/bin" "$1/venv/bin"; do
    [ -d "$candidate" ] && echo "$candidate" && return
  done
}
VENV_BIN=$(find_venv_bin "$PROJECT_ROOT")

# --- Frontend dir detection (looks for package.json with vue/react/svelte) ---
find_frontend_dir() {
  local root="$1"
  for candidate in "$root" "$root/frontend" "$root/web" "$root/client" "$root/app"; do
    if [ -f "$candidate/package.json" ] && grep -qE '"(vue|react|svelte|@vue|@react)"' "$candidate/package.json" 2>/dev/null; then
      echo "$candidate"; return
    fi
  done
  # One level deeper: look for any */frontend or */web
  for candidate in "$root"/*/frontend "$root"/*/web; do
    if [ -f "$candidate/package.json" ] && grep -qE '"(vue|react|svelte|@vue|@react)"' "$candidate/package.json" 2>/dev/null; then
      echo "$candidate"; return
    fi
  done
}
FRONTEND_DIR=$(find_frontend_dir "$PROJECT_ROOT")

# --- Helpers ---
ERRORS=""
run_check() {
  local label="$1"; shift
  local out
  out=$("$@" 2>&1)
  if [ $? -ne 0 ]; then
    ERRORS="${ERRORS}${label}: ${out}"$'\n'
  fi
}

# --- Route by file type (language-specific linters) ---
case "$FILE" in
  *.py)
    if [ -n "$VENV_BIN" ] && [ -x "$VENV_BIN/ruff" ]; then
      "$VENV_BIN/ruff" check --fix "$FILE" >/dev/null 2>&1
      run_check "ruff" "$VENV_BIN/ruff" check "$FILE"
    fi
    ;;
  *.css)
    if [ -n "$FRONTEND_DIR" ]; then
      cd "$FRONTEND_DIR"
      run_check "stylelint" npx --no-install stylelint --fix "$FILE"
    fi
    ;;
  *.vue|*.js|*.ts|*.tsx|*.jsx)
    if [ -n "$FRONTEND_DIR" ] && [[ "$FILE" == "$FRONTEND_DIR"/* ]]; then
      cd "$FRONTEND_DIR"
      npx --no-install eslint --fix "$FILE" >/dev/null 2>&1
      npx --no-install prettier --write "$FILE" >/dev/null 2>&1
      ESLINT_OUT=$(npx --no-install eslint "$FILE" 2>&1)
      if [ $? -ne 0 ]; then
        ERRORS="${ERRORS}eslint: $(echo "$ESLINT_OUT" | grep "  error  ")"$'\n'
      fi
    fi
    ;;
esac

# --- Semgrep (language-agnostic) — runs on any file in the project if .semgrep/ exists ---
if [ -d "$PROJECT_ROOT/.semgrep" ] && [[ "$FILE" == "$PROJECT_ROOT/"* ]]; then
  SEMGREP_BIN=""
  if [ -n "$VENV_BIN" ] && [ -x "$VENV_BIN/semgrep" ]; then
    SEMGREP_BIN="$VENV_BIN/semgrep"
  elif command -v semgrep >/dev/null 2>&1; then
    SEMGREP_BIN="semgrep"
  fi
  if [ -n "$SEMGREP_BIN" ]; then
    run_check "semgrep" "$SEMGREP_BIN" --config="$PROJECT_ROOT/.semgrep/" --error --quiet --no-git-ignore "$FILE"
  fi
fi

if [ -n "$ERRORS" ]; then
  ESCAPED=$(echo "$ERRORS" | head -20 | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
  echo "{\"decision\": \"block\", \"reason\": \"Lint errors in $FILE: $ESCAPED\"}"
fi

exit 0
