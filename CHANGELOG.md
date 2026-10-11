# Changelog

## 0.1.1

### Fixed

- MP4 export (`skill/scripts/export-mp4.sh`) creates the output folder before rendering on every operating system.
- Tests no longer use `find -printf` or require symlinks; where symlinks cannot be created, only the symlinked state-path case is skipped.

### Platforms

- Installer, MP4 export and tests work on stock macOS (BSD tools, Bash 3.2) and in Git Bash on native Windows.
- Under Git Bash, the installer keeps an explicit HOME and uses the Windows user profile (USERPROFILE) only when HOME is unset or empty. It accepts Windows-style paths and prints one note when Node.js is missing.
- MP4 export passes Windows-style paths to node and ffmpeg when `cygpath` exists.
- Text files stay LF in any checkout (`.gitattributes`).

### Changed

- State the 0.1.1 version, a platform table and Node.js LTS in the README.
- CI runs both fresh-user tests, the static check and `tests/test_ci_workflow.sh` on ubuntu, macOS and Windows (Git Bash) with Node LTS; fail-fast is off and every step runs after a failure, so each failing check is listed.

## 0.1.0

- 23 coded generative systems, each with a working, self-contained HTML template,
  plus an ordered registry and catalogue of mechanisms and loop recipes.
- Seeded contact sheets with 12 labeled previews, deterministic frame rendering,
  and optional MP4 export through Playwright and ffmpeg.
- Reduced-motion support that displays a finished still frame without playback.
- Installer for Claude Code and OpenAI Codex CLI, with shared skill content,
  custom directories, reinstall backups, and uninstall.
- Offline static, browser, and fresh-user tests for templates, contact sheets,
  MP4 export, and installation on both hosts. Tests never invoke either CLI or a model.
- Template contract, web hero guidance, and reference-based iteration recipes.
