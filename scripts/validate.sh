#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ENVIRONMENTS_DIR="${ROOT_DIR}/environments"
SELECTED_ENVIRONMENT="${1:-all}"
all_environments=(dev staging prod)

required_commands=(terraform tflint checkov trivy infracost)

for command_name in "${required_commands[@]}"; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "${command_name}" >&2
    exit 1
  fi
done

case "${SELECTED_ENVIRONMENT}" in
  all)
    environments=("${all_environments[@]}")
    ;;
  dev | staging | prod)
    environments=("${SELECTED_ENVIRONMENT}")
    ;;
  *)
    printf 'Usage: %s [all|dev|staging|prod]\n' "$0" >&2
    exit 1
    ;;
esac

auto_vars_files=()
cleanup() {
  rm -f "${auto_vars_files[@]}"
}

trap cleanup EXIT INT TERM

for environment_name in "${all_environments[@]}"; do
  auto_vars_file="${ENVIRONMENTS_DIR}/${environment_name}/infracost.auto.tfvars"
  if [[ -e "${auto_vars_file}" ]]; then
    printf 'Refusing to overwrite existing file: %s\n' "${auto_vars_file}" >&2
    exit 1
  fi

  cp "${ENVIRONMENTS_DIR}/${environment_name}/terraform.tfvars.example" "${auto_vars_file}"
  auto_vars_files+=("${auto_vars_file}")
done

printf '%s\n' 'Running Terraform and security validation...'
terraform fmt -check -recursive "${ROOT_DIR}"
terraform -chdir="${ROOT_DIR}/bootstrap" init -backend=false -input=false >/dev/null
terraform -chdir="${ROOT_DIR}/bootstrap" validate

for environment_name in "${environments[@]}"; do
  environment_dir="${ENVIRONMENTS_DIR}/${environment_name}"
  terraform -chdir="${environment_dir}" init -backend=false -input=false >/dev/null
  terraform -chdir="${environment_dir}" validate
  tflint --chdir="${environment_dir}" --recursive

  case "${environment_name}" in
    dev)
      checkov -d "${environment_dir}" --framework terraform --quiet --compact \
        --skip-check CKV_AWS_139,CKV_AWS_338
      ;;
    staging)
      checkov -d "${environment_dir}" --framework terraform --quiet --compact \
        --skip-check CKV_AWS_338
      ;;
    prod)
      checkov -d "${environment_dir}" --framework terraform --quiet --compact
      ;;
  esac
done

trivy --quiet config "${ROOT_DIR}" --severity HIGH,CRITICAL --exit-code 1

printf '\nRunning repository-wide Infracost scan...\n'
infracost scan "${ROOT_DIR}" --include-warnings >/dev/null

for environment_name in "${environments[@]}"; do
  project_name="environments-${environment_name}"
  printf '\nInspecting Infracost results for %s...\n' "${environment_name}"

  summary="$(infracost inspect --project "${project_name}" --summary --fields monthly_cost,failing_policies,critical_diagnostics --llm)"
  printf '%s\n' "${summary}"

  monthly_cost="$(printf '%s\n' "${summary}" | awk -F': ' '$1 == "monthly_cost" { value = $2; gsub(/[\$"]/ , "", value); print value }')"
  failing_policies="$(printf '%s\n' "${summary}" | awk -F': ' '$1 == "failing_policies" { value = $2; gsub(/"/, "", value); print value }')"
  critical_diagnostics="$(printf '%s\n' "${summary}" | awk -F': ' '$1 == "critical_diagnostics" { value = $2; gsub(/"/, "", value); print value }')"

  case "${environment_name}" in
    dev)
      monthly_budget="${INFRACOST_DEV_MONTHLY_BUDGET:-155}"
      ;;
    staging)
      monthly_budget="${INFRACOST_STAGING_MONTHLY_BUDGET:-275}"
      ;;
    prod)
      monthly_budget="${INFRACOST_PROD_MONTHLY_BUDGET:-350}"
      ;;
  esac

  if [[ "${critical_diagnostics}" != "0" ]]; then
    printf 'Infracost reported %s critical diagnostics for %s.\n' "${critical_diagnostics}" "${environment_name}" >&2
    infracost inspect --project "${project_name}" --diagnostics >&2
    exit 1
  fi

  if ! awk -v cost="${monthly_cost}" -v budget="${monthly_budget}" 'BEGIN { exit !(cost <= budget) }'; then
    printf 'Estimated monthly cost $%s exceeds the %s budget of $%s.\n' "${monthly_cost}" "${environment_name}" "${monthly_budget}" >&2
    exit 1
  fi

  if [[ "${failing_policies}" != "0" ]]; then
    printf '%s has unexpected FinOps policy failures.\n' "${environment_name}" >&2
    infracost inspect --project "${project_name}" --failing >&2
    exit 1
  fi
done

printf '\nAll infrastructure validation checks passed.\n'