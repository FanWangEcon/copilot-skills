---
name: setup-latex-build
description: 'Set up or update manual-only incremental LaTeX compilation in VS Code using Git Bash and latexmk, external output directories, bibliography caching, and EPS conversion caching. Use when replicating a fast LaTeX project build workflow.'
argument-hint: 'Main TeX file and absolute external output directory'
disable-model-invocation: true
---

# Manual external incremental LaTeX builds

Configure the current workspace, not this skill's own repository. Implement and
validate the configuration; do not merely give advice.

## Inputs

Determine the target workspace, main TeX document, and dedicated external output
directory. Ask for missing or ambiguous choices. Locate Git Bash and the TeX
distribution. Never read credentials or upload project content.

## Templates

- [Bash build script](./assets/draft_watch_fw.sh)
- [VS Code settings](./assets/settings.template.json)
- [Manual task](./assets/tasks.template.json)

These are self-contained templates, not executable commands to run in the skill
directory. Copy and adapt them into the target workspace. Replace every
`__MAIN_TEX__`, `__OUTPUT_DIR__`, `__SCRIPT_PATH__`, and `__GIT_BASH__` token.
Escape paths for the containing format, particularly JSON backslashes.

## Efficient execution

- Reuse main/output paths and manual-only choices already supplied. Ask only
  for unresolved decisions, grouping cleanup questions together; do not add an
  extra approval round unless the user or active planning workflow requires it.
- Inspect the main document, its actual preambles/inputs, root build rules,
  VS Code configuration, and templates in one bounded batch. Follow the main
  document's dependencies instead of recursively searching every slide,
  poster, archive, and figure tree. Narrow searches after a timeout.
- Locate Git Bash and TeX executables once. Invoke the actual Git Bash by
  absolute path, not bare `bash` (which can select WSL). If VS Code's environment
  lacks TeX on PATH, prepend the discovered distribution's bin directory in
  the adapted script; do not hard-code a distribution version from another
  project. Batch lightweight availability/version checks.
- Make one coherent template adaptation, then run `bash -n` using that same
  Git Bash, parse the merged JSON, and check unresolved tokens before any
  expensive build or source-output cleanup. Re-run syntax checks after
  structural shell edits, not after every individual line change.
- Run the real document once, then its unchanged incremental check. Use one
  small isolated fixture and a single sequential test runner for included-text,
  citation, bibliography, and figure changes. Assert which rules ran, cache
  timestamps/content, expected output changes, and exit codes; summarize
  results rather than repeatedly dumping full compiler logs.
- Regenerate the fixture's adapted script from the current project script
  after every script fix, preserving only deliberate fixture substitutions.
  Never rerun a stale copied script and attribute its behavior to the fix.
  Keep fixture outputs in their own external directory, not the real cache.
- Leave temporary directories before removing them. Verify no fixture build
  process remains, remove only known test artifacts, and retain the real
  incremental cache. Report approval/input waiting separately from execution
  time when explaining elapsed session time.

## Procedure

1. Inspect the target document, inputs, graphics, bibliography backend, TeX
   engine, latexmk rules, and existing VS Code configuration. Preserve user edits
   and unrelated settings/tasks. Do not copy manuscript content into this skill.
2. Adapt the Bash template in the project root. Set TEX_FILE to the main path
   relative to that root, PDF_FILE to the main document's basename plus `.pdf`,
   and OUT_DIR_WIN to a dedicated absolute directory outside the source tree.
   The template assumes a root-level main document; adapt source/graphics and
   bibliography lookup when the target has a different layout.
3. The baseline uses Windows Git Bash, pdflatex, and latexmk. Adapt the engine
   flags for XeLaTeX/LuaLaTeX when required. Inspect whether the project needs
   explicit latexmk configuration: the template's `-norc` ignores automatic
   configuration loading and must not silently bypass required custom rules.
4. Keep compilation manual by default (`--once`). Never start a watcher, add a
   folderOpen task, or enable automatic builds unless explicitly requested.
5. Build from the external directory. Keep all generated output there,
   including EPS conversions, filecontents products, logs, bibliography state,
   and latexmk's dependency database. Keep caches between builds. Never force
   every rebuild using `-g`/`-gg` or replace latexmk with fixed pdflatex passes.
