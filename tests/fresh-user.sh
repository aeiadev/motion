#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT
export HOME="$test_home"
export USERPROFILE="$test_home/userprofile"
export XDG_STATE_HOME="$test_home/state"
backups="$XDG_STATE_HOME/motion/backups"
unset CLAUDE_HOME CODEX_HOME
cd -- "$repo_dir"

fail() {
  printf 'FAIL fresh install: %s\n' "$*" >&2
  exit 1
}

bash ./install.sh --host claude
installed="$HOME/.claude/skills/motion"
[[ -f "$installed/SKILL.md" ]] || fail 'SKILL.md is missing'
[[ -f "$installed/systems.json" ]] || fail 'systems.json is missing'
[[ ! -e "$HOME/.agents/skills/motion" ]] || fail 'Claude install also installed the other host'
node --input-type=module - "$repo_dir/skill" "$installed" <<'NODE'
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
const [source, installed] = process.argv.slice(2);
function checkTree(relative = '') {
  const expected = readdirSync(join(source, relative), { withFileTypes: true });
  assert.deepEqual(readdirSync(join(installed, relative)).sort(), expected.map(entry => entry.name).sort(),
    `installed layout differs at ${relative || '.'}`);
  for (const entry of expected) {
    const child = join(relative, entry.name);
    if (entry.isDirectory()) checkTree(child);
    else assert.deepEqual(readFileSync(join(installed, child)), readFileSync(join(source, child)),
      `installed content differs at ${child}`);
  }
}
checkTree();
const skill = readFileSync(join(installed, 'SKILL.md'), 'utf8');
const frontmatter = skill.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/)?.[1];
assert.ok(frontmatter, 'installed SKILL.md must have YAML frontmatter');
assert.match(frontmatter, /^name:\s*motion\s*$/m, 'installed skill must be named motion');
assert.match(frontmatter, /^description:\s*\S.+$/m, 'installed skill must have a description');
const systems = JSON.parse(readFileSync(join(installed, 'systems.json'), 'utf8'));
assert.equal(systems.length, 23, 'installed registry must contain exactly 23 systems');
NODE
node tests/static-check.mjs --skill-dir "$installed"
if grep -RIl '/home/' "$installed"; then
  fail 'installed files contain an absolute home directory reference'
fi
if grep -RIl 'CLAUDE_SKILL_DIR' "$installed"; then
  fail 'installed files depend on a host-specific skill directory variable'
fi

# Portable tree snapshot (BSD find, bash 3.2): path, type and link target.
tree_snapshot() {
  local entry kind
  (cd -- "$1" && find . -print | LC_ALL=C sort | while IFS= read -r entry; do
    if [ -L "$entry" ]; then kind="l $(readlink "$entry")"; elif [ -d "$entry" ]; then kind=d; else kind=f; fi
    printf '%s %s\n' "$entry" "$kind"
  done)
}

snap_probe="$HOME/snap-probe"
mkdir -p -- "$snap_probe"
snap_a=$(tree_snapshot "$snap_probe")
mkdir -- "$snap_probe/added"
[[ $(tree_snapshot "$snap_probe") != "$snap_a" ]] || fail 'tree_snapshot did not notice a new entry'
rm -rf -- "$snap_probe"

# Rejected state paths must leave every entry in the skills root unchanged.
skills_root="${installed%/motion}"
# Git Bash without symlink rights copies instead of linking; skip only the alias case then.
alias_state=''
if ln -s -- "$skills_root" "$HOME/skills-alias" 2>/dev/null && [ -L "$HOME/skills-alias" ]; then
  alias_state="$HOME/skills-alias/nested-state"
else
  rm -rf -- "$HOME/skills-alias"
  printf 'SKIP symlink alias case: symlinks are unavailable here\n'
fi
skills_before=$(tree_snapshot "$skills_root")
for bad_state in "$skills_root/nested-state" ${alias_state:+"$alias_state"} "$skills_root/missing/../nested-state"; do
  if XDG_STATE_HOME="$bad_state" bash ./install.sh --host claude > "$HOME/nested-state-output" 2>&1; then
    fail 'accepted a backup state directory inside a skills root'
  fi
  grep -q 'outside all skills directories' "$HOME/nested-state-output" || fail 'unsafe state path failed without explaining the rejection'
  [[ $(tree_snapshot "$skills_root") == "$skills_before" ]] || fail 'rejected state path changed the skills root'
  [[ -f "$installed/SKILL.md" ]] || fail 'unsafe backup path damaged the installed skill'
