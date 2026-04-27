# ast-checker

A Claude Code plugin that runs [ast-grep](https://ast-grep.github.io/) on every file Claude edits, blocking Claude when project-specific architecture rules fail. Multi-language via tree-sitter (Python, JS, Go, Rust, Java, Kotlin, Ruby, etc.).

## What this is for

You want to forbid specific code shapes — function calls, imports, structural patterns — and have Claude self-correct in the same turn. The plugin sits in Claude's edit loop, runs your `.ast-grep/` rules after each edit, and returns a `decision: block` payload when a rule fires. Claude sees the block, fixes, retries — within a single turn.

## What this is NOT for

| Problem | Use this instead |
|---|---|
| Tell Claude what components/APIs exist | CLAUDE.md, [Karpathy's LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f), RAG over your codebase |
| Standard formatting | Prettier / Black / gofmt — runs in your existing toolchain |
| Standard language linting | ruff / ESLint / golangci-lint — separate plugins or your normal lint pipeline |
| Semantic code review ("is this naming clear?") | LLM-as-judge / `/review` skill |

This plugin does ONE thing: run `ast-grep` rules on edit and block Claude on findings. See [PHILOSOPHY.md](PHILOSOPHY.md) for the framework.

## Quickstart (30 seconds)

1. Install ast-grep: `brew install ast-grep` (or `cargo install ast-grep --locked`)
2. Install plugin (assumes you've added the marketplace):
   ```
   /plugin install ast-checker@yuncun
   ```
3. In your project, run `/harness init` — scaffolds `sgconfig.yml` + `.ast-grep/` with a starter rule.
4. Adapt the starter rule to your project (file paths, field names). Edit a file. Watch Claude get blocked and self-correct.

## Slash commands

| Command | What it does |
|---|---|
| `/harness init` | Set up ast-checker in the current project (creates `sgconfig.yml`, `.ast-grep/`, copies a starter rule) |
| `/harness status` | Show current setup: ast-grep installed?, rules loaded, last scan result |
| `/harness add-rule` | Browse the rule catalog (no args) or copy a named rule into `.ast-grep/` |

## How it works

```
Claude edits file → PostToolUse hook fires
                  → if project has sgconfig.yml or .ast-grep/, run `ast-grep scan` on the file
                  → findings? return JSON {"decision": "block", "reason": ...}
                  → Claude sees the block, edits again to fix
                  → loop until clean
```

The hook auto-detects the project root (walks up from the edited file looking for `.git`, `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`, or `sgconfig.yml`). Skips silently if ast-grep isn't installed or if no rules exist.

## Adding rules

Browse [`templates/`](templates/) for the catalog. Each rule is a self-contained YAML file with a metadata header (when to use, when not to, how to adapt).

Three ways:
- **From the catalog:** `/harness add-rule <name>` — copies a template and surfaces placeholders
- **Custom rule:** ask Claude in natural language ("add an ast-grep rule to ban console.log in components") — the bundled `writing-ast-grep-rules` skill walks Claude through pattern, file location, and testing
- **Manually:** `cp templates/<rule>.yml /your/project/.ast-grep/` and adapt

## Limitations

- Mac/Linux only for now. The hook script is bash; Windows would need a `.cmd` wrapper.
- The hook runs ast-grep but no other linters. For ruff/eslint/etc., use a separate plugin or your existing pipeline. (Other `*-checker` plugins live under the same `yuncun` marketplace.)

## License

MIT
