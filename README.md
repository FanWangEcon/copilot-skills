# Personal Copilot skills

## Installed skill

[setup-latex-build](./setup-latex-build/SKILL.md) configures manual-only,
external, incremental LaTeX builds in Windows VS Code.

Open a target project and invoke in Copilot Chat:

```text
/setup-latex-build

Main document: paper.tex
External output directory: C:\path\outside\the-project\build
Configure manual builds only; no compilation on save or workspace opening.
```

Reload VS Code if the newly installed skill is not listed after typing `/`.
The skill configures a project once. After setup, save edits and press
Ctrl+Alt+B or Build LaTeX Project. No AI is required for ordinary builds.

## Repository status

This repository is installed locally under `%USERPROFILE%\.copilot\skills`.
The intended public remote is `FanWangEcon/copilot-skills`. Remote creation and
publication have not been performed by the assistant.

Review every file before publishing. Templates use placeholders rather than
personal project paths. Do not commit manuscripts, credentials, build caches,
or generated outputs.

To publish yourself using your authenticated WSL GitHub CLI, convert this local
directory to its WSL path and run these commands in WSL:

```bash
cd /mnt/c/Users/fan/.copilot/skills
gh repo create FanWangEcon/copilot-skills --public
git push -u origin main
```

If that repository already exists, inspect it before setting a remote or pushing;
do not overwrite remote history. The assistant has not inspected its existence.

For later updates, review changes, commit locally, and push from your
authenticated environment. On another Windows machine with an absent skills
directory, clone the repository into `%USERPROFILE%\.copilot\skills`; if the
directory already contains skills, merge safely instead of replacing it.

Updating a skill does not automatically update scripts copied into existing
projects. Invoke the skill there again and request an update.