done
[ -z "$alias_state" ] || rm -- "$HOME/skills-alias"

# Validation also precedes creation of an entirely new override directory.
for operation in install uninstall; do
  args=(--host claude --dir "$HOME/new skills")
  [[ $operation == install ]] || args+=(--uninstall)
  if XDG_STATE_HOME="$HOME/new skills/nested-state" bash ./install.sh "${args[@]}" > "$HOME/nested-state-output" 2>&1; then
    fail 'accepted a state path inside a nonexistent skills root'
  fi
  [[ ! -e "$HOME/new skills" ]] || fail 'rejected state path created a new skills root'
done

printf 'preserve this local file\n' > "$installed/fresh-user-sentinel.txt"
bash ./install.sh --host claude
# Hosts discover SKILL.md recursively, including hidden and deeply nested copies.
unexpected=$(find "${installed%/motion}" -name SKILL.md ! -path "$installed/SKILL.md" -print -quit)
[[ -z "$unexpected" ]] || fail 'reinstall exposed a second SKILL.md inside the skills root'
[[ ! -e "$installed/fresh-user-sentinel.txt" ]] || fail 'reinstall did not replace the skill cleanly'
backup=$(find "$backups" -mindepth 2 -maxdepth 2 -path '*/motion.backup.*/fresh-user-sentinel.txt' -print -quit)
[[ -n "$backup" ]] || fail 'reinstall did not preserve the existing directory in a backup'
[[ $(cat "$backup") == 'preserve this local file' ]] || fail 'backup changed the existing contents'
# Fail the final move, then verify automatic restoration from the external backup.
printf 'restore after failure\n' > "$installed/restore-sentinel.txt"
mv() {
  if [[ ${2:-} == */.motion-install.* && ${3:-} == */motion ]]; then
    printf 'simulated install move failure\n' >&2
    return 1
  fi
  command mv "$@"
}
export -f mv
if bash ./install.sh --host claude > "$HOME/restore-output" 2>&1; then
  fail 'injected install failure unexpectedly succeeded'
fi
unset -f mv
[[ -f "$installed/SKILL.md" && $(cat "$installed/restore-sentinel.txt") == 'restore after failure' ]] || fail 'failed reinstall did not restore the previous skill'
[[ $(find "${installed%/motion}" -name SKILL.md -print) == "$installed/SKILL.md" ]] || fail 'restoration exposed a second skill'

