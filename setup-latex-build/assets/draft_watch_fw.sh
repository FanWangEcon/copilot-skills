#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEX_FILE="__MAIN_TEX__"
PDF_FILE="$(basename "${TEX_FILE%.tex}").pdf"
OUT_DIR_WIN='__OUTPUT_DIR__'
MODE="${1:---once}"

if [[ $# -gt 1 || ( "$MODE" != "--watch" && "$MODE" != "--once" ) ]]; then
  echo "Usage: $(basename "$0") [--watch|--once]" >&2
  exit 2
fi
if ! command -v cygpath >/dev/null 2>&1; then
  if command -v wslpath >/dev/null 2>&1 && [[ -x '/mnt/c/Program Files/Git/bin/bash.exe' ]]; then
    echo "[watch] Redirecting WSL launch to Windows Git Bash."
    exec '/mnt/c/Program Files/Git/bin/bash.exe' --noprofile --norc \
      "$(wslpath -w "$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")")" "$@"
  fi
  echo "Run this script with Git Bash (C:\\Program Files\\Git\\bin\\bash.exe), not WSL Bash." >&2
  exit 1
fi
if [[ ! -f "$SCRIPT_DIR/$TEX_FILE" ]]; then
  echo "Main document not found: $SCRIPT_DIR/$TEX_FILE" >&2
  exit 1
fi
for tool in latexmk.exe epstopdf.exe; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool is required. Add your TeX Live bin\\windows directory to PATH." >&2
    exit 1
  fi
done

OUT_DIR="$(cygpath -u "$OUT_DIR_WIN")"
OUT_TEX="$(cygpath -m "$OUT_DIR")"
SOURCE_WIN="$(cygpath -m "$SCRIPT_DIR")"
TEX_WIN="$(cygpath -m "$SCRIPT_DIR/$TEX_FILE")"
LOCK_DIR="${OUT_DIR}.watch.lock"
mkdir -p "$OUT_DIR"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Build target is locked: $LOCK_DIR" >&2
  echo "Stop the other watcher/build first. If it crashed, remove this empty lock directory manually." >&2
  exit 1
fi
trap 'rmdir "$LOCK_DIR"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Windows TeX uses semicolon-separated search paths; the trailing separator
# preserves its standard package search. Relative project inputs resolve here.
export TEXINPUTS="${SOURCE_WIN};${TEXINPUTS:-}"
export BIBINPUTS="${SOURCE_WIN};${BIBINPUTS:-}"
export MSYS_NO_PATHCONV=1

generated_files() {
  find "$1" -type f \( \
    -name '*.aux' -o -name '*.bbl' -o -name '*.bcf' -o -name '*.bcf-SAVE-ERROR' \
    -o -name '*.bbl-SAVE-ERROR' -o -name '*.blg' -o -name '*.fdb_latexmk' -o -name '*.fls' \
    -o -name '*.log' -o -name '*.out' -o -name '*.run.xml' \
    -o -name '*.synctex.gz' -o -name '*.synctex(busy)' \
    -o -name '*.toc' -o -name '*.lof' -o -name '*.lot' \
    -o -name '*.idx' -o -name '*.ilg' -o -name '*.ind' \
    -o -name '*.nav' -o -name '*.snm' -o -name '*.vrb' \
    -o -name '*-eps-converted-to.pdf' -o -name 'pdflatex*.tmp' \
  \) -print0
}

cleanup_generated() {
  local directory="$1"
  local file
  local files
  # Collect the list first so enumeration failures are not lost in a process
  # substitution. Deletions always target individual known build files.
  files="$(generated_files "$directory" | tr '\0' '\n')" || return
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    echo "[cleanup] $file"
    rm -f -- "$file" || return
  done <<< "$files"
}

cleanup_local() {
  cleanup_generated "$SCRIPT_DIR" || return
  if [[ -f "$SCRIPT_DIR/$PDF_FILE" ]]; then
    echo "[cleanup] $SCRIPT_DIR/$PDF_FILE"
    rm -f -- "$SCRIPT_DIR/$PDF_FILE" || return
  fi
}

compile_build() {
  local status
  local eps
  local converted
  local eps_files
  local cached_files
  local cached
  local temporary_pdf
  cleanup_local || return
  echo "[compile] Building $TEX_FILE into $OUT_DIR_WIN"
  # Invoke the converter directly: restricted TeX shell escape rejects absolute
  # output paths outside the source tree. No unrestricted shell escape is needed.
  eps_files="$(find "$SCRIPT_DIR" -type f -iname '*.eps')" || return
  declare -A converted_sources=()
  while IFS= read -r eps; do
    [[ -n "$eps" ]] || continue
    converted="$(basename "${eps%.*}")-eps-converted-to.pdf"
    if [[ -n "${converted_sources[$converted]:-}" ]]; then
      echo "[compile] Duplicate EPS output name: $eps and ${converted_sources[$converted]}" >&2
      return 1
    fi
    converted_sources["$converted"]="$eps"
    if [[ -s "$OUT_DIR/$converted" && ! "$eps" -nt "$OUT_DIR/$converted" ]]; then
      echo "[cache] Reusing $converted"
      continue
    fi
    echo "[convert] $eps"
    temporary_pdf="$OUT_DIR/${converted%.pdf}.pending.pdf"
    if epstopdf.exe "--outfile=$(cygpath -m "$temporary_pdf")" "$(cygpath -m "$eps")"; then
      if [[ ! -s "$temporary_pdf" ]]; then
        echo "[convert] Converter produced no PDF for $eps" >&2
        return 1
      fi
      mv -f -- "$temporary_pdf" "$OUT_DIR/$converted" || return
    else
      status=$?
      rm -f -- "$temporary_pdf" || return
      return "$status"
    fi
  done <<< "$eps_files"
  cached_files="$(find "$OUT_DIR" -maxdepth 1 -type f -name '*-eps-converted-to.pdf' -print)" || return
  while IFS= read -r cached; do
    [[ -n "$cached" ]] || continue
    if [[ -z "${converted_sources[$(basename "$cached")]:-}" ]]; then
      echo "[cache] Removing obsolete conversion $cached"
      rm -f -- "$cached" || return
    fi
  done <<< "$cached_files"
  if [[ -f "$SCRIPT_DIR/biber.conf" ]]; then
    if ! cmp -s "$SCRIPT_DIR/biber.conf" "$OUT_DIR/biber.conf"; then
      cp -- "$SCRIPT_DIR/biber.conf" "$OUT_DIR/biber.conf" || return
      # Biber's configuration is not necessarily a recorded latexmk input.
      # Removing its result explicitly schedules bibliography regeneration.
      rm -f -- "$OUT_DIR/${TEX_FILE%.tex}.bbl" || return
    fi
  fi
  # The existing epstopdf outdir=./ and filecontents now point externally.
  if (
    cd "$OUT_DIR" &&
    latexmk.exe -norc -cd- -pdf -emulate-aux-dir- \
      -interaction=nonstopmode -halt-on-error -file-line-error \
      "-outdir=$OUT_TEX" "-auxdir=$OUT_TEX" "$TEX_WIN"
  ); then
    if [[ ! -s "$OUT_DIR/$PDF_FILE" ]]; then
      echo "[compile] Compiler reported success but the expected PDF is missing or empty." >&2
      return 1
    fi
    cleanup_local || return
    echo "[compile] Ready: $OUT_DIR_WIN\\$PDF_FILE (incremental build cache retained)."
  else
    status=$?
    return "$status"
  fi
}

compile_once() {
  local status started="$SECONDS"
  if compile_build; then
    echo "[compile] Completed in $((SECONDS - started)) seconds."
    return 0
  else
    status=$?
    echo "[compile] Failed (exit $status). Diagnostics retained in $OUT_DIR_WIN." >&2
    echo "[compile] Failed after $((SECONDS - started)) seconds." >&2
    return "$status"
  fi
}

source_signature() {
  find "$SCRIPT_DIR" -type f \
    \( -iname '*.tex' -o -iname '*.bib' -o -iname '*.eps' \
       -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
       -o -iname '*.pdf' -o -iname '*.svg' -o -name 'biber.conf' \) \
    ! -name "$PDF_FILE" ! -name '*-eps-converted-to.pdf' \
    -printf '%P|%T@|%s\n' | LC_ALL=C sort | sha256sum
}

if [[ "$MODE" == "--once" ]]; then
  compile_once
  exit 0
fi

LAST_SIG="$(source_signature)"
if ! compile_once; then
  echo "[watch] Fix errors and save a source file to retry; watcher continues." >&2
fi
echo "[watch] Watching $SCRIPT_DIR recursively (Ctrl+C to stop)."
echo "[watch] Output: $OUT_DIR_WIN\\$PDF_FILE"
while true; do
  sleep 1
  NEW_SIG="$(source_signature)"
  if [[ "$NEW_SIG" != "$LAST_SIG" ]]; then
    # Snapshot before building so an edit during a build triggers another pass.
    LAST_SIG="$NEW_SIG"
    echo "[watch] Source change detected."
    if ! compile_once; then
      echo "[watch] Fix errors and save a source file to retry; watcher continues." >&2
    fi
  fi
done
