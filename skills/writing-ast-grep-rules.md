---
name: writing-ast-grep-rules
description: Use when the user wants to write or add a new ast-grep rule for the ast-checker plugin (e.g., "add a rule to stop X", "ban Y in our codebase", "write an ast-grep rule for Z"). Walks through intent capture, sample writing, pattern testing, and verification — based on the ast-grep team's canonical 5-step methodology.
---

<!--
Workflow design adapted from the ast-grep maintainer's post on AI-generated rules:
https://ast-grep.github.io/blog/ast-grep-agent.html

Key principles imported:
- Five-step flow: intent → samples → rule → test against samples → verify against codebase
- Compounding errors: small mistakes early snowball; verify each step
- Hallucination is real: even Claude invents non-existent syntax sometimes — test interactively before saving
- Iterate until correct, don't expect first-attempt perfection
- Don't follow this rigidly if the user's intent can't be expressed structurally — flag and suggest alternatives instead

Note on community sources: ast-grep has an official catalog (https://ast-grep.github.io/catalog/) and
community packs (e.g. coderabbitai/ast-grep-essentials). They're useful as starting points for common
patterns but have no per-rule quality signals (no stars, no usage stats, no verification). Treat anything
copied from them as draft and run the same verification this skill does.
-->


# Writing ast-grep rules for ast-checker

The user wants a custom ast-grep rule in their project. Follow this workflow. It's based on the ast-grep team's own guidance for AI-generated rules — each step prevents a specific failure mode.

## Step 1: Capture intent (concrete code shape, not behavior)

Translate the user's request into a SPECIFIC pattern of code to forbid. If their request is fuzzy, push for concretion before continuing.

Example translations:
- "stop using bad fonts" → "ban `font-family: $X` declarations in `.css` files outside `src/styles/tokens.css`"
- "no print debugging" → "ban `print($X)` calls in `.py` files outside `tests/`"
- "use our logger" → "ban `console.log($X)` calls outside `src/utils/logger.js`"

Confirm the translated intent with the user before continuing.

**If the intent is genuinely not structural** (e.g., "ban functions with cyclomatic complexity > 10"), STOP and tell the user ast-grep can't express this — suggest a different tool (radon for Python complexity, etc.).

## Step 2: Write sample code (BEFORE drafting the rule)

This is the step that prevents the rest of the workflow from compounding errors. Write 3-4 short code snippets:

- 1 INVALID example: code that should match (the rule should fire on this)
- 2-3 VALID examples: code that should NOT match (rule should be silent on these — pick edge cases that test the rule's scope)

Show them to the user. Confirm: "When I save the rule, the invalid example should be flagged and the valid examples should not. Does this match what you want?"

If user disagrees, refine the intent (Step 1) before continuing.

## Step 3: Verify ast-grep + project setup (inline, no delegation)

1. Check `command -v ast-grep`. Missing → tell user `brew install ast-grep` and STOP.
2. Find project root: `git rev-parse --show-toplevel` (fall back to cwd, warn if not a git repo).
3. Set up the project structure inline:
   - If `<root>/.ast-grep/` missing: `mkdir -p <root>/.ast-grep` (announce: "created `.ast-grep/`")
   - If `<root>/sgconfig.yml` missing: write it with:
     ```yaml
     ruleDirs:
       - .ast-grep
     ```
     (announce: "created `sgconfig.yml`")

## Step 4: Draft the rule + test it interactively (iterate until correct)

Draft the rule pattern:

```yaml
id: <kebab-case-name>
language: <python|javascript|typescript|vue|go|rust|kotlin|java|css|...>
rule:
  pattern: <pattern in target language with $X / $$$ metavariables>
files:
  - <glob>
message: |
  <Clear explanation of what's forbidden + how to fix it.>

  Why this rule exists: <reason — Claude reads this during the redirect.>
severity: error
```

**Now test the pattern against your samples WITHOUT saving the rule.** Use `ast-grep run`:

```bash
# Should match (invalid sample):
echo '<invalid sample>' | ast-grep run --pattern '<your pattern>' --lang <language> --stdin

# Should NOT match (valid samples):
echo '<valid sample 1>' | ast-grep run --pattern '<your pattern>' --lang <language> --stdin
echo '<valid sample 2>' | ast-grep run --pattern '<your pattern>' --lang <language> --stdin
```

**Iterate.** If the pattern misses the invalid sample or fires on a valid sample, the pattern is wrong — adjust it and re-test. ast-grep patterns can be subtle:
- `$X.foo($$$)` matches any args; `$X.foo($Y)` matches exactly one arg
- For composite rules: `inside:` traverses parent; add `stopBy: end` to traverse all ancestors
- For metavariable name constraints: use `constraints: { METHOD: { regex: "..." } }` at rule top level

Don't proceed to Step 5 until ALL samples behave correctly. If you can't find a pattern that works after a few iterations, tell the user — sometimes ast-grep's structural matching genuinely can't express the intent, and a different approach is needed.

## Step 5: Save the rule with metadata

Once the pattern works on samples, save to `<project-root>/.ast-grep/<name>.yml` with this header prepended:

```yaml
# Added: <today's date YYYY-MM-DD>
# Catches: <one-line summary of what fires the rule>
# Why I added this: <first-person reminder — what user goal this serves, what was happening before>
```

The `# Why I added this:` is for the user's future-self when they wonder "why does this rule exist?" — keep it factual, not presumptive.

## Step 6: Verify against the actual codebase

Run `ast-grep scan` from the project root.

- If it fires on existing code: either the rule is too broad OR existing code already violates it. Investigate.
- **Do not declare done with false positives** — they train Claude (and the user) to ignore the rule.

## Step 7: Add a permanent test fixture

Create `<project-root>/__tests__/<name>-test.yml` (create the dir if missing):

```yaml
id: <name>
valid:
  - <reuse valid sample 1 from Step 2>
  - <reuse valid sample 2 from Step 2>
invalid:
  - <reuse invalid sample from Step 2>
```

Reuse the samples from Step 2 — don't make up new ones, that risks drift.

If the project's `sgconfig.yml` doesn't have a `testConfigs:` block yet, add:
```yaml
testConfigs:
  - testDir: __tests__
```

Run `ast-grep test --skip-snapshot-tests` to verify all tests pass.

## Step 8: Confirm to the user

Print a summary:
- Rule name + path saved
- What it catches (one line)
- Test fixture added (yes/no, path)
- Confirmation that the post-edit hook will pick it up automatically on next file edit

## Pattern syntax reference

For the actual pattern syntax beyond the basics above, see [ast-grep rule essentials](https://ast-grep.github.io/guide/rule-config.html). Don't invent syntax — when unsure, look it up or test it interactively.

## When to deviate from this flow

These steps are guidance, not a strict checklist. Reasons to deviate:
- User explicitly asks to skip testing ("just give me the rule")
- Pattern is trivial enough that samples are obvious (still recommend testing once before saving)
- Intent is unexpressible structurally — flag and suggest a different tool

Deviation is fine. Sloppy deviation isn't — explain WHY you're skipping a step if you do.
