#!/usr/bin/env bash
# Verifies that modules from this checkout and modules from release 2.0.0
# reject each other, by planning tests-compatibility/published-releases with a
# mocked provider and checking the errors of that plan.
#
# Run from the repository root after:
#   tofu init -backend=false -test-directory=tests-compatibility
set -euo pipefail

# The test fails by design, so the errors are checked, not the exit status.
json=$(tofu test -json -test-directory=tests-compatibility || true)

# One line per error: its summary and its detail, with line breaks removed.
errors=$(jq -r 'select(.type == "diagnostic" and .diagnostic.severity == "error")
  | .diagnostic | "\(.summary): \(.detail // "" | gsub("\\s+"; " "))"' <<<"$json")
printf 'Errors from the plan:\n%s\n\n' "$errors"

release=$(<VERSION)
failed=0

expect() { # <description> <grep option> <pattern>
  local count
  count=$(grep -c "$2" -- "$3" <<<"$errors" || true)
  if [ "$count" -ne 1 ]; then
    echo "Expected exactly one error for $1, found $count."
    failed=1
  fi
}

# The zone modules from release 2.0.0 reject the zone object of this enclave module.
missing_attribute='declared at .*: attribute "template_version" is required\.$'
expect "the published single-AZ zone module" -E \
  "^Invalid value for input variable: The given value is not suitable for module\.published_zone\.var\.zone $missing_attribute"
expect "the published multi-AZ zone module" -E \
  "^Invalid value for input variable: The given value is not suitable for module\.published_zone_multi_az\.var\.zone $missing_attribute"

# The zone modules of this checkout reject the zone object of the 2.0.0 enclave module.
for zone in prod.aws-us-east-1c prod.aws-us-east-1; do
  expect "the zone module of $zone" -Fx \
    "Resource precondition failed: Zone $zone uses zone module release $release, but its zone object comes from enclave module release 2.0.0. The enclave module and all of its zone modules must be installed at the same release. Set every module block to the same version, $release or newer, then run init -upgrade."
done

if [ "$(grep -c . <<<"$errors" || true)" -ne 4 ]; then
  echo "Expected exactly four errors."
  failed=1
fi

if [ "$failed" -ne 0 ]; then
  echo "The plan did not fail with exactly the expected errors."
  exit 1
fi
echo "All pairings with release 2.0.0 were rejected as expected."
