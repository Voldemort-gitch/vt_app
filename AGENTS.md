# AGENTS.md

# Visual Time (vt_app) - AI Git Workflow

## Purpose

This file defines the mandatory Git workflow for all AI coding agents
(OpenCode, Claude Code, Codex, etc.) working on this repository.

Always read this file before performing any coding or Git operation.

---

# Role

You are an AI software engineer.

Your responsibilities are:

- Implement requested features.
- Fix bugs.
- Refactor code when requested.
- Manage Git until the code is pushed.
- Leave all review and merge decisions to the developer.

---

# Git Workflow

For every coding task:

1. Ensure the local repository is synchronized with the latest `main`.
2. If currently on `main`, create a new working branch.
3. Implement the requested changes.
4. Run project validation.
5. Commit using a meaningful commit message.
6. Push the branch to GitHub.
7. Stop and wait for the developer.

---

# Branch Naming

Use one of the following:

feature/<feature-name>

bugfix/<bug-name>

hotfix/<issue>

refactor/<module>

Examples

feature/payroll

feature/leave-management

bugfix/login

refactor/attendance-service

---

# Validation

Before committing always run:

```bash
flutter analyze
```

If tests exist:

```bash
flutter test
```

If formatting is needed:

```bash
dart format .
```

If validation fails:

- Stop immediately.
- Explain the error.
- Wait for instructions.

Never commit failing code.

---

# Commit Rules

Use clear commit messages.

Good examples:

- Add payroll module
- Fix GPS validation
- Improve QR scanner
- Refactor attendance repository

Avoid:

- update
- fix
- changes
- test

---

# Push Rules

After committing:

- Push the current branch.
- Stop.

Do not continue automatically.

---

# Never Do These

Never:

- Commit directly to main
- Merge Pull Requests
- Approve Pull Requests
- Close Pull Requests
- Delete local branches
- Delete remote branches
- Force push
- Rewrite Git history
- Modify GitHub settings

These actions always require developer approval.

---

# After Push

After the branch has been pushed:

STOP.

Wait for the developer.

The developer will:

- Open the Pull Request
- Review GitHub Actions
- Review CodeRabbit feedback
- Merge if approved

Do nothing until instructed.

---

# After Merge

Only after the developer explicitly says:

"The Pull Request has been merged."

perform:

```bash
git checkout main
git pull origin main
git branch -d <merged-branch>
```

Never assume a Pull Request has been merged.

---

# Safety

If Git reports:

- merge conflicts
- rejected push
- authentication errors
- detached HEAD
- unknown repository state

Stop immediately.

Explain the issue.

Wait for the developer.

Never attempt risky recovery automatically.

---

# Highest Priority Rule

Protect the `main` branch.

Never perform any irreversible Git operation without explicit developer approval.