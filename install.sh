#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
usage() {
  cat <<'USAGE'
Usage: bash install.sh [--host claude|codex|both] [--dir SKILLS_DIR] [--uninstall]

Without --host, install for each host found on PATH or with a configuration
directory. Explicit --host also works before the host is installed.
Claude: ${CLAUDE_HOME:-$HOME/.claude}/skills/motion
Codex:  $HOME/.agents/skills/motion
--dir overrides the skills parent directory for either or both hosts.
Reinstall keeps motion.backup.* under ${XDG_STATE_HOME:-$HOME/.local/state}/motion/backups.
--uninstall keeps those backups outside the skills directories.
USAGE
}

host=''
override_dir=''
uninstall=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      [[ $# -ge 2 ]] || fail '--host needs claude, codex, or both.'
      case "$2" in
        claude|codex|both) host="$2" ;;
        *) fail '--host must be claude, codex, or both.' ;;
      esac
      shift 2
      ;;
    --dir)
      [[ $# -ge 2 && -n $2 && $2 != -* ]] || fail '--dir needs a skills parent directory.'
      override_dir="$2"
      shift 2
      ;;
    --uninstall) uninstall=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) fail "Unknown argument: $1. Use --help for usage." ;;
  esac
done

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Git Bash (MSYS/Cygwin): use the Windows user profile as home and accept
# Windows-style paths such as C:\Users\me in the path variables and --dir.
# An explicit HOME always wins; USERPROFILE is used only when HOME is unset or empty.
home_dir=${HOME:-}
is_windows_shell=false
case "$(uname -s 2>/dev/null || true)" in
  MINGW*|MSYS*|CYGWIN*)
    if command -v cygpath >/dev/null 2>&1; then
      is_windows_shell=true
      if [[ -z $home_dir && -n ${USERPROFILE:-} ]]; then home_dir=$(cygpath -u "$USERPROFILE"); fi
    fi
    ;;
esac
unix_path() {
  if [[ $is_windows_shell == true && $1 =~ ^[A-Za-z]:[\\/] ]]; then cygpath -u "$1"; else printf '%s\n' "$1"; fi
}
[[ -n $home_dir ]] || fail 'HOME is not set. Set HOME (or USERPROFILE under Git Bash).'
claude_home=$(unix_path "${CLAUDE_HOME:-$home_dir/.claude}")
codex_home=$(unix_path "${CODEX_HOME:-$home_dir/.codex}")
state_home=$(unix_path "${XDG_STATE_HOME:-$home_dir/.local/state}")
[[ -z $override_dir ]] || override_dir=$(unix_path "$override_dir")
hosts=()
case "$host" in
  claude|codex) hosts=("$host") ;;
  both) hosts=(claude codex) ;;
  '')
    if command -v claude >/dev/null 2>&1 || [[ -d $claude_home ]]; then
      hosts+=(claude)
    fi
    if command -v codex >/dev/null 2>&1 || [[ -d $codex_home ]]; then
      hosts+=(codex)
    fi
    [[ ${#hosts[@]} -gt 0 ]] || fail 'No supported host detected. Choose --host claude, --host codex, or --host both.'
    ;;
esac

skills_dirs=()
for selected_host in "${hosts[@]}"; do
  if [[ -n $override_dir ]]; then
    skills_dir="$override_dir"
  elif [[ $selected_host == claude ]]; then
    skills_dir="$claude_home/skills"
  else
    skills_dir="$home_dir/.agents/skills"
  fi
  # A shared override is one installation, even when both hosts are selected.
  if [[ ${#skills_dirs[@]} -eq 0 || $skills_dir != "${skills_dirs[0]}" ]]; then
    skills_dirs+=("$skills_dir")
  fi
done

source_dir="$repo_dir/skill"
# Resolve existing symlinks and missing path components without creating them.
resolve_directory() (
  local directory="$1" parent leaf
  if [[ -d $directory ]]; then
    cd -P -- "$directory" && pwd -P
    return
  fi
  [[ ! -e $directory && ! -L $directory ]] || fail 'A directory path is blocked by a file or broken symlink.'
  directory=${directory%/}
  parent=$(resolve_directory "$(dirname -- "$directory")") || return
  leaf=${directory##*/}
  case "$leaf" in
    ''|.) printf '%s\n' "$parent" ;;
    ..) parent=${parent%/*}; printf '%s\n' "${parent:-/}" ;;
    *) printf '%s/%s\n' "${parent%/}" "$leaf" ;;
  esac
)

prepare_backups() {
  local root
  backup_root=$(resolve_directory "$state_home/motion/backups")
  # Check every selected and standard skills root, including missing roots,
  # before creating anything. Retained copies must never become discoverable.
  for root in "${skills_dirs[@]}" "$claude_home/skills" "$home_dir/.agents/skills" "$home_dir/.codex/skills"; do
    root=$(resolve_directory "$root")
    [[ $root != / && $backup_root != "$root" && $backup_root != "$root/"* ]] || fail 'Choose XDG_STATE_HOME outside all skills directories.'
  done
  mkdir -p -- "$backup_root"
}

install_skill() (
  skills_dir="$1"
  destination="$skills_dir/motion"
  mkdir -p -- "$skills_dir"
  staging=$(mktemp -d "$backup_root/.motion-install.XXXXXXXX")
  backup=''
  cleanup() {
    rm -rf -- "$staging"
    if [[ -n $backup && ! -e $destination && ! -L $destination ]]; then
      mv -- "$backup" "$destination"
    fi
  }
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  cp -R -- "$source_dir/." "$staging/"
  if [[ -e $destination || -L $destination ]]; then
    backup=$(mktemp -d "$backup_root/motion.backup.XXXXXXXX")
    rmdir -- "$backup"
    mv -- "$destination" "$backup"
    printf 'Previous install backed up to %s\n' "$backup"
  fi
  mv -- "$staging" "$destination"
  printf 'Installed motion in %s\n' "$destination"
)

if [[ $uninstall == false ]]; then
  [[ -f "$source_dir/SKILL.md" && -f "$source_dir/systems.json" ]] || fail 'The source skill directory is incomplete.'
fi
prepare_backups
for skills_dir in "${skills_dirs[@]}"; do
  if [[ $uninstall == true ]]; then
    rm -rf -- "$skills_dir/motion"
    printf 'Removed motion from %s. Existing backups were kept.\n' "$skills_dir"
  else
    install_skill "$skills_dir"
  fi
done
[[ $uninstall == false ]] || exit 0

for selected_host in "${hosts[@]}"; do
  if [[ $selected_host == claude ]]; then
    printf '%s\n' 'Next: open Claude Code in your project and ask /motion for a looping piece.'
  else
    printf '%s\n' 'Next: open Codex CLI in your project and ask $motion for a looping piece.'
  fi
done
command -v node >/dev/null 2>&1 || printf '%s\n' 'Note: Node.js was not found on PATH. Installing does not need it; contact sheets and MP4 export do.' >&2
printf '%s\n' 'Read README.md for optional Playwright (PW_DIR) and ffmpeg setup.'
