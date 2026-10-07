#!/usr/bin/env bash
# Export numbered loop frames through ffmpeg without retaining intermediate PNGs.
set -euo pipefail

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
usage='Usage: bash export-mp4.sh <template.html> <output.mp4> [--fps 30] [--duration 4] [--width 1280] [--height 720] [--seed 1]'
[[ $# -ge 2 ]] || fail "$usage"
command -v ffmpeg >/dev/null 2>&1 || fail 'ffmpeg was not found. Install ffmpeg and put it on PATH to export MP4.'
command -v node >/dev/null 2>&1 || fail 'Node.js was not found. Install Node.js and put it on PATH.'

template=$1
output=$2
shift 2
fps=30
options=("$@")
while (( $# )); do
  [[ $# -ge 2 ]] || fail "Missing value for $1. $usage"
  case "$1" in
    --fps) fps=$2 ;;
    --duration|--width|--height|--seed) ;;
    *) fail "Unknown option: $1. $usage" ;;
  esac
  shift 2
done
crf=${CRF:-23}
[[ $crf =~ ^[0-9]+$ ]] && (( 10#$crf <= 51 )) || fail 'CRF must be an integer from 0 to 51.'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
frames_dir=$(mktemp -d "${TMPDIR:-/tmp}/motion-frames.XXXXXXXX")
cleanup() { rm -rf -- "$frames_dir"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

node "$script_dir/render-frames.mjs" "$template" "$frames_dir" "${options[@]}"
mkdir -p -- "$(dirname -- "$output")"
ffmpeg -nostdin -y -loglevel error -framerate "$fps" -start_number 0 \
  -i "$frames_dir/frame-%05d.png" -vf 'pad=ceil(iw/2)*2:ceil(ih/2)*2' \
  -c:v libx264 -pix_fmt yuv420p -crf "$crf" -movflags +faststart -an "$output"
printf 'Wrote %s\n' "$output"