6. Retain EPS caching when relevant. Reuse nonempty conversions newer than the
   source; regenerate missing/empty/older conversions; remove obsolete ones.
   Detect basename collisions. Inspect epstopdf options and adapt them so TeX
   uses external cached conversions, not local outputs. Do not enable
   unrestricted shell escape merely to work around path handling.
   If setting `\epstopdfsetup{outdir=./}` in the preamble, explicitly load
   `\usepackage{epstopdf}` first: graphicx's automatic epstopdf loading can
   happen later, leaving the setup command undefined at that point.
   Scope EPS discovery to the target document's asset directories, not unrelated
   posters/slides. Check all output basenames case-insensitively before any
   conversion, so a collision cannot overwrite a valid cached figure.
7. Adapt bibliography handling to the actual backend. Preserve configuration
   copying and invalidation for changed biber.conf. Handle configuration
   deletion too when applicable; do not leave a stale external configuration.
8. Merge settings rather than overwriting unrelated configuration:
   - autoBuild.run and autoClean.run are `never`.
   - outDir is the external directory.
   - external.build.command is the actual Git Bash executable.
   - external.build.args uses the absolute target script path and `--once`.
   The external command bypasses active-file/root detection so Ctrl+Alt+B and
   Build LaTeX Project always build the fixed main document, even from an
   unrelated TeX file in the workspace. Do not change global shortcuts or the
   user's PDF viewer. Keep a matching manual task/recipe as fallback.
9. Inspect source-tree generated files before cleanup. Adapt the template's
   cleanup patterns to the target: .bbl files can be intentional submission
   sources, and logs/other extensions can be unrelated source data. Remove
   only confirmed generated files and the local main output PDF. Preserve
   source PDF figures, EPS, images, TeX, bibliography, and configuration.
   Never recursively delete a project, output root, or skill directory.
10. Preserve locking, explicit error reporting, native exit codes, build timing,
    and diagnostics. Do not stop unrelated compilers. Remove stale locks only
    after verifying that their build process is no longer running.
11. Update the project's compilation documentation: save then manually build;
    no build on save/open; exact main/output paths; retained external caches;
    optional explicit --watch; crash recovery; incremental behavior.

## Required validation

- Check Bash syntax, JSON parsing, and absence of unresolved template tokens.
- Validate failure exit codes too. Bash `set -e` is suppressed inside functions
  called as `if` conditions; explicitly propagate failing conversion/copy/
  invalidation commands so a later successful command cannot hide the failure.
- Execute the configured external command from a nested source directory.
- Run a real build; verify the correct PDF and no generated source-tree files.
- Repeat unchanged: verify latexmk skips unnecessary typesetting/Biber.
- Test an included text edit: verify output updates and unnecessary figure/
  bibliography work is skipped.
- Verify new citations, bibliography edits, and changed figures cause the
  necessary work. Use isolated temporary fixtures where needed, not destructive
  manuscript edits. Test Biber configuration changes if applicable.
- Confirm saves alone do not compile and no watcher was left running.
- Clean exact temporary artifacts; restore only your own test edits.
- Measure actual elapsed times; do not promise fixed limits. Full-document
  typesetting is still required for text edits and can need additional passes.
- Report existing manuscript errors rather than claiming successful output or
  silently changing manuscript content.

## Learnings

- The Bash asset is a baseline, not proof that every project-specific
  requirement is satisfied. Its recursive cleanup list must be narrowed to
  confirmed generated files; do not delete unrelated `.bbl` or `.log` files
  just because they match an extension.
- When adapting Biber configuration handling, test deletion as well as creation
  and modification: removal of source `biber.conf` must remove the copied
  external configuration and invalidate the external `.bbl`.
- Full-document builds are not a cheap syntax check. Catch Bash syntax and
  TeX package-load-order mistakes first, then use measured real builds and
  isolated fixtures rather than repeatedly rebuilding the manuscript.

## Updating an existing setup

Inspect the installed version and merge improvements without resetting project
customization. Preserve the external incremental cache unless invalidation is
needed for correctness. Updating this skill alone does not update projects
previously configured from it.
