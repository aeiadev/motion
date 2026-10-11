#!/usr/bin/env bash
# Static check of .github/workflows/ci.yml, offline: ubuntu, macOS and Windows without fail-fast,
# Node LTS, a step for every test file, every step after the first test step still runs after a
# failure, pinned actions, and every tests/ path it names exists. Then checks that broken copies
# are rejected. Bash 3.2 and BSD tools are enough.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$repo_dir/.github/workflows/ci.yml"
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT

fail() {
  printf 'FAIL ci workflow: %s\n' "$*" >&2
  exit 1
}

# problems FILE: one line per broken rule; nothing when the workflow holds.
problems() {
  local file=$1 line path name
  have() { grep -Fxq -- "$1" "$file"; }
  have 'defaults:' && have '    shell: bash' || echo 'bash default'
  have '    runs-on: ${{ matrix.os }}' || echo 'runs-on'
  have '        os: [ubuntu-latest, macos-latest, windows-latest]' || echo 'os matrix'
  have '      fail-fast: false' || echo 'fail-fast'
  { have '      - uses: actions/setup-node@v4' && have '          node-version: lts/*'; } || echo 'node lts'
  have '      - uses: actions/checkout@v4' || echo 'checkout'
  for line in 'bash tests/fresh-user.sh' 'bash tests/fresh-user-codex.sh' 'node tests/static-check.mjs'; do
    have "        run: $line" || echo "step $line"
  done
  for path in "$repo_dir"/tests/test_*.sh "$repo_dir"/tests/fresh-user*.sh; do
    [[ -e $path ]] || continue
    name="tests/${path##*/}"
    have "        run: bash $name" || echo "unrun test $name"
  done
  awk '
    function flush() { if (in_step && is_test) { tests++; if (tests > 1 && !has_if) bad = 1 } }
    /^      - / { flush(); in_step = 1; has_if = 0; is_test = 0 }
    in_step && $0 == "        if: ${{ !cancelled() }}" { has_if = 1 }
    in_step && (index($0, "        run: bash tests/") == 1 || index($0, "        run: node tests/") == 1) { is_test = 1 }
    END { flush(); if (bad) print "steps after a failure" }
  ' "$file"
  while IFS= read -r line; do
    case $line in
      'actions/checkout@v4' | 'actions/setup-node@v4') ;;
      *) echo "action pin $line" ;;
    esac
  done < <(sed -n 's/^ *- uses: *//p' "$file")
  while IFS= read -r path; do
    [[ -e "$repo_dir/$path" ]] || echo "missing $path"
  done < <(grep -E '^ +run: ' "$file" | grep -Eo 'tests/[A-Za-z0-9_.-]+' || true)
  if grep -Eq '^ +run: .*\|\| *true' "$file"; then echo 'ignored failure'; fi
}

# replace FILE OLD NEW: FILE with every OLD replaced by NEW, literally, line by line.
replace() {
  awk -v old="$2" -v new="$3" '{
    out = ""; rest = $0
    while ((i = index(rest, old)) > 0) { out = out substr(rest, 1, i - 1) new; rest = substr(rest, i + length(old)) }
    print out rest
  }' "$1"
}

[[ -f $workflow ]] || fail "no $workflow"
found=$(problems "$workflow")
[[ -z $found ]] || fail "$(printf '%s\n' "$found" | tr '\n' ';')"

expect() { # expect NAME-OF-PROBLEM COPY
  local got
  got=$(problems "$2")
  printf '%s\n' "$got" | grep -Fxq -- "$1" || fail "broken copy not rejected for '$1' (got: ${got:-nothing})"
}
copy="$scratch/ci.yml"
replace "$workflow" 'os: [ubuntu-latest, macos-latest, windows-latest]' 'os: [ubuntu-latest, macos-latest]' > "$copy"
expect 'os matrix' "$copy"
replace "$workflow" 'fail-fast: false' 'fail-fast: true' > "$copy"
expect 'fail-fast' "$copy"
replace "$workflow" 'node-version: lts/*' 'node-version: 20' > "$copy"
expect 'node lts' "$copy"
replace "$workflow" 'actions/setup-node@v4' 'actions/setup-node@main' > "$copy"
expect 'action pin actions/setup-node@main' "$copy"
grep -Fxv '        if: ${{ !cancelled() }}' "$workflow" > "$copy"
expect 'steps after a failure' "$copy"
replace "$workflow" 'run: bash tests/fresh-user-codex.sh' 'run: true' > "$copy"
expect 'step bash tests/fresh-user-codex.sh' "$copy"
expect 'unrun test tests/fresh-user-codex.sh' "$copy"
replace "$workflow" 'run: node tests/static-check.mjs' 'run: node tests/static-check.mjs || true' > "$copy"
expect 'ignored failure' "$copy"
replace "$workflow" 'run: bash tests/fresh-user.sh' 'run: bash tests/nope.sh' > "$copy"
expect 'missing tests/nope.sh' "$copy"
replace "$workflow" '    shell: bash' '    shell: sh' > "$copy"
expect 'bash default' "$copy"

echo 'PASS ci workflow'
