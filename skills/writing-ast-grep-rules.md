---
name: writing-ast-grep-rules
description: Use when the user wants to write or add a new ast-grep rule for the ast-checker plugin (e.g., "add a rule to stop X", "ban Y in our codebase", "write an ast-grep rule for Z"). Walks through pattern syntax, file location, metadata, testing, and verification.
---

# Writing ast-grep rules for ast-checker

The user wants a custom ast-grep rule in their project. Follow this workflow.

## Step 1: Translate intent into a concrete pattern

If the user's request is fuzzy (e.g., "stop using bad fonts"), make it concrete BEFORE writing:
- What language? (Python, JavaScript, Vue, Go, Rust, Kotlin, Java, CSS, etc.)
- What files should the rule apply to? (path glob)
- What's the EXACT code shape to forbid? Translate "no bad fonts" → "ban `font-family: $X` declarations in `.css` files outside `src/styles/tokens.css`."

Ask the user to clarify if needed.

## Step 2: Verify ast-grep + project setup

1. `command -v ast-grep` — must be installed (`brew install ast-grep` on Mac).
2. Find project root: `git rev-parse --show-toplevel`.
3. Confirm `<root>/sgconfig.yml` and `<root>/.ast-grep/` exist. If not, run `/harness init` first.

## Step 3: Draft the rule

ast-grep YAML format:

```yaml
id: <kebab-case-name>
language: <python|javascript|typescript|vue|go|rust|kotlin|java|css|...>
rule:
  pattern: <pattern in target language with $X / $$$ metavariables>
files:
  - <glob1>
  - <glob2>
message: |
  <Clear explanation of what's forbidden + how to fix it.>

  Why this rule exists: <reason — Claude reads this during the redirect, so a clear "why" helps it pick a good fix.>
severity: error
```

Pattern syntax basics:
- Patterns LOOK LIKE the language. `pattern: foo($X)` matches any call to `foo(...)`.
- `$X` matches a single node. `$$$X` matches a sequence (e.g., function args).
- For composite rules (matching inside other constructs), use `inside:` with `stopBy: end`. To constrain by name, add `has: { field: name, regex: "^pattern_" }`.
- Constrain a metavariable's text: add `constraints:` block at rule top level: `constraints: { METHOD: { regex: "^(generate|repose)$" } }`.

Save to `<project-root>/.ast-grep/<name>.yml`.

## Step 4: Verify zero false positives (CRITICAL)

Run `ast-grep scan` from the project root.

- If the rule fires on existing code → either the rule is too broad OR existing code already violates it. Fix one before declaring done. **Do not commit a rule that fires on legitimate code** — false positives train Claude to suppress the rule.

## Step 5: Add a test fixture (recommended)

Create `<project-root>/__tests__/<name>-test.yml` (create the dir if needed):

```yaml
id: <name>
valid:
  - <code that should NOT match — at least 2 examples covering edge cases>
invalid:
  - <code that SHOULD match — at least 1 example>
```

If the project's `sgconfig.yml` doesn't yet have a `testConfigs:` entry, add:
```yaml
testConfigs:
  - testDir: __tests__
```

Then run `ast-grep test --skip-snapshot-tests` from project root. All tests must pass.

## Step 6: Add the metadata header

Edit the rule file to prepend a metadata block:

```yaml
# Added: <today's date YYYY-MM-DD>
# Catches: <one-line summary>
# Why I added this: <first-person reminder of intent — what user goal this serves>
```

This is for the user's future-self when they wonder why a rule exists. Skipping it is fine but discouraged.

## Step 7: Confirm to the user

Summarize:
- Rule name + path saved
- What it catches (one line)
- Whether you added a test fixture
- Confirm the post-edit hook will pick it up automatically on next file edit

## Tips on patterns by language

- **Python**: `pattern: $X.method($$$)` works for any object's method call. For decorators, `pattern: "@$DECORATOR\ndef $FN($$$): $$$"`.
- **JavaScript/TypeScript**: `pattern: console.$METHOD($$$)` then constraint METHOD regex `"^(log|debug)$"` to ban specific console methods.
- **Vue SFCs**: ast-grep parses them via the JS/TS parser for `<script>` blocks. Rules use `language: javascript` or `language: typescript`.
- **Imports**: `pattern: import $X from "$LIB"` (JS) or `pattern: from $LIB import $X` (Python). Constrain `LIB` regex to ban specific packages.
- **CSS**: `pattern: "font-family: $X"` to match font declarations. Note: ast-grep CSS support is via tree-sitter; check that the pattern parses with `ast-grep run --pattern '...' --lang css`.

## When unsure

Test the pattern interactively:
```bash
ast-grep run --pattern '<pattern>' --lang <language> path/to/sample.py
```

This runs the pattern without saving a rule. Iterate until it matches what you want.

For complex patterns, see [ast-grep's rule essentials docs](https://ast-grep.github.io/guide/rule-config.html).
