# Semgrep rule catalog

Architecture rules that catch common LLM shortcuts. Each rule is in its own file with metadata explaining when to use it. Copy the ones you want into your project's `.semgrep/` directory.

| Rule | Catches | Added |
|---|---|---|
| [no-direct-field-mutation](no-direct-field-mutation.yml) | LLM mutating an entity field outside the service layer | 2026-04-24 |
| [handler-defer-persist](handler-defer-persist.yml) | Persistence calls inside handlers that should defer to accept/commit | 2026-04-24 |
| [routes-must-use-service](routes-must-use-service.yml) | Route handlers calling backend methods directly instead of via service layer | 2026-04-24 |

## How to use

1. Pick the rules that match patterns in your project.
2. Copy them into your project's `.semgrep/` directory:

   ```bash
   mkdir -p .semgrep
   cp path/to/erics-review-harness/templates/semgrep/no-direct-field-mutation.yml .semgrep/
   ```

3. **Adapt the rule.** Every rule has placeholders (e.g. `**/your_app/routes.py`, field names, function patterns). Edit them to match your project.

4. **Verify zero false positives** before committing. Run `semgrep --config=.semgrep/ .` against your existing code — if it fires, either the rule is wrong or your code already has the violation. Fix one before adding the rule.

5. The post-edit hook (from this plugin) will pick up the new rules automatically — it reads `.semgrep/` from your project root.

## Adding your own rules

Same pattern: one file per rule, metadata header explaining when to use it. Each rule should pass on existing code (zero false positives) before you commit. PRs welcome if you have rules that generalize beyond your project.

## Why per-file?

Each file is a self-contained unit you can copy or skip. The metadata header tells you what each rule does and when it's appropriate, so you can browse the catalog without reading the actual Semgrep YAML. Adding more rules over time doesn't bloat any single file.
