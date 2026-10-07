#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT
export HOME="$test_home"
export XDG_STATE_HOME="$test_home/state"
backups="$XDG_STATE_HOME/motion/backups"
unset CLAUDE_HOME CODEX_HOME
cd -- "$repo_dir"

fail() {
  printf 'FAIL fresh install (Codex): %s\n' "$*" >&2
  exit 1
}

# Preflight must reject the second host's unsafe state path before creating either root.
if XDG_STATE_HOME="$HOME/.agents/skills/nested-state" bash ./install.sh --host both > "$HOME/nested-state-output" 2>&1; then
  fail 'accepted a state path inside a future skills root'
fi
[[ ! -e "$HOME/.claude" && ! -e "$HOME/.agents" && ! -e "$XDG_STATE_HOME" ]] || fail 'rejected multi-host install created directories'

bash ./install.sh --host codex
installed="$HOME/.agents/skills/motion"
[[ -f "$installed/SKILL.md" ]] || fail 'SKILL.md is missing from the shared skills directory'
[[ ! -e "$HOME/.claude/skills/motion" ]] || fail 'Codex install also installed Claude'
[[ ! -e "$HOME/.codex/skills/motion" ]] || fail 'Codex install used the deprecated directory'
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
    else {
      const contents = readFileSync(join(installed, child));
      assert.deepEqual(contents, readFileSync(join(source, child)), `installed content differs at ${child}`);
      assert.ok(!contents.includes(Buffer.from('CLAUDE_SKILL_DIR')), `host-specific path in ${child}`);
      assert.ok(!contents.includes(Buffer.from('/home/')), `absolute home directory in ${child}`);
    }
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

# Rejected state paths must leave every entry in the skills root unchanged.
skills_root="${installed%/motion}"
ln -s -- "$skills_root" "$HOME/skills-alias"
skills_before=$(find "$skills_root" -printf '%P %y %l\n' | LC_ALL=C sort)
for bad_state in "$skills_root/nested-state" "$HOME/skills-alias/nested-state" "$skills_root/missing/../nested-state"; do
  if XDG_STATE_HOME="$bad_state" bash ./install.sh --host codex > "$HOME/nested-state-output" 2>&1; then
    fail 'accepted a backup state directory inside a skills root'
  fi
  grep -q 'outside all skills directories' "$HOME/nested-state-output" || fail 'unsafe state path failed without explaining the rejection'
  [[ $(find "$skills_root" -printf '%P %y %l\n' | LC_ALL=C sort) == "$skills_before" ]] || fail 'rejected state path changed the skills root'
  [[ -f "$installed/SKILL.md" ]] || fail 'unsafe backup path damaged the installed skill'
done
rm -- "$HOME/skills-alias"

# Validation also precedes creation of an entirely new override directory.
for operation in install uninstall; do
  args=(--host codex --dir "$HOME/new skills")
  [[ $operation == install ]] || args+=(--uninstall)
  if XDG_STATE_HOME="$HOME/new skills/nested-state" bash ./install.sh "${args[@]}" > "$HOME/nested-state-output" 2>&1; then
    fail 'accepted a state path inside a nonexistent skills root'
  fi
  [[ ! -e "$HOME/new skills" ]] || fail 'rejected state path created a new skills root'
done

printf 'preserve this local file\n' > "$installed/fresh-user-sentinel.txt"
bash ./install.sh --host codex
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
if bash ./install.sh --host codex > "$HOME/restore-output" 2>&1; then
  fail 'injected install failure unexpectedly succeeded'
fi
unset -f mv
[[ -f "$installed/SKILL.md" && $(cat "$installed/restore-sentinel.txt") == 'restore after failure' ]] || fail 'failed reinstall did not restore the previous skill'
[[ $(find "${installed%/motion}" -name SKILL.md -print) == "$installed/SKILL.md" ]] || fail 'restoration exposed a second skill'