printf 'preserve this second file\n' > "$installed/fresh-user-second.txt"
bash ./install.sh --host claude
second_backup=$(find "$backups" -mindepth 2 -maxdepth 2 -path '*/motion.backup.*/fresh-user-second.txt' -print -quit)
[[ -n "$second_backup" && ${backup%/*} != "${second_backup%/*}" ]] || fail 'repeated reinstall did not create a unique backup'
[[ $(cat "$second_backup") == 'preserve this second file' ]] || fail 'second backup changed the existing contents'
bash ./install.sh --host claude --uninstall
[[ ! -e "$installed" ]] || fail 'uninstall left the skill directory behind'
[[ -f "$backup" && -f "$second_backup" ]] || fail 'uninstall removed a previous backup'
# The documented manual restore keeps the original content usable.
mv -- "${backup%/*}" "$installed"
[[ -f "$installed/SKILL.md" && $(cat "$installed/fresh-user-sentinel.txt") == 'preserve this local file' ]] || fail 'manual backup restore failed'

bash ./install.sh --uninstall --host claude

export CLAUDE_HOME="$HOME/custom claude"
bash ./install.sh --host claude
[[ -f "$CLAUDE_HOME/skills/motion/SKILL.md" ]] || fail 'CLAUDE_HOME installation failed'
bash ./install.sh --host claude --uninstall
[[ ! -e "$CLAUDE_HOME/skills/motion" ]] || fail 'CLAUDE_HOME uninstall failed'
bash ./install.sh --host claude --dir "$HOME/custom skills"
[[ -f "$HOME/custom skills/motion/SKILL.md" ]] || fail '--dir installation failed'
[[ ! -e "$CLAUDE_HOME/skills/motion" ]] || fail '--dir did not override CLAUDE_HOME'
bash ./install.sh --uninstall --host claude --dir "$HOME/custom skills"
[[ ! -e "$HOME/custom skills/motion" ]] || fail '--dir uninstall failed'

# Git Bash simulation: fake uname/cygpath/node/ffmpeg on PATH, no real Windows needed.
win_bin="$HOME/win-bin"
mkdir -p -- "$win_bin" "$HOME/winprofile"
printf '#!/bin/sh\necho MINGW64_NT-10.0\n' > "$win_bin/uname"
printf '#!/bin/sh\nif [ "$1" = -u ]; then echo "%s/winprofile"; else [ "$1" = -- ] && shift; echo "M:$1"; fi\n' "$HOME" > "$win_bin/cygpath"
printf '#!/bin/sh\necho "$@" >> "%s/node-args"\n' "$HOME" > "$win_bin/node"
printf '#!/bin/sh\necho "$@" >> "%s/ffmpeg-args"\n' "$HOME" > "$win_bin/ffmpeg"
chmod +x "$win_bin"/*
env -u HOME -u CLAUDE_HOME -u XDG_STATE_HOME PATH="$win_bin:$PATH" USERPROFILE='C:\Users\me' bash ./install.sh --host claude > /dev/null
[[ -f "$HOME/winprofile/.claude/skills/motion/SKILL.md" ]] || fail 'Git Bash install did not use the Windows user profile when HOME is unset'
bash ./install.sh --uninstall --host claude --dir "$HOME/winprofile/.claude/skills"
env -u CLAUDE_HOME -u XDG_STATE_HOME PATH="$win_bin:$PATH" USERPROFILE='C:\Users\me' bash ./install.sh --host claude > /dev/null
[[ -f "$HOME/.claude/skills/motion/SKILL.md" && ! -e "$HOME/winprofile/.claude/skills/motion" ]] || fail 'USERPROFILE overrode an explicit HOME'
bash ./install.sh --uninstall --host claude
bash ./install.sh --help | grep -q 'CLAUDE_HOME:-\$HOME/.claude' || fail '--help lost its path text'
PATH="$win_bin:$PATH" bash skill/scripts/export-mp4.sh "$repo_dir/skill/SKILL.md" "$HOME/out/x.mp4" > /dev/null
grep -q 'M:' "$HOME/node-args" && grep -q 'M:' "$HOME/ffmpeg-args" || fail 'export-mp4 did not pass mixed paths under Git Bash'
rm -f -- "$HOME/node-args" "$HOME/ffmpeg-args"
PATH="$win_bin:$PATH" TMPDIR="$HOME/tmp dir" bash skill/scripts/export-mp4.sh "$repo_dir/skill/SKILL.md" "$HOME/out/x.mp4" > /dev/null 2>&1 && fail 'export-mp4 ignored a missing TMPDIR' || true
rm -f -- "$HOME/node-args" "$HOME/ffmpeg-args"
# Linux/macOS paths stay untouched when cygpath is absent.
nocyg_bin="$HOME/nocyg-bin"
mkdir -p -- "$nocyg_bin"
cp -- "$win_bin/node" "$win_bin/ffmpeg" "$nocyg_bin/"
PATH="$nocyg_bin:/usr/bin:/bin" bash skill/scripts/export-mp4.sh "$repo_dir/skill/SKILL.md" "$HOME/out/y.mp4" > /dev/null
grep -q 'M:' "$HOME/node-args" && fail 'export-mp4 rewrote paths without cygpath'
# Missing node gets a one-line note from the installer.
nonode_bin="$HOME/nonode-bin"
mkdir -p -- "$nonode_bin"
for command_name in dirname mkdir mktemp cp mv rm rmdir uname; do
  printf '#!%s\nexec %q "$@"\n' "$(command -v bash)" "$(command -v "$command_name")" > "$nonode_bin/$command_name"
  chmod +x "$nonode_bin/$command_name"
done
env -u CLAUDE_HOME PATH="$nonode_bin" "$(command -v bash)" ./install.sh --host claude --dir "$HOME/nonode skills" 2> "$HOME/nonode-err" > /dev/null
[[ $(grep -c 'Node.js was not found' "$HOME/nonode-err") -eq 1 ]] || fail 'missing node was not reported in one line'
printf 'PASS fresh install (Claude): layout, metadata, paths, registry, static checks, unique backups and uninstall\n'
