#!/usr/bin/env bash
# @req SCI-TRACE-001
# @req SCI-CI-001
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

declare -A valid_requirements=()
while IFS= read -r requirement_id; do
  valid_requirements["${requirement_id}"]=1
done < <(grep -oE 'SCI-[A-Z]+-[0-9]{3}' requirements.yaml | sort -u)

mapfile -d '' files < <(
  find charts ansible .github/workflows \
    \( -path 'ansible/.generated' -o -path 'ansible/.generated/*' \) -prune -o \
    -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.tpl' \) -print0 | sort -z
)

missing_annotations=()
orphan_annotations=()
workflow_job_annotation_errors=()

for file in "${files[@]}"; do
  if ! grep -Eq '@req[[:space:]]+SCI-' "${file}"; then
    missing_annotations+=("${file}")
  fi

  while IFS= read -r referenced_id; do
    [[ -z "${referenced_id}" ]] && continue
    if [[ -z "${valid_requirements[${referenced_id}]:-}" ]]; then
      orphan_annotations+=("${file}: ${referenced_id}")
    fi
  done < <(grep -oE 'SCI-[A-Z]+-[0-9]{3}' "${file}" | sort -u)
done

while IFS= read -r workflow_file; do
  [[ -z "${workflow_file}" ]] && continue

  while IFS=: read -r line_number job_key; do
    [[ -z "${line_number}" ]] && continue
    start_line=$(( line_number > 2 ? line_number - 2 : 1 ))

    if ! sed -n "${start_line},${line_number}p" "${workflow_file}" | grep -Eq '@req[[:space:]]+SCI-'; then
      workflow_job_annotation_errors+=("${workflow_file}:${line_number}: ${job_key%:}")
    fi
  done < <(
    awk '
      /^jobs:[[:space:]]*$/ { in_jobs=1; next }
      in_jobs && /^[^[:space:]]/ { in_jobs=0 }
      in_jobs && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ { print FNR ":" $1 }
    ' "${workflow_file}"
  )
done < <(find .github/workflows -type f \( -name '*.yaml' -o -name '*.yml' \) | sort)

if (( ${#missing_annotations[@]} > 0 )); then
  printf 'Unannotated files:\n'
  printf '  - %s\n' "${missing_annotations[@]}"
fi

if (( ${#orphan_annotations[@]} > 0 )); then
  printf 'Orphan @req references:\n'
  printf '  - %s\n' "${orphan_annotations[@]}"
fi

if (( ${#workflow_job_annotation_errors[@]} > 0 )); then
  printf 'Workflow jobs missing nearby @req comments:\n'
  printf '  - %s\n' "${workflow_job_annotation_errors[@]}"
fi

if (( ${#missing_annotations[@]} > 0 || ${#orphan_annotations[@]} > 0 || ${#workflow_job_annotation_errors[@]} > 0 )); then
  exit 1
fi

printf 'Traceability check passed for %s files.\n' "${#files[@]}"
