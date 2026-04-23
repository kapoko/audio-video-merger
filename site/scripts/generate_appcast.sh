#!/usr/bin/env bash

set -euo pipefail

INPUT_DIR="${1:-}"
OUTPUT_DIR="${2:-./site/static}"
RELEASE_TAG="${3:-}"
REPO="${4:-${GITHUB_REPOSITORY:-}}"

if [[ -z "${INPUT_DIR}" || -z "${RELEASE_TAG}" || -z "${REPO}" ]]; then
  echo "Missing required argument(s)" >&2
  echo "Usage: ./site/scripts/generate_appcast.sh <input-dir> <output-dir> <release-tag> <repo>" >&2
  exit 1
fi

if [[ ! -d "${INPUT_DIR}" ]]; then
  echo "Input directory not found: ${INPUT_DIR}" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SPARKLE_GENERATE_APPCAST="${REPO_ROOT}/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"

if [[ ! -x "${SPARKLE_GENERATE_APPCAST}" ]]; then
  echo "Sparkle generate_appcast not found at ${SPARKLE_GENERATE_APPCAST}" >&2
  exit 1
fi

IS_PRERELEASE=0
if [[ "${RELEASE_TAG}" == *-* ]]; then
  IS_PRERELEASE=1
fi

find_asset() {
  local pattern="$1"
  local file_name
  local asset=""

  shopt -s nullglob
  for file_name in "${INPUT_DIR}"/*; do
    if [[ -f "${file_name}" && "$(basename "${file_name}")" =~ ${pattern} ]]; then
      asset="${file_name}"
      break
    fi
  done
  shopt -u nullglob

  if [[ -n "${asset}" ]]; then
    printf '%s\n' "${asset}"
    return 0
  fi

  return 1
}

generate_feed_for_arch() {
  local arch_label="$1"
  local pattern="$2"
  local output_file="$3"

  local arch_tmpdir="${TMPDIR_ROOT}/${arch_label}"
  rm -rf "${arch_tmpdir}"
  mkdir -p "${arch_tmpdir}"

  local asset_path
  if ! asset_path="$(find_asset "${pattern}")"; then
    echo "Missing ${arch_label} release asset in ${INPUT_DIR}" >&2
    exit 1
  fi

  cp "${asset_path}" "${arch_tmpdir}/"

  local channel_args=()
  if [[ "${IS_PRERELEASE}" -eq 1 ]]; then
    channel_args=(--channel beta)
  fi

  "${SPARKLE_GENERATE_APPCAST}" \
    "${arch_tmpdir}" \
    -o "${output_file}" \
    --download-url-prefix "https://github.com/${REPO}/releases/download/${RELEASE_TAG}/" \
    --link "https://audiovideomerger.github.io" \
    --full-release-notes-url "https://github.com/${REPO}/releases" \
    "${channel_args[@]}"

  if [[ ! -f "${output_file}" ]]; then
    echo "Failed to produce ${output_file}" >&2
    exit 1
  fi
}

mkdir -p "${OUTPUT_DIR}"
TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT

generate_feed_for_arch \
  "arm64" \
  'AudioVideoMerger-darwin-arm64-.*\.(dmg|zip)$' \
  "${OUTPUT_DIR}/appcast-arm64.xml"

generate_feed_for_arch \
  "x86_64" \
  'AudioVideoMerger-darwin-(x86_64|x64)-.*\.(dmg|zip)$' \
  "${OUTPUT_DIR}/appcast-x86_64.xml"

echo "Generated Sparkle appcasts:"
echo "- ${OUTPUT_DIR}/appcast-arm64.xml"
echo "- ${OUTPUT_DIR}/appcast-x86_64.xml"