printf 'preserve this second file\n' > "$installed/fresh-user-second.txt"
bash ./install.sh --host codex
second_backup=$(find "$backups" -mindepth 2 -maxdepth 2 -path '*/motion.backup.*/fresh-user-second.txt' -print -quit)
[[ -n "$second_backup" && ${backup%/*} != "${second_backup%/*}" ]] || fail 'repeated reinstall did not create a unique backup'
[[ $(cat "$second_backup") == 'preserve this second file' ]] || fail 'second backup changed the existing contents'
bash ./install.sh --host codex --uninstall
[[ ! -e "$installed" ]] || fail 'uninstall left the skill directory behind'
[[ -f "$backup" && -f "$second_backup" ]] || fail 'uninstall removed a previous backup'
# The documented manual restore keeps the original content usable.
mv -- "${backup%/*}" "$installed"
[[ -f "$installed/SKILL.md" && $(cat "$installed/fresh-user-sentinel.txt") == 'preserve this local file' ]] || fail 'manual backup restore failed'

bash ./install.sh --uninstall --host codex

export CODEX_HOME="$HOME/custom codex"
bash ./install.sh --host codex
[[ -f "$installed/SKILL.md" ]] || fail 'CODEX_HOME incorrectly changed the shared skills destination'
[[ ! -e "$CODEX_HOME/skills/motion" ]] || fail 'CODEX_HOME redirected installation to a deprecated directory'
bash ./install.sh --host codex --uninstall
bash ./install.sh --dir "$HOME/custom skills" --host codex
[[ -f "$HOME/custom skills/motion/SKILL.md" ]] || fail '--dir installation failed'
[[ ! -e "$installed" ]] || fail '--dir did not override the default destination'
bash ./install.sh --uninstall --dir "$HOME/custom skills" --host codex
[[ ! -e "$HOME/custom skills/motion" ]] || fail '--dir uninstall failed'
unset CODEX_HOME

bash ./install.sh --host both
[[ -f "$installed/SKILL.md" && -f "$HOME/.claude/skills/motion/SKILL.md" ]] || fail '--host both did not install both destinations'
bash ./install.sh --host both --uninstall
[[ ! -e "$installed" && ! -e "$HOME/.claude/skills/motion" ]] || fail '--host both did not uninstall both destinations'
shared_backup_count=$(find "$backups" -mindepth 1 -maxdepth 1 -name 'motion.backup.*' -print | wc -l)
bash ./install.sh --host both --dir "$HOME/shared skills"
[[ -f "$HOME/shared skills/motion/SKILL.md" ]] || fail 'shared --dir installation failed'
[[ $(find "$backups" -mindepth 1 -maxdepth 1 -name 'motion.backup.*' -print | wc -l) -eq $shared_backup_count ]] || fail '--host both installed the shared destination twice'
printf 'shared local file\n' > "$HOME/shared skills/motion/shared-sentinel.txt"
bash ./install.sh --host both --dir "$HOME/shared skills"
shared_backup=$(find "$backups" -mindepth 2 -maxdepth 2 -path '*/motion.backup.*/shared-sentinel.txt' -print -quit)
[[ -n "$shared_backup" && $(cat "$shared_backup") == 'shared local file' ]] || fail 'shared reinstall did not retain the prior install'
[[ $(find "$backups" -mindepth 1 -maxdepth 1 -name 'motion.backup.*' -print | wc -l) -eq $((shared_backup_count + 1)) ]] || fail 'shared reinstall created more than one backup'
[[ $(find "$HOME/shared skills" -name SKILL.md -print) == "$HOME/shared skills/motion/SKILL.md" ]] || fail 'shared reinstall exposed a second skill'
bash ./install.sh --host both --dir "$HOME/shared skills" --uninstall
[[ ! -e "$HOME/shared skills/motion" && -f "$shared_backup" ]] || fail 'shared uninstall did not preserve backups'

# Control discovery without requiring either host to be installed on this machine.
bash_bin=$(command -v bash)
fixture_bin="$HOME/fixture-bin"
mkdir -p -- "$fixture_bin"
for command_name in dirname mkdir mktemp cp mv rm rmdir; do
  ln -s -- "$(command -v "$command_name")" "$fixture_bin/$command_name"
done
rm -rf -- "$HOME/.claude" "$HOME/.codex"
if PATH="$fixture_bin" "$bash_bin" ./install.sh > "$HOME/no-host-output" 2>&1; then
  fail 'default install succeeded when no hosts were present'
fi
grep -q -- '--host' "$HOME/no-host-output" || fail 'no-host failure did not explain how to select a host'

mkdir -p -- "$HOME/.codex"
PATH="$fixture_bin" "$bash_bin" ./install.sh
[[ -f "$installed/SKILL.md" && ! -e "$HOME/.claude/skills/motion" ]] || fail 'default install did not detect only the Codex config directory'
PATH="$fixture_bin" "$bash_bin" ./install.sh --uninstall
mkdir -p -- "$HOME/.claude"
PATH="$fixture_bin" "$bash_bin" ./install.sh
[[ -f "$installed/SKILL.md" && -f "$HOME/.claude/skills/motion/SKILL.md" ]] || fail 'default install did not detect both config directories'
PATH="$fixture_bin" "$bash_bin" ./install.sh --uninstall
rm -rf -- "$HOME/.claude" "$HOME/.codex"

for host_name in claude codex; do
  cat > "$fixture_bin/$host_name" <<'STUB'
#!/bin/sh
printf 'host executable was invoked\n' > "$HOME/host-command-executed"
exit 97
STUB
  chmod +x "$fixture_bin/$host_name"
done
PATH="$fixture_bin" "$bash_bin" ./install.sh
[[ -f "$installed/SKILL.md" && -f "$HOME/.claude/skills/motion/SKILL.md" ]] || fail 'default install did not detect host executables'
PATH="$fixture_bin" "$bash_bin" ./install.sh --uninstall
[[ ! -e "$HOME/host-command-executed" ]] || fail 'host discovery executed a host command'

for invalid_host in unknown ''; do
  if bash ./install.sh --host "$invalid_host" > "$HOME/invalid-output" 2>&1; then
    fail 'an invalid host was accepted'
  fi
  grep -qi 'host' "$HOME/invalid-output" || fail 'invalid host failure did not explain the problem'
done
for missing_argument in --host --dir; do
  if bash ./install.sh "$missing_argument" > "$HOME/invalid-output" 2>&1; then
    fail "$missing_argument accepted a missing argument"
  fi
  [[ -s "$HOME/invalid-output" ]] || fail "$missing_argument failure did not explain the problem"
done
if bash ./install.sh --unknown > "$HOME/invalid-output" 2>&1; then
  fail 'an unknown option was accepted'
fi
printf 'PASS fresh install (Codex): layout, metadata, host-neutral paths, unique backups, uninstall, overrides and host discovery\n'
