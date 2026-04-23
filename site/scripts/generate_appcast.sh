#!/usr/bin/env bash

set -euo pipefail

INPUT_DIR="${1:-}"
OUTPUT_DIR="${2:-./site/static}"
RELEASE_TAG="${3:-}"
REPO="${4:-${GITHUB_REPOSITORY:-}}"
RELEASE_CHANNEL="${5:-}"
RELEASE_VERSION="${RELEASE_TAG#v}"
RELEASE_BUILD_VERSION="$(printf '%s' "${RELEASE_VERSION}" | sed -E 's/-beta\.([0-9]+)$/b\1/; s/-.*$//')"

if [[ -z "${INPUT_DIR}" || -z "${RELEASE_TAG}" || -z "${REPO}" ]]; then
  echo "Missing required argument(s)" >&2
  echo "Usage: ./site/scripts/generate_appcast.sh <input-dir> <output-dir> <release-tag> <repo> [channel]" >&2
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

collect_assets() {
  local pattern="$1"
  local file_name

  shopt -s nullglob
  for file_name in "${INPUT_DIR}"/*; do
    if [[ -f "${file_name}" && "$(basename "${file_name}")" =~ ${pattern} ]]; then
      printf '%s\n' "${file_name}"
    fi
  done
  shopt -u nullglob
}

generate_feed_for_arch() {
  local arch_label="$1"
  local pattern="$2"
  local output_file="$3"
  local appcast_name
  appcast_name="$(basename "${output_file}")"
  local appcast_path

  local arch_tmpdir="${TMPDIR_ROOT}/${arch_label}"
  appcast_path="${arch_tmpdir}/${appcast_name}"
  rm -rf "${arch_tmpdir}"
  mkdir -p "${arch_tmpdir}"

  if [[ -f "${output_file}" ]]; then
    cp "${output_file}" "${appcast_path}"
  fi

  local asset_path
  local -a arch_assets=()
  while IFS= read -r asset_path; do
    arch_assets+=("${asset_path}")
  done < <(collect_assets "${pattern}")

  local -a selected_assets=()
  local -a selected_versions=()
  local asset_name
  local asset_version
  local selected_index
  local i

  for asset_path in "${arch_assets[@]}"; do
    asset_name="$(basename "${asset_path}")"

    if [[ "${asset_name}" != *"-${RELEASE_VERSION}."* ]]; then
      continue
    fi

    if [[ "${asset_name}" =~ ^AudioVideoMerger-darwin-(arm64|x86_64|x64)-(.+)\.(dmg|zip)$ ]]; then
      asset_version="${BASH_REMATCH[2]}"
      selected_index=""

      for i in "${!selected_versions[@]}"; do
        if [[ "${selected_versions[$i]}" == "${asset_version}" ]]; then
          selected_index="${i}"
          break
        fi
      done

      if [[ -z "${selected_index}" ]]; then
        selected_versions+=("${asset_version}")
        selected_assets+=("${asset_path}")
      elif [[ "${selected_assets[$selected_index]}" == *.zip && "${asset_path}" == *.dmg ]]; then
        selected_assets[$selected_index]="${asset_path}"
      fi
    else
      selected_assets+=("${asset_path}")
    fi
  done

  if [[ "${#selected_assets[@]}" -eq 0 ]]; then
    echo "Missing ${arch_label} assets in ${INPUT_DIR}" >&2
    exit 1
  fi

  local matched_release_asset=false
  for asset_path in "${selected_assets[@]}"; do
    if [[ "$(basename "${asset_path}")" == *"-${RELEASE_VERSION}."* ]]; then
      matched_release_asset=true
    fi
    cp "${asset_path}" "${arch_tmpdir}/"
  done

  if [[ "${matched_release_asset}" != "true" ]]; then
    echo "Missing ${arch_label} release asset for ${RELEASE_VERSION} in ${INPUT_DIR}" >&2
    exit 1
  fi

  local channel_args=()
  if [[ -n "${RELEASE_CHANNEL}" ]]; then
    channel_args=(--channel "${RELEASE_CHANNEL}")
  fi

  "${SPARKLE_GENERATE_APPCAST}" \
    "${arch_tmpdir}" \
    -o "${appcast_path}" \
    --disable-nested-code-check \
    --maximum-versions 1 \
    --versions "${RELEASE_BUILD_VERSION}" \
    --download-url-prefix "https://github.com/${REPO}/releases/download/${RELEASE_TAG}/" \
    --link "https://audiovideomerger.github.io" \
    --full-release-notes-url "https://github.com/${REPO}/releases" \
    "${channel_args[@]}"

  cp "${appcast_path}" "${output_file}"

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
