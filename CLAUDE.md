# Working on the ast-checker plugin

This repo IS the `ast-checker` plugin published in the `yuncun` marketplace. Templates in `templates/` ship to every install.

## Adding a new rule to the catalog

When a Claude shortcut keeps recurring across multiple sessions, it earns a slot in the catalog. To add one:

1. **Create `templates/<rule-name>.yml`** with this header convention:

   ```yaml
   # Added: YYYY-MM-DD
   # Catches: <one-line description of what the rule fires on>
   # Why I added this: <first-person reminder of intent — what user goal this serves>
   # Adapt: <what placeholders the user must change for their project>

   id: <rule-name>
   language: <python|javascript|...>
   rule:
     pattern: <ast-grep pattern>
   files:
     - "<glob with **/your_app/ placeholder>"
   message: |
     <What's forbidden + how to fix.>

     Why this rule exists: <reason — Claude reads this during the redirect.>
   severity: error
   ```

2. **Write a sibling test at `__tests__/<rule-name>-test.yml`:**

   ```yaml
   id: <rule-name>
   valid:
     - <code that should NOT match>
   invalid:
     - <code that SHOULD match>
   ```

3. **Verify:** `ast-grep test --skip-snapshot-tests` — all tests must pass.

4. **Update `templates/README.md`** to list the new rule in the catalog table.

5. Commit + push. Bump `version` in `.claude-plugin/plugin.json` if the change is significant; existing installs pick up the new version on next `/plugin marketplace remove + add + install` cycle.

## Conventions

- **Metadata header is for humans, `message:` is for Claude.** The `# Why I added this:` line is what future-you sees when wondering "why this rule?". The `message:` field is what Claude sees during the redirect — explain not just WHAT is forbidden but WHY, so Claude makes a good fix.
- **Templates use placeholder paths** (`**/your_app/routes.py`). Users adapt these to their real project on `/harness add-rule`.
- **Zero false positives is the bar** before adding a rule. If `ast-grep scan` fires on existing code in any project that uses this template, the rule is too broad.

## Don't break the harness

- Don't edit hooks/`ast-grep-on-edit.sh` without testing — it runs on every Claude edit in every project that has this plugin installed. Silent breakage means Claude is no longer caught for any rule.
- Don't change the JSON `decision: block` output format without checking the [Claude Code hooks docs](https://code.claude.com/docs/en/hooks) — the format is what makes Claude self-correct.
- Don't add new linters or dispatchers to the hook. This plugin does ast-grep only by design (single responsibility). Other linters get their own plugins.
