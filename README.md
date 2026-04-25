# erics-review-harness

A post-edit hook for [Claude Code](https://claude.ai/code) that runs your linters on every file Claude edits, plus a curated catalog of [Semgrep](https://semgrep.dev) rules for AI-specific architecture violations.

## why

When Claude writes code, it drifts. Inline styles, hardcoded values, raw `fetch()` calls, mutations of fields outside the service layer — the same shortcuts come back over and over, even when CLAUDE.md explicitly forbids them.

The reason isn't carelessness. CLAUDE.md is **advisory** — a long instruction set the model may or may not honor in any given turn. Past a certain rule count, adherence drops. You can't scale code quality by writing more rules in CLAUDE.md.

## solution

Three layers, with different reliability and cost:

| Layer | Mechanism | Catches | Reliability |
|---|---|---|---|
| **Inform** | CLAUDE.md, skills | Intent, *why* decisions | Low (LLM drifts) |
| **Enforce** | Linters via post-edit hook (this repo) | Mechanical violations | 100% — deterministic |
| **Audit** | Code review (manual or `/review`) | Judgment-based smells | Medium |

This plugin owns the **enforce** layer. After every `Edit` or `Write`, the hook runs the right linter for the file type. If the linter finds errors, the hook returns a JSON `{"decision": "block", "reason": "..."}` payload. Claude sees the block and fixes the error in the next turn. Loops until lint passes.

The post-edit hook is one of the few mechanisms in Claude Code that's **guaranteed to be seen by the model** — unlike CLAUDE.md, which is advisory.

## architecture

1. **The hook script** (`hooks/lint-on-edit.sh`) — auto-detects your project root, Python venv, and frontend dir, then runs:
   - **Language-specific linters** by file extension:
     - `.py` → ruff (auto-fix + check)
     - `.css` → stylelint
     - `.vue` / `.js` / `.ts` / `.tsx` / `.jsx` → ESLint (auto-fix + check) and Prettier
   - **Semgrep** on any file in the project (if `.semgrep/` exists). Semgrep [supports 30+ languages](https://semgrep.dev/docs/supported-languages) — Python, JS, TS, Java, Go, Rust, Ruby, C, C++, Kotlin, Scala, Swift, PHP, C#, etc. Rules declare their language; only matching rules fire.
   - Linters that aren't installed are skipped silently.

2. **Semgrep rule catalog** (`templates/semgrep/`) — curated architecture rules with metadata headers explaining when to use them. Copy what you want. Each rule has zero false positives by design.

That's it. The plugin doesn't ship ESLint or stylelint rules — those are well-documented elsewhere and every project has its own. The plugin's value-add is (a) wiring everything into the Claude Code edit loop, and (b) the Semgrep rules, which are the non-obvious part — and (c) because Semgrep is multi-language, the architecture-rules layer works for any language Semgrep supports.

## Install

This is a Claude Code plugin. Install from this repo:

```bash
# In Claude Code:
/plugin install <github-url-here>
```

## Use it in your project

The plugin runs whatever linters are configured in your project. It doesn't impose anything.

### Python projects

1. Install ruff: `pip install ruff` (in your venv)
2. Configure ruff in `pyproject.toml` as you normally would
3. Hook will run ruff on every `.py` edit
4. **Optional but recommended:** install Semgrep (`pip install semgrep`), browse [`templates/semgrep/`](templates/semgrep/), copy rules you want into `.semgrep/`

### JS / Vue / TS projects

1. Set up ESLint + Prettier as you normally would (with `eslint-plugin-vue`, `eslint-plugin-react`, etc.)
2. Hook will run ESLint + Prettier on every `.vue`/`.js`/`.ts` edit
3. **Suggestion:** add these AI-specific ESLint rules to your config — they catch common LLM shortcuts but aren't in this plugin because they're standard ESLint:
   - `max-lines: ['warn', { max: 300 }]` — forces componentization without naming "make components" as a rule
   - `max-lines-per-function: ['warn', { max: 80 }]`
   - `no-console: ['error', { allow: ['error', 'warn'] }]`
   - `no-magic-numbers` with a curated `ignore` list
   - For component dirs: `no-restricted-syntax` banning `fetch()` (force use of an api wrapper)

### CSS projects

1. Set up stylelint as you normally would (with `stylelint-config-standard` etc.)
2. Hook will run stylelint on every `.css` edit
3. **Suggestion:** add `color-no-hex` if you have a design token system, and `unit-disallowed-list: [['px']]` for layout values

### Other languages (Go, Rust, Java, Ruby, etc.)

The hook doesn't ship language-specific linter integrations beyond Python and JS/Vue/CSS, but Semgrep works natively for 30+ languages. Install Semgrep, write rules in `.semgrep/` for your language, and they'll fire on every edit. Bring your own standard linters (`gofmt`, `clippy`, `rubocop`) and run them via your project's pre-commit / CI — the hook focuses on the architecture layer.

PRs welcome to add language-specific linter routing for other ecosystems.

## Why these tools

| Tool | What it catches | Why in this plugin's flow |
|---|---|---|
| **ruff** | Standard Python lints (unused imports, syntax, deprecated features) | Fast, ubiquitous, every Python project should have it |
| **semgrep** | Pattern-based architecture rules across 30+ languages — "field X cannot be mutated outside file Y", "function matching pattern A cannot call function B" | The novel part; templates included; multi-language by default |
| **ESLint** | JS/Vue/React rules. Magic numbers, max-lines, custom restricted patterns | Universal in JS world; bring your own config |
| **stylelint** | CSS rules. Hardcoded colors, disallowed units | Universal in CSS world; bring your own config |
| **Prettier** | Formatting | Removes a whole category of churn |

For Python architecture (layer dependencies), also consider [`import-linter`](https://github.com/seddonym/import-linter) — separate tool, configured in `pyproject.toml`. The hook doesn't run it (it's a project-level check, not a per-file check), but `make lint` should.

## What this is NOT

- **Not a linter.** It runs your linters; you bring them.
- **Not a replacement for code review.** Linters catch mechanical violations. Architectural judgment ("you bandaided this") still needs a human or an LLM auditor.
- **Not a silver bullet.** Bad rules cause false positives that train the LLM to suppress them. Test every rule on existing code before adding it.

## Limitations

- Mac/Linux only for now. The hook script is bash; Windows would need a `.cmd` wrapper.
- Auto-detection is heuristic. Projects with non-standard layouts may need overrides (future work).
- Frontend detection only checks the obvious places (`./`, `frontend/`, `web/`, `client/`, `app/`).

## License

MIT
