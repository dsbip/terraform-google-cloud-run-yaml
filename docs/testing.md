# Testing

The module is tested in four layers. The first three need no Google Cloud access and run in CI on every push; the live test runs on demand.

| Layer | Tool | What it proves | Where |
|---|---|---|---|
| Static | `terraform fmt`, `terraform validate` | Formatting; valid HCL against the provider schema, for the root module and the three submodules | |
| Unit | `terraform test` with a mocked provider | Loading and templating, precedence, both defaults merges, every attribute from YAML to the planned service, job and scheduler job, secret modes, traffic, IAM, outputs, the submodules on their own, every validation message, every example | `tests/*.tftest.hcl` (60+ runs) |
| Plan | pytest + real provider, dummy credentials | Every example and the live fixture pass the real provider's validation and plan logic with the expected resource count; examples and fixtures match the JSON Schema; the schema stays readable by `validation.tf`; the complete example uses every key; every key is documented; links resolve | `tests/python/` |
| Live | pytest + real provider, real project | A service, a job and a schedule deploy, a second plan is empty (no drift), in-place updates work, destroy is clean | `tests/python/test_live.py`, `tests/integration/` |

## Requirements

- Terraform >= 1.7 for the unit tests (mock providers); the module itself supports >= 1.5
- Python >= 3.9 with `pip install -r tests/python/requirements.txt` (pytest, PyYAML, jsonschema)
- Network access to download providers

## Running the tests

Everything offline, in one command:

```bash
scripts/test.sh
```

Or step by step from the repository root:

```bash
terraform fmt -check -recursive
terraform init -backend=false && terraform validate
terraform test                                    # unit tests
python -m pytest tests/python -v                  # schema, docs and real-provider plans
```

A single unit test file: `terraform test -filter=tests/validation.tftest.hcl`.

To check the minimum versions, run the plan tests with Terraform 1.5.7 and pin the provider:

```bash
TERRAFORM_BIN=/path/to/terraform-1.5.7 GOOGLE_PROVIDER_VERSION=7.42.0 python -m pytest tests/python -v
```

## Unit tests

| File | Covers |
|---|---|
| `config.tftest.hcl` | `config_file` templating (placeholders, expressions, `%{ if }`, `$${`), `config_yaml`, `yamlencode()`, blank files, project/region/label precedence, entry and container defaults merges, nulls, names, `enabled` |
| `services.tftest.hcl` | every service and template attribute, Direct VPC and GPUs, containers (env, secrets, ports, resources, mounts), every probe type, every volume type with octal and decimal modes, traffic forms |
| `jobs.tftest.hcl` | job attributes, the split into execution and task template, execution tokens, containers, volumes, the run URI |
| `schedules.tftest.hcl` | service schedules (URI, OIDC audience, body, headers, retries, regions) and job schedules (Admin API URI, OAuth, override bodies) |
| `iam.tftest.hcl` | invokers and grants, duplicates, skipped redundant invoker grants, conditions (`command = apply`) |
| `modules.tftest.hcl` | `modules/service`, `modules/job` and `modules/schedule` called directly, with their input validation |
| `validation.tftest.hcl` | every validation message, as complete sets, including the deepest level of defaults |
| `examples.tftest.hcl` | the behaviour each example's README describes |
| `outputs.tftest.hcl` | outputs after a mocked apply |

Validation tests plant several mistakes and compare the complete set of messages, so a missing message and a spurious extra one both fail:

```hcl
run "rules_beyond_the_schema" {
  command         = plan
  variables { config_yaml = <<-EOT ... EOT }
  expect_failures = [terraform_data.validation]
  assert {
    condition = toset(local.validation_errors) == toset([
      "services.multi.template.containers: the name \"a\" is used 2 times",
      ...
    ])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}
```

## Plan tests

`test_example_plans.py` copies the repository to a temporary directory and runs `terraform init` and `terraform plan -refresh=false` in every example with a dummy `GOOGLE_OAUTH_ACCESS_TOKEN`. The provider needs no API calls to plan new resources, so the plans exercise its full validation and diff logic offline. Each test checks the exact number of planned resources. The live-test fixture is planned the same way with every option enabled, so it stays deployable.

## Live test

The live test deploys `tests/integration/` into a real project: a service (Google's sample image, a startup probe and an in-memory volume) and a job, plus an invoker grant and a paused job schedule when a member and a scheduler service account are given. It then runs:

1. `apply`
2. `plan -detailed-exitcode` must report no changes (catches permanent diffs)
3. `apply` with a changed description, label and environment variables (in-place updates, new revision)
4. another empty plan
5. `destroy` (always, also after a failure)

All names start with `crun-<random>`, the service scales to at most one instance, the job is never executed and the schedule is paused, so a run costs next to nothing.

```bash
gcloud auth application-default login
export CR_YAML_TEST_PROJECT=my-sandbox-project
export CR_YAML_TEST_REGION=europe-west1                                          # optional
export CR_YAML_TEST_MEMBER=user:me@example.com                                   # optional: invoker grant
export CR_YAML_TEST_SCHEDULER=scheduler@my-sandbox-project.iam.gserviceaccount.com  # optional: job schedule
python -m pytest tests/python/test_live.py -v
```

The project needs the Cloud Run Admin API (and Cloud Scheduler for the schedule). The identity needs `roles/run.admin`, `roles/iam.serviceAccountUser` and, for the schedule, `roles/cloudscheduler.admin`. If a run is interrupted before its destroy step, delete the leftover `crun-*` services, jobs and scheduler jobs by hand.

The **Live test** workflow runs the same test from GitHub Actions. To enable it:

1. Create a Workload Identity Federation provider for the repository.
2. Set the repository variables `CR_YAML_TEST_PROJECT`, `GCP_WORKLOAD_IDENTITY_PROVIDER` and `GCP_SERVICE_ACCOUNT`.
3. Start the workflow from the Actions tab.

## Continuous integration

`.github/workflows/ci.yml` runs on pushes to `main` and on pull requests:

| Job | Terraform | Provider |
|---|---|---|
| fmt and validate | latest | latest |
| terraform test | 1.7.5, latest | 7.42.0, latest (4 combinations) |
| example plans, schema and docs tests | 1.5.7 with 7.42.0 (the minimums), latest with latest | |

## Adding a feature

1. Add the key to its definition in `schemas/cloud-run-config.schema.json` (with a description; enumerations, ranges and patterns are enforced automatically).
2. Add it to the variable type in `modules/service/variables.tf` or `modules/job/variables.tf` and pass it to the resource.
3. Add a rule to `validation.tf` part 2 if invalid combinations are possible, with a message that starts with the YAML path.
4. Add a unit test for the planned attribute, and a validation test if you added a rule.
5. Use it in `examples/complete` and document it in `docs/services.md` or `docs/jobs.md` (tests fail otherwise).
