#!/usr/bin/env bash
# Runs every offline test layer (no Google Cloud access needed):
#   1. terraform fmt           formatting
#   2. terraform validate      module and submodule syntax, provider schema
#   3. terraform test          unit tests with a mocked provider (Terraform >= 1.7)
#   4. pytest tests/python     JSON Schema and documentation checks, and
#                              real-provider plans of every example (needs
#                              network access to download providers)
#
# Usage:   scripts/test.sh
# Options: TERRAFORM_BIN=/path/to/terraform  PYTHON=python3
#          GOOGLE_PROVIDER_VERSION=7.42.0 pins the provider for step 4.
# The live test (tests/python/test_live.py) runs only when CR_YAML_TEST_PROJECT
# is set; see docs/testing.md.
set -euo pipefail

cd "$(dirname "$0")/.."
TF="${TERRAFORM_BIN:-terraform}"
PY="${PYTHON:-python3}"

echo "==> terraform fmt"
"$TF" fmt -check -recursive

echo "==> terraform validate"
for dir in . modules/service modules/job modules/schedule; do
  (cd "$dir" && "$TF" init -input=false -backend=false >/dev/null && "$TF" validate)
done

echo "==> terraform test"
"$TF" test

echo "==> pytest"
TERRAFORM_BIN="$TF" "$PY" -m pytest tests/python -q
